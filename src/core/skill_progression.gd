# SPDX-License-Identifier: MIT
## SkillProgression — 纯技巧进度系统
##
## 追踪玩家技巧指标: 平均连击长度、闪避成功率、万剑归宗频率。
## 维护最近 10 局历史记录，提供局间趋势数据。
##
## 职责边界:
## - 做: 技巧指标计算、历史存储、趋势分析
## - 不做: UI 显示 (HUD)、连击计数 (ComboSystem)
##
## 设计参考:
## - design/gdd/skill-progression.md
## - docs/architecture/adr-0018-skill-progression-architecture.md
##
## 上游依赖:
## - ComboSystem (连击数据)
## - PlayerController (闪避数据)
## - GameStateManager (游戏时长)
##
## @see ADR-0018
## @see design/gdd/skill-progression.md
class_name SkillProgression
extends Node

## 最大历史记录数
const MAX_HISTORY: int = 10

## 本局技巧数据
class SessionMetrics:
	extends RefCounted

	var total_combo_length: int = 0    ## 总连击长度（所有连击之和）
	var combo_break_count: int = 0     ## 连击中断次数
	var dodge_success_count: int = 0   ## 成功闪避次数
	var dodge_total_count: int = 0     ## 总闪避次数
	var myriad_count: int = 0          ## 万剑归宗触发次数
	var game_duration_sec: float = 0.0 ## 游戏时长（秒）

	## 平均连击长度
	func get_avg_combo_length() -> float:
		if combo_break_count <= 0:
			return 0.0
		return float(total_combo_length) / float(combo_break_count)

	## 闪避成功率
	func get_dodge_success_rate() -> float:
		if dodge_total_count <= 0:
			return 0.0
		return float(dodge_success_count) / float(dodge_total_count)

	## 万剑归宗频率（次/分钟）
	func get_myriad_frequency() -> float:
		if game_duration_sec < 60.0:
			return 0.0
		return float(myriad_count) / (game_duration_sec / 60.0)

	func to_dict() -> Dictionary:
		return {
			"avg_combo": get_avg_combo_length(),
			"dodge_rate": get_dodge_success_rate(),
			"myriad_freq": get_myriad_frequency(),
			"duration": game_duration_sec,
		}


## 趋势数据
class ProgressionTrend:
	extends RefCounted

	var combo_trend: float = 0.0     ## 正 = 进步, 负 = 退步
	var dodge_trend: float = 0.0
	var myriad_trend: float = 0.0
	var is_improving: bool = false   ## 至少 2 项进步

	func _init(p_combo: float = 0.0, p_dodge: float = 0.0, p_myriad: float = 0.0) -> void:
		combo_trend = p_combo
		dodge_trend = p_dodge
		myriad_trend = p_myriad
		var improving_count := 0
		if combo_trend > 0: improving_count += 1
		if dodge_trend > 0: improving_count += 1
		if myriad_trend > 0: improving_count += 1
		is_improving = improving_count >= 2


## 历史记录
var _history: Array[SessionMetrics] = []

## 本局数据
var _current_session: SessionMetrics = SessionMetrics.new()

## 游戏开始时间戳
var _game_start_time: float = 0.0


func _ready() -> void:
	_game_start_time = Time.get_ticks_msec() / 1000.0


## ── 公开 API ──────────────────────────────────────────────────────────────

## 记录连击中断。
## @param combo_length: int - 中断时的连击长度
func on_combo_broken(combo_length: int) -> void:
	if combo_length <= 0:
		return
	_current_session.total_combo_length += combo_length
	_current_session.combo_break_count += 1


## 记录闪避尝试。
## @param success: bool - 是否成功闪避
func on_dodge_attempt(success: bool) -> void:
	_current_session.dodge_total_count += 1
	if success:
		_current_session.dodge_success_count += 1


## 记录万剑归宗触发。
func on_myriad_triggered(_trail_count: int = 0, _damage: float = 0.0, _radius: float = 0.0) -> void:
	_current_session.myriad_count += 1


## 结束本局并保存记录。
## 计算游戏时长，存入历史，超出 MAX_HISTORY 时移除最旧。
func end_session() -> void:
	_current_session.game_duration_sec = Time.get_ticks_msec() / 1000.0 - _game_start_time
	_history.append(_current_session)
	if _history.size() > MAX_HISTORY:
		_history.remove_at(0)
	# 创建新 session
	_current_session = SessionMetrics.new()
	_game_start_time = Time.get_ticks_msec() / 1000.0


## 获取本局指标。
## @return SessionMetrics - 本局数据
func get_current_metrics() -> SessionMetrics:
	return _current_session


## 获取历史记录数。
## @return int
func get_history_count() -> int:
	return _history.size()


## 获取趋势数据（本局 vs 历史平均值）。
## 至少 1 局历史才可计算趋势。
## @return ProgressionTrend - 无历史时返回 null
func get_progression_trend() -> ProgressionTrend:
	if _history.is_empty():
		return null

	# 计算历史平均值
	var hist_combo_sum := 0.0
	var hist_dodge_sum := 0.0
	var hist_myriad_sum := 0.0
	for session in _history:
		hist_combo_sum += session.get_avg_combo_length()
		hist_dodge_sum += session.get_dodge_success_rate()
		hist_myriad_sum += session.get_myriad_frequency()

	var count := float(_history.size())
	var avg_combo := hist_combo_sum / count
	var avg_dodge := hist_dodge_sum / count
	var avg_myriad := hist_myriad_sum / count

	# 趋势 = 本局 - 历史平均
	var combo_trend := _current_session.get_avg_combo_length() - avg_combo
	var dodge_trend := _current_session.get_dodge_success_rate() - avg_dodge
	var myriad_trend := _current_session.get_myriad_frequency() - avg_myriad

	return ProgressionTrend.new(combo_trend, dodge_trend, myriad_trend)


## 获取最近 N 局的指标快照。
## @param count: int - 获取的局数（0 = 全部）
## @return Array[Dictionary] - 指标字典数组
func get_history_snapshots(count: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start := 0
	if count > 0 and count < _history.size():
		start = _history.size() - count
	for i in range(start, _history.size()):
		result.append(_history[i].to_dict())
	return result


## ── 测试辅助 ──────────────────────────────────────────────────────────────

## 测试辅助：清空历史
func _test_clear_history() -> void:
	_history.clear()

## 测试辅助：添加历史记录
func _test_add_history(avg_combo: float, dodge_rate: float, myriad_freq: float) -> void:
	var m := SessionMetrics.new()
	m.total_combo_length = int(avg_combo * 3)
	m.combo_break_count = 3
	m.dodge_success_count = int(dodge_rate * 10)
	m.dodge_total_count = 10
	m.myriad_count = int(myriad_freq)
	m.game_duration_sec = 120.0
	_history.append(m)
