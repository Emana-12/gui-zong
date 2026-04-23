## TuningMetrics — 调参指标收集系统
##
## 监听战斗信号，收集组合连击长度、剑式触发频率、战斗空档频率。
## 所有数据在帧热路径中零分配（预分配 + 复用）。
##
## 设计参考:
## - design/gdd/tuning-metrics.md
## - docs/architecture/adr-0017-scoring-system-architecture.md
##
## 性能约束: < 0.5ms/帧开销
## @see S02-07
class_name TuningMetrics
extends Node

## 组合连击时间窗口（秒）—— 连续命中在此窗口内视为同一连击
const COMBO_WINDOW: float = 1.5

## 每次指标导出的时间间隔（秒）
const RECORD_INTERVAL: float = 5.0

## 预分配数组容量（避免运行时扩容）
const MAX_RECENT_HITS: int = 32
const MAX_RECENT_COMBOS: int = 16

## 当前组合连击计数
var _combo_count: int = 0

## 上一次命中时间戳（毫秒）
var _last_hit_time: int = 0

## 组合连击长度记录（预分配，实际使用 _recent_combo_count 个元素）
var _recent_combos: Array[int] = []
var _recent_combo_count: int = 0

## 剑式触发计数（按 Form 枚举索引）
var _form_trigger_counts: Array[int] = [0, 0, 0, 0]

## 总剑式触发次数
var _total_form_triggers: int = 0

## 战斗空档计数
var _dead_zone_count: int = 0

## 击杀计数
var _kill_count: int = 0

## 会话开始时间戳（毫秒）
var _session_start_time: int = 0

## 上次指标记录时间（毫秒）
var _last_record_time: int = 0

## 指标快照（预分配复用）
var _snapshot: Dictionary = {}

## 敌人是否处于战斗状态标记
var _in_combat: bool = false


func _ready() -> void:
	_session_start_time = Time.get_ticks_msec()
	_last_record_time = _session_start_time
	# 预分配数组
	_recent_combos.resize(MAX_RECENT_COMBOS)
	_connect_signals()


## 连接到源系统信号
func _connect_signals() -> void:
	# HitJudgment — 命中判定系统
	var hit_judgment: Node = HitJudgment
	if hit_judgment:
		hit_judgment.hit_landed.connect(_on_hit_landed)
		hit_judgment.hit_blocked.connect(_on_hit_blocked)

	# ThreeFormsCombat — 三式剑招系统
	# 通过父节点或组查找（非 autoload，需动态连接）
	_connect_three_forms()

	# EnemySystem — 敌人系统
	var enemy_system: EnemySystem = get_node_or_null("/root/EnemySystem")
	if enemy_system:
		enemy_system.enemy_died.connect(_on_enemy_died)
		enemy_system.enemy_state_changed.connect(_on_enemy_state_changed)


## 动态查找并连接 ThreeFormsCombat
func _connect_three_forms() -> void:
	# ThreeFormsCombat 在场景树中（非 autoload），需要延迟连接
	call_deferred("_deferred_connect_three_forms")


func _deferred_connect_three_forms() -> void:
	var combat_nodes := get_tree().get_nodes_in_group("combat_system")
	for node in combat_nodes:
		if node is ThreeFormsCombat:
			if not node.form_activated.is_connected(_on_form_activated):
				node.form_activated.connect(_on_form_activated)
			if not node.form_finished.is_connected(_on_form_finished):
				node.form_finished.connect(_on_form_finished)


## 命中信号回调
func _on_hit_landed(_result: Object) -> void:
	var now := Time.get_ticks_msec()
	var elapsed_ms := now - _last_hit_time

	if _last_hit_time > 0 and elapsed_ms < int(COMBO_WINDOW * 1000.0):
		_combo_count += 1
	else:
		# 前一组合结束，记录长度
		if _combo_count > 1:
			_push_combo(_combo_count)
		_combo_count = 1

	_last_hit_time = now


## 被格挡信号回调 — 不计入连击
func _on_hit_blocked(_result: Object) -> void:
	pass


## 剑式激活回调
func _on_form_activated(form: ThreeFormsCombat.Form) -> void:
	if form >= 0 and form < _form_trigger_counts.size():
		_form_trigger_counts[form] += 1
	_total_form_triggers += 1
	_in_combat = true


## 剑式完成回调
func _on_form_finished(_form: ThreeFormsCombat.Form) -> void:
	pass


## 敌人死亡回调
func _on_enemy_died(_enemy_id: int) -> void:
	_kill_count += 1


## 敌人状态变更回调 — 检测空档
func _on_enemy_state_changed(_enemy_id: int, _old_state: EnemySystem.EnemyState, new_state: EnemySystem.EnemyState) -> void:
	if new_state == EnemySystem.EnemyState.IDLE and _in_combat:
		_dead_zone_count += 1
		_in_combat = false


## 每帧更新（在 _process 中调用，零分配）
func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_record_time < int(RECORD_INTERVAL * 1000.0):
		return
	_last_record_time = now
	_export_snapshot()


## 推入连击记录（预分配数组复用）
func _push_combo(length: int) -> void:
	if _recent_combo_count < MAX_RECENT_COMBOS:
		_recent_combos[_recent_combo_count] = length
		_recent_combo_count += 1


## 生成指标快照并记录到控制台
func _export_snapshot() -> void:
	var session_secs := float(Time.get_ticks_msec() - _session_start_time) / 1000.0

	# 连击长度统计
	var max_combo := 0
	var total_combo := 0
	for i in _recent_combo_count:
		var v := _recent_combos[i]
		total_combo += v
		if v > max_combo:
			max_combo = v
	var avg_combo := total_combo / max(_recent_combo_count, 1) as float

	# 剑式触发率（次/分钟）
	var trigger_rate := 0.0
	if session_secs > 0.0:
		trigger_rate = _total_form_triggers as float / (session_secs / 60.0)

	# 空档频率（次/分钟）
	var dead_zone_rate := 0.0
	if session_secs > 0.0:
		dead_zone_rate = _dead_zone_count as float / (session_secs / 60.0)

	# 填充预分配快照字典（避免新字典分配）
	_snapshot.clear()
	_snapshot["session_seconds"] = session_secs
	_snapshot["combo_max"] = max_combo
	_snapshot["combo_avg"] = avg_combo
	_snapshot["combo_recent_count"] = _recent_combo_count
	_snapshot["trigger_rate_per_min"] = trigger_rate
	_snapshot["form_counts"] = _form_trigger_counts.duplicate()
	_snapshot["dead_zone_count"] = _dead_zone_count
	_snapshot["dead_zone_rate_per_min"] = dead_zone_rate
	_snapshot["kill_count"] = _kill_count
	_snapshot["total_form_triggers"] = _total_form_triggers

	print("[TuningMetrics] ", JSON.stringify(_snapshot))


## 获取当前指标快照（只读，供外部查询）
func get_snapshot() -> Dictionary:
	_export_snapshot()
	return _snapshot.duplicate()


## 重置会话统计
func reset_session() -> void:
	_combo_count = 0
	_last_hit_time = 0
	_recent_combo_count = 0
	_form_trigger_counts = [0, 0, 0, 0]
	_total_form_triggers = 0
	_dead_zone_count = 0
	_kill_count = 0
	_in_combat = false
	_session_start_time = Time.get_ticks_msec()
	_last_record_time = _session_start_time
	_snapshot.clear()


## 将指标导出为 JSON 字符串（供外部工具消费）
func export_json() -> String:
	get_snapshot()
	return JSON.stringify(_snapshot, "\t")
