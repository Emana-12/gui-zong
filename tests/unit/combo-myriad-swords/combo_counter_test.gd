## combo_counter_test.gd — ComboSystem 连击计数测试
##
## 覆盖 story-001-combo-counter 全部 4 个 AC：
## - AC-1: 不同式连续命中 +1
## - AC-2: 同式连续命中不变
## - AC-3: 受击归零
## - AC-4: 超时归零
##
## @see production/epics/combo-myriad-swords/story-001-combo-counter.md
## @see docs/architecture/adr-0009-combo-system-architecture.md
extends GdUnitTestSuite

var _combo: ComboSystem


func before_test() -> void:
	_combo = auto_free(ComboSystem.new())
	_combo.combo_timeout = 1.0  # 测试用短超时，避免测试等待过长
	add_child(_combo)


func after_test() -> void:
	pass


## ── AC-1: 不同式连续命中 +1 ──────────────────────────────────────────────────

## 游→钻→绕连续命中，第 3 次命中时连击数 = 3
func test_combo_ac1_you_zuan_rao_returns_3() -> void:
	_combo.on_hit_landed(1)  # SwordForm.YOU
	_combo.on_hit_landed(3)  # SwordForm.ZUAN
	_combo.on_hit_landed(2)  # SwordForm.RAO
	assert_int(_combo.get_combo_count()).is_equal(3)


## 游→钻→游→钻（交替），连击数 = 4
func test_combo_ac1_alternating_returns_4() -> void:
	_combo.on_hit_landed(1)  # YOU
	_combo.on_hit_landed(3)  # ZUAN
	_combo.on_hit_landed(1)  # YOU
	_combo.on_hit_landed(3)  # ZUAN
	assert_int(_combo.get_combo_count()).is_equal(4)


## 长序列：20 次不同式交替命中
func test_combo_ac1_long_alternating_sequence() -> void:
	for i in range(20):
		if i % 2 == 0:
			_combo.on_hit_landed(1)  # YOU
		else:
			_combo.on_hit_landed(3)  # ZUAN
	assert_int(_combo.get_combo_count()).is_equal(20)


## 首次命中：连击数 0 → 1
func test_combo_ac1_first_hit_returns_1() -> void:
	_combo.on_hit_landed(1)  # SwordForm.YOU
	assert_int(_combo.get_combo_count()).is_equal(1)


## ── AC-2: 同式连续命中不变 ──────────────────────────────────────────────────

## 连击数 = 3 时，再使用游剑式命中（与上一式相同），连击数不变
func test_combo_ac2_same_form_does_not_increase() -> void:
	_combo.on_hit_landed(1)  # YOU
	_combo.on_hit_landed(3)  # ZUAN
	_combo.on_hit_landed(2)  # RAO
	_combo.on_hit_landed(1)  # YOU (again, same as last)
	assert_int(_combo.get_combo_count()).is_equal(3)


## 连续 3 次同式命中，连击数仍为 1
func test_combo_ac2_triple_same_form_stays_1() -> void:
	_combo.on_hit_landed(1)  # YOU
	_combo.on_hit_landed(1)  # YOU
	_combo.on_hit_landed(1)  # YOU
	assert_int(_combo.get_combo_count()).is_equal(1)


## 同式命中后仍然可以继续增加连击（不同式恢复）
func test_combo_ac2_same_then_different_increases() -> void:
	_combo.on_hit_landed(1)  # YOU → 1
	_combo.on_hit_landed(1)  # YOU (same) → still 1
	_combo.on_hit_landed(3)  # ZUAN (different) → 2
	assert_int(_combo.get_combo_count()).is_equal(2)


## ── AC-3: 受击归零 ──────────────────────────────────────────────────────────

## 连击数 = 5 时被敌人击中，连击归零
func test_combo_ac3_hit_resets_to_zero() -> void:
	for i in range(5):
		if i % 2 == 0:
			_combo.on_hit_landed(1)
		else:
			_combo.on_hit_landed(3)
	assert_int(_combo.get_combo_count()).is_equal(5)

	_combo.on_player_hit()
	assert_int(_combo.get_combo_count()).is_equal(0)


