@warning_ignore_start("inferred_declaration")
## InputSystem 输入映射与查询 API 测试
##
## 使用 GDUnit4 框架。
## 覆盖 Story 001: Input Mapping & Query API 的 AC-1 ~ AC-9。
extends GdUnitTestSuite

var _input_system: InputSystem


func before_test() -> void:
	_input_system = auto_free(InputSystem.new())
	# 注册测试用输入动作到 InputMap
	_register_test_action("move_forward", KEY_W)
	_register_test_action("move_left", KEY_A)
	_register_test_action("move_right", KEY_D)
	_register_test_action("move_down", KEY_S)
	_register_test_action("attack_you", KEY_J)
	_register_test_action("attack_zuan", KEY_K)
	add_child(_input_system)


func after_test() -> void:
	# 清理 InputMap 中注册的测试动作
	_unregister_test_action("move_forward")
	_unregister_test_action("move_left")
	_unregister_test_action("move_right")
	_unregister_test_action("move_down")
	_unregister_test_action("attack_you")
	_unregister_test_action("attack_zuan")


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


## =========================================================================
## AC-1: 基础按下查询
## GIVEN 玩家按下 W 键
## WHEN 查询 is_action_pressed("move_forward")
## THEN 返回 true
## =========================================================================
func test_is_action_pressed_when_key_held_returns_true() -> void:
	simulate_key_pressed(KEY_W)
	await idle_frame

	assert_bool(_input_system.is_action_pressed(&"move_forward")).is_true()


## =========================================================================
## AC-1 边界: 多帧按住返回一致结果
## =========================================================================
func test_is_action_pressed_multiple_frames_consistent() -> void:
	simulate_key_pressed(KEY_W)

	await idle_frame
	assert_bool(_input_system.is_action_pressed(&"move_forward")).is_true()

	await idle_frame
	assert_bool(_input_system.is_action_pressed(&"move_forward")).is_true()


## =========================================================================
## AC-2: 释放查询
## GIVEN W 键已按下
## WHEN 模拟释放 W 键
## THEN is_action_pressed("move_forward") == false
## =========================================================================
func test_is_action_released_returns_false() -> void:
	simulate_key_pressed(KEY_W)
	await idle_frame
	assert_bool(_input_system.is_action_pressed(&"move_forward")).is_true()

	simulate_key_released(KEY_W)
	await idle_frame

	assert_bool(_input_system.is_action_pressed(&"move_forward")).is_false()


## =========================================================================
## AC-3: just_pressed 单帧标记
## GIVEN 无
## WHEN 模拟按下 J 键，连续查询 3 帧
## THEN 第 1 帧 true，第 2-3 帧 false
## =========================================================================
func test_just_pressed_single_frame() -> void:
	simulate_key_pressed(KEY_J)

	# 第 1 帧
	await idle_frame
	assert_bool(_input_system.is_action_just_pressed(&"attack_you")).is_true()

	# 第 2 帧
	await idle_frame
	assert_bool(_input_system.is_action_just_pressed(&"attack_you")).is_false()

	# 第 3 帧
	await idle_frame
	assert_bool(_input_system.is_action_just_pressed(&"attack_you")).is_false()


## =========================================================================
## AC-4: just_released 单帧标记
## GIVEN J 键已按下
## WHEN 模拟释放 J 键，连续查询 3 帧
## THEN 第 1 帧 true，第 2-3 帧 false
## =========================================================================
func test_just_released_single_frame() -> void:
	simulate_key_pressed(KEY_J)
	await idle_frame

	simulate_key_released(KEY_J)

	# 第 1 帧
	await idle_frame
	assert_bool(_input_system.is_action_just_released(&"attack_you")).is_true()

	# 第 2 帧
	await idle_frame
	assert_bool(_input_system.is_action_just_released(&"attack_you")).is_false()

	# 第 3 帧
	await idle_frame
	assert_bool(_input_system.is_action_just_released(&"attack_you")).is_false()


## =========================================================================
## AC-5: 同时按下处理
## GIVEN 无
## WHEN 同一帧模拟按下 J 和 K
## THEN 两者的 just_pressed 均为 true，缓冲动作为最后处理的
## =========================================================================
func test_simultaneous_press() -> void:
	simulate_key_pressed(KEY_J)
	simulate_key_pressed(KEY_K)
	await idle_frame

	# 两个攻击动作的 just_pressed 都应为 true（Godot Input 事件处理）
	assert_bool(_input_system.is_action_just_pressed(&"attack_you")).is_true()
	assert_bool(_input_system.is_action_just_pressed(&"attack_zuan")).is_true()

	# 缓冲动作应为最后处理的 (attack_zuan)
	assert_str(_input_system.get_buffered_action()).is_equal(&"attack_zuan")


