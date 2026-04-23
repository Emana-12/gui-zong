## CameraController Follow 测试
##
## 测试 Story 001: 固定角度跟随
## AC-1: 平滑跟随 — lerp factor 5.0, XZ 插值, Y 固定 6.0
## AC-2: 固定 45°/8m/60°FOV
extends GdUnitTestSuite

var _camera: CameraController
var _mock_target: Node3D
var _mock_gsm: Node


func before_test() -> void:
	_camera = auto_free(CameraController.new())
	_mock_target = auto_free(Node3D.new())
	_mock_gsm = _create_mock_gsm()

	# 手动初始化（跳过 _ready 中的 Camera3D 创建）
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


# ── AC-2: 固定角度/距离/FOV ──────────────────────────────────────────────

func test_camera_fov_is_60() -> void:
	assert_float(_camera.get_child(0).fov).is_equal(60.0)


func test_camera_tilt_is_45_degrees() -> void:
	var cam: Camera3D = _camera.get_child(0)
	assert_float(cam.rotation_degrees.x).is_equal(-45.0)


func test_camera_offset_y_is_fixed() -> void:
	var cam: Camera3D = _camera.get_child(0)
	assert_float(cam.position.y).is_equal(6.0)


func test_camera_offset_z_is_distance() -> void:
	var cam: Camera3D = _camera.get_child(0)
	assert_float(cam.position.z).is_equal(8.0)


# ── AC-1: 平滑跟随 ─────────────────────────────────────────────────────

func test_follow_target_xz() -> void:
	_mock_target.global_position = Vector3(5.0, 0.0, 3.0)
	_camera.global_position = Vector3.ZERO

	# 模拟 1 帧物理处理
	_camera._physics_process(0.016)

	# X 应精确到 lerp(0, 5, 5.0 * 0.016) = 0.4
	assert_float(_camera.global_position.x).is_equal_approx(0.4, 0.01)
	# Y 应固定在 CAMERA_Y_FIXED
	assert_float(_camera.global_position.y).is_equal(6.0)
	# Z 应精确到 lerp(0, 3, 5.0 * 0.016) = 0.24
	assert_float(_camera.global_position.z).is_equal_approx(0.24, 0.01)


func test_follow_converges_over_time() -> void:
	_mock_target.global_position = Vector3(10.0, 0.0, 10.0)
	_camera.global_position = Vector3.ZERO

	# 模拟 60 帧（约 1 秒）
	for i in range(60):
		_camera._physics_process(0.016)

	# 应非常接近目标（XZ），Y 保持固定
	assert_float(_camera.global_position.x).is_greater(9.0)
	assert_float(_camera.global_position.z).is_greater(9.0)
	assert_float(_camera.global_position.y).is_equal(6.0)


func test_follow_ignores_target_y() -> void:
	_mock_target.global_position = Vector3(0.0, 100.0, 0.0)
	_camera.global_position = Vector3(0.0, 6.0, 0.0)

	_camera._physics_process(0.016)

	# Y 不应受目标 Y 影响
	assert_float(_camera.global_position.y).is_equal(6.0)


func test_no_target_no_crash() -> void:
	_camera.set_follow_target(null)
	_camera._physics_process(0.016)
	# 不崩溃即通过
	assert_bool(true).is_true()


# ── Query Methods ────────────────────────────────────────────────────────

func test_get_camera_position() -> void:
	_camera.global_position = Vector3(1.0, 6.0, 2.0)
	var pos := _camera.get_camera_position()
	assert_vector(pos).is_equal(Vector3(1.0, 6.0, 2.0))


func test_set_follow_speed() -> void:
	_camera.set_follow_speed(10.0)
	_mock_target.global_position = Vector3(5.0, 0.0, 0.0)
	_camera.global_position = Vector3.ZERO

	_camera._physics_process(0.016)

	# 更高速度应导致更大位移
	assert_float(_camera.global_position.x).is_greater(0.0)


# ── Game State Integration ───────────────────────────────────────────────

func test_inactive_state_freezes_follow() -> void:
	_mock_gsm._current_state = 0  # TITLE (not COMBAT)
	_mock_target.global_position = Vector3(10.0, 0.0, 10.0)
	_camera.global_position = Vector3.ZERO

	_camera._physics_process(0.016)

	# 非 COMBAT 状态不应跟随
	assert_float(_camera.global_position.x).is_equal(0.0)
	assert_float(_camera.global_position.z).is_equal(0.0)


# ── Helpers ──────────────────────────────────────────────────────────────

func _create_mock_gsm() -> Node:
	var mock := _MockGameStateManager.new()
	return mock


class _MockGameStateManager extends Node:
	signal state_changed(old_state: int, new_state: int)
	var _current_state: int = 1  # COMBAT

	func get_current_state() -> int:
		return _current_state
