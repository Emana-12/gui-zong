@warning_ignore_start("inferred_declaration")
## PerformanceBaseline — 基线性能测试
##
## 测量 3/5/10 敌人数量下的帧时间、绘制调用、内存使用。
## 输出基线报告到控制台和 UI Label。
##
## 使用: 打开 baseline_test.tscn → 运行场景 (F6)
## 需要 EnemySystem 节点在场景树中。

extends Node3D

## 每个敌人数量级别观察时间（秒）
const OBSERVE_DURATION := 5.0
## 测试目标帧率
const TARGET_FPS := 60.0
## 帧时间预算（毫秒）
const FRAME_BUDGET_MS := 16.6
## 绘制调用预算
const DRAW_CALL_BUDGET := 50.0
## 场景三角形预算
const TRIANGLE_BUDGET := 10000.0

## 敌人数量测试级别
const ENEMY_COUNTS: Array[int] = [3, 5, 10]
## 敌人生成间距
const SPAWN_SPACING := 3.0

@onready var _enemy_system: EnemySystem = $EnemySystem
@onready var _info_label: Label = $UI/InfoLabel

var _elapsed := 0.0
var _current_level := 0
var _frame_times: Array[float] = []
var _draw_calls: Array[float] = []
var _memory_usage: Array[float] = []
var _triangle_count: Array[float] = []
var _results: Dictionary = {}
var _collecting := false
var _test_done := false


func _ready() -> void:
	print("=== Performance Baseline Test (S02-03) ===")
	print("Target: ", TARGET_FPS, "fps / ", FRAME_BUDGET_MS, "ms frame budget")
	_update_label("Initializing performance baseline test...")
	# 延迟一帧等待场景树稳定
	await get_tree().process_frame
	_start_level()


func _process(delta: float) -> void:
	if _test_done:
		return

	if not _collecting:
		return

	_elapsed += delta

	# 收集数据
	_frame_times.append(delta * 1000.0)
	_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_memory_usage.append(Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0))
	_triangle_count.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))

	if _elapsed >= OBSERVE_DURATION:
		_finish_level()


func _start_level() -> void:
	var count: int = ENEMY_COUNTS[_current_level]
	print("\n--- Level: ", count, " enemies ---")

	# 清除旧敌人
	if _enemy_system:
		_enemy_system.kill_all()

	# 生成敌人
	_spawn_enemies(count)

	# 重置收集器
	_elapsed = 0.0
	_frame_times.clear()
	_draw_calls.clear()
	_memory_usage.clear()
	_triangle_count.clear()
	_collecting = true

	_update_label("Measuring: %d enemies (%.0fs)..." % [count, OBSERVE_DURATION])


func _spawn_enemies(count: int) -> void:
	if not _enemy_system:
		push_warning("PerformanceBaseline: EnemySystem not found")
		return

	var types: Array = ["pine", "stone", "water", "ranged", "agile"]
	for i in range(count):
		var enemy_type: String = types[i % types.size()]
		var angle: float = i * TAU / count
		var pos := Vector3(cos(angle) * SPAWN_SPACING, 0.0, sin(angle) * SPAWN_SPACING)
		_enemy_system.spawn_enemy(enemy_type, pos)


func _finish_level() -> void:
	_collecting = false
	var count: int = ENEMY_COUNTS[_current_level]
	var stats := _calculate_stats(count)
	_results[count] = stats

	_print_stats(stats)
	_advance_or_finish()


func _calculate_stats(count: int) -> Dictionary:
	return {
		"enemy_count": count,
		"frame_time": {
			"avg": _average(_frame_times),
			"min": _min_val(_frame_times),
			"max": _max_val(_frame_times),
			"p95": _percentile(_frame_times, 95.0),
			"budget_pass": _max_val(_frame_times) <= FRAME_BUDGET_MS,
		},
		"draw_calls": {
			"avg": _average(_draw_calls),
			"max": _max_val(_draw_calls),
			"budget_pass": _max_val(_draw_calls) <= DRAW_CALL_BUDGET,
		},
		"memory_mb": {
			"avg": _average(_memory_usage),
			"max": _max_val(_memory_usage),
		},
		"triangles": {
			"avg": _average(_triangle_count),
			"max": _max_val(_triangle_count),
			"budget_pass": _max_val(_triangle_count) <= TRIANGLE_BUDGET,
		},
	}


