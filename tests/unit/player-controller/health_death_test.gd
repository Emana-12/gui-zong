@warning_ignore_start("inferred_declaration")
## PlayerController — 生命值与死亡测试
##
## 覆盖 Story 003 的 3 个 Acceptance Criteria:
## - AC-1: HP=3, take_damage(1) -> HP=2, health_changed 信号触发
## - AC-2: HP=1, take_damage(1) -> HP=0, player_died 信号触发
## - AC-3: HP=0, take_damage(1) -> 忽略，不重复死亡
##
## 设计参考: production/epics/player-controller/story-003-health-death.md
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
# AC-1: take_damage 减少 HP 并触发 health_changed 信号
# =========================================================================

## AC-1a: 初始 HP=3, take_damage(1) -> HP=2。
func test_take_damage_reduces_health_from_3_to_2() -> void:
	assert_int(_player.health).is_equal(3)

	_player.take_damage(1)

	assert_int(_player.health).is_equal(2)


## AC-1b: take_damage 触发 health_changed 信号。
func test_take_damage_emits_health_changed_signal() -> void:
	var received_health: int = -1
	var received_max: int = -1
	_player.health_changed.connect(func(h: int, m: int) -> void:
		received_health = h
		received_max = m
	)

	_player.take_damage(1)

	assert_int(received_health).is_equal(2)
	assert_int(received_max).is_equal(3)


## AC-1c: take_damage 后进入 HIT_STUN 状态。
func test_take_damage_enters_hit_stun_state() -> void:
	_mock_game_state.current_state = 1  # COMBAT

	_player.take_damage(1)

	assert_int(_player.get_state()).is_equal(PlayerController.State.HIT_STUN)


## AC-1d: HIT_STUN 0.5s 后回到 IDLE 状态。
func test_hit_stun_ends_after_05_seconds() -> void:
	_mock_game_state.current_state = 1  # COMBAT

	_player.take_damage(1)
	assert_int(_player.get_state()).is_equal(PlayerController.State.HIT_STUN)

	# 模拟 0.5s（30 帧）
	_simulate_seconds(0.5)

	assert_int(_player.get_state()).is_equal(PlayerController.State.IDLE)


## AC-1e: HIT_STUN 期间 is_invincible() 返回 true。
func test_hit_stun_is_invincible() -> void:
	_mock_game_state.current_state = 1  # COMBAT

	_player.take_damage(1)

	assert_bool(_player.is_invincible()).is_true()

	# 0.3s 后仍无敌
	_simulate_seconds(0.3)
	assert_bool(_player.is_invincible()).is_true()


## AC-1f: HIT_STUN 期间不能闪避。
func test_hit_stun_prevents_dodge() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	_player.take_damage(1)
	assert_int(_player.get_state()).is_equal(PlayerController.State.HIT_STUN)

	# HIT_STUN 期间尝试闪避
	_mock_input.dodge_just_pressed = true
	_player._physics_process(1.0 / 60.0)
	_mock_input.dodge_just_pressed = false

	# 应仍在 HIT_STUN，而不是 DODGING
	assert_int(_player.get_state()).is_equal(PlayerController.State.HIT_STUN)


## AC-1g: HIT_STUN 期间可以正常移动。
func test_hit_stun_allows_movement() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)  # 前进

	_player.take_damage(1)

	# 移动 0.3s
	_simulate_seconds(0.3)

	# 应沿 -Z 方向移动（正常速度 5.0 m/s * 0.3s = 1.5m）
	assert_float(_player.position.z).is_less(-1.0)


# =========================================================================
# AC-2: HP<=0 时触发 player_died 信号并进入 DEAD 状态
# =========================================================================

## AC-2a: HP=1, take_damage(1) -> HP=0, player_died 信号触发。
func test_lethal_damage_triggers_player_died_signal() -> void:
	var died_emitted: bool = false
	_player.player_died.connect(func() -> void: died_emitted = true)

	_player.health = 1
	_player.take_damage(1)

	assert_int(_player.health).is_equal(0)
	assert_bool(died_emitted).is_true()


## AC-2b: 死亡后进入 DEAD 状态。
func test_death_enters_dead_state() -> void:
	_mock_game_state.current_state = 1  # COMBAT

	_player.health = 1
	_player.take_damage(1)

	assert_int(_player.get_state()).is_equal(PlayerController.State.DEAD)


## AC-2c: 死亡后速度归零。
func test_death_zeroes_velocity() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	# 先移动一下建立速度
	_simulate_frames(5)

	_player.health = 1
	_player.take_damage(1)
	_simulate_frames(5)

	assert_float(_player.velocity.length()).is_equal(0.0)


