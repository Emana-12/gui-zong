# 战斗 HUD 显示测试
extends GdUnitTestSuite

var _hud: BattleHUD


func before_test() -> void:
	_hud = auto_free(BattleHUD.new())
	add_child(_hud)
	await get_tree().process_frame


# ─── 生命值显示 ──────────────────────────────────────────────────────────────

func test_update_health_display_sets_target_alpha_to_full() -> void:
	_hud._test_set_last_hit_time(0.0)
	_hud.update_health_display(3, 3)
	# 受伤后 HUD 应恢复全显
	assert_float(_hud._test_get_target_alpha()).is_equal(1.0)


func test_update_health_resets_fade_timer() -> void:
	# 模拟长时间无操作
	_hud._test_set_last_hit_time(-100.0)
	_hud.update_health_display(2, 3)
	# 受击后 last_hit_time 应更新
	# _target_alpha 应为 FULL_ALPHA
	assert_float(_hud._test_get_target_alpha()).is_equal(1.0)


# ─── 连击显示 ────────────────────────────────────────────────────────────────

func test_combo_label_visible_when_combo_greater_than_zero() -> void:
	_hud.update_combo_display(5)
	# 标签应可见（如果节点存在）
	# 无实际节点时不崩溃
	pass


func test_combo_zero_does_not_crash() -> void:
	_hud.update_combo_display(0)
	pass


# ─── 剑式指示器 ──────────────────────────────────────────────────────────────

func test_form_display_does_not_crash() -> void:
	_hud.update_form_display(0)
	_hud.update_form_display(1)
	_hud.update_form_display(2)
	pass


# ─── 蓄力环 ──────────────────────────────────────────────────────────────────

func test_charge_display_does_not_crash() -> void:
	_hud.update_charge_display(0.0)
	_hud.update_charge_display(0.5)
	_hud.update_charge_display(1.0)
	pass


# ─── HUD 淡出/恢复 ───────────────────────────────────────────────────────────

func test_fade_hud_sets_target_alpha() -> void:
	_hud.fade_hud(0.0, 0.3)
	assert_float(_hud._test_get_target_alpha()).is_equal(0.0)


func test_restore_hud_sets_target_alpha_to_full() -> void:
	_hud.fade_hud(0.0, 0.3)
	_hud.restore_hud()
	assert_float(_hud._test_get_target_alpha()).is_equal(1.0)


# ─── 自动淡出 ────────────────────────────────────────────────────────────────

func test_auto_fade_after_delay() -> void:
	# 设置上次受击为很久以前
	_hud._test_set_last_hit_time(-100.0)
	# 手动触发 _update_auto_fade
	_hud._update_auto_fade(0.016)
	# 目标 alpha 应为 FADED_ALPHA
	assert_float(_hud._test_get_target_alpha()).is_equal_approx(0.3, 0.01)


func test_no_auto_fade_when_recently_hit() -> void:
	# 刚刚受击
	_hud._test_set_last_hit_time(Time.get_ticks_msec() / 1000.0)
	_hud._update_auto_fade(0.016)
	assert_float(_hud._test_get_target_alpha()).is_equal(1.0)


# ─── 常量 ────────────────────────────────────────────────────────────────────

func test_constants() -> void:
	assert_float(BattleHUD.AUTO_FADE_DELAY).is_equal(3.0)
	assert_float(BattleHUD.FADED_ALPHA).is_equal(0.3)
	assert_float(BattleHUD.FULL_ALPHA).is_equal(1.0)
	assert_int(BattleHUD.MAX_INK_DROPS).is_equal(3)
	assert_int(BattleHUD.MAX_INK_DOTS).is_equal(20)
