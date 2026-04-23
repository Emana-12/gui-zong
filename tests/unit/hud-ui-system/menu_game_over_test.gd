@warning_ignore_start("inferred_declaration")
## BattleHUD 菜单系统与游戏结束测试
##
## 测试菜单栈 (push/pop)、游戏结束画面、墨迹侵蚀动画。
## 基于 Story 003 的所有 AC。
extends GdUnitTestSuite

var _hud: BattleHUD


func before_test() -> void:
	_hud = auto_free(BattleHUD.new())
	_hud._menu_stack = []
	_hud._menu_nodes = {}
	_hud._hud_root = null
	_hud._menu_layer = null
	_hud._last_hit_time = Time.get_ticks_msec() / 1000.0
	_hud._current_alpha = 1.0
	_hud._target_alpha = 1.0


## =========================================================================
## AC-1: show_menu() 推入菜单到栈顶，菜单可见
## =========================================================================
func test_show_menu_pushes_to_stack() -> void:
	# Arrange
	var fake_menu := auto_free(Panel.new())
	fake_menu.visible = false
	_hud._menu_nodes["pause"] = fake_menu

	# Act
	_hud.show_menu("pause")

	# Assert
	var stack: Array = _hud._test_get_menu_stack()
	assert_int(stack.size()).is_equal(1)
	assert_str(stack[0]).is_equal("pause")
	assert_bool(fake_menu.visible).is_true()


## =========================================================================
## AC-2: hide_menu() 弹出栈顶菜单，隐藏该菜单
## =========================================================================
func test_hide_menu_pops_from_stack() -> void:
	# Arrange
	var fake_menu := auto_free(Panel.new())
	fake_menu.visible = true
	_hud._menu_nodes["pause"] = fake_menu
	_hud.show_menu("pause")

	# Act
	_hud.hide_menu()

	# Assert
	var stack: Array = _hud._test_get_menu_stack()
	assert_int(stack.size()).is_equal(0)
	assert_bool(fake_menu.visible).is_false()


## =========================================================================
## AC-3: 菜单栈 — push 多个菜单后 pop 恢复前一个
## =========================================================================
func test_menu_stack_push_pop() -> void:
	# Arrange
	var menu_a := auto_free(Panel.new())
	var menu_b := auto_free(Panel.new())
	_hud._menu_nodes["a"] = menu_a
	_hud._menu_nodes["b"] = menu_b

	# Act: push 两个菜单
	_hud.show_menu("a")
	_hud.show_menu("b")

	# Assert: 栈中有两个，顶部是 b
	var stack: Array = _hud._test_get_menu_stack()
	assert_int(stack.size()).is_equal(2)
	assert_str(stack[1]).is_equal("b")

	# Act: pop b
	_hud.hide_menu()

	# Assert: 栈中只剩 a
	stack = _hud._test_get_menu_stack()
	assert_int(stack.size()).is_equal(1)
	assert_str(stack[0]).is_equal("a")
	assert_bool(menu_b.visible).is_false()
	assert_bool(menu_a.visible).is_true()


## =========================================================================
## AC-4: hide_all_menus() 隐藏所有菜单并清空栈
## =========================================================================
func test_hide_all_menus_clears_stack() -> void:
	# Arrange
	var menu_a := auto_free(Panel.new())
	var menu_b := auto_free(Panel.new())
	_hud._menu_nodes["a"] = menu_a
	_hud._menu_nodes["b"] = menu_b
	_hud.show_menu("a")
	_hud.show_menu("b")

	# Act
	_hud.hide_all_menus()

	# Assert
	var stack: Array = _hud._test_get_menu_stack()
	assert_int(stack.size()).is_equal(0)
	assert_bool(menu_a.visible).is_false()
	assert_bool(menu_b.visible).is_false()


## =========================================================================
## AC-5: show_game_over() 创建游戏结束面板
## =========================================================================
func test_show_game_over_creates_panel() -> void:
	# Act
	_hud.show_game_over(12500)

	# Assert
	assert_bool(_hud._game_over_panel != null).is_true()
	assert_bool(_hud._game_over_panel.visible).is_true()


## =========================================================================
## AC-6: 游戏结束面板标题和说明文字为纯白色 (非金墨)
## =========================================================================
func test_game_over_text_is_white() -> void:
	# Act
	_hud.show_game_over(8000)

	# Assert: 标题 "剑已断" 和 "分" 应为白色
	var labels := _find_labels_recursive(_hud._game_over_panel)
	assert_bool(labels.size() > 0).is_true()

	for label in labels:
		# 跳过得分标签（金墨色）
		if label.text == "8000":
			continue
		var font_color: Color = label.get_theme_color("font_color")
		assert_float(font_color.r).is_equal(1.0)
		assert_float(font_color.g).is_equal(1.0)
		assert_float(font_color.b).is_equal(1.0)


## =========================================================================
## AC-6b: 得分标签为金墨色
## =========================================================================
func test_game_over_score_is_gold() -> void:
	# Act
	_hud.show_game_over(8000)

	# Assert: 得分标签应为金墨色
	var score_label := _find_label_by_text(_hud._game_over_panel, "8000")
	assert_bool(score_label != null).is_true()

	var font_color: Color = score_label.get_theme_color("font_color")
	assert_float(font_color.r).is_equal_approx(0.85, 0.01)
	assert_float(font_color.g).is_equal_approx(0.65, 0.01)
	assert_float(font_color.b).is_equal_approx(0.13, 0.01)


