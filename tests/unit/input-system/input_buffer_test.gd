## InputSystem 输入缓冲机制测试
##
## 使用 GDUnit4 框架。
## 覆盖 Story 002: Input Buffering 的 AC-1 ~ AC-6。
extends GdUnitTestSuite

var _input_system: InputSystem


func before_test() -> void:
	_input_system = auto_free(InputSystem.new())
	_register_test_action("attack_you", KEY_J)
	_register_test_action("attack_zuan", KEY_K)
	_register_test_action("attack_rao", KEY_L)
	_register_test_action("dodge", KEY_SPACE)
	add_child(_input_system)


func after_test() -> void:
	_unregister_test_action("attack_you")
	_unregister_test_action("attack_zuan")
	_unregister_test_action("attack_rao")
	_unregister_test_action("dodge")


func _register_test_action(action_name: String, key: int) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.keycode = key
	InputMap.action_add_event(action_name, event)


func _unregister_test_action(action_name: String) -> void:
	if InputMap.has_action(action_name):
		InputMap.erase_action(action_name)


## 创建模拟 GameStateManager（带 state_changed 信号）
func _create_mock_game_state_manager() -> Node:
	var mock := Node.new()
	mock.set_script(preload("res://tests/unit/input-system/mock_game_state_manager.gd"))
	auto_free(mock)
	return mock


## =========================================================================
## AC-1: 缓冲捕获
## GIVEN 缓冲窗口激活中
## WHEN 按下 K 键 (attack_zuan)
## THEN get_buffered_action() 返回 "attack_zuan"
## =========================================================================
func test_buffer_capture_returns_attack_zuan() -> void:
	simulate_key_pressed(KEY_K)
	await idle_frame

	assert_str(_input_system.get_buffered_action()).is_equal(&"attack_zuan")


## =========================================================================
## AC-1 边界: 缓冲窗口内可查询
## =========================================================================
func test_buffer_available_within_window() -> void:
	simulate_key_pressed(KEY_K)
	await idle_frame

	# 在窗口内（默认 6 帧）缓冲持续可用
	await idle_frame
	assert_str(_input_system.get_buffered_action()).is_equal(&"attack_zuan")


## =========================================================================
## AC-2: 缓冲覆盖（容量=1）
## GIVEN 缓冲区中有 "attack_you"
## WHEN 按下 K 键 (attack_zuan)
## THEN get_buffered_action() 返回 "attack_zuan"
## =========================================================================
func test_buffer_overwrites_previous_action() -> void:
	# 先缓冲 attack_you
	simulate_key_pressed(KEY_J)
	await idle_frame
	assert_str(_input_system.get_buffered_action()).is_equal(&"attack_you")

	# 覆盖为 attack_zuan
	simulate_key_pressed(KEY_K)
	await idle_frame
	assert_str(_input_system.get_buffered_action()).is_equal(&"attack_zuan")


## =========================================================================
## AC-2 边界: 连续三次覆盖只保留最后一次
## =========================================================================
func test_buffer_capacity_one_overwrites() -> void:
	simulate_key_pressed(KEY_J)
	await idle_frame

	simulate_key_pressed(KEY_K)
	await idle_frame

	simulate_key_pressed(KEY_L)
	await idle_frame

	# 只保留最后一次（attack_rao）
	assert_str(_input_system.get_buffered_action()).is_equal(&"attack_rao")


## =========================================================================
## AC-3: DEATH 状态清空缓冲
## GIVEN 缓冲区中有 "attack_zuan"
## WHEN GameStateManager 发出 state_changed(_, DEATH) 信号
## THEN get_buffered_action() 返回空
## =========================================================================
func test_death_state_clears_buffer() -> void:
	# 缓冲一个攻击动作
	simulate_key_pressed(KEY_K)
	await idle_frame
	assert_str(_input_system.get_buffered_action()).is_equal(&"attack_zuan")

	# 连接 mock GameStateManager
	var mock_gsm := _create_mock_game_state_manager()
	# 手动设置 _game_state_manager 并连接信号
	_input_system._game_state_manager = mock_gsm
	mock_gsm.state_changed.connect(_input_system._on_game_state_changed)

	# 模拟 DEATH 状态切换（DEATH == 3）
	mock_gsm.state_changed.emit(1, 3)  # COMBAT -> DEATH

	assert_str(_input_system.get_buffered_action()).is_equal(&"")


