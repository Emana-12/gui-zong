## ShaderManager — 材质池 + 公共 API + 自动降级
##
## 设计参考:
## - design/gdd/shader-rendering.md §Public API
## - docs/architecture/adr-0003-rendering-pipeline-architecture.md §Key Interfaces
##
## Autoload 单例，管理所有水墨着色器材质实例。
## 材质池上限 15 个实例，哈希去重，零热路径分配。
## @see S02-01

class_name ShaderManager
extends Node

# --- 常量 ---

## 材质池上限
const MAX_POOL_SIZE: int = 15

## 自动降级阈值
const DEGRADE_FPS_THRESHOLD: int = 30
const CRITICAL_FPS_THRESHOLD: int = 20

## 降级后的 ink_steps 值
const DEGRADED_INK_STEPS: int = 2

## FPS 采样窗口（帧数）
const FPS_SAMPLE_WINDOW: int = 60

# --- 预加载着色器 ---

const SHD_INK_CHARACTER: Shader = preload("res://shaders/shd_ink_character.gdshader")
const SHD_INK_ENVIRONMENT: Shader = preload("res://shaders/shd_ink_environment.gdshader")
const SHD_LIGHT_TRAIL: Shader = preload("res://shaders/shd_light_trail.gdshader")

# --- 材质池 ---

## 哈希 → ShaderMaterial 映射
var _material_pool: Dictionary = {}

## 池中当前实例数
var _pool_count: int = 0

# --- 状态 ---

## 后处理是否启用
var _post_process_enabled: bool = true

## 当前是否处于降级模式
var _degraded: bool = false

## FPS 采样累加器
var _fps_accumulator: float = 0.0
var _fps_frame_count: int = 0
var _cached_fps: int = 60

# --- 生命周期 ---

func _ready() -> void:
	# 预创建基础材质
	_preload_base_materials()


func _process(delta: float) -> void:
	_update_fps(delta)
	_check_degradation()


# --- 公共 API ---

## 获取或创建命名材质（材质池入口）
## @param name 材质标识符（用作哈希键）
## @param shader 目标着色器
## @return ShaderMaterial 或 null（池满时）
func get_material(mat_name: StringName, shader: Shader = SHD_INK_ENVIRONMENT) -> Material:
	if _material_pool.has(mat_name):
		return _material_pool[mat_name]

	if _pool_count >= MAX_POOL_SIZE:
		push_warning("ShaderManager: 材质池已满 (%d/%d)，拒绝创建 '%s'" % [_pool_count, MAX_POOL_SIZE, mat_name])
		return null

	var mat := ShaderMaterial.new()
	mat.shader = shader
	_material_pool[mat_name] = mat
	_pool_count += 1
	return mat


## 创建轨迹材质（带颜色参数）
## @param color 轨迹颜色
## @param alpha 轨迹透明度
## @return ShaderMaterial 或 null
func create_trail_material(color: Color, alpha: float) -> Material:
	var hash_key: StringName = StringName("trail_%s_%s" % [color.to_html(), str(alpha)])
	var mat := get_material(hash_key, SHD_LIGHT_TRAIL)
	if mat:
		mat.set_shader_parameter("trail_color", Vector3(color.r, color.g, color.b))
		mat.set_shader_parameter("trail_alpha", alpha)
	return mat


## 设置角色高光强度
## @param intensity 0.0（学徒/无高光）~ 1.0（剑圣/满高光）
func set_character_highlight(intensity: float) -> void:
	var mat := get_material(&"character_default", SHD_INK_CHARACTER)
	if mat:
		mat.set_shader_parameter("highlight_intensity", clampf(intensity, 0.0, 1.0))


## 启用/禁用后处理通道
## @param pass_name 通道名称
## @param enabled 是否启用
func set_post_process_enabled(pass_name: StringName, enabled: bool) -> void:
	_post_process_enabled = enabled
	# 后处理具体实现在 ADR-0003 §Post-Processing 中定义
	# 此处仅记录状态，后续 post-process 节点查询此标志
	_notify_post_process_change(pass_name, enabled)


## 获取当前 FPS
## @return 缓存的 FPS 值（每 FPS_SAMPLE_WINDOW 帧更新一次）
func get_fps() -> int:
	return _cached_fps


## 获取材质池使用情况
## @return [当前数量, 最大数量]
func get_pool_usage() -> Array:
	return [_pool_count, MAX_POOL_SIZE]


## 检查是否处于降级模式
## @return true 表示已因性能不足自动降级
func is_degraded() -> bool:
	return _degraded


## 重置降级状态（场景切换时调用）
func reset_degradation() -> void:
	_degraded = false
	_post_process_enabled = true


# --- 内部方法 ---

func _preload_base_materials() -> void:
	# 预创建最常用的材质，避免首次使用时的分配
	get_material(&"character_default", SHD_INK_CHARACTER)
	get_material(&"environment_default", SHD_INK_ENVIRONMENT)
	get_material(&"environment_degraded", SHD_INK_ENVIRONMENT)


func _update_fps(delta: float) -> void:
	_fps_accumulator += delta
	_fps_frame_count += 1

	if _fps_frame_count >= FPS_SAMPLE_WINDOW:
		_cached_fps = int(round(float(_fps_frame_count) / _fps_accumulator))
		_fps_accumulator = 0.0
		_fps_frame_count = 0


func _check_degradation() -> void:
	var fps := get_fps()

	if fps < CRITICAL_FPS_THRESHOLD:
		# 严重降级：ink_steps = 2，关闭后处理
		if not _degraded:
			_degraded = true
			_post_process_enabled = false
			_apply_degraded_ink_steps()
			push_warning("ShaderManager: FPS < %d，严重降级模式激活" % CRITICAL_FPS_THRESHOLD)

	elif fps < DEGRADE_FPS_THRESHOLD:
		# 轻度降级：关闭后处理
		if _post_process_enabled:
			_post_process_enabled = false
			_degraded = true
			push_warning("ShaderManager: FPS < %d，关闭后处理" % DEGRADE_FPS_THRESHOLD)


func _apply_degraded_ink_steps() -> void:
	var env_mat := _material_pool.get(&"environment_degraded") as ShaderMaterial
	if env_mat:
		env_mat.set_shader_parameter("ink_steps", DEGRADED_INK_STEPS)


func _notify_post_process_change(pass_name: StringName, enabled: bool) -> void:
	# 后处理节点通过信号监听变化
	# 具体连接在场景树中完成
	pass
