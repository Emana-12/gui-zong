## CameraController — 固定 3/4 俯视角相机 (Node3D)
##
## 管理 Camera3D 子节点，实现平滑跟随玩家。
## Story 001: 固定角度跟随（IDLE/COMBAT → 跟随玩家，XZ lerp，Y 固定）
## Story 002: 视觉效果（FOV zoom、shake、hit stop）
## Story 003: 状态驱动行为（DEATH 冻结、TITLE 轨道旋转）
##
## 设计参考:
## - docs/architecture/adr-0012-camera-system-architecture.md
## - design/gdd/camera-system.md
## - production/epics/camera-system/story-001-follow.md
## - production/epics/camera-system/story-002-effects.md
##
## 依赖:
## - GameStateManager (Autoload): 提供游戏状态和 state_changed 信号
##
## @see ADR-0012
class_name CameraController
extends Node3D

## 相机俯角（度）。绕 X 轴旋转，产生俯视角效果。
const CAMERA_TILT_DEG: float = 45.0

## 相机距离玩家的偏移量（米）。
const CAMERA_DISTANCE: float = 8.0

## 相机视野（度）。
const CAMERA_FOV: float = 60.0

## 相机 Y 轴固定高度（米）。
const CAMERA_Y_FIXED: float = 6.0

## 跟随插值速度。
const DEFAULT_FOLLOW_SPEED: float = 5.0

## TITLE/INTERMISSION 轨道旋转速度（弧度/秒）。
const ORBIT_SPEED: float = 0.3

## 相机偏移（相对于玩家位置）。由 tilt + distance 计算得出。
const CAMERA_OFFSET: Vector3 = Vector3(0.0, CAMERA_Y_FIXED, CAMERA_DISTANCE)

## 跟随目标引用。
var _follow_target: Node3D = null

## GameStateManager 引用。运行时通过 _ready() 获取，测试时通过 set_game_state_manager() 注入。
var _game_state_manager: Node = null

## 跟随速度。
var _follow_speed: float = DEFAULT_FOLLOW_SPEED

## Camera3D 子节点引用（缓存，避免每帧 get_node）。
var _camera: Camera3D = null

# ── State-Driven Behavior (Story 003) ────────────────────────────────────────

## 当前游戏状态。由 _on_game_state_changed 更新，_physics_process 读取。
var _current_state: int = 1  # 默认 COMBAT

## 冻结状态标志（DEATH 时为 true）。相机完全停止更新。
var _is_frozen: bool = false

## 轨道旋转状态标志（TITLE/INTERMISSION 时为 true）。
var _is_orbiting: bool = false

## 轨道目标位置（进入 ORBIT 状态时的初始位置）。
var _orbit_position: Vector3 = Vector3.ZERO

# ── Effect System (Story 002) ──────────────────────────────────────────────

## 效果类型枚举。优先级：HIT_STOP > FOV_ZOOM > SHAKE。
enum EffectType { NONE, FOV_ZOOM, SHAKE, HIT_STOP }

## FOV zoom 阶段：扩张 → 恢复。
enum FovPhase { NONE, EXPANDING, RECOVERING }

## 当前活跃的主要效果。
var _active_effect: EffectType = EffectType.NONE

## 效果计时器（秒）。
var _effect_timer: float = 0.0

## Shake 是否叠加在其他效果上。
var _shake_active: bool = false
var _shake_timer: float = 0.0
var _shake_intensity: float = 0.1

## FOV zoom 参数。
var _fov_phase: FovPhase = FovPhase.NONE
var _fov_target: float = 75.0
var _fov_expand_time: float = 2.0
var _fov_recover_time: float = 1.0
var _fov_expand_elapsed: float = 0.0
var _fov_recover_elapsed: float = 0.0

## Hit stop 参数。
var _hit_stop_frames: int = 0
var _hit_stop_original_scale: float = 1.0
var _hit_stop_active: bool = false


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.fov = CAMERA_FOV
	add_child(_camera)
	_camera.position = CAMERA_OFFSET
	_camera.rotation_degrees.x = -CAMERA_TILT_DEG

	_resolve_dependencies()
	_connect_game_state_signals()


func _exit_tree() -> void:
	if _game_state_manager and _game_state_manager.has_signal("state_changed"):
		if _game_state_manager.state_changed.is_connected(_on_game_state_changed):
			_game_state_manager.state_changed.disconnect(_on_game_state_changed)