## AC-2d: 死亡后 is_invincible() 返回 false。
func test_death_cancels_invincibility() -> void:
	_mock_game_state.current_state = 1  # COMBAT

	_player.health = 1
	_player.take_damage(1)

	assert_bool(_player.is_invincible()).is_false()


## AC-2e: 死亡后忽略所有输入（不能移动）。
func test_death_ignores_input() -> void:
	_mock_game_state.current_state = 1  # COMBAT
	_mock_input.move_direction = Vector2(0.0, -1.0)

	_player.health = 1
	_player.take_damage(1)

	# 尝试移动
	_simulate_seconds(0.5)

	# 位置应不变（速度为零）
	assert_float(_player.position.length()).is_equal(0.0)


# =========================================================================
# AC-3: 已死亡时 take_damage 被忽略
# =========================================================================

## AC-3a: HP=0, take_damage(1) -> HP 保持 0。
func test_damage_when_dead_is_ignored() -> void:
	_player.health = 0
	_player.take_damage(1)

	assert_int(_player.health).is_equal(0)


## AC-3b: 已死亡时 take_damage 不再次触发 player_died。
func test_damage_when_dead_does_not_reemit_died() -> void:
	var died_count: int = 0
	_player.player_died.connect(func() -> void: died_count += 1)

	# 第一次死亡
	_player.health = 1
	_player.take_damage(1)
	assert_int(died_count).is_equal(1)

	# 已死，再次受伤 —— 不应再次触发
	_player.take_damage(1)
	assert_int(died_count).is_equal(1)


## AC-3c: 已死亡时 take_damage 不改变状态（保持 DEAD）。
func test_damage_when_dead_preserves_dead_state() -> void:
	_mock_game_state.current_state = 1  # COMBAT

	_player.health = 0
	_player.take_damage(1)

	assert_int(_player.get_state()).is_equal(PlayerController.State.DEAD)


# =========================================================================
# heal() 功能测试
# =========================================================================

## AC-3d: heal() 正常恢复生命值。
func test_heal_restores_health() -> void:
	_player.health = 1
	_player.heal(2)

	assert_int(_player.health).is_equal(3)


## AC-3e: heal() 触发 health_changed 信号。
func test_heal_emits_health_changed_signal() -> void:
	var received_health: int = -1
	_player.health_changed.connect(func(h: int, _m: int) -> void:
		received_health = h
	)

	_player.health = 1
	_player.heal(1)

	assert_int(received_health).is_equal(2)


## AC-3f: heal() 不超过 max_health。
func test_heal_does_not_exceed_max_health() -> void:
	_player.health = 2
	_player.max_health = 3
	_player.heal(5)

	assert_int(_player.health).is_equal(3)


## AC-3g: get_health() 和 get_max_health() 返回正确值。
func test_get_health_and_max_health_return_correct_values() -> void:
	_player.health = 2
	_player.max_health = 5

	assert_int(_player.get_health()).is_equal(2)
	assert_int(_player.get_max_health()).is_equal(5)


# =========================================================================
# 受击无敌计时器（InvincibleTimer = 0.65s）
# =========================================================================

## 受击无敌在 0.65s 后结束。
func test_hit_invincibility_ends_after_065_seconds() -> void:
	_mock_game_state.current_state = 1  # COMBAT

	_player.take_damage(1)
	assert_bool(_player.is_invincible()).is_true()

	# 0.5s 后 HIT_STUN 结束，但仍无敌（0.65s buffer）
	_simulate_seconds(0.5)
	assert_int(_player.get_state()).is_equal(PlayerController.State.IDLE)
	assert_bool(_player.is_invincible()).is_true()

	# 再前进 0.16s（总计 0.66s > 0.65s），无敌应结束
	_simulate_seconds(0.16)
	assert_bool(_player.is_invincible()).is_false()


## 受击无敌期间 take_damage 被忽略。
func test_damage_ignored_during_hit_invincibility() -> void:
	_mock_game_state.current_state = 1  # COMBAT

	_player.take_damage(1)
	assert_int(_player.health).is_equal(2)

	# 无敌期间再次受伤 —— 应忽略
	_simulate_seconds(0.2)
	_player.take_damage(1)
	assert_int(_player.health).is_equal(2)


# =========================================================================
# get_health / get_max_health
# =========================================================================

## 初始值正确。
func test_initial_health_values() -> void:
	assert_int(_player.get_health()).is_equal(3)
	assert_int(_player.get_max_health()).is_equal(3)
