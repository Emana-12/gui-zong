@warning_ignore_start("inferred_declaration")
## GameStateManager 暂停与 Web 焦点集成测试
##
## 使用 GDUnit4 框架。
## 覆盖 Story 003: Pause & Web Focus 的 AC-1 ~ AC-3（自动化）。
## AC-4 (Web focus out) 和 AC-5 (Web focus in) 需手动验证。
extends GdUnitTestSuite

var _manager: GameStateManager


func before_test() -> void:
	_manager = auto_free(GameStateManager.new())
	_manager.death_delay = 0.01
	# add_child 确保 get_tree() 可用（pause/resume 需要 get_tree().paused）
	add_child(_manager)


func after_test() -> void:
	# 每个测试后解除暂停，避免影响后续测试
	if _manager and is_instance_valid(_manager):
		get_tree().paused = false


## =========================================================================
## AC-1: pause_game() 冻结游戏
## GIVEN 游戏运行中, is_paused() == false
## WHEN 调用 pause_game()
## THEN get_tree().paused == true; is_paused() == true; game_paused(true) 信号被发出
## =========================================================================
func test_pause_game_freezes_game() -> void:
	assert_bool(_manager.is_paused()).is_false()

	var received_signals: Array = []
	_manager.game_paused.connect(func(paused: bool) -> void:
		received_signals.append(paused)
	)

	_manager.pause_game()

	assert_bool(_manager.is_paused()).is_true()
	assert_bool(get_tree().paused).is_true()
	assert_int(received_signals.size()).is_equal(1)
	assert_bool(received_signals[0]).is_true()


## =========================================================================
## AC-1 边界: 重复调用 pause_game() 不产生副作用
## =========================================================================
func test_pause_game_idempotent() -> void:
	var received_signals: Array = []
	_manager.game_paused.connect(func(paused: bool) -> void:
		received_signals.append(paused)
	)

	_manager.pause_game()
	_manager.pause_game()  # 第二次调用

	assert_bool(_manager.is_paused()).is_true()
	assert_bool(get_tree().paused).is_true()
	# 信号只发出一次
	assert_int(received_signals.size()).is_equal(1)


## =========================================================================
## AC-2: resume_game() 恢复游戏
## GIVEN 游戏已暂停
## WHEN 调用 resume_game()
## THEN get_tree().paused == false; is_paused() == false; game_paused(false) 信号被发出
## =========================================================================
func test_resume_game_resumes() -> void:
	_manager.pause_game()
	assert_bool(_manager.is_paused()).is_true()

	var received_signals: Array = []
	_manager.game_paused.connect(func(paused: bool) -> void:
		received_signals.append(paused)
	)

	_manager.resume_game()

	assert_bool(_manager.is_paused()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_int(received_signals.size()).is_equal(1)
	assert_bool(received_signals[0]).is_false()


## =========================================================================
## AC-2 边界: 未暂停时调用 resume_game() 不产生副作用
## =========================================================================
func test_resume_without_pause_no_side_effect() -> void:
	var received_signals: Array = []
	_manager.game_paused.connect(func(paused: bool) -> void:
		received_signals.append(paused)
	)

	_manager.resume_game()  # 未暂停时调用

	assert_bool(_manager.is_paused()).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_int(received_signals.size()).is_equal(0)


## =========================================================================
## AC-3: 暂停不影响当前状态
## GIVEN 当前状态 = COMBAT
## WHEN 调用 pause_game() 然后 resume_game()
## THEN get_current_state() == COMBAT（状态不变）
## =========================================================================
func test_pause_resume_preserves_combat_state() -> void:
	_manager.change_state(GameStateManager.State.COMBAT)

	_manager.pause_game()
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.COMBAT)

	_manager.resume_game()
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.COMBAT)


## =========================================================================
## AC-3 边界: 在 TITLE 状态下暂停恢复，状态不变
## =========================================================================
func test_pause_resume_preserves_title_state() -> void:
	_manager.pause_game()
	_manager.resume_game()

	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.TITLE)


## =========================================================================
## AC-3 边界: 在 INTERMISSION 状态下暂停恢复，状态不变
## =========================================================================
func test_pause_resume_preserves_intermission_state() -> void:
	_manager.change_state(GameStateManager.State.COMBAT)
	_manager.change_state(GameStateManager.State.INTERMISSION)

	_manager.pause_game()
	_manager.resume_game()

	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.INTERMISSION)


## =========================================================================
## AC-3 边界: 在 DEATH 状态下暂停恢复，状态不变
## =========================================================================
func test_pause_resume_preserves_death_state() -> void:
	_manager.change_state(GameStateManager.State.COMBAT)
	_manager.change_state(GameStateManager.State.DEATH)

	_manager.pause_game()
	_manager.resume_game()

	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.DEATH)


## =========================================================================
## process_mode 验证: GameStateManager 设置为 PROCESS_MODE_ALWAYS
## =========================================================================
func test_manager_process_mode_is_always() -> void:
	assert_int(_manager.process_mode) \
		.is_equal(Node.PROCESS_MODE_ALWAYS)


## =========================================================================
## death_timer process_mode 验证: 暂停期间死亡延迟继续计时
## =========================================================================
func test_death_timer_process_mode_is_always() -> void:
	# 进入 DEATH 启动计时器
	_manager.change_state(GameStateManager.State.COMBAT)
	_manager.change_state(GameStateManager.State.DEATH)

	# _death_timer 是私有变量，通过反射访问
	var death_timer: Timer = _manager.get("_death_timer")
	assert_int(death_timer.process_mode) \
		.is_equal(Node.PROCESS_MODE_ALWAYS)


## =========================================================================
## pause_on_focus_loss 验证: 默认值为 true
## =========================================================================
func test_pause_on_focus_loss_default_true() -> void:
	assert_bool(_manager.pause_on_focus_loss).is_true()


## =========================================================================
## 集成: 暂停期间状态转换仍可执行（因为 process_mode = ALWAYS）
## =========================================================================
func test_state_change_works_during_pause() -> void:
	_manager.change_state(GameStateManager.State.COMBAT)
	_manager.pause_game()

	# 暂停期间仍可进行状态转换（PROCESS_MODE_ALWAYS）
	var result: bool = _manager.change_state(GameStateManager.State.INTERMISSION)

	assert_bool(result).is_true()
	assert_int(_manager.get_current_state()) \
		.is_equal(GameStateManager.State.INTERMISSION)

	_manager.resume_game()
