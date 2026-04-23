## ThreeFormsCombat — 三式剑招系统核心
##
## 管理游剑式(YOU)、钻剑式(ZUAN)、绕剑式(RAO)的状态机执行。
## 每式有独立的 EXECUTING → RECOVERING → COOLDOWN 生命周期。
##
## 职责边界：
## - 做：剑招执行、状态管理、hitbox 生命周期、冷却计时
## - 不做：碰撞检测（物理碰撞层）、命中判定（命中判定层）、视觉效果
##
## @see docs/architecture/adr-0006
class_name ThreeFormsCombat
extends Node

## 三式枚举
enum Form { NONE, YOU, ZUAN, RAO }

## 剑招阶段
enum Phase { IDLE, EXECUTING, RECOVERING, COOLDOWN }

## 三式配置数据（按 GDD 重新设计，执行时间加长以展现差异化）
const FORM_DATA: Dictionary = {
	Form.YOU:  { "execute_time": 0.5, "recovery_time": 0.1, "cooldown_time": 0.2, "damage": 1, "hitbox_radius": 0.8, "range": 3.0, "fan_angle": 150.0 },
	Form.ZUAN: { "execute_time": 0.8, "recovery_time": 0.2, "cooldown_time": 0.5, "damage": 3, "hitbox_radius": 1.0, "range": 4.0, "fan_angle": 90.0 },
	Form.RAO:  { "execute_time": 0.6, "recovery_time": 0.15, "cooldown_time": 0.3, "damage": 2, "hitbox_radius": 1.2, "range": 2.5, "fan_angle": -1.0 },
}

## 输入动作名映射
const FORM_ACTIONS: Dictionary = {
	Form.YOU: &"attack_you",
	Form.ZUAN: &"attack_zuan",
	Form.RAO: &"attack_rao",
}

## 剑式激活信号 — 当剑招进入 EXECUTING 阶段时发出
signal form_activated(form: Form)

## 剑式完成信号 — 当剑招完成（进入 COOLDOWN）时发出
signal form_finished(form: Form)

## 最小执行时长（防止极端调参导致 0 时长）
@export var min_execute_time: float = 0.05

## 当前激活的剑式
var _current_form: Form = Form.NONE

## 当前阶段
var _current_phase: Phase = Phase.IDLE

## 当前阶段计时器
var _phase_timer: float = 0.0

## 各式冷却计时器
var _cooldown_timers: Array[float] = [0.0, 0.0, 0.0, 0.0]

## 当前活跃 hitbox ID
var _hitbox_id: int = -1

## 物理碰撞系统引用
var _physics_system: PhysicsCollisionSystem = null

## hitbox 扫动进度（0.0 → 1.0 在 EXECUTING 阶段）
var _sweep_progress: float = 0.0

## hitbox 起始偏移（左前方）
var _sweep_start_offset: Vector3 = Vector3.ZERO

## hitbox 结束偏移（右前方）
var _sweep_end_offset: Vector3 = Vector3.ZERO

## 每帧记录 hitbox 位置（用于轨迹弧线渲染）
var _trail_positions: Array[Vector3] = []

## 当前活跃的 LightTrailSystem 轨迹 ID
var _active_trail_id: int = -1

## LightTrailSystem 引用（延迟获取）
var _trail_system: Node = null


func _ready() -> void:
	# 添加到 combat_system 组（TuningMetrics 通过此组查找）
	add_to_group("combat_system")
	# 查找物理碰撞系统
	_physics_system = get_tree().root.find_child("PhysicsCollisionSystem", true, false)
	# 查找流光轨迹系统
	_trail_system = get_tree().root.find_child("LightTrailSystem", true, false)
	# 初始化冷却计时器
	_cooldown_timers.resize(4)
	for i in range(4):
		_cooldown_timers[i] = 0.0


func _process(delta: float) -> void:
	# 更新冷却计时器
	for i in range(1, 4):
		if _cooldown_timers[i] > 0.0:
			_cooldown_timers[i] = maxf(_cooldown_timers[i] - delta, 0.0)

	if _current_phase == Phase.IDLE:
		return

	# EXECUTING 阶段：更新 hitbox 位置（扫动效果）+ 轨迹更新
	if _current_phase == Phase.EXECUTING and _hitbox_id >= 0:
		_update_hitbox_sweep(delta)
		_update_light_trail()

	_phase_timer -= delta
	if _phase_timer > 0.0:
		return

	# 阶段超时 → 转入下一阶段
	match _current_phase:
		Phase.EXECUTING:
			_transition_to(Phase.RECOVERING)
		Phase.RECOVERING:
			_transition_to(Phase.COOLDOWN)
		Phase.COOLDOWN:
			_transition_to(Phase.IDLE)