## 解析运行时依赖。测试时可跳过此方法，通过 setter 注入。
func _resolve_dependencies() -> void:
	if Engine.has_singleton("GameStateManager"):
		_game_state_manager = Engine.get_singleton("GameStateManager")
	elif GameStateManager:
		_game_state_manager = GameStateManager


## 连接 GameStateManager 的 state_changed 信号。
func _connect_game_state_signals() -> void:
	if _game_state_manager and _game_state_manager.has_signal("state_changed"):
		_game_state_manager.state_changed.connect(_on_game_state_changed)


## 注入 GameStateManager 引用（用于测试）。
func set_game_state_manager(manager: Node) -> void:
	if _game_state_manager and _game_state_manager.has_signal("state_changed"):
		if _game_state_manager.state_changed.is_connected(_on_game_state_changed):
			_game_state_manager.state_changed.disconnect(_on_game_state_changed)
	_game_state_manager = manager
	_connect_game_state_signals()


## 设置跟随目标。
func set_follow_target(target: Node3D) -> void:
	_follow_target = target


## 设置跟随速度。
func set_follow_speed(speed: float) -> void:
	_follow_speed = speed


## 物理帧处理。根据游戏状态执行不同的相机行为。
## COMBAT: 平滑跟随目标（仅 XZ 平面，Y 固定）
## TITLE: 固定位置 + 轨道旋转
## INTERMISSION: 轻微拉远 + 轨道旋转
## DEATH: 完全冻结
func _physics_process(delta: float) -> void:
	if _is_frozen:
		return

	if _is_orbiting:
		rotate_y(ORBIT_SPEED * delta)
		return

	if _follow_target == null:
		return
	if _current_state != 1:  # State.COMBAT
		return

	var target_pos: Vector3 = _follow_target.global_position
	var current_pos: Vector3 = global_position

	# 仅在 XZ 平面插值，Y 保持固定
	var new_x: float = lerp(current_pos.x, target_pos.x, _follow_speed * delta)
	var new_z: float = lerp(current_pos.z, target_pos.z, _follow_speed * delta)
	global_position = Vector3(new_x, CAMERA_Y_FIXED, new_z)


## 检查游戏状态是否允许相机跟随。
## COMBAT 状态（== 1）时返回 true。
func _is_gameplay_active() -> bool:
	return _current_state == 1  # State.COMBAT


## 获取相机世界位置。
func get_camera_position() -> Vector3:
	return global_position


## 获取相机前方向量。
func get_camera_forward() -> Vector3:
	if _camera:
		return -_camera.global_basis.z
	return -global_basis.z


## 获取 Camera3D 子节点引用。
func get_camera() -> Camera3D:
	return _camera


## 获取当前游戏状态（用于测试）。
func get_current_state() -> int:
	return _current_state


## 获取是否处于冻结状态（用于测试）。
func is_frozen() -> bool:
	return _is_frozen


## 获取是否处于轨道旋转状态（用于测试）。
func is_orbiting() -> bool:
	return _is_orbiting


## 游戏状态变更回调。
## 根据新状态设置相机行为模式。
func _on_game_state_changed(_old_state: int, new_state: int) -> void:
	_current_state = new_state
	_is_frozen = false
	_is_orbiting = false

	match new_state:
		0:  # TITLE
			_is_orbiting = true
		1:  # COMBAT — 正常跟随，无需额外处理
			pass
		2:  # INTERMISSION
			_is_orbiting = true
		3:  # DEATH
			_is_frozen = true
			# 停止所有视觉效果
			_shake_active = false
			if _camera:
				_camera.h_offset = 0.0
				_camera.v_offset = 0.0
			_fov_phase = FovPhase.NONE
		4:  # RESTART — 瞬间回到 COMBAT 位置，由外部处理
			pass


# ── Effect System (Story 002) ──────────────────────────────────────────────

## 每帧处理视觉效果（FOV zoom、shake、hit stop）。
## 效果使用 _process 而非 _physics_process，因为视觉效果应与渲染帧同步。
func _process(delta: float) -> void:
	if _camera == null:
		return
	_update_hit_stop()
	_update_fov_zoom(delta)
	_update_shake(delta)


