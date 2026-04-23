@warning_ignore_start("inferred_declaration")
## PlayerController — 闪避与无敌帧测试
##
## 覆盖 Story 002 的 3 个 Acceptance Criteria:
## - AC-1: 闪避位移 — 按 dodge 后位置偏移约 3.0m
## - AC-2: 无敌帧 — 闪避期间 is_invincible() 返回 true
## - AC-3: 冷却 — 冷却期间不能再次闪避
##
## 设计参考: production/epics/player-controller/story-002-dodge.md
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
	_mock_input.dodge_just_pressed = false


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


## 模拟 InputSystem — 提供 get_move_direction() 和 is_action_just_pressed()。
class MockInputSystem extends Node:
	var move_direction: Vector2 = Vector2.ZERO
	var dodge_just_pressed: bool = false

	func get_move_direction() -> Vector2:
		return move_direction

	func is_action_just_pressed(action: String) -> bool:
		if action == "dodge":
			return dodge_just_pressed
		return false


# =========================================================================
# 辅助方法
# =========================================================================

## 模拟指定秒数的物理帧（60 fps）。
func _simulate_seconds(seconds: float) -> void:
	var frames := int(seconds * 60.0)
	for i in frames:
		_player._physics_process(1.0 / 60.0)


## 模拟指定帧数。
func _simulate_frames(count: int) -> void:
	for i in count:
		_player._physics_process(1.0 / 60.0)


# =========================================================================
# AC-1: 闪避位移 — 按 dodge 后位置偏移约 3.0m
# =========================================================================

## AC-1a: 前进方向闪避，位移约 3.0m（15.0 m/s × 0.2s）。
func test_dodge_forward_displaces_player_about_3m() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)  # 前进

	# 触发闪避
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false

	# 完成闪避（0.2s）+ 余量
	_simulate_seconds(0.25)

	# 位移应约为 3.0m（允许 0.5 容差，因为 move_and_slide 有碰撞微调）
	var displacement := _player.position.length()
	assert_float(displacement).is_between(2.5, 3.5)


## AC-1b: 闪避方向与移动方向一致。
func test_dodge_direction_matches_movement_direction() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(1.0, 0.0)  # 右移

	# 触发闪避
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false

	# 完成闪避
	_simulate_seconds(0.25)

	# 主要沿 X 轴正方向移动
	assert_float(_player.position.x).is_greater(2.0)
	assert_float(abs(_player.position.z)).is_less(0.5)


## AC-1c: 无移动输入时闪避，使用角色朝向方向。
func test_dodge_without_input_uses_facing_direction() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2.ZERO  # 无输入

	# 触发闪避（无移动输入，使用默认朝向 -Z）
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false

	# 完成闪避
	_simulate_seconds(0.25)

	# 应沿 -Z 方向移动（默认朝向）
	assert_float(_player.position.z).is_less(-2.0)


## AC-1d: 闪避进入 DODGING 状态，结束后进入 DODGE_COOLDOWN。
func test_dodge_transitions_to_dodging_then_cooldown() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 触发闪避
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false

	assert_int(_player.get_state()).is_equal(PlayerController.State.DODGING)

	# 完成闪避
	_simulate_seconds(0.25)

	assert_int(_player.get_state()).is_equal(PlayerController.State.DODGE_COOLDOWN)


## AC-1e: 冷却结束后回到 IDLE 状态。
func test_dodge_cooldown_ends_in_idle_state() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 触发闪避并完成
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false

	# 完成闪避 + 冷却（0.2 + 0.5 = 0.7s）
	_simulate_seconds(0.75)

	assert_int(_player.get_state()).is_equal(PlayerController.State.IDLE)


## AC-1f: dodge_attempts 计数递增。
func test_dodge_increments_attempts_counter() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	assert_int(_player.dodge_attempts).is_equal(0)

	# 触发闪避
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false

	assert_int(_player.dodge_attempts).is_equal(1)

	# 完成闪避 + 冷却
	_simulate_seconds(0.75)

	# 再次闪避
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false

	assert_int(_player.dodge_attempts).is_equal(2)


## AC-1g: dodge_successes 计数在闪避完成时递增。
func test_dodge_completes_increments_successes() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	assert_int(_player.dodge_successes).is_equal(0)

	# 触发闪避并完成
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false
	_simulate_seconds(0.25)

	assert_int(_player.dodge_successes).is_equal(1)


# =========================================================================
# AC-2: 无敌帧 — 闪避期间 is_invincible() 返回 true
# =========================================================================

