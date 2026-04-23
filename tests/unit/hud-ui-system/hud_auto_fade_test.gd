## BattleHUD 自动淡出与状态响应测试
##
## 测试 BattleHUD 的自动淡出逻辑、自定义淡出、万剑归宗恢复。
## 基于 Story 002 的所有 AC。
extends GdUnitTestSuite

var _hud: BattleHUD


func before_test() -> void:
	_hud = auto_free(BattleHUD.new())
	# 手动模拟 _ready — 不加载实际子节点，仅初始化变量
	_hud._menu_stack = []
	_hud._menu_nodes = {}
	_hud._hud_root = null
	_hud._last_hit_time = Time.get_ticks_msec() / 1000.0
	_hud._current_alpha = 1.0
	_hud._target_alpha = 1.0


## =========================================================================
## AC-1: 常量验证 — AUTO_FADE_DELAY=3.0, FADED_ALPHA=0.3
## =========================================================================
func test_auto_fade_constants() -> void:
	assert_float(BattleHUD.AUTO_FADE_DELAY).is_equal(3.0)
	assert_float(BattleHUD.FADED_ALPHA).is_equal(0.3)


## =========================================================================
## AC-2: 3 秒无受击后 target_alpha 变为 FADED_ALPHA (0.3)
## =========================================================================
func test_auto_fade_after_delay() -> void:
	# Arrange: 将 last_hit_time 设为 4 秒前（超过 AUTO_FADE_DELAY=3.0）
	_hud._test_set_last_hit_time(Time.get_ticks_msec() / 1000.0 - 4.0)

	# Act: 调用 auto_fade 更新
	_hud._update_auto_fade(0.016)

	# Assert: target_alpha 应该被设为 FADED_ALPHA
	assert_float(_hud._test_get_target_alpha()).is_equal(0.3)


## =========================================================================
## AC-3: 未到 3 秒时 target_alpha 保持 1.0
## =========================================================================
func test_no_fade_within_delay() -> void:
	# Arrange: last_hit_time 设为 1 秒前（未超过 3 秒）
	_hud._test_set_last_hit_time(Time.get_ticks_msec() / 1000.0 - 1.0)

	# Act
	_hud._update_auto_fade(0.016)

	# Assert
	assert_float(_hud._test_get_target_alpha()).is_equal(1.0)


## =========================================================================
## AC-4: lerp 平滑过渡 — alpha 应单调变化，无跳变
## =========================================================================
func test_alpha_lerp_smooth_transition() -> void:
	# Arrange: 超过延迟，alpha 从 1.0 开始
	_hud._test_set_last_hit_time(Time.get_ticks_msec() / 1000.0 - 5.0)
	_hud._current_alpha = 1.0
	_hud._target_alpha = 1.0

	var previous_alpha: float = _hud._current_alpha

	# Act: 模拟多帧迭代
	for i in range(60):
		_hud._update_auto_fade(0.016)
		var current_alpha: float = _hud._test_get_current_alpha()
		# Assert: alpha 应该单调递减（向 0.3 靠拢）
		assert_float(current_alpha).is_less_equal(previous_alpha + 0.001)
		previous_alpha = current_alpha

	# 最终应该接近 FADED_ALPHA
	assert_float(_hud._test_get_current_alpha()).is_between(0.3, 0.5)


## =========================================================================
## AC-5: 受伤后立即恢复 — alpha 目标重置为 1.0
## =========================================================================
func test_damage_resets_fade() -> void:
	# Arrange: 先设置为已淡出状态
	_hud._test_set_last_hit_time(Time.get_ticks_msec() / 1000.0 - 5.0)
	_hud._update_auto_fade(0.016)
	_hud._current_alpha = 0.35  # 已接近淡出

	# Act: 受伤 — 调用 update_health_display 重置 last_hit_time
	_hud.update_health_display(2, 3)

	# Assert: target_alpha 应恢复为 1.0
	assert_float(_hud._test_get_target_alpha()).is_equal(1.0)

	# 经过多帧 alpha 应该回升到接近 1.0
	for i in range(120):
		_hud._update_auto_fade(0.016)

	assert_float(_hud._test_get_current_alpha()).is_greater_equal(0.9)