## =========================================================================
## AC-6: 状态过滤 — 禁用后 pressed 返回 false
## GIVEN 调用 enable_action("attack_you", false)，J 键被按住
## WHEN 查询 is_action_pressed("attack_you")
## THEN 返回 false
## =========================================================================
func test_disabled_action_pressed_returns_false() -> void:
	simulate_key_pressed(KEY_J)
	await idle_frame

	# 先确认启用时返回 true
	assert_bool(_input_system.is_action_pressed(&"attack_you")).is_true()

	# 禁用后返回 false
	_input_system.enable_action(&"attack_you", false)

	assert_bool(_input_system.is_action_pressed(&"attack_you")).is_false()


## =========================================================================
## AC-6 边界: 重新启用后恢复
## =========================================================================
func test_re_enabled_action_pressed_returns_true() -> void:
	simulate_key_pressed(KEY_J)
	await idle_frame

	_input_system.enable_action(&"attack_you", false)
	assert_bool(_input_system.is_action_pressed(&"attack_you")).is_false()

	_input_system.enable_action(&"attack_you", true)
	assert_bool(_input_system.is_action_pressed(&"attack_you")).is_true()


## =========================================================================
## AC-7: 状态过滤 — 禁用不触发 just_released
## GIVEN J 键被按住
## WHEN 调用 enable_action("attack_you", false)，下一帧查询 just_released
## THEN is_action_just_released("attack_you") == false
## =========================================================================
func test_disable_does_not_trigger_just_released() -> void:
	simulate_key_pressed(KEY_J)
	await idle_frame

	# 禁用动作（J 键仍物理按住）
	_input_system.enable_action(&"attack_you", false)

	# 下一帧查询 just_released — 禁用时不触发释放事件
	await idle_frame
	assert_bool(_input_system.is_action_just_released(&"attack_you")).is_false()


## =========================================================================
## AC-7 边界: 禁用状态不影响其他动作
## =========================================================================
func test_disable_one_action_does_not_affect_others() -> void:
	simulate_key_pressed(KEY_J)
	simulate_key_pressed(KEY_K)
	await idle_frame

	_input_system.enable_action(&"attack_you", false)

	# attack_you 被禁用
	assert_bool(_input_system.is_action_pressed(&"attack_you")).is_false()
	# attack_zuan 仍然可用
	assert_bool(_input_system.is_action_pressed(&"attack_zuan")).is_true()


## =========================================================================
## AC-8: 缓冲窗口帧数计算
## GIVEN buffer_window_ms=100, target_fps=60
## WHEN 计算 buffer_window_frames
## THEN 结果为 6
## =========================================================================
func test_buffer_window_frames_default_value() -> void:
	# 默认 buffer_window_frames = 6（对应 100ms@60fps）
	assert_int(_input_system.buffer_window_frames).is_equal(6)


## =========================================================================
## AC-9: 缓冲窗口动态设置
## GIVEN 无
## WHEN 调用 set_buffer_window(3)
## THEN buffer_window_frames == 3
## =========================================================================
func test_set_buffer_window() -> void:
	_input_system.set_buffer_window(3)

	assert_int(_input_system.buffer_window_frames).is_equal(3)


## =========================================================================
## AC-9 边界: 设为 0（禁用缓冲）
## =========================================================================
func test_set_buffer_window_zero_disables_buffer() -> void:
	_input_system.set_buffer_window(0)

	assert_int(_input_system.buffer_window_frames).is_equal(0)


## =========================================================================
## AC-9 边界: 设为极大值
## =========================================================================
func test_set_buffer_window_large_value() -> void:
	_input_system.set_buffer_window(100)

	assert_int(_input_system.buffer_window_frames).is_equal(100)


## =========================================================================
## 未禁用动作的查询不被过滤
## =========================================================================
func test_unblocked_action_queries_unfiltered() -> void:
	# 未禁用的动作直接委托给 Godot Input
	simulate_key_pressed(KEY_J)
	await idle_frame

	assert_bool(_input_system.is_action_pressed(&"attack_you")).is_true()
	assert_bool(_input_system.is_action_just_pressed(&"attack_you")).is_true()


## =========================================================================
## 释放未禁用动作正常工作
## =========================================================================
func test_release_unblocked_action_works() -> void:
	simulate_key_pressed(KEY_J)
	await idle_frame

	simulate_key_released(KEY_J)
	await idle_frame

	assert_bool(_input_system.is_action_pressed(&"attack_you")).is_false()
	assert_bool(_input_system.is_action_just_released(&"attack_you")).is_true()
