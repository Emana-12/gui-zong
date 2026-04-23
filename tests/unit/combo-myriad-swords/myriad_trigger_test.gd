## myriad_trigger_test.gd — ComboSystem 万剑归宗触发测试
##
## 覆盖 story-002-myriad-trigger 全部 5 个 AC：
## - AC-1: 蓄力进度查询
## - AC-2: 手动触发万剑归宗
## - AC-3: 自动触发（20 连击）
## - AC-4: 公式计算
## - AC-5: 冷却拒绝
##
## @see production/epics/combo-myriad-swords/story-002-myriad-trigger.md
## @see docs/architecture/adr-0009-combo-system-architecture.md
extends GdUnitTestSuite

var _combo: ComboSystem


func before_test() -> void:
	_combo = auto_free(ComboSystem.new())
	_combo.combo_timeout = 10.0  # 长超时，避免测试中意外归零
	add_child(_combo)


func after_test() -> void:
	pass


## ── 辅助：通过命中事件积累连击 ──────────────────────────────────────────────

## 通过交替命中快速积累连击到目标值
func _accumulate_combo_to(target: int) -> void:
	for i in range(target):
		if i % 2 == 0:
			_combo.on_hit_landed(1)  # YOU
		else:
			_combo.on_hit_landed(3)  # ZUAN


## ── AC-1: 蓄力进度查询 ──────────────────────────────────────────────────────

## 连击数 = 0 时，蓄力进度 = 0.0
func test_charge_progress_at_zero_returns_0() -> void:
	assert_float(_combo.get_charge_progress()).is_equal(0.0)


## 连击数 = 5 时，蓄力进度 = 0.5
func test_charge_progress_at_5_returns_0_5() -> void:
	_accumulate_combo_to(5)
	assert_float(_combo.get_charge_progress()).is_equal(0.5)


## 连击数 = 10 时，蓄力进度 = 1.0（蓄力完成）
func test_charge_progress_at_10_returns_1() -> void:
	_accumulate_combo_to(10)
	assert_float(_combo.get_charge_progress()).is_equal(1.0)


## 连击数 = 15 时，蓄力进度 clamp 为 1.0
func test_charge_progress_at_15_returns_1_clamped() -> void:
	_accumulate_combo_to(15)
	assert_float(_combo.get_charge_progress()).is_equal(1.0)


## 蓄力进度 = 1.0 时 is_myriad_ready 返回 true
func test_myriad_ready_when_charged() -> void:
	_accumulate_combo_to(10)
	assert_bool(_combo.is_myriad_ready()).is_true()


## 连击数 < 10 时 is_myriad_ready 返回 false
func test_myriad_not_ready_below_threshold() -> void:
	_accumulate_combo_to(9)
	assert_bool(_combo.is_myriad_ready()).is_false()


## ── AC-2: 手动触发万剑归宗 ──────────────────────────────────────────────────

## 连击数 = 10，不在冷却中，trigger_myriad() 返回 true
func test_trigger_myriad_at_charge_threshold_returns_true() -> void:
	_accumulate_combo_to(10)
	assert_bool(_combo.trigger_myriad()).is_true()


## trigger_myriad 成功后连击归零
func test_trigger_myriad_resets_combo() -> void:
	_accumulate_combo_to(10)
	_combo.trigger_myriad()
	assert_int(_combo.get_combo_count()).is_equal(0)


## trigger_myriad 成功后蓄力进度归零
func test_trigger_myriad_resets_charge_progress() -> void:
	_accumulate_combo_to(10)
	_combo.trigger_myriad()
	assert_float(_combo.get_charge_progress()).is_equal(0.0)


## trigger_myriad 成功后 is_myriad_ready 返回 false
func test_trigger_myriad_disables_ready() -> void:
	_accumulate_combo_to(10)
	_combo.trigger_myriad()
	assert_bool(_combo.is_myriad_ready()).is_false()


## 连击数 = 9（< 蓄力阈值），trigger_myriad() 返回 false
func test_trigger_myriad_below_threshold_returns_false() -> void:
	_accumulate_combo_to(9)
	assert_bool(_combo.trigger_myriad()).is_false()


## 连击数 = 0，trigger_myriad() 返回 false
func test_trigger_myriad_at_zero_returns_false() -> void:
	assert_bool(_combo.trigger_myriad()).is_false()


## ── AC-3: 自动触发（20 连击）────────────────────────────────────────────────

## 连击达到 20 时自动触发万剑归宗
func test_auto_trigger_at_20_emits_signal() -> void:
	var monitor := await monitor_signals(_combo)
	_accumulate_combo_to(20)
	await assert_signal(monitor).is_emitted("myriad_triggered")


## 自动触发后连击归零
func test_auto_trigger_resets_combo() -> void:
	_accumulate_combo_to(20)
	assert_int(_combo.get_combo_count()).is_equal(0)


## 自动触发后进入冷却
func test_auto_trigger_enters_cooldown() -> void:
	_accumulate_combo_to(20)
	assert_bool(_combo.trigger_myriad()).is_false()


## ── AC-4: 公式计算 ──────────────────────────────────────────────────────────

## 连击数 = 10 时触发：轨迹数 = 15（5+10），伤害 = 5，范围 = 8.0
func test_myriad_formulas_at_combo_10() -> void:
	# 使用测试辅助方法直接设置连击数，跳过正常命中流程
	_combo._test_set_combo_count(10)
	_combo.trigger_myriad()

	# 通过信号验证参数 — 连接信号捕获
	var captured_trail_count: int = -1
	var captured_damage: float = -1.0
	var captured_radius: float = -1.0

	var callback := func(trail_count: int, damage: float, radius: float) -> void:
		captured_trail_count = trail_count
		captured_damage = damage
		captured_radius = radius

	_combo.myriad_triggered.connect(callback)
	_combo._test_set_combo_count(10)
	_combo.trigger_myriad()

	assert_int(captured_trail_count).is_equal(15)
	assert_float(captured_damage).is_equal(5.0)
	assert_float(captured_radius).is_equal(8.0)