## =========================================================================
## AC-6: fade_hud(to_alpha, duration) 自定义淡出
## =========================================================================
func test_fade_hud_custom_alpha() -> void:
	# Act
	_hud.fade_hud(0.0, 0.3)

	# Assert: target_alpha 应变为 0.0
	assert_float(_hud._test_get_target_alpha()).is_equal(0.0)


## =========================================================================
## AC-7: fade_hud(0.0) 完全淡出 + restore_hud() 恢复
## =========================================================================
func test_fade_and_restore() -> void:
	# Act: 淡出
	_hud.fade_hud(0.0, 0.0)
	# Assert
	assert_float(_hud._test_get_target_alpha()).is_equal(0.0)

	# Act: 恢复
	_hud.restore_hud()
	# Assert
	assert_float(_hud._test_get_target_alpha()).is_equal(1.0)


## =========================================================================
## AC-8: trigger_myriad_hud_effect() 调用 fade_hud(0.0, ...)
## =========================================================================
func test_myriad_effect_fades_hud() -> void:
	# Act
	_hud.trigger_myriad_hud_effect()

	# Assert
	assert_float(_hud._test_get_target_alpha()).is_equal(0.0)


## =========================================================================
## AC-9: restore_hud_from_myriad() 恢复 full alpha
## =========================================================================
func test_restore_from_myriad() -> void:
	# Arrange
	_hud.trigger_myriad_hud_effect()

	# Act
	_hud.restore_hud_from_myriad()

	# Assert
	assert_float(_hud._test_get_target_alpha()).is_equal(1.0)


## =========================================================================
## AC-10: 连续受击 — 每次都重置淡出计时器
## =========================================================================
func test_consecutive_hits_reset_timer() -> void:
	# Arrange: 进入淡出
	_hud._test_set_last_hit_time(Time.get_ticks_msec() / 1000.0 - 5.0)
	_hud._update_auto_fade(0.016)
	assert_float(_hud._test_get_target_alpha()).is_equal(0.3)

	# Act: 第一次受击
	_hud.update_health_display(2, 3)
	# Assert
	assert_float(_hud._test_get_target_alpha()).is_equal(1.0)

	# Arrange: 等待 2 秒（未到 3 秒）
	_hud._test_set_last_hit_time(Time.get_ticks_msec() / 1000.0 - 2.0)
	_hud._update_auto_fade(0.016)
	# Assert: 未触发淡出
	assert_float(_hud._test_get_target_alpha()).is_equal(1.0)

	# Act: 第二次受击 — 重置计时器
	_hud.update_health_display(1, 3)
	_hud._update_auto_fade(0.016)
	# Assert
	assert_float(_hud._test_get_target_alpha()).is_equal(1.0)


## =========================================================================
## AC-11: alpha 范围限制 — alpha 永不为负
## =========================================================================
func test_alpha_never_negative() -> void:
	# Arrange
	_hud._current_alpha = 0.0
	_hud._target_alpha = 0.0

	# Act
	_hud.fade_hud(-0.5, 0.0)

	# Assert: 即使传入负值，target_alpha 不应为负
	assert_float(_hud._test_get_target_alpha()).is_equal(0.0)


## =========================================================================
## AC-Edge: 淡出时发出 hud_fade_changed 信号
## =========================================================================
func test_fade_changed_signal() -> void:
	var signal_monitor := monitor_signals(_hud)

	# Act
	_hud._test_set_last_hit_time(Time.get_ticks_msec() / 1000.0 - 5.0)
	_hud._update_auto_fade(0.016)

	# Assert
	await assert_signal(signal_monitor).is_emitted("hud_fade_changed")


## =========================================================================
## AC-Edge: 淡出后 _test_is_faded() 返回 true
## =========================================================================
func test_is_faded_reflects_alpha() -> void:
	# Arrange: 正常状态
	assert_bool(_hud._test_is_faded()).is_false()

	# Act: 淡出
	_hud._current_alpha = 0.35

	# Assert
	assert_bool(_hud._test_is_faded()).is_true()