## AC-2a: 闪避开始时立即进入无敌。
func test_dodge_start_is_invincible() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 闪避前非无敌
	assert_bool(_player.is_invincible()).is_false()

	# 触发闪避
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false

	# 闪避中应为无敌
	assert_bool(_player.is_invincible()).is_true()


## AC-2b: 闪避全程无敌（0.15 秒内）。
func test_dodge_is_invincible_during_entire_window() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 触发闪避
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false

	# 闪避中间（0.1s）仍无敌
	_simulate_seconds(0.1)
	assert_bool(_player.is_invincible()).is_true()


## AC-2c: 闪避结束后取消无敌。
func test_dodge_end_cancels_invincibility() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 触发闪避并完成
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false
	_simulate_seconds(0.25)

	# 闪避结束后应取消无敌
	assert_bool(_player.is_invincible()).is_false()


## AC-2d: is_dodging() 在 DODGING 状态返回 true。
func test_is_dodging_returns_true_during_dodge() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 触发闪避
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false

	assert_bool(_player.is_dodging()).is_true()

	# 完成闪避后
	_simulate_seconds(0.25)

	assert_bool(_player.is_dodging()).is_false()


## AC-2e: 闪避前 0.15s 内无敌（GDD 无敌窗口）。
func test_invincibility_covers_first_015s() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 触发闪避
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false

	# 前进 0.15s（9 帧）
	_simulate_seconds(0.15)

	# 0.15s 时仍应在 DODGING 状态且无敌
	assert_bool(_player.is_invincible()).is_true()
	assert_bool(_player.is_dodging()).is_true()


# =========================================================================
# AC-3: 冷却 — 冷却期间不能再次闪避
# =========================================================================

## AC-3a: 冷却期间按 dodge 不触发闪避位移。
func test_cooldown_prevents_second_dodge() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 第一次闪避
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false
	_simulate_seconds(0.25)

	# 现在处于 DODGE_COOLDOWN
	assert_int(_player.get_state()).is_equal(PlayerController.State.DODGE_COOLDOWN)

	# 冷却期间再次尝试闪避（移动方向改向右）
	_mock_input.move_direction = Vector2(1.0, 0.0)
	_mock_input.dodge_just_pressed = true
	_simulate_frames(5)
	_mock_input.dodge_just_pressed = false

	# 应仍在 DODGE_COOLDOWN 状态，而不是 DODGING
	assert_int(_player.get_state()).is_equal(PlayerController.State.DODGE_COOLDOWN)


## AC-3b: 冷却期间可以正常移动。
func test_cooldown_allows_normal_movement() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 第一次闪避并完成
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false
	_simulate_seconds(0.25)

	# 冷却期间右移
	_mock_input.move_direction = Vector2(1.0, 0.0)
	_simulate_seconds(0.3)

	# 应沿 X 轴正方向移动（正常速度 5.0 m/s × 0.3s ≈ 1.5m）
	assert_float(_player.position.x).is_greater(1.0)
	assert_int(_player.get_state()).is_equal(PlayerController.State.DODGE_COOLDOWN)


## AC-3c: 冷却结束后可以再次闪避。
func test_cooldown_ends_can_dodge_again() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 第一次闪避并完成 + 冷却
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false
	_simulate_seconds(0.75)

	# 应回到 IDLE
	assert_int(_player.get_state()).is_equal(PlayerController.State.IDLE)

	# 再次闪避
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false

	assert_int(_player.get_state()).is_equal(PlayerController.State.DODGING)
	assert_int(_player.dodge_attempts).is_equal(2)


## AC-3d: get_dodge_success_rate 计算正确。
func test_dodge_success_rate_calculates_correctly() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 无尝试时为 0
	assert_float(_player.get_dodge_success_rate()).is_equal(0.0)

	# 第一次闪避完成（成功）
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false
	_simulate_seconds(0.75)

	# 1/1 = 1.0
	assert_float(_player.get_dodge_success_rate()).is_equal(1.0)

	# 第二次闪避完成（成功）
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false
	_simulate_seconds(0.75)

	# 2/2 = 1.0
	assert_float(_player.get_dodge_success_rate()).is_equal(1.0)


# =========================================================================
# 闪避中断（不可打断 — 除非死亡，见 Story 003）
# =========================================================================

## 闪避中移动输入不改变闪避方向。
func test_dodge_direction_locked_during_dodge() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)  # 前进

	# 触发闪避
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false

	# 闪避中改变输入方向
	_mock_input.move_direction = Vector2(1.0, 0.0)  # 改为右移
	_simulate_seconds(0.15)

	# 位移应主要沿 -Z 方向（原闪避方向），而非 X 方向
	assert_float(abs(_player.position.z)).is_greater(abs(_player.position.x))