## =========================================================================
## AC-3 边界: 非 DEATH 状态切换不清空缓冲
## =========================================================================
func test_non_death_state_change_preserves_buffer() -> void:
	simulate_key_pressed(KEY_K)
	await idle_frame
	assert_str(_input_system.get_buffered_action()).is_equal(&"attack_zuan")

	var mock_gsm := _create_mock_game_state_manager()
	_input_system._game_state_manager = mock_gsm
	mock_gsm.state_changed.connect(_input_system._on_game_state_changed)

	# COMBAT -> INTERMISSION（不应清空）
	mock_gsm.state_changed.emit(1, 2)

	assert_str(_input_system.get_buffered_action()).is_equal(&"attack_zuan")


## =========================================================================
## AC-3 边界: DEATH 状态下防御性检查清空缓冲
## GIVEN GameStateManager 处于 DEATH 状态
## WHEN 调用 get_buffered_action()
## THEN 返回空（即使缓冲区有数据）
## =========================================================================
func test_defensive_death_check_clears_buffer() -> void:
	# 缓冲一个攻击动作
	simulate_key_pressed(KEY_K)
	await idle_frame
	assert_str(_input_system.get_buffered_action()).is_equal(&"attack_zuan")

	# 设置 mock 为 DEATH 状态
	var mock_gsm := _create_mock_game_state_manager()
	mock_gsm._current_state = 3  # DEATH
	_input_system._game_state_manager = mock_gsm

	# get_buffered_action() 防御性检查应清空缓冲
	assert_str(_input_system.get_buffered_action()).is_equal(&"")


## =========================================================================
## AC-4: 帧计数超时清空缓冲
## GIVEN 缓冲区中有 "attack_zuan"
## WHEN 等待 buffer_window_frames 帧
## THEN get_buffered_action() 返回空
## =========================================================================
func test_buffer_frame_expiry_clears_buffer() -> void:
	# 设置较短的缓冲窗口以便测试
	_input_system.set_buffer_window(3)

	simulate_key_pressed(KEY_K)
	await idle_frame
	assert_str(_input_system.get_buffered_action()).is_equal(&"attack_zuan")

	# 等待 3 帧（_process 递增计数）
	await idle_frame
	await idle_frame
	await idle_frame

	assert_str(_input_system.get_buffered_action()).is_equal(&"")


## =========================================================================
## AC-4 边界: 超时前一帧仍有效
## =========================================================================
func test_buffer_valid_before_expiry() -> void:
	_input_system.set_buffer_window(3)

	simulate_key_pressed(KEY_K)
	await idle_frame

	# 等待 2 帧（未超时）
	await idle_frame
	await idle_frame

	assert_str(_input_system.get_buffered_action()).is_equal(&"attack_zuan")


## =========================================================================
## AC-5: 非攻击动作不被缓冲
## GIVEN 无
## WHEN 按下 Space 键 (dodge)
## THEN get_buffered_action() 仍为空
## =========================================================================
func test_non_attack_actions_not_buffered() -> void:
	simulate_key_pressed(KEY_SPACE)
	await idle_frame

	assert_str(_input_system.get_buffered_action()).is_equal(&"")


## =========================================================================
## AC-5 边界: 攻击和非攻击混合输入
## GIVEN 按下 Space (dodge)
## WHEN 随后按下 K (attack_zuan)
## THEN 缓冲 attack_zuan，dodge 不影响
## =========================================================================
func test_mixed_input_only_buffers_attacks() -> void:
	simulate_key_pressed(KEY_SPACE)
	await idle_frame
	assert_str(_input_system.get_buffered_action()).is_equal(&"")

	simulate_key_pressed(KEY_K)
	await idle_frame
	assert_str(_input_system.get_buffered_action()).is_equal(&"attack_zuan")


## =========================================================================
## AC-6: 快速连续输入返回最后一个
## GIVEN 无
## WHEN 快速连续按下 J/K/L（同帧或相邻帧）
## THEN get_buffered_action() 返回 "attack_rao"
## =========================================================================
func test_rapid_sequential_input_returns_last() -> void:
	# 直接调用 _input 模拟同帧快速输入
	var event_j := InputEventKey.new()
	event_j.keycode = KEY_J
	event_j.pressed = true
	_input_system._input(event_j)

	var event_k := InputEventKey.new()
	event_k.keycode = KEY_K
	event_k.pressed = true
	_input_system._input(event_k)

	var event_l := InputEventKey.new()
	event_l.keycode = KEY_L
	event_l.pressed = true
	_input_system._input(event_l)

	await idle_frame

	assert_str(_input_system.get_buffered_action()).is_equal(&"attack_rao")
