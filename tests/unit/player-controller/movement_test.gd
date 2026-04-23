## PlayerController — 移动与自动朝向测试
##
## 覆盖 Story 001 的全部 4 个 Acceptance Criteria:
## - AC-1: W 键 + COMBAT 状态 → 5.0 m/s 移动
## - AC-2: 所有键释放 → 立即停止
## - AC-3: TITLE 状态 → 不移动
## - AC-4: 最近敌人变化 → 下一帧自动朝向
##
## 设计参考: production/epics/player-controller/story-001-movement.md
extends GdUnitTestSuite

var _player: PlayerController
var _mock_game_state: MockGameStateManager
var _mock_input: MockInputSystem


func before_test() -> void:
	_mock_game_state = auto_free(MockGameStateManager.new())
	_mock_input = auto_free(MockInputSystem.new())
	_player = auto_free(PlayerController.new())
	_player.set_game_state_manager(_mock_game_state)
	_player.set_input_system(_mock_input)
	add_child(_player)


func after_test() -> void:
	_mock_input.move_direction = Vector2.ZERO


# =========================================================================
# Mock 辅助类
# =========================================================================

## 模拟 GameStateManager — 提供 state_changed 信号和 get_current_state()。
class MockGameStateManager extends Node:
	signal state_changed(old_state: int, new_state: int)
	var current_state: int = 1  # 默认 COMBAT

	func get_current_state() -> int:
		return current_state

	func set_state(new_state: int) -> void:
		var old := current_state
		current_state = new_state
		state_changed.emit(old, new_state)


## 模拟 InputSystem — 提供 get_move_direction() 返回预设值。
class MockInputSystem extends Node:
	var move_direction: Vector2 = Vector2.ZERO

	func get_move_direction() -> Vector2:
		return move_direction


## 模拟敌人节点 — 用于测试自动朝向。
class MockEnemy extends Node3D:
	func _init(pos: Vector3) -> void:
		global_position = pos


# =========================================================================
# AC-1: W 键 + COMBAT 状态 → 5.0 m/s 移动
# =========================================================================

## AC-1a: 给定前进输入 + COMBAT 状态，经过 1 秒物理帧后，
## 期望角色沿 Z 轴前进约 5.0 单位。
func test_combat_forward_input_moves_player_forward() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)  # 前进 (W 键)

	# 模拟 1 秒物理帧 (60 fps)
	for i in 60:
		_player._physics_process(1.0 / 60.0)

	# Z 轴应为负值（前进方向 = -Z）
	assert_float(_player.position.z).is_less(0.0)
	# 移动距离约 5.0 单位（允许 0.1 容差）
	assert_float(abs(_player.position.z)).is_between(4.9, 5.1)


## AC-1b: 给定右移输入 + COMBAT 状态，沿 X 轴正方向移动。
func test_combat_right_input_moves_player_right() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(1.0, 0.0)  # 右移 (D 键)

	for i in 60:
		_player._physics_process(1.0 / 60.0)

	assert_float(_player.position.x).is_greater(0.0)
	assert_float(abs(_player.position.x)).is_between(4.9, 5.1)


## AC-1c: 移动速度精确为 5.0 m/s（对角线归一化后）。
func test_combat_diagonal_input_speed_is_normalized() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(1.0, -1.0).normalized()  # 右前

	for i in 60:
		_player._physics_process(1.0 / 60.0)

	# 总位移应约为 5.0（归一化后的对角线速度）
	var total_dist := _player.position.length()
	assert_float(total_dist).is_between(4.9, 5.1)


## AC-1d: 进入 MOVING 状态。
func test_combat_forward_input_transitions_to_moving_state() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	_player._physics_process(1.0 / 60.0)

	assert_int(_player.get_state()).is_equal(PlayerController.State.MOVING)


# =========================================================================
# AC-2: 所有键释放 → 立即停止
# =========================================================================

## AC-2a: 移动中释放所有键，velocity 立即归零。
func test_release_all_keys_stops_movement() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 前进 10 帧
	for i in 10:
		_player._physics_process(1.0 / 60.0)

	# 释放按键
	_mock_input.move_direction = Vector2.ZERO
	_player._physics_process(1.0 / 60.0)

	assert_float(_player.velocity.length()).is_equal(0.0)


## AC-2b: 释放后角色位置不再变化（再过几帧确认）。
func test_release_all_keys_position_stable() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	for i in 10:
		_player._physics_process(1.0 / 60.0)

	var pos_before := _player.position

	_mock_input.move_direction = Vector2.ZERO
	for i in 5:
		_player._physics_process(1.0 / 60.0)

	assert_vector3(_player.position).is_equal(pos_before)


## AC-2c: 释放后回到 IDLE 状态。
func test_release_all_keys_transitions_to_idle() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)
	_player._physics_process(1.0 / 60.0)
	assert_int(_player.get_state()).is_equal(PlayerController.State.MOVING)

	_mock_input.move_direction = Vector2.ZERO
	_player._physics_process(1.0 / 60.0)

	assert_int(_player.get_state()).is_equal(PlayerController.State.IDLE)


# =========================================================================
# AC-3: TITLE 状态 → 不移动
# =========================================================================

