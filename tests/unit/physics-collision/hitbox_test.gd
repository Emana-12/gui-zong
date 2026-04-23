@warning_ignore_start("inferred_declaration")
# 物理碰撞系统单元测试
# 测试覆盖 Story 001 的所有 Acceptance Criteria
class_name HitboxTest
extends GdUnitTestSuite

var physics_system: PhysicsCollisionSystem
var player_area: Area3D
var player_shape: CollisionShape3D
var enemy_area: Area3D
var enemy_shape: CollisionShape3D


func before_test() -> void:
	# 创建物理碰撞系统
	physics_system = PhysicsCollisionSystem.new()
	auto_free(physics_system)

	# 创建测试用的 hurtbox（玩家）
	player_area = Area3D.new()
	player_shape = CollisionShape3D.new()
	player_shape.shape = SphereShape3D.new()
	(player_shape.shape as SphereShape3D).radius = 0.5
	player_area.add_child(player_shape)
	physics_system.add_child(player_area)

	# 创建测试用的 hurtbox（敌人）
	enemy_area = Area3D.new()
	enemy_shape = CollisionShape3D.new()
	enemy_shape.shape = SphereShape3D.new()
	(enemy_shape.shape as SphereShape3D).radius = 0.8
	enemy_area.add_child(enemy_shape)
	physics_system.add_child(enemy_area)

	# 配置碰撞层
	player_area.collision_layer = PhysicsCollisionSystem.CollisionLayer.PLAYER
	player_area.collision_mask = PhysicsCollisionSystem.CollisionLayer.ENEMY_ATTACK
	enemy_area.collision_layer = PhysicsCollisionSystem.CollisionLayer.ENEMY
	enemy_area.collision_mask = PhysicsCollisionSystem.CollisionLayer.PLAYER_ATTACK


func after_test() -> void:
	pass  # auto_free handles cleanup


## AC-1: Sword hitbox overlaps enemy hurtbox → collision_detected signal with position + target
## Given: 玩家挥剑，剑招 hitbox 与敌人 hurtbox 重叠
## When: _physics_process 执行
## Then: collision_detected 信号触发，返回碰撞位置和对象
func test_sword_hitbox_overlaps_enemy_hurtbox_triggers_collision_detected() -> void:
	# 准备：创建玩家攻击 hitbox
	var hitbox_shape := BoxShape3D.new()
	hitbox_shape.size = Vector3(1.0, 0.5, 2.0)  # 剑招 hitbox
	var hitbox_pos := Vector3(0, 0, 0)
	var hitbox_rot := Vector3(0, 0, 0)

	var hitbox_id := physics_system.create_hitbox(player_area, hitbox_shape, hitbox_pos, hitbox_rot)
	assert_int(hitbox_id).is_greater_equal(0)

	# 配置 hitbox 的碰撞层
	var hitbox_data: PhysicsCollisionSystem.HitboxData = physics_system._active_hitboxes[hitbox_id]
	hitbox_data.area.collision_layer = PhysicsCollisionSystem.CollisionLayer.PLAYER_ATTACK
	hitbox_data.area.collision_mask = PhysicsCollisionSystem.CollisionLayer.ENEMY

	# 将敌人 hurtbox 放在 hitbox 位置（重叠）
	enemy_area.global_position = Vector3(0, 0, 0)

	# 监听信号
	var signal_monitor := monitor_signals(physics_system)

	# 执行：等待物理帧处理
	await physics_process_frame()

	# 验证：collision_detected 信号被触发
	assert_bool(signal_monitor.is_emitted("collision_detected")).is_true()

	# 验证：碰撞结果包含正确的位置和对象
	var emitted_args := signal_monitor.get_emitted_args("collision_detected")
	assert_int(emitted_args.size()).is_greater(0)
	var result: CollisionResult = emitted_args[0][0]
	assert_object(result.collider).is_equal(enemy_area.get_parent())
	assert_vector3(result.hit_position).is_equal(enemy_area.global_position)


## AC-2: Player hurtbox overlaps enemy attack during invincibility → collision still detected
## Given: 玩家处于无敌帧
## When: 敌人攻击 hitbox 与玩家 hurtbox 重叠
## Then: 物理碰撞层仍检测到碰撞（由命中判定层过滤）
func test_player_invincibility_still_detects_collision() -> void:
	# 准备：创建敌人攻击 hitbox
	var hitbox_shape := BoxShape3D.new()
	hitbox_shape.size = Vector3(1.0, 0.5, 2.0)
	var hitbox_pos := Vector3(0, 0, 0)
	var hitbox_rot := Vector3(0, 0, 0)

	var hitbox_id := physics_system.create_hitbox(enemy_area, hitbox_shape, hitbox_pos, hitbox_rot)
	assert_int(hitbox_id).is_greater_equal(0)

	# 配置 hitbox 的碰撞层
	var hitbox_data: PhysicsCollisionSystem.HitboxData = physics_system._active_hitboxes[hitbox_id]
	hitbox_data.area.collision_layer = PhysicsCollisionSystem.CollisionLayer.ENEMY_ATTACK
	hitbox_data.area.collision_mask = PhysicsCollisionSystem.CollisionLayer.PLAYER

	# 将玩家 hurtbox 放在 hitbox 位置（重叠）
	player_area.global_position = Vector3(0, 0, 0)

	# 监听信号
	var signal_monitor := monitor_signals(physics_system)

	# 执行：等待物理帧处理
	await physics_process_frame()

	# 验证：collision_detected 信号被触发（物理层检测到碰撞）
	assert_bool(signal_monitor.is_emitted("collision_detected")).is_true()

	# 注意：无敌帧过滤由命中判定层负责，物理层只负责检测碰撞
	# 这个测试验证物理层在无敌帧期间仍能检测到碰撞


