## LevelSceneManager — 关卡/场景管理器
##
## 管理 2 个竞技场区域（山石/水竹）的加载、切换和重置。
## 场景使用 PackedScene 预加载，运行时实例化和销毁。
##
## 场景结构（需在 .tscn 中构建）:
## SceneManager (Node)
## ├── ActiveScene (Node3D) — 当前竞技场实例的容器
## ├── FadeOverlay (CanvasLayer, layer=100)
## │   └── FadeRect (ColorRect, full_rect, black)
## └── level_scene_manager.gd (本脚本)
##
## 注册方式: 作为场景节点添加到主场景树，不是 Autoload。
##
## 信号:
## - [signal scene_changed]: 场景切换完成后发出 (scene_name)
## - [signal scene_reset]: 场景重置完成后发出
##
## 使用示例:
##   var manager: LevelSceneManager = $SceneManager
##   manager.change_scene("bamboo")
##   manager.reset_scene()
##   var points: PackedVector3Array = manager.get_spawn_points()
##
class_name LevelSceneManager
extends Node

## 场景切换完成后发出。参数: (scene_name: String)
signal scene_changed(scene_name: String)

## 场景重置完成后发出。
signal scene_reset()

## 竞技场 PackedScene 预加载字典。
## 键为场景名称，值为对应的 PackedScene 资源。
const ARENA_SCENES: Dictionary = {
	"mountain": preload("res://scenes/arenas/ArenaMountain.tscn"),
	"bamboo": preload("res://scenes/arenas/ArenaBamboo.tscn"),
}

## 默认场景名称
const DEFAULT_SCENE: String = "mountain"

## Fade 动画持续时间（秒）
@export_range(0.0, 1.0, 0.05) var fade_duration: float = 0.3

## Web 端加载超时时间（秒）
@export_range(1.0, 15.0, 0.5) var scene_load_timeout: float = 5.0

## ActiveScene 容器节点路径 — 存放当前竞技场实例
@export var active_scene_path: NodePath = ^"ActiveScene"

## FadeOverlay CanvasLayer 节点路径
@export var fade_overlay_path: NodePath = ^"FadeOverlay"

## FadeRect ColorRect 节点路径（FadeOverlay 的子节点）
@export var fade_rect_path: NodePath = ^"FadeOverlay/FadeRect"

## 当前场景名称（只读，通过 get_current_scene() 访问）
var _current_scene: String = ""

## 当前场景实例的引用（ActiveScene 的子节点）
var _active_instance: Node3D = null

## 场景切换互斥锁 — 防止重入
var _transitioning: bool = false

## ActiveScene 容器引用
var _active_scene_container: Node3D

## FadeRect 引用
var _fade_rect: ColorRect

## Web 超时回退计时器
var _timeout_timer: Timer


func _ready() -> void:
	# 缓存节点引用
	_active_scene_container = get_node_or_null(active_scene_path) as Node3D
	if _active_scene_container == null:
		push_error("LevelSceneManager: ActiveScene container not found at path '%s'" % active_scene_path)
		return

	_fade_rect = get_node_or_null(fade_rect_path) as ColorRect
	if _fade_rect == null:
		push_warning("LevelSceneManager: FadeRect not found at path '%s' — fade transitions disabled" % fade_rect_path)

	# 初始化 FadeRect 为不可见
	if _fade_rect:
		_fade_rect.visible = false
		_fade_rect.color.a = 0.0

	# 创建超时计时器
	_timeout_timer = Timer.new()
	_timeout_timer.one_shot = true
	_timeout_timer.wait_time = scene_load_timeout
	_timeout_timer.timeout.connect(_on_load_timeout)
	add_child(_timeout_timer)

	# 加载默认场景
	_load_scene(DEFAULT_SCENE)


