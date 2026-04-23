# SPDX-License-Identifier: MIT
## ScoringSystem — 计分系统
##
## 追踪玩家每局表现数据：最高波次、最长连击、万剑归宗触发次数。
## 维护最佳记录，持久化到本地文件。
##
## 职责边界:
## - 做: 计分数据追踪、最佳记录比较、持久化
## - 不做: UI 显示 (HUD)、连击计数 (ComboSystem)、波次管理 (ArenaWaveSystem)
##
## 设计参考:
## - design/gdd/scoring-system.md
## - docs/architecture/adr-0017-scoring-system-architecture.md
##
## 上游依赖:
## - ArenaWaveSystem (wave_completed 信号)
## - ComboSystem (combo_broken 信号 / myriad_triggered 信号)
## - GameStateManager (state_changed → save_score on DEATH)
##
## @see ADR-0017
## @see design/gdd/scoring-system.md
class_name ScoringSystem
extends Node

## 持久化文件路径
const SAVE_PATH := "user://best_score.json"

## 计分数据结构
class ScoreData:
	extends RefCounted

	var highest_wave: int = 0
	var longest_combo: int = 0
	var myriad_count: int = 0

	func _init(p_wave: int = 0, p_combo: int = 0, p_myriad: int = 0) -> void:
		highest_wave = p_wave
		longest_combo = p_combo
		myriad_count = p_myriad

	func to_dict() -> Dictionary:
		return {
			"highest_wave": highest_wave,
			"longest_combo": longest_combo,
			"myriad_count": myriad_count,
		}

	static func from_dict(data: Dictionary) -> ScoreData:
		return ScoreData.new(
			data.get("highest_wave", 0),
			data.get("longest_combo", 0),
			data.get("myriad_count", 0),
		)

	func is_better_than(other: ScoreData) -> bool:
		if highest_wave > other.highest_wave:
			return true
		if highest_wave == other.highest_wave and longest_combo > other.longest_combo:
			return true
		if highest_wave == other.highest_wave and longest_combo == other.longest_combo:
			return myriad_count > other.myriad_count
		return false


## 最佳记录更新信号
signal best_score_updated(new_best: ScoreData)

## 是否启用持久化（测试可关闭）
@export var score_save_enabled: bool = true

## 本局数据
var _current: ScoreData = ScoreData.new()

## 最佳记录
var _best: ScoreData = ScoreData.new()

## 最佳记录是否已加载
var _best_loaded: bool = false


func _ready() -> void:
	_load_best_score()


## ── 公开 API ──────────────────────────────────────────────────────────────

## 获取本局计分数据。
## @return ScoreData - 本局数据快照
func get_current_score() -> ScoreData:
	return _current


## 获取历史最佳记录。
## @return ScoreData - 最佳记录快照
func get_best_score() -> ScoreData:
	return _best


## 保存本局数据为最佳记录（如果本局更好）。
## 与历史最佳比较，打破记录则更新并持久化。
func save_score() -> void:
	if _current.is_better_than(_best):
		_best = ScoreData.new(_current.highest_wave, _current.longest_combo, _current.myriad_count)
		best_score_updated.emit(_best)
		if score_save_enabled:
			_persist_best_score()


## 重置本局数据为零。
func reset_current() -> void:
	_current = ScoreData.new()


## ── 数据更新方法（由外部系统信号回调调用）─────────────────────────────────

## 更新最高波次。
## @param wave_number: int - 当前完成的波次号
func on_wave_completed(wave_number: int) -> void:
	if wave_number <= 0:
		return
	if wave_number > _current.highest_wave:
		_current.highest_wave = wave_number


## 更新最长连击。
## @param combo_count: int - 连击中断时的连击数
func on_combo_broken(combo_count: int) -> void:
	if combo_count <= 0:
		return
	if combo_count > _current.longest_combo:
		_current.longest_combo = combo_count


## 万剑归宗触发时计数 +1。
## @param _trail_count: int - 轨迹数（未使用，信号接口需要）
## @param _damage: float - 伤害（未使用）
## @param _radius: float - 范围（未使用）
func on_myriad_triggered(_trail_count: int = 0, _damage: float = 0.0, _radius: float = 0.0) -> void:
	_current.myriad_count += 1


## ── 持久化 ────────────────────────────────────────────────────────────────

## 从本地文件加载最佳记录。
func _load_best_score() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_best_loaded = true
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("ScoringSystem: Failed to open save file")
		_best_loaded = true
		return

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_warning("ScoringSystem: Failed to parse save data")
		_best_loaded = true
		return

	var data: Dictionary = json.data
	if data is Dictionary:
		_best = ScoreData.from_dict(data)

	_best_loaded = true


## 持久化最佳记录到本地文件。
func _persist_best_score() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("ScoringSystem: Failed to save score")
		return

	var json_string := JSON.stringify(_best.to_dict())
	file.store_string(json_string)
	file.close()


## ── 测试辅助 ──────────────────────────────────────────────────────────────

## 测试辅助：检查最佳记录是否已加载
func _test_is_best_loaded() -> bool:
	return _best_loaded

## 测试辅助：强制设置最佳记录
func _test_set_best(wave: int, combo: int, myriad: int) -> void:
	_best = ScoreData.new(wave, combo, myriad)

## 测试辅助：禁止持久化（测试隔离）
func _test_disable_save() -> void:
	score_save_enabled = false
