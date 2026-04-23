## ComboSystem — 连击计数与万剑归宗触发
##
## 监听三式剑招系统的命中事件，追踪不同剑式连续命中次数。
## 同式连续命中不增加连击但不断连，受击归零，超时归零。
## 连击达到蓄力阈值后可手动触发万剑归宗，达到自动阈值时自动触发。
##
## 职责边界：
## - 做：连击计数、超时管理、连击重置、万剑归宗蓄力与触发
## - 不做：轨迹生成（流光轨迹系统）、伤害应用（命中判定层）
##
## 公式 (GDD: design/gdd/combo-myriad-swords.md):
##   轨迹数 = 20 + combo_count * 2 (上限 50)
##   伤害   = 5 + combo_count * 0.5
##   范围   = 8.0 (固定)
##
## 设计参考:
## - docs/architecture/adr-0009-combo-system-architecture.md
## - design/gdd/combo-myriad-swords.md
##
## 上游依赖:
## - HitJudgment (hit_landed 信号 → on_hit_landed)
## - ThreeFormsCombat (form_activated 信号用于确认当前剑式)
##
## 下游依赖:
## - HUD (combo_changed 信号 → 墨点计数器, charge_changed → 蓄力环)
## - 流光轨迹系统 (myriad_triggered 信号 → 批量创建轨迹)
## - 摄像机系统 (myriad_triggered 信号 → FOV 拉远)
## - 音频系统 (myriad_triggered 信号 → 高潮曲)
##
## @see ADR-0009
## @see production/epics/combo-myriad-swords/story-001-combo-counter.md
## @see production/epics/combo-myriad-swords/story-002-myriad-trigger.md
class_name ComboSystem
extends Node

## 连击超时时间（秒）。超过此时间无命中则连击归零。
@export var combo_timeout: float = 3.0

## 万剑归宗蓄力阈值 — 需要多少次不同剑式命中才蓄力完成
const CHARGE_THRESHOLD: int = 10

## 自动触发阈值 — 达到此连击数时自动触发万剑归宗
const AUTO_TRIGGER_THRESHOLD: int = 20

## 万剑归宗冷却时间（秒）— 冷却期间拒绝触发
const MYRIAD_COOLDOWN: float = 10.0

## 万剑归宗轨迹公式参数
const BASE_TRAILS: int = 20
const TRAILS_PER_COMBO: int = 2
const MAX_TRAILS: int = 50

## 万剑归宗基础伤害
const BASE_DAMAGE: float = 5.0
const DAMAGE_PER_COMBO: float = 0.5

## 万剑归宗范围（固定）
const MYRIAD_RADIUS: float = 8.0

## 连击数变化信号。每次连击数变化时发出，参数为当前连击数。
signal combo_changed(count: int)

## 蓄力进度变化信号 (0.0–1.0)
signal charge_changed(progress: float)

## 万剑归宗触发信号。参数：轨迹数、伤害、范围半径。
signal myriad_triggered(trail_count: int, damage: float, radius: float)

## 当前连击数
var _combo_count: int = 0

## 上一次命中的剑式类型（HitJudgment.SwordForm 枚举值）。
## 使用 -1 表示无上次命中（初始状态）。
var _last_sword_form: int = -1

## 超时计时器节点
var _timeout_timer: Timer = null

## 万剑归宗冷却计时器节点
var _cooldown_timer: Timer = null

## 万剑归宗是否已蓄力完成
var _myriad_ready: bool = false


func _ready() -> void:
	_timeout_timer = Timer.new()
	_timeout_timer.one_shot = true
	_timeout_timer.wait_time = combo_timeout
	_timeout_timer.timeout.connect(_on_timeout)
	add_child(_timeout_timer)

	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	_cooldown_timer.wait_time = MYRIAD_COOLDOWN
	add_child(_cooldown_timer)


## 接收命中判定层的命中事件。
## 不同剑式连续命中才 +1，同式连续命中不增加但不断连。
##
## @param sword_form: int - HitJudgment.SwordForm 枚举值
func on_hit_landed(sword_form: int) -> void:
	# 敌人攻击不计入玩家连击
	if sword_form == 0:  # HitJudgment.SwordForm.ENEMY
		return

	# 同式连续命中：不增加但不断连，刷新超时
	if sword_form == _last_sword_form:
		_restart_timeout_timer()
		return

	# 不同剑式命中：连击 +1
	_last_sword_form = sword_form
	_combo_count += 1
	_restart_timeout_timer()
	combo_changed.emit(_combo_count)
	charge_changed.emit(get_charge_progress())

	# 蓄力完成判定
	if _combo_count >= CHARGE_THRESHOLD:
		_myriad_ready = true

	# 自动触发：达到阈值时立即触发
	if _combo_count >= AUTO_TRIGGER_THRESHOLD:
		trigger_myriad()


