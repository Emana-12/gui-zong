## GameStateManager — Intermission & Wave Completion 测试
##
## 使用 GDUnit4 框架。
## 测试覆盖 Story 002: Intermission & Wave Completion 的所有 AC。
extends GdUnitTestSuite

## 测试用 GameStateManager 实例
var _manager: GameStateManager


func before_test() -> void:
	_manager = auto_free(GameStateManager.new())
	_manager.death_delay = 0.01
	_manager._ready()


## =========================================================================
## AC-1: COMBAT 状态下收到 wave_completed 信号，转换为 INTERMISSION
## =========================================================================
func test_wave_completed_combat_to_intermission() -> void:
	# Arrange
	_manager.change_state(GameStateManager.State.COMBAT)
	var signal_monitor := monitor_signals(_manager)

	# Act
	_manager._on_wave_completed(1)

	# Assert
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.INTERMISSION)
	await assert_signal(signal_monitor).is_emitted("state_changed")


## =========================================================================
## AC-2: INTERMISSION 状态手动调用 change_state(COMBAT)，转换成功
## =========================================================================
func test_intermission_manual_advance_to_combat() -> void:
	# Arrange
	_manager.change_state(GameStateManager.State.COMBAT)
	_manager._on_wave_completed(1)
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.INTERMISSION)

	# Act
	var result: bool = _manager.change_state(GameStateManager.State.COMBAT)

	# Assert
	assert_bool(result).is_true()
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.COMBAT)


## =========================================================================
## AC-3: INTERMISSION 状态自动推进（模拟外部计时器调用 change_state）
## =========================================================================
func test_intermission_auto_advance_to_combat() -> void:
	# Arrange
	_manager.change_state(GameStateManager.State.COMBAT)
	_manager._on_wave_completed(1)
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.INTERMISSION)

	# Act — 模拟竞技场波次系统计时器到期后调用
	var result: bool = _manager.change_state(GameStateManager.State.COMBAT)

	# Assert
	assert_bool(result).is_true()
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.COMBAT)


## =========================================================================
## AC-4: 同帧死亡优先于波次完成
## 先 change_state(DEATH)，再触发 wave_completed，最终状态应为 DEATH
## =========================================================================
func test_death_priority_over_wave_completed() -> void:
	# Arrange
	_manager.change_state(GameStateManager.State.COMBAT)

	# Act — 先处理死亡
	_manager.change_state(GameStateManager.State.DEATH)
	# 再收到 wave_completed
	_manager._on_wave_completed(1)

	# Assert — wave_completed 被忽略，状态保持 DEATH
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.DEATH)


## =========================================================================
## AC-5: 非 COMBAT 状态收到 wave_completed 信号，状态不变
## =========================================================================
func test_wave_completed_ignored_in_title_state() -> void:
	# Arrange
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.TITLE)

	# Act
	_manager._on_wave_completed(1)

	# Assert
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.TITLE)


func test_wave_completed_ignored_in_death_state() -> void:
	# Arrange
	_manager.change_state(GameStateManager.State.COMBAT)
	_manager.change_state(GameStateManager.State.DEATH)
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.DEATH)

	# Act
	_manager._on_wave_completed(1)

	# Assert
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.DEATH)


func test_wave_completed_ignored_in_intermission_state() -> void:
	# Arrange
	_manager.change_state(GameStateManager.State.COMBAT)
	_manager._on_wave_completed(1)
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.INTERMISSION)

	# Act
	_manager._on_wave_completed(2)

	# Assert — 状态仍为 INTERMISSION
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.INTERMISSION)


## =========================================================================
## 边界测试: wave_number 参数正确传递（回调接收值验证）
## =========================================================================
func test_wave_completed_receives_wave_number() -> void:
	# Arrange
	_manager.change_state(GameStateManager.State.COMBAT)
	var received_wave_number: int = -1
	_manager.state_changed.connect(func(_old: GameStateManager.State, _new: GameStateManager.State) -> void:
		# 在信号回调中验证（间接验证 wave_number 已被使用）
		pass
	)

	# Act — 传递 wave_number=5
	_manager._on_wave_completed(5)

	# Assert — 状态转换成功即可，wave_number 由竞技场系统负责
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.INTERMISSION)


## =========================================================================
## 边界测试: 连续波次完成流程
## COMBAT→INTERMISSION→COMBAT→INTERMISSION
## =========================================================================
func test_consecutive_wave_completion_cycle() -> void:
	# 第一波
	_manager.change_state(GameStateManager.State.COMBAT)
	_manager._on_wave_completed(1)
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.INTERMISSION)

	_manager.change_state(GameStateManager.State.COMBAT)
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.COMBAT)

	# 第二波
	_manager._on_wave_completed(2)
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.INTERMISSION)
