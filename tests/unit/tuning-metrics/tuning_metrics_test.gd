@warning_ignore_start("inferred_declaration")
## TuningMetrics 单元测试
##
## 测试组合连击长度追踪、剑式触发率统计、空档频率检测。
## 遵循 test_[system]_[scenario]_[expected_result] 命名规范。
@tool
extends GdUnitTestSuite

var _metrics: TuningMetrics


func before_test() -> void:
	_metrics = TuningMetrics.new()
	add_child(_metrics)


func after_test() -> void:
	if _metrics:
		_metrics.free()


## 组合连击: 连续命中在窗口内应增加连击计数
func test_tuning_metrics_combo_single_hit_records_combo_one() -> void:
	# Arrange
	var attacker := auto_free(Node3D.new())
	var target := auto_free(Node3D.new())
	var result := HitJudgment.HitResult.new(
		attacker, target,
		HitJudgment.SwordForm.YOU, 1,
		Vector3.ZERO, Vector3.UP, &"body"
	)

	# Act
	_metrics._on_hit_landed(result)

	# Assert
	assert_int(_metrics._combo_count).is_equal(1)


## 组合连击: 连续两次命中在同一窗口内应增加连击到 2
func test_tuning_metrics_combo_two_hits_in_window_increments() -> void:
	# Arrange
	var attacker := auto_free(Node3D.new())
	var target := auto_free(Node3D.new())
	var result := HitJudgment.HitResult.new(
		attacker, target,
		HitJudgment.SwordForm.YOU, 1,
		Vector3.ZERO, Vector3.UP, &"body"
	)

	# Act — 两次命中间隔 100ms（在 1.5s 窗口内）
	_metrics._on_hit_landed(result)
	_metrics._last_hit_time = Time.get_ticks_msec() - 100
	_metrics._on_hit_landed(result)

	# Assert
	assert_int(_metrics._combo_count).is_equal(2)


## 组合连击: 超过窗口时间的命中应结束前一个组合
func test_tuning_metrics_combo_hit_after_window_starts_new_combo() -> void:
	# Arrange
	var attacker := auto_free(Node3D.new())
	var target := auto_free(Node3D.new())
	var result := HitJudgment.HitResult.new(
		attacker, target,
		HitJudgment.SwordForm.YOU, 1,
		Vector3.ZERO, Vector3.UP, &"body"
	)

	# Act — 第一次命中
	_metrics._on_hit_landed(result)
	# 模拟超过 COMBO_WINDOW (1.5s) 的间隔
	_metrics._last_hit_time = Time.get_ticks_msec() - 2000
	_metrics._on_hit_landed(result)

	# Assert — 旧组合应被记录（2 hit），新组合计数为 1
	assert_int(_metrics._combo_count).is_equal(1)
	assert_int(_metrics._recent_combo_count).is_equal(1)
	assert_int(_metrics._recent_combos[0]).is_equal(2)


## 组合连击: 被格挡的命中不应计入连击
func test_tuning_metrics_combo_blocked_hit_does_not_increment() -> void:
	# Arrange
	var attacker := auto_free(Node3D.new())
	var target := auto_free(Node3D.new())
	var hit_result := HitJudgment.HitResult.new(
		attacker, target,
		HitJudgment.SwordForm.YOU, 1,
		Vector3.ZERO, Vector3.UP, &"body"
	)
	var blocked_result := HitJudgment.HitResult.new(
		attacker, target,
		HitJudgment.SwordForm.YOU, 0,
		Vector3.ZERO, Vector3.UP, &"body"
	)

	# Act
	_metrics._on_hit_landed(hit_result)
	_metrics._on_hit_blocked(blocked_result)

	# Assert — 只有有效命中增加计数
	assert_int(_metrics._combo_count).is_equal(1)


## 触发率: 剑式激活应增加对应计数
func test_tuning_metrics_trigger_form_activation_increments_count() -> void:
	# Act
	_metrics._on_form_activated(ThreeFormsCombat.Form.YOU)
	_metrics._on_form_activated(ThreeFormsCombat.Form.YOU)
	_metrics._on_form_activated(ThreeFormsCombat.Form.RAO)

	# Assert
	assert_int(_metrics._form_trigger_counts[ThreeFormsCombat.Form.YOU]).is_equal(2)
	assert_int(_metrics._form_trigger_counts[ThreeFormsCombat.Form.RAO]).is_equal(1)
	assert_int(_metrics._total_form_triggers).is_equal(3)


## 空档检测: 敌人回到 IDLE 状态应记录空档
func test_tuning_metrics_dead_zone_enemy_idle_records_dead_zone() -> void:
	# Arrange
	_metrics._in_combat = true

	# Act
	_metrics._on_enemy_state_changed(
		0,
		EnemySystem.EnemyState.ATTACK,
		EnemySystem.EnemyState.IDLE
	)

	# Assert
	assert_int(_metrics._dead_zone_count).is_equal(1)
	assert_bool(_metrics._in_combat).is_false()


## 空档检测: 非 IDLE 状态转换不应记录空档
func test_tuning_metrics_dead_zone_non_idle_transition_no_record() -> void:
	# Arrange
	_metrics._in_combat = true

	# Act
	_metrics._on_enemy_state_changed(
		0,
		EnemySystem.EnemyState.APPROACH,
		EnemySystem.EnemyState.ATTACK
	)

	# Assert
	assert_int(_metrics._dead_zone_count).is_equal(0)
	assert_bool(_metrics._in_combat).is_true()


## 击杀计数: 敌人死亡应增加计数
func test_tuning_metrics_kill_enemy_died_increments_count() -> void:
	# Act
	_metrics._on_enemy_died(0)
	_metrics._on_enemy_died(1)
	_metrics._on_enemy_died(2)

	# Assert
	assert_int(_metrics._kill_count).is_equal(3)


## 快照生成: get_snapshot 应返回非空字典
func test_tuning_metrics_snapshot_returns_valid_dictionary() -> void:
	# Act
	var snapshot := _metrics.get_snapshot()

	# Assert
	assert_bool(snapshot.has("session_seconds")).is_true()
	assert_bool(snapshot.has("combo_max")).is_true()
	assert_bool(snapshot.has("trigger_rate_per_min")).is_true()
	assert_bool(snapshot.has("dead_zone_count")).is_true()
	assert_bool(snapshot.has("kill_count")).is_true()


## 会话重置: reset_session 应清零所有统计
func test_tuning_metrics_reset_clears_all_stats() -> void:
	# Arrange — 生成一些数据
	_metrics._combo_count = 5
	_metrics._dead_zone_count = 3
	_metrics._kill_count = 10
	_metrics._total_form_triggers = 20

	# Act
	_metrics.reset_session()

	# Assert
	assert_int(_metrics._combo_count).is_equal(0)
	assert_int(_metrics._dead_zone_count).is_equal(0)
	assert_int(_metrics._kill_count).is_equal(0)
	assert_int(_metrics._total_form_triggers).is_equal(0)
	assert_int(_metrics._recent_combo_count).is_equal(0)


## JSON 导出: export_json 应返回有效 JSON 字符串
func test_tuning_metrics_export_json_returns_valid_json() -> void:
	# Act
	var json_str := _metrics.export_json()

	# Assert
	assert_bool(json_str.length() > 0).is_true()
	var parsed = JSON.parse_string(json_str)
	assert_bool(parsed != null).is_true()
	assert_bool(parsed is Dictionary).is_true()