## 切换到指定场景。
##
## 执行流程: fade_out -> queue_free 旧场景 -> instantiate 新场景 -> add_child -> fade_in
##
## 场景名称必须是 ARENA_SCENES 字典中的键（"mountain" 或 "bamboo"）。
##
## [param scene_name]: 目标场景名称
##
## 使用示例:
##   change_scene("bamboo")
func change_scene(scene_name: String) -> void:
	# 校验
	if _transitioning:
		push_warning("LevelSceneManager: Scene transition already in progress, ignoring '%s'" % scene_name)
		return

	if not ARENA_SCENES.has(scene_name):
		push_error("LevelSceneManager: Unknown scene name '%s'. Valid: %s" % [scene_name, ARENA_SCENES.keys()])
		return

	if scene_name == _current_scene:
		return

	_transitioning = true

	# Fade to black
	await _fade_to_black()

	# 清除旧场景实例
	_clear_active_scene()

	# 实例化新场景
	_start_timeout_timer()
	_active_instance = ARENA_SCENES[scene_name].instantiate() as Node3D
	_stop_timeout_timer()

	if _active_instance == null:
		push_error("LevelSceneManager: Failed to instantiate scene '%s'" % scene_name)
		# 回退到默认场景
		_active_instance = ARENA_SCENES[DEFAULT_SCENE].instantiate() as Node3D
		_current_scene = DEFAULT_SCENE
	else:
		_current_scene = scene_name

	_active_scene_container.add_child(_active_instance)

	# Fade from black
	await _fade_from_black()

	_transitioning = false

	# 发出切换完成信号
	scene_changed.emit(_current_scene)


## 重置当前场景 — 销毁并重新实例化。
##
## RESTART 状态时调用。销毁当前实例，重新实例化同一场景。
##
## 使用示例:
##   reset_scene()
func reset_scene() -> void:
	if _transitioning:
		push_warning("LevelSceneManager: Scene transition already in progress, ignoring reset")
		return

	if _current_scene.is_empty():
		push_warning("LevelSceneManager: No scene loaded, nothing to reset")
		return

	var scene_name: String = _current_scene
	_transitioning = true

	# Fade to black
	await _fade_to_black()

	# 清除旧场景实例
	_clear_active_scene()

	# 重新实例化同一场景
	_start_timeout_timer()
	_active_instance = ARENA_SCENES[scene_name].instantiate() as Node3D
	_stop_timeout_timer()

	if _active_instance == null:
		push_error("LevelSceneManager: Failed to reinstantiate scene '%s', falling back to default" % scene_name)
		_active_instance = ARENA_SCENES[DEFAULT_SCENE].instantiate() as Node3D
		_current_scene = DEFAULT_SCENE
	else:
		_current_scene = scene_name

	_active_scene_container.add_child(_active_instance)

	# Fade from black
	await _fade_from_black()

	_transitioning = false

	# 发出重置完成信号
	scene_reset()


## 返回当前场景名称。
##
## 返回值为空字符串表示尚未加载任何场景。
##
## 返回: [String] 场景名称 ("mountain" 或 "bamboo")
##
## 使用示例:
##   var name: String = get_current_scene()  # "mountain"
func get_current_scene() -> String:
	return _current_scene


## 收集当前场景中所有 Marker3D 生成点的 global_position。
##
## 遍历 active_instance 的直接子节点，收集名称以 "SpawnPoint_" 开头的 Marker3D 节点。
## 波次系统使用这些位置生成敌人。
##
## 返回: [PackedVector3Array] 所有生成点的世界坐标位置
##
## 使用示例:
##   var spawn_positions: PackedVector3Array = get_spawn_points()
##   for pos in spawn_positions:
##       print("Spawn at: ", pos)
func get_spawn_points() -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()

	if _active_instance == null:
		push_warning("LevelSceneManager: No active scene instance, returning empty spawn points")
		return points

	for child in _active_instance.get_children():
		if child is Marker3D and child.name.begins_with("SpawnPoint_"):
			points.append(child.global_position)

	return points


## 返回当前是否有场景已加载。
##
## 使用示例:
##   if is_scene_loaded():
##       var points = get_spawn_points()
func is_scene_loaded() -> bool:
	return _active_instance != null and not _current_scene.is_empty()


