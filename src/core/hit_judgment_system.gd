# 命中判定系统 — Autoload 单例
extends Node

## 碰撞→命中转换层。过滤碰撞（无敌、自伤），计算伤害，广播命中信号。
##
## 设计参考:
## - docs/architecture/adr-0011-hit-judgment-architecture.md
## - design/gdd/hit-judgment.md
## - production/epics/hit-judgment/story-001-hit-processing.md
##
## 依赖:
## - PhysicsCollisionSystem (collision_detected 信号源)
## - PlayerController (is_invincible(), take_damage())
##
## @see ADR-0011

## 剑招类型枚举。对应四种攻击形式。
enum SwordForm {
	ENEMY = 0,  ## 敌人攻击
	YOU = 1,    ## 游剑式
	RAO = 2,    ## 绕剑式
	ZUAN = 3,   ## 钻剑式
}

## 伤害表：SwordForm → base damage
const DAMAGE_TABLE: Dictionary = {
	SwordForm.YOU: 1,
	SwordForm.ZUAN: 3,
	SwordForm.RAO: 2,
	SwordForm.ENEMY: 1,
}

## 材质检测组名映射
const MATERIAL_GROUPS: Dictionary = {
	&"body": [&"enemies", &"player"],
	&"metal": [&"environment_metal"],
	&"wood": [&"environment_wood"],
	&"ink": [&"environment_ink"],
}

## 默认材质（无组匹配时回退）
const DEFAULT_MATERIAL: StringName = &"body"

## 方向判定扇形半角（度）。总扇形 = 2 × HALF_FAN_ANGLE = 240°。
## 只排除玩家正后方 120° 区域。
const HALF_FAN_ANGLE_DEG: float = 120.0

## 方向判定用弧度值
const HALF_FAN_ANGLE_RAD: float = HALF_FAN_ANGLE_DEG * PI / 180.0

## 最小有效距离（小于此距离视为重叠，应命中）
const MIN_HIT_DISTANCE: float = 0.1

## 最大有效距离（超过此距离不判定）
const MAX_HIT_DISTANCE: float = 10.0

## 命中结果数据结构。包含一次有效命中的全部信息。
class HitResult:
	extends RefCounted

	var attacker: Node       ## 攻击者节点（ThreeFormsCombat 或 Node3D）
	var target: Node3D         ## 被击中节点
	var sword_form: int        ## SwordForm 枚举值
	var damage: int            ## 最终伤害值
	var hit_position: Vector3  ## 命中世界坐标
	var hit_normal: Vector3    ## 命中法线
	var material_type: StringName  ## 材质类型
	var is_vulnerability_hit: bool = false  ## 是否击中方向破绽

	func _init(p_attacker: Node, p_target: Node3D, p_sword_form: int,
			p_damage: int, p_hit_position: Vector3, p_hit_normal: Vector3,
			p_material_type: StringName) -> void:
		attacker = p_attacker
		target = p_target
		sword_form = p_sword_form
		damage = p_damage
		hit_position = p_hit_position
		hit_normal = p_hit_normal
		material_type = p_material_type


## 有效命中信号。参数包含完整的 HitResult 数据。
signal hit_landed(result: HitResult)

## 被格挡信号（目标无敌时触发，用于音效反馈）。
signal hit_blocked(result: HitResult)

## 命中去重字典：hitbox_id → { target_id: bool }
var _hit_registry: Dictionary = {}

## 最近一次命中结果缓存。
var _last_hit: HitResult = null

## 预分配去重嵌套字典的池，避免热路径分配。
var _empty_dict: Dictionary = {}


## ── 公开 API ──────────────────────────────────────────────────────────────

## 处理碰撞事件，执行 5 步过滤管线并返回 HitResult 或 null。
## 管线: invincibility → self-hit → dedup → direction → damage
##
## @param collision: CollisionResult - 物理碰撞结果
## @param attacker: Node - 攻击者（hitbox 所有者）
## @param sword_form: int - SwordForm 枚举值
## @return HitResult - 有效命中返回 HitResult，被过滤返回 null
func process_collision(collision: CollisionResult, attacker: Node,
		sword_form: int = SwordForm.YOU) -> HitResult:
	var target: Node3D = collision.collider

	# 步骤 1: 无敌检查
	if _is_invincible(target):
		var blocked := _make_hit_result(attacker, target, sword_form, 0,
				collision.hit_position, collision.hit_normal)
		hit_blocked.emit(blocked)
		return null

	# 步骤 2: 自伤检查
	if attacker == target:
		return null

	# 步骤 3: 去重检查
	if is_already_hit(collision.hitbox_id, target.get_instance_id()):
		return null

	# 步骤 4: 方向/距离检查 (S03-09)
	if not _is_in_hit_fan(attacker, collision.hit_position):
		return null

	# 步骤 5: 伤害计算（含方向破绽检查）
	var base_damage := calculate_damage(sword_form)
	var damage_multiplier := _check_vulnerability(target, attacker, sword_form)
	var damage := int(base_damage * damage_multiplier)
	var material := _detect_material_type(target)
	var result := _make_hit_result(attacker, target, sword_form, damage,
			collision.hit_position, collision.hit_normal, material)
	result.is_vulnerability_hit = damage_multiplier > 1.0

	# 注册命中去重
	register_hit(collision.hitbox_id, target.get_instance_id())

	# 缓存并广播
	_last_hit = result
	hit_landed.emit(result)
	return result


