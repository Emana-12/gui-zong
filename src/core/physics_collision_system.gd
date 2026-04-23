# 物理碰撞系统
class_name PhysicsCollisionSystem
extends Node

## 管理 hitbox/hurtbox、执行空间查询（射线检测、ShapeCast3D），
## 并提供碰撞结果给上层系统（命中判定层、三式剑招系统等）
##
## 职责：
## - 碰撞体管理（创建/销毁/更新碰撞形状）
## - 空间查询（射线检测、ShapeCast3D、Area3D 重叠检测）
## - 碰撞结果输出（碰撞位置、法线、碰撞对象）
##
## 不负责：
## - 伤害计算（由命中判定层负责）
## - 命中类型判断（由命中判定层负责）
## - 无敌帧逻辑（由玩家控制器/命中判定层负责）

## 碰撞信号：当 hitbox 与 hurtbox 发生碰撞时触发
signal collision_detected(result: CollisionResult)

## 碰撞层定义（与 Godot 的 collision_layer / collision_mask 对应）
enum CollisionLayer {
	PLAYER = 1,           # 玩家 hurtbox (layer 1)
	ENEMY = 2,            # 敌人 hurtbox (layer 2)
	PLAYER_ATTACK = 4,    # 玩家攻击 hitbox (layer 3)
	ENEMY_ATTACK = 8,     # 敌人攻击 hitbox (layer 4)
	ENVIRONMENT = 16,     # 环境（地形、障碍物）(layer 5)
	INTERACTABLE = 32,    # 可交互物体（绕剑式附着点）(layer 6)
}

## hitbox 数据结构
class HitboxData:
	var id: int
	var area: Area3D
	var collision_shape: CollisionShape3D
	var owner: Node
	var is_active: bool
	var pending_destroy: bool

	func _init(p_id: int, p_area: Area3D, p_collision_shape: CollisionShape3D, p_owner: Node3D) -> void:
		id = p_id
		area = p_area
		collision_shape = p_collision_shape
		owner = p_owner
		is_active = false
		pending_destroy = false

## Hitbox 池化配置
const MAX_HITBOXES := 18

## 运行时数据
var _hitbox_pool: Array[HitboxData] = []
var _next_hitbox_id: int = 0
var _active_hitboxes: Dictionary = {}  # {hitbox_id: HitboxData}
var _pending_removal_buffer: Array[int] = []  # 预分配，避免每帧分配

# 碰撞层配置
# Player(1) 碰撞: EnemyAttack(4), Environment(5), Interactable(6)
const PLAYER_COLLISION_MASK := CollisionLayer.ENEMY_ATTACK | CollisionLayer.ENVIRONMENT | CollisionLayer.INTERACTABLE
# Enemy(2) 碰撞: PlayerAttack(3), Environment(5)
const ENEMY_COLLISION_MASK := CollisionLayer.PLAYER_ATTACK | CollisionLayer.ENVIRONMENT
# PlayerAttack(3) 碰撞: Enemy(2), Interactable(6)
const PLAYER_ATTACK_COLLISION_MASK := CollisionLayer.ENEMY | CollisionLayer.INTERACTABLE
# EnemyAttack(4) 碰撞: Player(1), Environment(5)
const ENEMY_ATTACK_COLLISION_MASK := CollisionLayer.PLAYER | CollisionLayer.ENVIRONMENT


func _ready() -> void:
	# 预创建 hitbox 池
	_precreate_hitbox_pool()


func _physics_process(_delta: float) -> void:
	# 处理待销毁的 hitbox（在物理帧中销毁，避免信号处理顺序问题）
	_pending_removal_buffer.clear()
	for hitbox_id in _active_hitboxes:
		var data: HitboxData = _active_hitboxes[hitbox_id]
		if data.pending_destroy:
			_deactivate_hitbox(data)
			_pending_removal_buffer.append(hitbox_id)

	for hitbox_id in _pending_removal_buffer:
		_active_hitboxes.erase(hitbox_id)