## 执行指定剑式
## @param form: Form - 要执行的剑式
## @return bool - 是否成功执行
func execute_form(form: Form) -> bool:
	if not _can_execute(form):
		return false

	# RECOVERING 中断：显式清理（hitbox 已在进入 RECOVERING 时销毁）
	if _current_phase == Phase.RECOVERING:
		_phase_timer = 0.0

	_current_form = form
	_transition_to(Phase.EXECUTING)

	# 创建 hitbox（失败不阻止剑招执行）
	if _physics_system:
		var data: Dictionary = FORM_DATA[form]
		var shape := SphereShape3D.new()
		shape.radius = data["hitbox_radius"]
		# hitbox 位置在玩家前方 range/2（沿朝向方向）
		var player_pos := Vector3.ZERO
		var player_forward := Vector3.FORWARD
		var player_right := Vector3.RIGHT
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player:
			player_pos = player.global_position
			# 投影到 XZ 平面，防止攻击偏移高度
			var raw_fwd := -player.global_basis.z
			player_forward = Vector3(raw_fwd.x, 0.0, raw_fwd.z).normalized()
			player_right = player.global_basis.x
		var range_m: float = data["range"]
		var hitbox_pos: Vector3 = player_pos + player_forward * (range_m * 0.5)
		_hitbox_id = _physics_system.create_hitbox(self, shape, hitbox_pos, Vector3.ZERO)

		# 设置扫动参数——每种剑式不同的攻击弧线
		_setup_sweep_pattern(form, player_pos, player_forward, player_right)
		_sweep_progress = 0.0

		# 通过流光轨迹系统创建剑气轨迹
		_create_sword_trail(form, hitbox_pos, player_forward)

	form_activated.emit(form)
	return true


## 返回当前激活的剑式
func get_active_form() -> Form:
	return _current_form


## 是否正在执行剑招
func is_executing() -> bool:
	return _current_phase == Phase.EXECUTING


## 指定剑式是否在冷却中
func is_on_cooldown(form: Form) -> bool:
	if form <= Form.NONE or form > Form.RAO:
		return false
	return _cooldown_timers[form] > 0.0


## 获取当前活跃 hitbox 的 ID
func get_hitbox_id() -> int:
	return _hitbox_id


## 取消当前剑招（死亡/状态变化时调用）
func cancel_current() -> void:
	if _hitbox_id >= 0 and _physics_system:
		_physics_system.destroy_hitbox(_hitbox_id)
	_hitbox_id = -1
	_current_form = Form.NONE
	_current_phase = Phase.IDLE
	_phase_timer = 0.0


## 测试辅助：跳过当前阶段到下一阶段
func _test_advance_phase() -> void:
	match _current_phase:
		Phase.EXECUTING:
			_transition_to(Phase.RECOVERING)
		Phase.RECOVERING:
			_transition_to(Phase.COOLDOWN)
		Phase.COOLDOWN:
			_transition_to(Phase.IDLE)


## 检查是否可以执行指定剑式
func _can_execute(form: Form) -> bool:
	if form <= Form.NONE or form > Form.RAO:
		return false
	if _current_phase == Phase.EXECUTING:
		return false
	if _cooldown_timers[form] > 0.0:
		return false
	return true


## 转入下一阶段
func _transition_to(phase: Phase) -> void:
	match phase:
		Phase.EXECUTING:
			_current_phase = Phase.EXECUTING
			var data: Dictionary = FORM_DATA[_current_form]
			_phase_timer = maxf(data["execute_time"], min_execute_time)

		Phase.RECOVERING:
			# 销毁 hitbox + 清理去重记录
			if _hitbox_id >= 0 and _physics_system:
				_physics_system.destroy_hitbox(_hitbox_id)
				var hj := get_node_or_null("/root/HitJudgment")
				if hj and hj.has_method("clear_hit_records"):
					hj.clear_hit_records(_hitbox_id)
				_hitbox_id = -1
			# 结束轨迹（开始淡出）
			_finish_light_trail()
			_current_phase = Phase.RECOVERING
			var data: Dictionary = FORM_DATA[_current_form]
			_phase_timer = maxf(data["recovery_time"], min_execute_time)

		Phase.COOLDOWN:
			_current_phase = Phase.COOLDOWN
			var data: Dictionary = FORM_DATA[_current_form]
			_phase_timer = data["cooldown_time"]
			_cooldown_timers[_current_form] = data["cooldown_time"]
			form_finished.emit(_current_form)

		Phase.IDLE:
			_current_form = Form.NONE
			_current_phase = Phase.IDLE
			_phase_timer = 0.0


## 通过流光轨迹系统创建剑气轨迹
func _create_sword_trail(_form: Form, start_pos: Vector3, _forward: Vector3) -> void:
	if _trail_system == null:
		return

	# Form 枚举 → 轨迹名称
	var form_names := { Form.YOU: &"you", Form.ZUAN: &"zuan", Form.RAO: &"rao" }
	var trail_name: StringName = form_names.get(_form, &"you")

	# 创建轨迹
	_active_trail_id = _trail_system.create_trail(trail_name, start_pos)
	_trail_positions.clear()
	_trail_positions.append(start_pos)