## 计算指定剑招类型的基础伤害。
##
## @param sword_form: int - SwordForm 枚举值
## @return int - 伤害值
func calculate_damage(sword_form: int) -> int:
	if DAMAGE_TABLE.has(sword_form):
		return DAMAGE_TABLE[sword_form]
	return DAMAGE_TABLE[SwordForm.ENEMY]


## 注册命中记录，用于去重。
##
## @param hitbox_id: int - hitbox ID
## @param target_id: int - 目标实例 ID
func register_hit(hitbox_id: int, target_id: int) -> void:
	if not _hit_registry.has(hitbox_id):
		_hit_registry[hitbox_id] = {}
	_hit_registry[hitbox_id][target_id] = true


## 检查指定 hitbox 是否已命中指定目标。
##
## @param hitbox_id: int - hitbox ID
## @param target_id: int - 目标实例 ID
## @return bool - 已命中返回 true
func is_already_hit(hitbox_id: int, target_id: int) -> bool:
	if not _hit_registry.has(hitbox_id):
		return false
	return _hit_registry[hitbox_id].has(target_id)


## 清除指定 hitbox 的所有命中记录（hitbox 被回收时调用）。
##
## @param hitbox_id: int - hitbox ID
func clear_hit_records(hitbox_id: int) -> void:
	_hit_registry.erase(hitbox_id)


## 获取最近一次有效命中结果。
##
## @return HitResult - 最近的命中结果，无命中返回 null
func get_last_hit() -> HitResult:
	return _last_hit


## ── 内部方法 ──────────────────────────────────────────────────────────────

## 检查目标是否无敌。
func _is_invincible(target: Node) -> bool:
	if target == null:
		return false
	if target.has_method("is_invincible"):
		return target.is_invincible()
	return false


## 检测目标的材质类型（通过节点组）。
func _detect_material_type(target: Node) -> StringName:
	for material_name in MATERIAL_GROUPS:
		var groups: Array = MATERIAL_GROUPS[material_name]
		for group_name in groups:
			if target.is_in_group(group_name):
				return material_name
	return DEFAULT_MATERIAL


## 构建 HitResult。
func _make_hit_result(attacker: Node, target: Node3D, sword_form: int,
		damage: int, hit_position: Vector3, hit_normal: Vector3,
		material_type: StringName = DEFAULT_MATERIAL) -> HitResult:
	return HitResult.new(attacker, target, sword_form, damage,
			hit_position, hit_normal, material_type)


## 检查命中点是否在玩家前方 90° 扇形内且距离有效。
## 用于过滤玩家背面的碰撞和超远距离碰撞。
##
## 规则:
## - 距离 < MIN_HIT_DISTANCE → 命中（重叠情况）
## - 距离 > MAX_HIT_DISTANCE → miss
## - 角度 ≤ 45° → 命中
## - 角度 > 45° → miss
##
## @param attacker: Node - 攻击者（玩家）
## @param hit_position: Vector3 - 命中点世界坐标
## @return bool - true = 命中在扇形内
func _is_in_hit_fan(_attacker: Node, hit_position: Vector3) -> bool:
	# 方向检查基于玩家节点（不是 ThreeFormsCombat 节点）
	var player: Node3D = null
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		var players := tree.get_nodes_in_group("player")
		if not players.is_empty():
			player = players[0] as Node3D

	if player == null:
		return true  # 无玩家时不做方向检查

	var to_target := hit_position - player.global_position
	var dist := to_target.length()

	# 距离边界检查
	if dist < MIN_HIT_DISTANCE:
		return true  # 重叠，应命中
	if dist > MAX_HIT_DISTANCE:
		return false  # 太远

	# 扇形角度检查
	var forward := -player.global_basis.z  # Godot 前方 = -Z
	var to_target_flat := Vector3(to_target.x, 0.0, to_target.z)

	# 如果目标几乎在正上方/下方（Y 轴），使用 3D 向量
	if to_target_flat.length_squared() < 0.0001:
		to_target_flat = to_target

	if to_target_flat.length_squared() < 0.0001:
		return true  # 完全重叠

	var forward_flat := Vector3(forward.x, 0.0, forward.z)
	if forward_flat.length_squared() < 0.0001:
		forward_flat = forward

	var cos_angle := forward_flat.normalized().dot(to_target_flat.normalized())
	# 钳制到 [-1, 1] 避免浮点误差
	cos_angle = clampf(cos_angle, -1.0, 1.0)
	var angle := acos(cos_angle)

	return angle <= HALF_FAN_ANGLE_RAD


## 检查方向破绽——通过 EnemySystem 查询目标敌人是否有被击中的破绽
func _check_vulnerability(target: Node3D, attacker: Node, sword_form: int) -> float:
	if not target.is_in_group("enemies"):
		return 1.0

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return 1.0
	var es := tree.root.find_child("EnemySystem", true, false)
	if es == null or not es.has_method("check_vulnerability_by_node"):
		return 1.0

	# 攻击者位置
	var attacker_pos: Vector3 = Vector3.ZERO
	if attacker is Node3D:
		attacker_pos = attacker.global_position
	else:
		var player := tree.get_first_node_in_group("player") as Node3D
		if player:
			attacker_pos = player.global_position

	return es.check_vulnerability_by_node(target, attacker_pos, sword_form)
