# 碰撞结果数据结构
class_name CollisionResult
extends RefCounted

## 碰撞结果，包含碰撞位置、法线、碰撞对象等信息
## 由 PhysicsCollisionSystem 返回给上层系统（命中判定层等）

var hit_position: Vector3 ## 碰撞世界坐标
var hit_normal: Vector3 ## 碰撞法线（从碰撞点指向被碰撞对象）
var collider: Node ## 碰撞到的对象（Area3D 的父节点）
var collider_id: int ## 碰撞对象的实例 ID
var hitbox_id: int ## 发生碰撞的 hitbox ID

func _init(p_hit_position: Vector3, p_hit_normal: Vector3, p_collider: Node, p_collider_id: int, p_hitbox_id: int) -> void:
	hit_position = p_hit_position
	hit_normal = p_hit_normal
	collider = p_collider
	collider_id = p_collider_id
	hitbox_id = p_hitbox_id