## =========================================================================
## AC-7: 游戏结束面板显示分数
## =========================================================================
func test_game_over_shows_score() -> void:
	# Act
	_hud.show_game_over(42000)

	# Assert
	var score_label := _find_label_by_text(_hud._game_over_panel, "42000")
	assert_bool(score_label != null).is_true()


## =========================================================================
## AC-8: show_game_over() 含"重新开始"按钮
## =========================================================================
func test_game_over_has_restart_button() -> void:
	# Act
	_hud.show_game_over(100)

	# Assert
	var buttons := _find_buttons_recursive(_hud._game_over_panel)
	assert_bool(buttons.size() > 0).is_true()

	var restart_found: bool = false
	for btn in buttons:
		if btn.text == "重新开始":
			restart_found = true
			break
	assert_bool(restart_found).is_true()


## =========================================================================
## AC-9: 重新开始按钮已绑定 pressed 信号
## =========================================================================
func test_restart_button_has_signal_connection() -> void:
	# Arrange
	_hud.show_game_over(500)

	# Act: 找到重新开始按钮
	var buttons := _find_buttons_recursive(_hud._game_over_panel)
	var restart_btn: Button = null
	for btn in buttons:
		if btn.text == "重新开始":
			restart_btn = btn
			break

	# Assert: 按钮存在且有信号连接
	assert_bool(restart_btn != null).is_true()
	var connections := restart_btn.pressed.get_connections()
	assert_bool(connections.size() > 0).is_true()


## =========================================================================
## AC-10: 幂等 push — 栈顶已是同名菜单时不重复推入
## =========================================================================
func test_idempotent_push_same_menu() -> void:
	# Arrange
	var fake_menu := auto_free(Panel.new())
	_hud._menu_nodes["pause"] = fake_menu

	# Act
	_hud.show_menu("pause")
	_hud.show_menu("pause")

	# Assert
	var stack: Array = _hud._test_get_menu_stack()
	assert_int(stack.size()).is_equal(1)


## =========================================================================
## AC-11: hide_menu() 空栈安全 — 不崩溃
## =========================================================================
func test_hide_menu_empty_stack_safe() -> void:
	# Act: 不应抛出异常
	_hud.hide_menu()

	# Assert
	var stack: Array = _hud._test_get_menu_stack()
	assert_int(stack.size()).is_equal(0)


## =========================================================================
## AC-12: show_menu() 发出 menu_opened 信号
## =========================================================================
func test_show_menu_emits_signal() -> void:
	var signal_monitor := monitor_signals(_hud)

	var fake_menu := auto_free(Panel.new())
	_hud._menu_nodes["test"] = fake_menu

	_hud.show_menu("test")

	await assert_signal(signal_monitor).is_emitted("menu_opened")


## =========================================================================
## AC-13: hide_menu() 发出 menu_closed 信号
## =========================================================================
func test_hide_menu_emits_signal() -> void:
	# Arrange
	var fake_menu := auto_free(Panel.new())
	_hud._menu_nodes["test"] = fake_menu
	_hud.show_menu("test")

	var signal_monitor := monitor_signals(_hud)

	# Act
	_hud.hide_menu()

	# Assert
	await assert_signal(signal_monitor).is_emitted("menu_closed")


## =========================================================================
## AC-14: show_game_over() 将 game_over 推入菜单栈
## =========================================================================
func test_show_game_over_pushes_to_stack() -> void:
	# Act
	_hud.show_game_over(999)

	# Assert
	var stack: Array = _hud._test_get_menu_stack()
	assert_int(stack.size()).is_equal(1)
	assert_str(stack[0]).is_equal("game_over")


## =========================================================================
## AC-15: 游戏结束面板按钮文字为纯白色
## =========================================================================
func test_restart_button_text_is_white() -> void:
	# Act
	_hud.show_game_over(100)

	# Assert
	var buttons := _find_buttons_recursive(_hud._game_over_panel)
	for btn in buttons:
		var font_color: Color = btn.get_theme_color("font_color")
		assert_float(font_color.r).is_equal(1.0)
		assert_float(font_color.g).is_equal(1.0)
		assert_float(font_color.b).is_equal(1.0)


## =========================================================================
## 辅助: 递归查找所有 Label
## =========================================================================
func _find_labels_recursive(node: Node) -> Array[Label]:
	var result: Array[Label] = []
	if node is Label:
		result.append(node as Label)
	for child in node.get_children():
		result.append_array(_find_labels_recursive(child))
	return result


## =========================================================================
## 辅助: 递归查找所有 Button
## =========================================================================
func _find_buttons_recursive(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button:
		result.append(node as Button)
	for child in node.get_children():
		result.append_array(_find_buttons_recursive(child))
	return result


## =========================================================================
## 辅助: 递归查找包含指定文本的 Label
## =========================================================================
func _find_label_by_text(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text.contains(text):
		return node as Label
	for child in node.get_children():
		var found := _find_label_by_text(child, text)
		if found != null:
			return found
	return null