## 连击数 = 20 时触发：轨迹数 = 25（5+20），伤害 = 10，范围 = 11.0
func test_myriad_formulas_at_combo_20() -> void:
	var captured_trail_count: int = -1
	var captured_damage: float = -1.0
	var captured_radius: float = -1.0

	var callback := func(trail_count: int, damage: float, radius: float) -> void:
		captured_trail_count = trail_count
		captured_damage = damage
		captured_radius = radius

	_combo.myriad_triggered.connect(callback)
	_combo._test_set_combo_count(20)
	_combo.trigger_myriad()

	assert_int(captured_trail_count).is_equal(25)
	assert_float(captured_damage).is_equal(10.0)
	assert_float(captured_radius).is_equal(11.0)


## 轨迹数上限 50：连击数 = 50 时轨迹数 = 50（不超出上限）
func test_myriad_trail_count_capped_at_50() -> void:
	var captured_trail_count: int = -1

	var callback := func(trail_count: int, _damage: float, _radius: float) -> void:
		captured_trail_count = trail_count

	_combo.myriad_triggered.connect(callback)
	_combo._test_set_combo_count(50)
	_combo.trigger_myriad()

	assert_int(captured_trail_count).is_equal(50)


## 轨迹数上限 50：连击数 = 60 时轨迹数仍 = 50
func test_myriad_trail_count_capped_at_50_over() -> void:
	var captured_trail_count: int = -1

	var callback := func(trail_count: int, _damage: float, _radius: float) -> void:
		captured_trail_count = trail_count

	_combo.myriad_triggered.connect(callback)
	_combo._test_set_combo_count(60)
	_combo.trigger_myriad()

	assert_int(captured_trail_count).is_equal(50)


## ── AC-5: 冷却拒绝 ──────────────────────────────────────────────────────────

## 万剑归宗刚触发后，再次调用 trigger_myriad() 返回 false
func test_trigger_myriad_during_cooldown_returns_false() -> void:
	_accumulate_combo_to(10)
	_combo.trigger_myriad()  # 第一次成功，进入冷却

	# 重新蓄力到阈值
	_accumulate_combo_to(10)
	assert_bool(_combo.trigger_myriad()).is_false()


## is_myriad_ready 在冷却中返回 false
func test_myriad_not_ready_during_cooldown() -> void:
	# 用测试辅助方法设置状态
	_combo._test_set_combo_count(10)
	_combo.trigger_myriad()

	# 重新蓄力
	_combo._test_set_combo_count(10)
	assert_bool(_combo.is_myriad_ready()).is_false()


## 冷却结束后可以重新触发
func test_trigger_myriad_after_cooldown_ends() -> void:
	# 设置短冷却用于测试（通过 test 辅助方法覆盖）
	_combo._test_set_combo_count(10)
	_combo.trigger_myriad()

	# 手动停止冷却模拟冷却结束
	_combo._test_set_cooldown(false)
	_combo._test_set_combo_count(10)
	assert_bool(_combo.trigger_myriad()).is_true()


## ── 蓄力进度信号测试 ────────────────────────────────────────────────────────

## 连击增加时 charge_changed 信号发出
func test_charge_changed_signal_emitted_on_combo_increase() -> void:
	var monitor := await monitor_signals(_combo)
	_combo.on_hit_landed(1)  # YOU, combo=1, progress=0.1
	await assert_signal(monitor).is_emitted("charge_changed", [0.1])


## 受击归零时 charge_changed 信号发出 0.0
func test_charge_changed_signal_emitted_on_reset() -> void:
	_accumulate_combo_to(5)
	var monitor := await monitor_signals(_combo)
	_combo.on_player_hit()
	await assert_signal(monitor).is_emitted("charge_changed", [0.0])


## ── myriad_triggered 信号测试 ────────────────────────────────────────────────

## 手动触发时 myriad_triggered 信号发出
func test_myriad_triggered_signal_emitted_on_manual() -> void:
	var monitor := await monitor_signals(_combo)
	_accumulate_combo_to(10)
	_combo.trigger_myriad()
	await assert_signal(monitor).is_emitted("myriad_triggered")


## ── 边界与集成 ──────────────────────────────────────────────────────────────

## 受击后蓄力重置，需要重新积累
func test_hit_resets_charge_progress() -> void:
	_accumulate_combo_to(10)
	assert_bool(_combo.is_myriad_ready()).is_true()

	_combo.on_player_hit()
	assert_float(_combo.get_charge_progress()).is_equal(0.0)
	assert_bool(_combo.is_myriad_ready()).is_false()


## 万剑归宗触发后可以重新积累连击和蓄力
func test_can_recharge_after_myriad() -> void:
	_accumulate_combo_to(10)
	_combo.trigger_myriad()

	# 重新积累
	_accumulate_combo_to(10)
	assert_int(_combo.get_combo_count()).is_equal(10)
	assert_bool(_combo.is_myriad_ready()).is_false()  # 冷却中


## 敌人攻击不触发自动万剑归宗
func test_enemy_hit_does_not_auto_trigger() -> void:
	_accumulate_combo_to(19)
	_combo.on_hit_landed(0)  # ENEMY
	assert_int(_combo.get_combo_count()).is_equal(19)
	# 万剑归宗不应触发（连击未达 20）
	assert_bool(_combo.is_myriad_ready()).is_true()  # 蓄力完成