## AC-3a: TITLE 状态下即使有输入也不移动。
func test_title_state_no_movement() -> void:
	_mock_game_state.current_state = 0  # TITLE
	_mock_input.move_direction = Vector2(0.0, -1.0)

	for i in 60:
		_player._physics_process(1.0 / 60.0)

	assert_float(_player.position.length()).is_equal(0.0)


## AC-3b: TITLE 状态下 velocity 归零。
func test_title_state_velocity_is_zero() -> void:
	_mock_game_state.current_state = 0  # TITLE
	_mock_input.move_direction = Vector2(0.0, -1.0)

	_player._physics_process(1.0 / 60.0)

	assert_float(_player.velocity.length()).is_equal(0.0)


## AC-3c: DEATH 状态下不移动。
func test_death_state_no_movement() -> void:
	_mock_game_state.current_state = 3  # DEATH
	_mock_input.move_direction = Vector2(0.0, -1.0)

	for i in 60:
		_player._physics_process(1.0 / 60.0)

	assert_float(_player.position.length()).is_equal(0.0)


## AC-3d: 游戏状态从 COMBAT 变为 TITLE 时，角色停止。
func test_game_state_transition_to_title_stops_player() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 先走 10 帧
	for i in 10:
		_player._physics_process(1.0 / 60.0)

	assert_float(_player.position.length()).is_greater(0.0)

	# 状态切换到 TITLE
	_mock_game_state.set_state(0)  # TITLE
	_player._physics_process(1.0 / 60.0)

	assert_float(_player.velocity.length()).is_equal(0.0)


# =========================================================================
# AC-4: 最近敌人变化 → 下一帧自动朝向
# =========================================================================

## AC-4a: 前方有敌人，移动时角色朝向该敌人。
func test_moving_towards_nearest_enemy_faces_enemy() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 在 (0, 0, -10) 放置敌人
	var enemy := auto_free(MockEnemy.new(Vector3(0.0, 0.0, -10.0)))
	enemy.add_to_group("enemies")
	add_child(enemy)

	_player._physics_process(1.0 / 60.0)

	# 角色朝向应指向敌人方向（-Z）
	# look_at 后 forward 向量 (basis.z) 应接近 (0, 0, -1) 归一化
	var forward: Vector3 = -_player.global_basis.z
	assert_float(abs(forward.x)).is_less(0.1)
	assert_float(forward.z).is_less(-0.9)


## AC-4b: 两个敌人，朝向距离更近的。
func test_faces_nearest_of_two_enemies() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 远敌: (10, 0, 0)
	var enemy_far := auto_free(MockEnemy.new(Vector3(10.0, 0.0, 0.0)))
	enemy_far.add_to_group("enemies")
	add_child(enemy_far)

	# 近敌: (0, 0, -5)
	var enemy_near := auto_free(MockEnemy.new(Vector3(0.0, 0.0, -5.0)))
	enemy_near.add_to_group("enemies")
	add_child(enemy_near)

	_player._physics_process(1.0 / 60.0)

	# 应朝向近敌 (0, 0, -5) 的方向
	var forward: Vector3 = -_player.global_basis.z
	assert_float(abs(forward.x)).is_less(0.1)
	assert_float(forward.z).is_less(-0.9)


## AC-4c: 无敌人时保持上一次朝向（不崩溃，不重置）。
func test_no_enemies_preserves_previous_facing() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(1.0, 0.0)  # 右移

	# 第一帧无敌人，朝向不变（初始默认朝向）
	_player._physics_process(1.0 / 60.0)
	var rotation_before := _player.rotation

	# 再走几帧，依然无敌人
	_player._physics_process(1.0 / 60.0)

	assert_vector3(_player.rotation).is_equal(rotation_before)


## AC-4d: 敌人位置变化后，下一帧更新朝向。
func test_enemy_moves_updates_facing_next_frame() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 敌人初始在右边 (10, 0, 0)
	var enemy := auto_free(MockEnemy.new(Vector3(10.0, 0.0, 0.0)))
	enemy.add_to_group("enemies")
	add_child(enemy)

	_player._physics_process(1.0 / 60.0)

	# 敌人瞬移到左边 (-10, 0, 0)
	enemy.global_position = Vector3(-10.0, 0.0, 0.0)
	_player._physics_process(1.0 / 60.0)

	# 朝向应更新为指向左边
	var forward: Vector3 = -_player.global_basis.z
	assert_float(forward.x).is_less(-0.9)


# =========================================================================
# 状态枚举完整性验证（为后续 Story 准备）
# =========================================================================

## 确认 6 个状态全部声明。
func test_state_enum_has_six_states() -> void:
	assert_int(PlayerController.State.size()).is_equal(6)
	assert_int(PlayerController.State.IDLE).is_equal(0)
	assert_int(PlayerController.State.MOVING).is_equal(1)
	assert_int(PlayerController.State.DODGING).is_equal(2)
	assert_int(PlayerController.State.DODGE_COOLDOWN).is_equal(3)
	assert_int(PlayerController.State.HIT_STUN).is_equal(4)
	assert_int(PlayerController.State.DEAD).is_equal(5)


## 初始状态为 IDLE。
func test_initial_state_is_idle() -> void:
	assert_int(_player.get_state()).is_equal(PlayerController.State.IDLE)