## 连击数 = 1 时受击归零
func test_combo_ac3_hit_at_1_resets_to_zero() -> void:
	_combo.on_hit_landed(1)
	assert_int(_combo.get_combo_count()).is_equal(1)

	_combo.on_player_hit()
	assert_int(_combo.get_combo_count()).is_equal(0)


## 连续受击两次，连击仍为 0
func test_combo_ac3_double_hit_stays_zero() -> void:
	_combo.on_hit_landed(1)
	_combo.on_hit_landed(3)
	_combo.on_player_hit()
	_combo.on_player_hit()
	assert_int(_combo.get_combo_count()).is_equal(0)


## ── AC-4: 超时归零 ──────────────────────────────────────────────────────────

## 连击数 = 7 时，超时后连击归零
func test_combo_ac4_timeout_resets_to_zero() -> void:
	# 用极短超时加速测试
	_combo.combo_timeout = 0.05
	for i in range(7):
		if i % 2 == 0:
			_combo.on_hit_landed(1)
		else:
			_combo.on_hit_landed(3)
	assert_int(_combo.get_combo_count()).is_equal(7)

	# 等待超时触发
	await await_millis(200)
	assert_int(_combo.get_combo_count()).is_equal(0)


## 超时剩余极少时新命中重启计时器
func test_combo_ac4_hit_before_timeout_restarts_timer() -> void:
	_combo.combo_timeout = 0.2
	_combo.on_hit_landed(1)
	_combo.on_hit_landed(3)
	assert_int(_combo.get_combo_count()).is_equal(2)

	# 在超时前追加命中
	await await_millis(100)
	_combo.on_hit_landed(2)  # RAO，不同式 → 3
	assert_int(_combo.get_combo_count()).is_equal(3)

	# 再次等待超时确认归零
	await await_millis(300)
	assert_int(_combo.get_combo_count()).is_equal(0)


## ── combo_changed 信号测试 ──────────────────────────────────────────────────

## 连击增加时 combo_changed 信号发出
func test_combo_changed_signal_emitted_on_increase() -> void:
	var monitor := await monitor_signals(_combo)
	_combo.on_hit_landed(1)  # YOU
	await assert_signal(monitor).is_emitted("combo_changed", [1])


## 受击归零时 combo_changed 信号发出
func test_combo_changed_signal_emitted_on_hit_reset() -> void:
	_combo.on_hit_landed(1)
	_combo.on_hit_landed(3)
	var monitor := await monitor_signals(_combo)
	_combo.on_player_hit()
	await assert_signal(monitor).is_emitted("combo_changed", [0])


## 同式命中不发出 combo_changed 信号
func test_combo_changed_not_emitted_on_same_form() -> void:
	_combo.on_hit_landed(1)
	var monitor := await monitor_signals(_combo)
	_combo.on_hit_landed(1)  # 同式
	await assert_signal(monitor).is_not_emitted("combo_changed")


## ── reset_combo 外部重置测试 ────────────────────────────────────────────────

## reset_combo 外部调用重置连击
func test_reset_combo_clears_count() -> void:
	_combo.on_hit_landed(1)
	_combo.on_hit_landed(3)
	assert_int(_combo.get_combo_count()).is_equal(2)
	_combo.reset_combo()
	assert_int(_combo.get_combo_count()).is_equal(0)


## ── 边界值测试 ──────────────────────────────────────────────────────────────

## SwordForm.ENEMY (0) 不计入连击
func test_enemy_hit_does_not_increase_combo() -> void:
	_combo.on_hit_landed(0)  # ENEMY
	assert_int(_combo.get_combo_count()).is_equal(0)


## 初始连击数为 0
func test_initial_combo_count_is_zero() -> void:
	assert_int(_combo.get_combo_count()).is_equal(0)
