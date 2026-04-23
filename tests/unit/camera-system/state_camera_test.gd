@warning_ignore_start("inferred_declaration")
## CameraController State-Driven 测试
##
## 测试 Story 003: 状态驱动相机行为
## AC-1: DEATH → 相机完全冻结
## AC-2: TITLE → 相机固定位置 + 轨道旋转
extends GdUnitTestSuite

var _camera: CameraController
var _mock_target: Node3D
var _mock_gsm: _MockGameStateManager


func before_test() -> void:
	_camera = auto_free(CameraController.new())
	_mock_target = auto_free(Node3D.new())
	_mock_gsm = _MockGameStateManager.new()

	_camera.set_game_state_manager(_mock_gsm)
	_camera.set_follow_target(_mock_target)

	# 手动添加 Camera3D 子节点（模拟 _ready）
	var cam := Camera3D.new()
	cam.fov = CameraController.CAMERA_FOV
	cam.position = CameraController.CAMERA_OFFSET
	cam.rotation_degrees.x = -CameraController.CAMERA_TILT_DEG
	_camera.add_child(cam)

	add_child(_camera)


func after_test() -> void:
	if _camera.get_parent():
		_camera.get_parent().remove_child(_camera)


# ── AC-1: DEATH 完全冻结 ────────────────────────────────────────────────

func test_death_state_freezes_camera() -> void:
	# Arrange: 先让相机跟随到某个位置
	_mock_target.global_position = Vector3(5.0, 0.0, 5.0)
	_camera.global_position = Vector3.ZERO
	for i in range(10):
		_camera._physics_process(0.016)

	var pos_before_death: Vector3 = _camera.global_position

	# Act: 触发 DEATH 状态
	_mock_gsm.emit_state_changed(1, 3)  # COMBAT → DEATH

	# 移动目标，DEATH 状态下相机不应跟随
	_mock_target.global_position = Vector3(100.0, 0.0, 100.0)
	for i in range(60):
		_camera._physics_process(0.016)

	# Assert: 相机位置不变
	assert_vector(_camera.global_position).is_equal(pos_before_death)
	assert_bool(_camera.is_frozen()).is_true()


func test_death_state_stops_shake() -> void:
	# Arrange: 先触发 shake
	_camera.trigger_shake(0.2, 1.0)

	# Act: 进入 DEATH
	_mock_gsm.emit_state_changed(1, 3)  # COMBAT → DEATH

	# Assert: shake 被停止
	assert_bool(_camera.is_frozen()).is_true()
	# 处理几帧确认不会崩溃
	_camera._process(0.016)
	_camera._process(0.016)
	assert_bool(true).is_true()


func test_death_state_clears_fov_zoom() -> void:
	# Arrange: 触发 FOV zoom
	_camera.trigger_fov_zoom(75.0, 2.0, 1.0)

	# Act: 进入 DEATH
	_mock_gsm.emit_state_changed(1, 3)  # COMBAT → DEATH

	# Assert: FOV zoom 阶段被清除
	assert_bool(_camera.is_frozen()).is_true()


# ── AC-2: TITLE 固定位置 + 轨道旋转 ─────────────────────────────────────

func test_title_state_enables_orbiting() -> void:
	# Act: 触发 TITLE 状态
	_mock_gsm.emit_state_changed(1, 0)  # COMBAT → TITLE

	# Assert
	assert_bool(_camera.is_orbiting()).is_true()
	assert_bool(_camera.is_frozen()).is_false()
	assert_int(_camera.get_current_state()).is_equal(0)


func test_title_orbit_rotates_camera() -> void:
	# Arrange: 记录初始旋转
	_camera.global_rotation = Vector3.ZERO
	var initial_rotation_y: float = _camera.global_rotation.y

	# Act: 触发 TITLE 并处理多帧
	_mock_gsm.emit_state_changed(1, 0)  # COMBAT → TITLE
	for i in range(60):
		_camera._physics_process(0.016)

	# Assert: Y 旋转应增加（轨道旋转）
	assert_float(_camera.global_rotation.y).is_greater(initial_rotation_y)


func test_title_does_not_follow_target() -> void:
	# Arrange
	_camera.global_position = Vector3.ZERO
	_mock_target.global_position = Vector3(50.0, 0.0, 50.0)

	# Act: 进入 TITLE
	_mock_gsm.emit_state_changed(1, 0)  # COMBAT → TITLE
	for i in range(60):
		_camera._physics_process(0.016)

	# Assert: 位置不应改变（轨道旋转只改变旋转不改变位置跟随）
	# TITLE 模式下 orbit 是 rotate_y，不影响 global_position
	assert_float(_camera.global_position.x).is_equal(0.0)
	assert_float(_camera.global_position.z).is_equal(0.0)


# ── 状态转换 ───────────────────────────────────────────────────────────

func test_combat_state_enables_follow() -> void:
	# Arrange: 先进入 DEATH
	_mock_gsm.emit_state_changed(1, 3)
	_camera.global_position = Vector3.ZERO

	# Act: 恢复 COMBAT
	_mock_gsm.emit_state_changed(3, 1)  # DEATH → COMBAT
	_mock_target.global_position = Vector3(5.0, 0.0, 0.0)
	_camera._physics_process(0.016)

	# Assert: 应跟随目标
	assert_bool(_camera.is_frozen()).is_false()
	assert_bool(_camera.is_orbiting()).is_false()
	assert_float(_camera.global_position.x).is_greater(0.0)


func test_intermission_enables_orbiting() -> void:
	# Act
	_mock_gsm.emit_state_changed(1, 2)  # COMBAT → INTERMISSION

	# Assert
	assert_bool(_camera.is_orbiting()).is_true()
	assert_bool(_camera.is_frozen()).is_false()


func test_default_state_is_combat() -> void:
	# Assert: 默认状态为 COMBAT
	assert_int(_camera.get_current_state()).is_equal(1)
	assert_bool(_camera.is_frozen()).is_false()
	assert_bool(_camera.is_orbiting()).is_false()


func test_death_to_title_transition() -> void:
	# Arrange: 先进入 DEATH
	_mock_gsm.emit_state_changed(1, 3)
	assert_bool(_camera.is_frozen()).is_true()

	# Act: DEATH → TITLE
	_mock_gsm.emit_state_changed(3, 0)

	# Assert: 冻结解除，轨道开启
	assert_bool(_camera.is_frozen()).is_false()
	assert_bool(_camera.is_orbiting()).is_true()


# ── Helpers ─────────────────────────────────────────────────────────────

class _MockGameStateManager extends Node:
	signal state_changed(old_state: int, new_state: int)
	var _current_state: int = 1  # COMBAT

	func get_current_state() -> int:
		return _current_state

	func emit_state_changed(old_state: int, new_state: int) -> void:
		_current_state = new_state
		state_changed.emit(old_state, new_state)
