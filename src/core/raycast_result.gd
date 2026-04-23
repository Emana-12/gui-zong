# 射线检测结果数据结构
class_name RaycastResult
extends RefCounted

## 射线检测结果，包含碰撞位置、法线、碰撞对象等信息
## 由 PhysicsCollisionSystem.raycast() 返回

var hit_position: Vector3 ## 碰撞世界坐标
var hit_normal: Vector3 ## 碰撞法线（从碰撞点指向被碰撞对象）
var collider: Node3D ## 碰撞到的对象
var collider_id: int ## 碰撞对象的实例 ID
var distance: float ## 从射线起点到碰撞点的距离

func _init(p_hit_position: Vector3, p_hit_normal: Vector3, p_collider: Node3D, p_collider_id: int, p_distance: float) -> void:
	hit_position = p_hit_position
	hit_normal = p_hit_normal
	collider = p_collider
	collider_id = p_collider_id
	distance = p_distance
