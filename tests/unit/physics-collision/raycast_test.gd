@warning_ignore_start("inferred_declaration")
# 射线检测系统单元测试
# 测试覆盖 Story 002 的所有 Acceptance Criteria
class_name RaycastTest
extends GdUnitTestSuite

var _collision_system: PhysicsCollisionSystem
var _floor_body: StaticBody3D
var _floor_shape: CollisionShape3D


func before_test() -> void:
	# 创建物理碰撞系统
	_collision_system = PhysicsCollisionSystem.new()
	auto_free(_collision_system)

	# 创建地面碰撞体用于射线命中测试
	_floor_body = StaticBody3D.new()
	_floor_body.collision_layer = PhysicsCollisionSystem.CollisionLayer.ENVIRONMENT
	_floor_body.collision_mask = 0
	_floor_shape = CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20.0, 0.5, 20.0)
	_floor_shape.shape = floor_box
	_floor_body.add_child(_floor_shape)
	_floor_body.position = Vector3(0, -0.25, 0)
	auto_free(_floor_body)

	# 添加到场景树（get_world_3d() 需要节点在树中）
	add_child(_collision_system)
	add_child(_floor_body)


func after_test() -> void:
	pass  # auto_free handles cleanup


## AC-2: raycast(A, A, mask) → null
## Given: 起点和终点相同
## When: raycast 调用
## Then: 返回 null
func test_raycast_same_start_end_returns_null() -> void:
	var point := Vector3(0, 5, 0)
	var result := _collision_system.raycast(point, point, 0xFFFFFFFF)
	assert_object(result).is_null()


## 无碰撞体路径：射线从上方发射到更上方，不命中任何物体
func test_raycast_no_collider_returns_null() -> void:
	var result := _collision_system.raycast(Vector3(0, 10, 0), Vector3(0, 20, 0), 0xFFFFFFFF)
	assert_object(result).is_null()


## AC-1: raycast(A, B, mask) with collider → RaycastResult
## Given: 射线从 (0, 5, 0) 向 -Y 发射，地面在 y=-0.25
## When: raycast 调用
## Then: 返回 RaycastResult 且包含碰撞体
func test_raycast_with_collider_returns_result() -> void:
	var result := _collision_system.raycast(Vector3(0, 5, 0), Vector3(0, -5, 0), 0xFFFFFFFF)
	assert_object(result).is_not_null()
	assert_object(result.collider).is_not_null()


## 验证射线命中时返回正确的碰撞位置（Y ≈ 0.25，地面顶部）
func test_raycast_hit_position_near_surface() -> void:
	var result := _collision_system.raycast(Vector3(0, 5, 0), Vector3(0, -5, 0), 0xFFFFFFFF)
	assert_bool(result != null).is_true()
	assert_float(result.hit_position.y).is_equal_approx(0.25, 0.1)


## 验证射线命中时 distance 正确（≈ 4.75）
func test_raycast_hit_distance_correct() -> void:
	var from := Vector3(0, 5, 0)
	var result := _collision_system.raycast(from, Vector3(0, -5, 0), 0xFFFFFFFF)
	assert_bool(result != null).is_true()
	var expected_distance := from.distance_to(result.hit_position)
	assert_float(result.distance).is_equal_approx(expected_distance, 0.01)


## 碰撞层过滤：ENVIRONMENT 掩码可检测地面
func test_raycast_mask_filters_by_layer() -> void:
	var env_mask := PhysicsCollisionSystem.CollisionLayer.ENVIRONMENT
	var result := _collision_system.raycast(Vector3(0, 5, 0), Vector3(0, -5, 0), env_mask)
	assert_object(result).is_not_null()


## 碰撞层过滤：仅 PLAYER 掩码不检测 ENVIRONMENT 地面
func test_raycast_wrong_mask_returns_null() -> void:
	var player_mask := PhysicsCollisionSystem.CollisionLayer.PLAYER
	var result := _collision_system.raycast(Vector3(0, 5, 0), Vector3(0, -5, 0), player_mask)
	assert_object(result).is_null()


## 额外测试：射线返回的法线方向合理（地面法线朝上）
func test_raycast_hit_normal_reasonable() -> void:
	var result := _collision_system.raycast(Vector3(0, 5, 0), Vector3(0, -5, 0), 0xFFFFFFFF)
	assert_bool(result != null).is_true()
	# 地面法线 Y 应为正（朝上）
	assert_bool(result.hit_normal.y > 0.0).is_true()