## 创建 hitbox
## @param owner: Node3D - hitbox 的所有者（用于碰撞回调识别）
## @param shape: Shape3D - 碰撞形状
## @param pos: Vector3 - 世界坐标位置
## @param rot: Vector3 - 旋转（欧拉角，弧度）
## @return int - hitbox ID，-1 表示创建失败（池已满）
func create_hitbox(owner: Node, shape: Shape3D, pos: Vector3, rot: Vector3) -> int:
	# 查找空闲的 hitbox
	var data: HitboxData = null
	for hitbox_data in _hitbox_pool:
		if not hitbox_data.is_active and not hitbox_data.pending_destroy:
			data = hitbox_data
			break

	if data == null:
		push_warning("PhysicsCollisionSystem: Hitbox pool exhausted (max %d)" % MAX_HITBOXES)
		return -1

	# 配置碰撞形状
	data.collision_shape.shape = shape
	data.collision_shape.transform = Transform3D.IDENTITY.rotated(Vector3.RIGHT, rot.x).rotated(Vector3.UP, rot.y).rotated(Vector3.FORWARD, rot.z)
	data.collision_shape.transform.origin = pos
	data.owner = owner
	data.is_active = true
	data.pending_destroy = false

	# 启用 Area3D
	data.area.monitoring = true
	data.area.monitorable = true

	_active_hitboxes[data.id] = data
	return data.id


## 销毁 hitbox（立即停用，放回池中）
## @param id: int - hitbox ID
func destroy_hitbox(id: int) -> void:
	if not _active_hitboxes.has(id):
		return

	var data: HitboxData = _active_hitboxes[id]
	# 立即停用，不延迟
	_deactivate_hitbox(data)
	_active_hitboxes.erase(id)


## 更新 hitbox 位置和旋转
## @param id: int - hitbox ID
## @param pos: Vector3 - 新的世界坐标位置
## @param rot: Vector3 - 新的旋转（欧拉角，弧度）
func update_hitbox_transform(id: int, pos: Vector3, rot: Vector3) -> void:
	if not _active_hitboxes.has(id):
		push_warning("PhysicsCollisionSystem: Attempt to update non-existent hitbox %d" % id)
		return

	var data: HitboxData = _active_hitboxes[id]
	data.collision_shape.transform = Transform3D.IDENTITY.rotated(Vector3.RIGHT, rot.x).rotated(Vector3.UP, rot.y).rotated(Vector3.FORWARD, rot.z)
	data.collision_shape.transform.origin = pos


## 获取活跃 hitbox 数量
## @return int - 当前活跃的 hitbox 数量
func get_active_hitbox_count() -> int:
	return _active_hitboxes.size()


## 获取 hitbox 池剩余可用数量
## @return int - 剩余可创建的 hitbox 数量
func get_remaining_hitbox_capacity() -> int:
	return MAX_HITBOXES - _active_hitboxes.size()


## 获取 hitbox 的所有碰撞结果
## @param id: int - hitbox ID
## @return Array[CollisionResult] - 碰撞结果列表
func get_hitbox_collisions(id: int) -> Array[CollisionResult]:
	if not _active_hitboxes.has(id):
		push_warning("PhysicsCollisionSystem: Attempt to query non-existent hitbox %d" % id)
		return []

	var data: HitboxData = _active_hitboxes[id]
	var results: Array[CollisionResult] = []

	# 获取重叠的 Area3D
	var overlapping_areas := data.area.get_overlapping_areas()
	for other_area in overlapping_areas:
		# 创建碰撞结果
		var hit_pos := other_area.global_position
		var hit_normal := (data.area.global_position - other_area.global_position).normalized()
		var collider_node := other_area.get_parent()
		var collider_id_val := other_area.get_instance_id()

		var result := CollisionResult.new(hit_pos, hit_normal, collider_node, collider_id_val, id)
		results.append(result)

	return results


## 射线检测
## @param from: Vector3 - 射线起点（世界坐标）
## @param to: Vector3 - 射线终点（世界坐标）
## @param mask: int - 碰撞层掩码
## @return RaycastResult - 最近碰撞点的结果，null 表示无碰撞
func raycast(from: Vector3, to: Vector3, mask: int) -> RaycastResult:
	# 起点和终点重合，返回 null
	if from.is_equal_approx(to):
		return null

	var space_state := get_viewport().find_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, mask)
	var result := space_state.intersect_ray(query)

	if result.is_empty():
		return null

	var hit_pos: Vector3 = result["position"]
	var hit_normal: Vector3 = result["normal"]
	var collider: Object = result.get("collider", null)
	if collider == null or not is_instance_valid(collider):
		return null
	var collider_node := collider as Node3D
	if collider_node == null:
		return null
	var collider_id_val: int = result["collider_id"]
	var distance := from.distance_to(hit_pos)

	return RaycastResult.new(hit_pos, hit_normal, collider_node, collider_id_val, distance)


