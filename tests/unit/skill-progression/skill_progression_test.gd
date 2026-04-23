@warning_ignore_start("inferred_declaration")
# SPDX-License-Identifier: MIT
## S03-08 纯技巧进度系统单元测试
##
## @see design/gdd/skill-progression.md
## @see production/sprints/sprint-03.md S03-08
extends GdUnitTestSuite

var _progression: SkillProgression


func before_test() -> void:
	_progression = auto_free(SkillProgression.new())
	_progression._game_start_time = 0.0


func after_test() -> void:
	_progression = null


## AC-1: 追踪平均连击长度
## Given: 3 次连击中断 (长度 5, 10, 15)
## When: 查询平均连击长度
## Then: 平均 = (5+10+15) / 3 = 10.0
func test_avg_combo_length() -> void:
	_progression.on_combo_broken(5)
	_progression.on_combo_broken(10)
	_progression.on_combo_broken(15)
	var metrics := _progression.get_current_metrics()
	assert_float(metrics.get_avg_combo_length()).is_equal(10.0)


## AC-1b: 连击 = 0 不记录
func test_combo_zero_no_record() -> void:
	_progression.on_combo_broken(0)
	var metrics := _progression.get_current_metrics()
	assert_int(metrics.combo_break_count).is_equal(0)


## AC-2: 追踪闪避成功率
## Given: 10 次闪避，7 次成功
## When: 查询闪避成功率
## Then: 成功率 = 0.7
func test_dodge_success_rate() -> void:
	for i in 7:
		_progression.on_dodge_attempt(true)
	for i in 3:
		_progression.on_dodge_attempt(false)
	var metrics := _progression.get_current_metrics()
	assert_float(metrics.get_dodge_success_rate()).is_equal(0.7)


## AC-2b: 无闪避记录 → 成功率 = 0
func test_dodge_no_attempts() -> void:
	var metrics := _progression.get_current_metrics()
	assert_float(metrics.get_dodge_success_rate()).is_equal(0.0)


## AC-3: 追踪万剑归宗频率
## Given: 游戏时长 120 秒，触发 3 次
## When: 查询频率
## Then: 频率 = 3 / 2min = 1.5 次/分钟
func test_myriad_frequency() -> void:
	# 模拟游戏时长 > 60 秒
	_progression._current_session.game_duration_sec = 120.0
	_progression.on_myriad_triggered()
	_progression.on_myriad_triggered()
	_progression.on_myriad_triggered()
	var metrics := _progression.get_current_metrics()
	# 手动设置时长以绕过 _ready 时间戳
	metrics.game_duration_sec = 120.0
	assert_float(metrics.get_myriad_frequency()).is_equal(1.5)


## AC-3b: 游戏时长 < 1 分钟 → 频率 = 0
func test_myriad_frequency_short_game() -> void:
	_progression.on_myriad_triggered()
	var metrics := _progression.get_current_metrics()
	metrics.game_duration_sec = 30.0
	assert_float(metrics.get_myriad_frequency()).is_equal(0.0)


## AC-4: 局间趋势 — 首局（无历史）→ null
func test_first_game_no_trend() -> void:
	assert_object(_progression.get_progression_trend()).is_null()


## AC-4b: 有历史时趋势计算正确
## Given: 历史平均 combo=5.0
## And: 本局 combo=10.0
## When: get_progression_trend()
## Then: combo_trend = 5.0 (进步)
func test_trend_calculation() -> void:
	# 添加历史记录: avg_combo=5.0, dodge_rate=0.5, myriad_freq=1.0
	_progression._test_add_history(5.0, 0.5, 1.0)

	# 本局: avg_combo=10.0
	_progression.on_combo_broken(10)
	_progression.on_combo_broken(10)

	var trend := _progression.get_progression_trend()
	assert_object(trend).is_not_null()
	assert_float(trend.combo_trend).is_greater(0.0)


## AC-5: 历史数据存储 — 最近 10 局
func test_history_max_10() -> void:
	for i in 15:
		_progression._test_add_history(5.0, 0.5, 1.0)
	assert_int(_progression.get_history_count()).is_equal(10)


## AC-6: get_progression_trend() 返回趋势可视化数据
func test_trend_has_all_fields() -> void:
	_progression._test_add_history(5.0, 0.5, 1.0)
	var trend := _progression.get_progression_trend()
	assert_object(trend).is_not_null()
	# combo_trend, dodge_trend, myriad_trend 存在
	assert_bool(trend is SkillProgression.ProgressionTrend).is_true()


## end_session 正确保存并重置
func test_end_session_saves_and_resets() -> void:
	_progression.on_combo_broken(10)
	_progression.end_session()
	assert_int(_progression.get_history_count()).is_equal(1)
	assert_int(_progression.get_current_metrics().combo_break_count).is_equal(0)


## 历史快照返回正确数据
func test_history_snapshots() -> void:
	_progression._test_add_history(5.0, 0.5, 1.0)
	_progression._test_add_history(8.0, 0.7, 2.0)
	var snapshots := _progression.get_history_snapshots(1)
	assert_int(snapshots.size()).is_equal(1)


## AC-Edge: 连击中断次数 = 0 → 平均连击长度 = 0（避免除零）
func test_no_combo_breaks_avg_zero() -> void:
	var metrics := _progression.get_current_metrics()
	assert_float(metrics.get_avg_combo_length()).is_equal(0.0)


## AC-Edge: 总闪避次数 = 0 → 闪避成功率 = 0
func test_no_dodges_rate_zero() -> void:
	var metrics := _progression.get_current_metrics()
	assert_float(metrics.get_dodge_success_rate()).is_equal(0.0)