## 每帧更新流光轨迹位置
func _update_light_trail() -> void:
	if _active_trail_id < 0 or _trail_system == null:
		return
	if _trail_positions.size() == 0:
		return
	var latest_pos: Vector3 = _trail_positions[-1]
	_trail_system.update_trail(_active_trail_id, latest_pos)


## 结束流光轨迹（开始淡出）
func _finish_light_trail() -> void:
	if _active_trail_id < 0 or _trail_system == null:
		return
	_trail_system.finish_trail(_active_trail_id)
	_active_trail_id = -1


## 更新 hitbox 位置——从左前方扫到右前方
## EXECUTING 阶段每帧调用，模拟剑招挥砍轨迹
func _update_hitbox_sweep(delta: float) -> void:
	if _hitbox_id < 0 or _physics_system == null:
		return

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	# 计算扫动进度
	var form_data: Dictionary = FORM_DATA.get(_current_form, {})
	var execute_time: float = maxf(form_data.get("execute_time", 0.3), 0.05)
	_sweep_progress = clampf(_sweep_progress + delta / execute_time, 0.0, 1.0)

	var new_pos: Vector3 = _calculate_sweep_position(player)
	_physics_system.update_hitbox_transform(_hitbox_id, new_pos, Vector3.ZERO)
	_trail_positions.append(new_pos)


## 根据剑式计算当前帧的 hitbox 位置——每种剑式完全不同的运动轨迹
func _calculate_sweep_position(player: Node3D) -> Vector3:
	var t := _sweep_progress
	var base := player.global_position

	match _current_form:
		Form.YOU:
			# 游剑式: S 形蛇行 — 前进中左右摆动
			var range_m: float = FORM_DATA[Form.YOU]["range"]
			var forward := Vector3(-player.global_basis.z.x, 0.0, -player.global_basis.z.z).normalized()
			var right := Vector3(player.global_basis.x.x, 0.0, player.global_basis.x.z).normalized()
			# 前进: 0→range
			var fwd_dist := t * range_m
			# 左右摆动: sin 波, 振幅 1.2m
			var side_offset := sin(t * TAU * 1.5) * 1.2
			return base + forward * fwd_dist + right * side_offset

		Form.ZUAN:
			# 钻剑式: 直线穿透 — 从近到远, 前快后慢
			var range_m: float = FORM_DATA[Form.ZUAN]["range"]
			var forward := Vector3(-player.global_basis.z.x, 0.0, -player.global_basis.z.z).normalized()
			# ease_in: 前慢后快（蓄力感）
			var eased := t * t
			return base + forward * (0.5 + eased * (range_m - 0.5))

		Form.RAO:
			# 绕剑式: 大弧环绕 — 从左后方扫到右后方, 围绕玩家
			var radius: float = FORM_DATA[Form.RAO]["range"]
			# 弧度: 从 -150° 到 +150° (300° 弧线)
			var angle := deg_to_rad(-150.0 + t * 300.0)
			var offset := Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)
			return base + offset

	return base + _sweep_start_offset.lerp(_sweep_end_offset, t)


## 设置每种剑式不同的扫动模式（Quick Spec: three-forms-vulnerability）
## 游剑式(YOU): S 形曲线 — 左前方→正前方→右前方
## 钻剑式(ZUAN): 直线穿透 — 前方 0.5m→3.5m
## 绕剑式(RAO): 360° 环绕 — 围绕玩家从后方扫到前方
func _setup_sweep_pattern(form: Form, player_pos: Vector3, forward: Vector3, right: Vector3) -> void:
	var data: Dictionary = FORM_DATA[form]
	var range_m: float = data["range"]
	# 强制投影到 XZ 平面（Y=0），防止扫动钻入地板
	var fwd := Vector3(forward.x, 0.0, forward.z).normalized()
	var rgt := Vector3(right.x, 0.0, right.z).normalized()
	match form:
		Form.YOU:
			# 游剑式: S 形曲线（左前→正前→右前）
			_sweep_start_offset = fwd * (range_m * 0.6) - rgt * (range_m * 0.5)
			_sweep_end_offset = fwd * (range_m * 0.6) + rgt * (range_m * 0.5)
		Form.ZUAN:
			# 钻剑式: 直线穿透 3.5m
			_sweep_start_offset = fwd * 0.5
			_sweep_end_offset = fwd * range_m
		Form.RAO:
			# 绕剑式: 大弧横扫（前方左侧→前方右侧）
			_sweep_start_offset = fwd * (range_m * 0.5) - rgt * range_m
			_sweep_end_offset = fwd * (range_m * 0.5) + rgt * range_m
		_:
			_sweep_start_offset = fwd * 1.0
			_sweep_end_offset = fwd * 2.0

	_trail_positions.clear()
	_trail_positions.append(player_pos + _sweep_start_offset)