func _advance_or_finish() -> void:
	_current_level += 1
	if _current_level >= ENEMY_COUNTS.size():
		_test_done = true
		_print_summary()
	else:
		_start_level()


func _print_stats(stats: Dictionary) -> void:
	var msg := ""
	msg += "Enemies: %d\n" % stats["enemy_count"]
	msg += "Frame time: avg=%.2fms, min=%.2fms, max=%.2fms, p95=%.2fms [%s]\n" % [
		stats["frame_time"]["avg"], stats["frame_time"]["min"],
		stats["frame_time"]["max"], stats["frame_time"]["p95"],
		"PASS" if stats["frame_time"]["budget_pass"] else "FAIL"
	]
	msg += "Draw calls: avg=%.1f, max=%.1f [%s]\n" % [
		stats["draw_calls"]["avg"], stats["draw_calls"]["max"],
		"PASS" if stats["draw_calls"]["budget_pass"] else "FAIL"
	]
	msg += "Memory: avg=%.2fMB, max=%.2fMB\n" % [
		stats["memory_mb"]["avg"], stats["memory_mb"]["max"]
	]
	msg += "Triangles: avg=%.0f, max=%.0f [%s]" % [
		stats["triangles"]["avg"], stats["triangles"]["max"],
		"PASS" if stats["triangles"]["budget_pass"] else "FAIL"
	]
	print(msg)


func _print_summary() -> void:
	print("\n=== BASELINE SUMMARY ===")
	var all_pass := true
	for count in ENEMY_COUNTS:
		if not _results.has(count):
			continue
		var stats: Dictionary = _results[count]
		var ft_pass: bool = stats["frame_time"]["budget_pass"]
		var dc_pass: bool = stats["draw_calls"]["budget_pass"]
		var tr_pass: bool = stats["triangles"]["budget_pass"]
		if not (ft_pass and dc_pass and tr_pass):
			all_pass = false

		print("%d enemies: FT=%.2fms(max) DC=%.0f(max) MEM=%.2fMB(max) TRIS=%.0f(max) [%s]" % [
			count,
			stats["frame_time"]["max"],
			stats["draw_calls"]["max"],
			stats["memory_mb"]["max"],
			stats["triangles"]["max"],
			"ALL PASS" if (ft_pass and dc_pass and tr_pass) else "SOME FAIL"
		])

	print("Overall: %s" % ("ALL LEVELS PASS" if all_pass else "SOME LEVELS FAIL"))
	print("Budget: FT<%.1fms, DC<%.0f, TRIS<%.0f" % [FRAME_BUDGET_MS, DRAW_CALL_BUDGET, TRIANGLE_BUDGET])
	_update_label("Baseline complete — see console for details")


func _update_label(text: String) -> void:
	if _info_label:
		_info_label.text = text


# --- 统计工具函数 ---

func _average(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var sum := 0.0
	for v in arr:
		sum += v
	return sum / arr.size()


func _min_val(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var result: float = arr[0]
	for v in arr:
		if v < result:
			result = v
	return result


func _max_val(arr: Array) -> float:
	if arr.is_empty():
		return 0.0
	var result: float = arr[0]
	for v in arr:
		if v > result:
			result = v
	return result


func _percentile(arr: Array, pct: float) -> float:
	if arr.is_empty():
		return 0.0
	var sorted := arr.duplicate()
	sorted.sort()
	var idx := int(ceil(pct / 100.0 * sorted.size())) - 1
	idx = clampi(idx, 0, sorted.size() - 1)
	return sorted[idx]