## AC-3: Create + destroy hitbox same frame → no error or residual
## Given: 创建 hitbox
## When: 同一帧销毁
## Then: 不产生错误或残留
func test_create_and_destroy_hitbox_same_frame_no_error() -> void:
	# 准备：创建 hitbox
	var hitbox_shape := BoxShape3D.new()
	hitbox_shape.size = Vector3(1.0, 0.5, 2.0)
	var hitbox_pos := Vector3(0, 0, 0)
	var hitbox_rot := Vector3(0, 0, 0)

	var hitbox_id := physics_system.create_hitbox(player_area, hitbox_shape, hitbox_pos, hitbox_rot)
	assert_int(hitbox_id).is_greater_equal(0)

	# 验证 hitbox 已创建
	assert_bool(physics_system._active_hitboxes.has(hitbox_id)).is_true()

	# 执行：同帧销毁
	physics_system.destroy_hitbox(hitbox_id)

	# 验证：hitbox 标记为待销毁
	var hitbox_data: PhysicsCollisionSystem.HitboxData = physics_system._active_hitboxes[hitbox_id]
	assert_bool(hitbox_data.pending_destroy).is_true()

	# 执行：等待物理帧处理（销毁在物理帧中执行）
	await physics_process_frame()

	# 验证：hitbox 已从活跃列表移除
	assert_bool(physics_system._active_hitboxes.has(hitbox_id)).is_false()

	# 验证：没有错误产生（测试通过即表示无错误）


## 额外测试：hitbox 池上限
func test_hitbox_pool_limit() -> void:
	var hitbox_shape := BoxShape3D.new()
	hitbox_shape.size = Vector3(1.0, 0.5, 2.0)
	var hitbox_pos := Vector3(0, 0, 0)
	var hitbox_rot := Vector3(0, 0, 0)

	# 创建最大数量的 hitbox
	for i in range(PhysicsCollisionSystem.MAX_HITBOXES):
		var hitbox_id := physics_system.create_hitbox(player_area, hitbox_shape, hitbox_pos, hitbox_rot)
		assert_int(hitbox_id).is_greater_equal(0)

	# 尝试创建超出上限的 hitbox
	var overflow_id := physics_system.create_hitbox(player_area, hitbox_shape, hitbox_pos, hitbox_rot)
	assert_int(overflow_id).is_equal(-1)


## 额外测试：raycast 起点=终点返回 null
func test_raycast_same_point_returns_null() -> void:
	var point := Vector3(0, 0, 0)
	var result := physics_system.raycast(point, point, 0xFFFFFFFF)
	assert_object(result).is_null()


## 额外测试：get_hitbox_collisions 返回正确的碰撞列表
func test_get_hitbox_collisions_returns_overlaps() -> void:
	# 创建 hitbox
	var hitbox_shape := SphereShape3D.new()
	(hitbox_shape as SphereShape3D).radius = 1.0
	var hitbox_pos := Vector3(0, 0, 0)
	var hitbox_rot := Vector3(0, 0, 0)

	var hitbox_id := physics_system.create_hitbox(player_area, hitbox_shape, hitbox_pos, hitbox_rot)
	assert_int(hitbox_id).is_greater_equal(0)

	# 配置 hitbox 碰撞层
	var hitbox_data: PhysicsCollisionSystem.HitboxData = physics_system._active_hitboxes[hitbox_id]
	hitbox_data.area.collision_layer = PhysicsCollisionSystem.CollisionLayer.PLAYER_ATTACK
	hitbox_data.area.collision_mask = PhysicsCollisionSystem.CollisionLayer.ENEMY

	# 将敌人放在 hitbox 位置
	enemy_area.global_position = Vector3(0, 0, 0)

	# 等待物理帧更新
	await physics_process_frame()

	# 获取碰撞结果
	var collisions := physics_system.get_hitbox_collisions(hitbox_id)
	assert_int(collisions.size()).is_greater(0)
	assert_object(collisions[0].collider).is_equal(enemy_area.get_parent())


## 额外测试：update_hitbox_transform 更新位置
func test_update_hitbox_transform_updates_position() -> void:
	var hitbox_shape := BoxShape3D.new()
	hitbox_shape.size = Vector3(1.0, 0.5, 2.0)
	var hitbox_pos := Vector3(0, 0, 0)
	var hitbox_rot := Vector3(0, 0, 0)

	var hitbox_id := physics_system.create_hitbox(player_area, hitbox_shape, hitbox_pos, hitbox_rot)
	assert_int(hitbox_id).is_greater_equal(0)

	# 更新位置
	var new_pos := Vector3(5, 0, 0)
	var new_rot := Vector3(0, PI / 4, 0)
	physics_system.update_hitbox_transform(hitbox_id, new_pos, new_rot)

	# 验证位置已更新
	var hitbox_data: PhysicsCollisionSystem.HitboxData = physics_system._active_hitboxes[hitbox_id]
	assert_vector3(hitbox_data.collision_shape.global_position).is_equal(new_pos)