## 更新 hit stop。每帧递减计数，归零时恢复 time_scale。
func _update_hit_stop() -> void:
	if not _hit_stop_active:
		return
	_hit_stop_frames -= 1
	if _hit_stop_frames <= 0:
		Engine.time_scale = _hit_stop_original_scale
		_hit_stop_active = false
		_active_effect = EffectType.NONE


## 更新 FOV zoom 效果。先扩张到目标 FOV，再恢复到默认 FOV。
func _update_fov_zoom(delta: float) -> void:
	if _fov_phase == FovPhase.NONE:
		return

	if _fov_phase == FovPhase.EXPANDING:
		_fov_expand_elapsed += delta
		_camera.fov = lerp(_camera.fov, _fov_target, 2.0 * delta)
		if _fov_expand_elapsed >= _fov_expand_time:
			_fov_phase = FovPhase.RECOVERING
			_fov_recover_elapsed = 0.0
	elif _fov_phase == FovPhase.RECOVERING:
		_fov_recover_elapsed += delta
		_camera.fov = lerp(_camera.fov, CAMERA_FOV, 2.0 * delta)
		if _fov_recover_elapsed >= _fov_recover_time:
			_camera.fov = CAMERA_FOV
			_fov_phase = FovPhase.NONE
			if _active_effect == EffectType.FOV_ZOOM:
				_active_effect = EffectType.NONE


## 更新 shake 效果。每帧随机偏移 camera 的 h_offset/v_offset。
func _update_shake(delta: float) -> void:
	if not _shake_active:
		return
	_shake_timer -= delta
	if _shake_timer <= 0.0:
		_shake_active = false
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		return
	_camera.h_offset = randf_range(-_shake_intensity, _shake_intensity)
	_camera.v_offset = randf_range(-_shake_intensity, _shake_intensity)


## 触发 FOV zoom 效果。FOV 从当前值扩张到 target_fov，然后恢复。
## 运动减弱模式下跳过效果。
## @param target_fov 目标 FOV（默认 75°）
## @param expand_time 扩张时间（默认 2s）
## @param recover_time 恢复时间（默认 1s）
func trigger_fov_zoom(target_fov: float = 75.0, expand_time: float = 2.0, recover_time: float = 1.0) -> void:
	var am := get_node_or_null("/root/AccessibilityManager")
	if am and am.get_motion_scale() <= 0.0:
		return
	_fov_target = target_fov
	_fov_expand_time = expand_time
	_fov_recover_time = recover_time
	_fov_expand_elapsed = 0.0
	_fov_recover_elapsed = 0.0
	_fov_phase = FovPhase.EXPANDING
	_active_effect = EffectType.FOV_ZOOM


## 触发 shake 效果。叠加在其他效果之上。
## 运动减弱模式下跳过效果。
## @param intensity 偏移强度（默认 ±0.1m）
## @param duration 持续时间（默认 0.1s）
func trigger_shake(intensity: float = 0.1, duration: float = 0.1) -> void:
	var am := get_node_or_null("/root/AccessibilityManager")
	if am and am.get_motion_scale() <= 0.0:
		return
	_shake_intensity = intensity
	_shake_timer = duration
	_shake_active = true


## 触发 hit stop 效果。设置 Engine.time_scale = 0 暂停所有游戏逻辑。
## 运动减弱模式下跳过效果。
## 注意：Web 平台可能导致音频爆音。
## @param frames 暂停帧数（默认 2 帧）
func trigger_hit_stop(frames: int = 2) -> void:
	var am := get_node_or_null("/root/AccessibilityManager")
	if am and am.get_motion_scale() <= 0.0:
		return
	if _hit_stop_active:
		return  # 已在 hit stop 中，忽略
	_hit_stop_original_scale = Engine.time_scale
	Engine.time_scale = 0.0
	_hit_stop_frames = frames
	_hit_stop_active = true
	_active_effect = EffectType.HIT_STOP


## 通过名称触发效果（便捷入口）。
## @param effect_name 效果名称："fov_zoom", "shake", "hit_stop"
func trigger_effect(effect_name: StringName) -> void:
	match effect_name:
		&"fov_zoom":
			trigger_fov_zoom()
		&"shake":
			trigger_shake()
		&"hit_stop":
			trigger_hit_stop()
		_:
			push_warning("CameraController: Unknown effect '%s'" % effect_name)