## 接收受击事件。连击归零。
func on_player_hit() -> void:
	_reset_state()


## 获取当前连击数。
##
## @return int - 当前连击数
func get_combo_count() -> int:
	return _combo_count


## 获取万剑归宗蓄力进度 (0.0–1.0)。
## 连击数 >= CHARGE_THRESHOLD 时返回 1.0 (已 clamp)。
##
## @return float - 蓄力进度，0.0 = 未蓄力，1.0 = 蓄力完成
func get_charge_progress() -> float:
	if _combo_count >= CHARGE_THRESHOLD:
		return 1.0
	return float(_combo_count) / float(CHARGE_THRESHOLD)


## 万剑归宗是否就绪（蓄力完成且不在冷却中）。
##
## @return bool - true = 可以触发
func is_myriad_ready() -> bool:
	return _myriad_ready and _cooldown_timer.time_left <= 0.0


## 手动触发万剑归宗。
## 蓄力未完成或冷却中时返回 false。
##
## @return bool - true = 成功触发，false = 拒绝触发
func trigger_myriad() -> bool:
	# 冷却中 — 拒绝
	if _cooldown_timer.time_left > 0.0:
		return false

	# 蓄力未完成 — 拒绝
	if not _myriad_ready:
		return false

	# 计算万剑归宗效果参数
	var trail_count: int = _calculate_trail_count()
	var damage: float = _calculate_damage()
	var radius: float = _calculate_radius()

	# 发出信号
	myriad_triggered.emit(trail_count, damage, radius)

	# 进入冷却 + 重置连击
	_cooldown_timer.start()
	_reset_state()

	return true


## 重置连击计数。外部系统可调用此方法强制重置。
func reset_combo() -> void:
	_reset_state()


## 超时回调。连击归零。
func _on_timeout() -> void:
	_reset_state()


## 重启超时计时器。每次有效命中后调用。
func _restart_timeout_timer() -> void:
	_timeout_timer.wait_time = combo_timeout
	_timeout_timer.start()


## 重置内部状态。连击归零、清空上次剑式、停止计时器、重置蓄力。
func _reset_state() -> void:
	_combo_count = 0
	_last_sword_form = -1
	_myriad_ready = false
	_timeout_timer.stop()
	combo_changed.emit(_combo_count)
	charge_changed.emit(0.0)


# ──────────────────────────────────────────────
#  万剑归宗公式 (Story 002)
# ──────────────────────────────────────────────

## 轨迹数 = 20 + combo_count * 2，上限 50
func _calculate_trail_count() -> int:
	return mini(BASE_TRAILS + _combo_count * TRAILS_PER_COMBO, MAX_TRAILS)

## 伤害 = 5 + combo_count * 0.5
func _calculate_damage() -> float:
	return BASE_DAMAGE + _combo_count * DAMAGE_PER_COMBO

## 范围 = 8.0 (固定)
func _calculate_radius() -> float:
	return MYRIAD_RADIUS


# ──────────────────────────────────────────────
#  测试辅助方法 (仅用于单元测试，生产代码不应调用)
# ──────────────────────────────────────────────

## 直接设置连击计数 — 仅用于测试
func _test_set_combo_count(count: int) -> void:
	_combo_count = count
	_last_sword_form = 1 if count > 0 else -1
	_myriad_ready = count >= CHARGE_THRESHOLD

## 直接设置冷却状态 — 仅用于测试
func _test_set_cooldown(active: bool) -> void:
	if active:
		_cooldown_timer.start()
	else:
		_cooldown_timer.stop()

## 获取总分（用于游戏结束画面显示）
func get_total_score() -> int:
	return _combo_count * 10 + (_myriad_ready as int) * 100


## 获取当前冷却剩余时间 — 仅用于测试
func _test_get_cooldown_remaining() -> float:
	return _cooldown_timer.time_left