## 形状投射检测
## @param from: Vector3 - 投射起点（世界坐标）
## @param to: Vector3 - 投射终点（世界坐标）
## @param shape: Shape3D - 投射的碰撞形状
## @param mask: int - 碰撞层掩码
## @return Array[CollisionResult] - 所有碰撞结果列表
##
## 注意：intersect_shape() 不返回碰撞点位置和法线（Godot API 限制）。
## CollisionResult 的 hit_position 和 hit_normal 使用默认值。
## 如需精确碰撞点，使用 raycast() 或 get_rest_info()。
func shape_cast(from: Vector3, to: Vector3, shape: Shape3D, mask: int) -> Array[CollisionResult]:
	var space_state := get_viewport().find_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D.IDENTITY.translated(from)
	query.collision_mask = mask

	var results: Array[CollisionResult] = []
	var collisions := space_state.intersect_shape(query, 32)  # 最多 32 个碰撞

	for collision in collisions:
		var collider: Object = collision.get("collider", null)
		if collider == null or not is_instance_valid(collider):
			continue
		var collider_node := collider as Node3D
		if collider_node == null:
			continue
		var collider_id_val: int = collision["collider_id"]

		# intersect_shape() 不返回 "point" 和 "normal"，使用 collider 位置近似
		var hit_pos := collider_node.global_position
		var result := CollisionResult.new(hit_pos, Vector3.ZERO, collider_node, collider_id_val, -1)
		results.append(result)

	return results


## 预创建 hitbox 池
func _precreate_hitbox_pool() -> void:
	for i in range(MAX_HITBOXES):
		var area := Area3D.new()
		var collision_shape := CollisionShape3D.new()
		area.add_child(collision_shape)
		add_child(area)

		# 初始禁用
		area.monitoring = false
		area.monitorable = false

		# 碰撞层配置：玩家攻击 hitbox 在 layer 3, 检测敌人 (layer 2) 和可交互物 (layer 6)
		area.collision_layer = CollisionLayer.PLAYER_ATTACK  # layer 3
		area.collision_mask = PLAYER_ATTACK_COLLISION_MASK   # ENEMY | INTERACTABLE

		var data := HitboxData.new(_next_hitbox_id, area, collision_shape, null)
		_hitbox_pool.append(data)
		_next_hitbox_id += 1

		# 连接信号
		area.area_entered.connect(_on_area_entered.bind(data))
		area.body_entered.connect(_on_body_entered.bind(data))


## 停用 hitbox（放回池中）
func _deactivate_hitbox(data: HitboxData) -> void:
	data.is_active = false
	data.pending_destroy = false
	data.area.monitoring = false
	data.area.monitorable = false
	data.owner = null


## Area3D 重叠信号回调
func _on_area_entered(other_area: Area3D, hitbox_data: HitboxData) -> void:
	# 只有当 hitbox 活跃时才处理碰撞
	if not hitbox_data.is_active or hitbox_data.pending_destroy:
		return

	# 创建碰撞结果
	var hit_pos := other_area.global_position
	var hit_normal := (hitbox_data.area.global_position - other_area.global_position).normalized()
	var collider_node := other_area.get_parent()
	var collider_id_val := other_area.get_instance_id()

	var result := CollisionResult.new(hit_pos, hit_normal, collider_node, collider_id_val, hitbox_data.id)

	# 发射信号
	collision_detected.emit(result)


## CharacterBody3D 重叠信号回调（用于检测敌人碰撞）
func _on_body_entered(body: Node3D, hitbox_data: HitboxData) -> void:
	if not hitbox_data.is_active or hitbox_data.pending_destroy:
		return

	# 创建碰撞结果
	var hit_pos := body.global_position
	var hit_normal := (hitbox_data.area.global_position - body.global_position).normalized()
	var collider_id_val := body.get_instance_id()

	var result := CollisionResult.new(hit_pos, hit_normal, body, collider_id_val, hitbox_data.id)

	# 发射信号
	collision_detected.emit(result)
