@warning_ignore_start("inferred_declaration")
# SPDX-License-Identifier: MIT
## S03-03 计分系统单元测试
##
## 测试内容:
## - 每波完成 → 最高波次更新
## - 连击中断 → 最长连击更新
## - 万剑归宗触发 → 计数 +1
## - save_score() → 最佳记录更新
## - reset_current() → 本局数据归零
## - 打破/未打破历史记录
##
## @see design/gdd/scoring-system.md
## @see production/sprints/sprint-03.md S03-03
extends GdUnitTestSuite

var _scoring: ScoringSystem


func before_test() -> void:
	_scoring = auto_free(ScoringSystem.new())
	_scoring._test_disable_save()  # 测试隔离：不持久化


func after_test() -> void:
	_scoring = null


## AC-1: 每波完成 → 最高波次更新
## Given: 本局最高波次 = 0
## When: on_wave_completed(10)
## Then: highest_wave = 10
func test_wave_completed_updates_highest() -> void:
	_scoring.on_wave_completed(10)
	assert_int(_scoring.get_current_score().highest_wave).is_equal(10)


## AC-1b: 更低波次不覆盖
## Given: 本局最高波次 = 10
## When: on_wave_completed(5)
## Then: highest_wave 仍为 10
func test_lower_wave_does_not_override() -> void:
	_scoring.on_wave_completed(10)
	_scoring.on_wave_completed(5)
	assert_int(_scoring.get_current_score().highest_wave).is_equal(10)


## AC-1c: 波次 = 0 不更新
## Given: 本局最高波次 = 0
## When: on_wave_completed(0)
## Then: highest_wave 仍为 0
func test_wave_zero_no_update() -> void:
	_scoring.on_wave_completed(0)
	assert_int(_scoring.get_current_score().highest_wave).is_equal(0)


## AC-2: 连击中断 → 最长连击更新
## Given: 本局最长连击 = 0
## When: on_combo_broken(15)
## Then: longest_combo = 15
func test_combo_broken_updates_longest() -> void:
	_scoring.on_combo_broken(15)
	assert_int(_scoring.get_current_score().longest_combo).is_equal(15)


## AC-2b: 更短连击不覆盖
## Given: 本局最长连击 = 15
## When: on_combo_broken(5)
## Then: longest_combo 仍为 15
func test_shorter_combo_does_not_override() -> void:
	_scoring.on_combo_broken(15)
	_scoring.on_combo_broken(5)
	assert_int(_scoring.get_current_score().longest_combo).is_equal(15)


## AC-2c: 连击 = 0 不更新
func test_combo_zero_no_update() -> void:
	_scoring.on_combo_broken(0)
	assert_int(_scoring.get_current_score().longest_combo).is_equal(0)


## AC-3: 万剑归宗触发 → 计数 +1
## Given: 本局万剑归宗 = 0
## When: on_myriad_triggered() 3 次
## Then: myriad_count = 3
func test_myriad_triggered_increments() -> void:
	_scoring.on_myriad_triggered()
	_scoring.on_myriad_triggered()
	_scoring.on_myriad_triggered()
	assert_int(_scoring.get_current_score().myriad_count).is_equal(3)


## AC-4: save_score() 打破记录 → 最佳记录更新
## Given: 最佳记录 wave=5, combo=10, myriad=1
## And: 本局 wave=8, combo=12, myriad=2
## When: save_score()
## Then: get_best_score() 返回新值
func test_save_score_updates_when_better() -> void:
	_scoring._test_set_best(5, 10, 1)
	_scoring.on_wave_completed(8)
	_scoring.on_combo_broken(12)
	_scoring.on_myriad_triggered()
	_scoring.on_myriad_triggered()
	_scoring.save_score()

	var best = _scoring.get_best_score()
	assert_int(best.highest_wave).is_equal(8)
	assert_int(best.longest_combo).is_equal(12)
	assert_int(best.myriad_count).is_equal(2)


## AC-4b: save_score() 未打破记录 → 最佳记录不变
## Given: 最佳记录 wave=10
## And: 本局 wave=5
## When: save_score()
## Then: get_best_score() 保持不变
func test_save_score_no_update_when_worse() -> void:
	_scoring._test_set_best(10, 15, 3)
	_scoring.on_wave_completed(5)
	_scoring.save_score()

	var best = _scoring.get_best_score()
	assert_int(best.highest_wave).is_equal(10)
	assert_int(best.longest_combo).is_equal(15)
	assert_int(best.myriad_count).is_equal(3)


## AC-5: reset_current() → 本局数据归零
## Given: 本局有数据
## When: reset_current()
## Then: 所有字段归零
func test_reset_current_clears_data() -> void:
	_scoring.on_wave_completed(10)
	_scoring.on_combo_broken(15)
	_scoring.on_myriad_triggered()
	_scoring.reset_current()

	var current = _scoring.get_current_score()
	assert_int(current.highest_wave).is_equal(0)
	assert_int(current.longest_combo).is_equal(0)
	assert_int(current.myriad_count).is_equal(0)


## AC-Edge: 首局游戏（无历史记录）
## Given: 无历史记录
## When: get_best_score()
## Then: 返回默认值 (0, 0, 0)
func test_first_game_best_score_defaults() -> void:
	# before_test 创建新实例，_load_best_score 找不到文件
	var best = _scoring.get_best_score()
	assert_int(best.highest_wave).is_equal(0)
	assert_int(best.longest_combo).is_equal(0)
	assert_int(best.myriad_count).is_equal(0)


## ScoreData.is_better_than: 波次优先比较
func test_score_comparison_wave_priority() -> void:
	var a := ScoringSystem.ScoreData.new(10, 5, 1)
	var b := ScoringSystem.ScoreData.new(5, 15, 3)
	assert_bool(a.is_better_than(b)).is_true()
	assert_bool(b.is_better_than(a)).is_false()


## ScoreData.is_better_than: 波次相同比连击
func test_score_comparison_combo_tiebreak() -> void:
	var a := ScoringSystem.ScoreData.new(10, 15, 1)
	var b := ScoringSystem.ScoreData.new(10, 5, 3)
	assert_bool(a.is_better_than(b)).is_true()


## ScoreData.is_better_than: 波次连击相同比万剑归宗
func test_score_comparison_myriad_tiebreak() -> void:
	var a := ScoringSystem.ScoreData.new(10, 15, 5)
	var b := ScoringSystem.ScoreData.new(10, 15, 3)
	assert_bool(a.is_better_than(b)).is_true()


## ScoreData.is_better_than: 完全相同不算更好
func test_score_comparison_equal() -> void:
	var a := ScoringSystem.ScoreData.new(10, 15, 3)
	var b := ScoringSystem.ScoreData.new(10, 15, 3)
	assert_bool(a.is_better_than(b)).is_false()