## 获取场景中所有碰撞体组合后的 AABB 包围盒。
##
## 遍历 active_instance 中所有 GeometryInstance3D 子节点，合并它们的 AABB。
## 空场景返回空 AABB。
##
## 返回: [AABB] 场景的总包围盒
##
## 使用示例:
##   var bounds: AABB = get_arena_bounds()
##   print("Arena size: ", bounds.size)
func get_arena_bounds() -> AABB:
	if _active_instance == null:
		return AABB()

	var combined_aabb := AABB()
	var first := true

	for child in _active_instance.get_children():
		if child is GeometryInstance3D:
			var child_aabb: AABB = child.get_aabb()
			if first:
				combined_aabb = child_aabb
				first = false
			else:
				combined_aabb = combined_aabb.merge(child_aabb)

	return combined_aabb


## 场景状态集成 — 监听 GameStateManager 的 state_changed 信号。
##
## 连接方式: 在场景设置时将 GameStateManager.state_changed 连接到此方法。
##
## 使用示例:
##   # 在主场景 _ready() 或初始化代码中:
##   GameStateManager.state_changed.connect(_on_state_changed)
##
## [param old_state]: 旧状态 (GameStateManager.State 枚举值)
## [param new_state]: 新状态 (GameStateManager.State 枚举值)
func _on_state_changed(old_state: int, new_state: int) -> void:
	match new_state:
		0:  # State.TITLE
			# TODO: 加载标题场景 (TitleScreen)
			pass
		4:  # State.RESTART
			reset_scene()


# ============================================================
# 内部方法
# ============================================================


## 实例化并加载指定场景（初始化时调用，无 fade 效果）。
func _load_scene(scene_name: String) -> void:
	if not ARENA_SCENES.has(scene_name):
		push_error("LevelSceneManager: Unknown scene name '%s', falling back to '%s'" % [scene_name, DEFAULT_SCENE])
		scene_name = DEFAULT_SCENE

	_start_timeout_timer()
	var instance: Node3D = ARENA_SCENES[scene_name].instantiate() as Node3D
	_stop_timeout_timer()

	if instance == null:
		push_error("LevelSceneManager: Failed to instantiate '%s', falling back to '%s'" % [scene_name, DEFAULT_SCENE])
		instance = ARENA_SCENES[DEFAULT_SCENE].instantiate() as Node3D
		_current_scene = DEFAULT_SCENE
	else:
		_current_scene = scene_name

	_active_scene_container.add_child(instance)
	_active_instance = instance

	scene_changed.emit(_current_scene)


## 清除当前活跃场景实例。
func _clear_active_scene() -> void:
	if _active_instance != null:
		# 先移除子节点（释放子树）
		for child in _active_instance.get_children():
			_active_instance.remove_child(child)
			child.queue_free()

		_active_scene_container.remove_child(_active_instance)
		_active_instance.queue_free()
		_active_instance = null

	# Web 平台: 等待一帧确保 queue_free 完成
	await get_tree().process_frame


## Fade 到黑屏。
func _fade_to_black() -> void:
	if _fade_rect == null or fade_duration <= 0.0:
		return

	_fade_rect.visible = true
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, fade_duration)
	await tween.finished


## 从黑屏淡出。
func _fade_from_black() -> void:
	if _fade_rect == null or fade_duration <= 0.0:
		return

	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 0.0, fade_duration)
	await tween.finished
	_fade_rect.visible = false


## 启动超时计时器。
func _start_timeout_timer() -> void:
	if _timeout_timer:
		_timeout_timer.start()


## 停止超时计时器。
func _stop_timeout_timer() -> void:
	if _timeout_timer:
		_timeout_timer.stop()


## Web 超时回调 — 回退到默认场景。
func _on_load_timeout() -> void:
	push_warning("LevelSceneManager: Scene load timeout (%.1fs) — falling back to '%s'" % [scene_load_timeout, DEFAULT_SCENE])

	# 清除可能部分加载的场景
	if _active_instance != null:
		_active_scene_container.remove_child(_active_instance)
		_active_instance.queue_free()
		_active_instance = null

	# 回退到默认场景
	_active_instance = ARENA_SCENES[DEFAULT_SCENE].instantiate() as Node3D
	_current_scene = DEFAULT_SCENE
	_active_scene_container.add_child(_active_instance)

	_transitioning = false
	scene_changed.emit(_current_scene)
