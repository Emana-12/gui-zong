@warning_ignore_start("inferred_declaration")
## PhysicsCollisionSystem 性能集成测试
##
## 使用 GDUnit4 框架。
## 覆盖 Story 003: Web Performance 的 AC-1（hitbox 预算）。
## AC-2 (Web 30fps 性能) 需 Web 导出手动验证。
extends GdUnitTestSuite

var _system: PhysicsCollisionSystem


func before_test() -> void:
	_system = auto_free(PhysicsCollisionSystem.new())
	add_child(_system)
	# 等待 _ready 完成（hitbox 池预创建）
	await _system.ready


func after_test() -> void:
	# 清理所有活跃 hitbox
	if _system and is_instance_valid(_system):
		var active_ids: Array = []
		for id in _system._active_hitboxes:
			active_ids.append(id)
		for id in active_ids:
			_system.destroy_hitbox(id)
		# 等待物理帧处理 pending_destroy
		await get_tree().physics_frame


## =========================================================================
## AC-1: hitbox 预算 ≤ 18
## GIVEN 3 player + 10 enemy + 5 environment hitboxes（共 18）
## WHEN 创建全部 hitbox
## THEN 活跃 hitbox 数量 ≤ MAX_HITBOXES (18)
## =========================================================================
func test_hitbox_budget_within_limit() -> void:
	var shape := SphereShape3D.new()
	var owner: Node3D = auto_free(Node3D.new())
	add_child(owner)

	# 创建 18 个 hitbox（池的最大容量）
	var created_ids: Array[int] = []
	for i in range(PhysicsCollisionSystem.MAX_HITBOXES):
		var id = _system.create_hitbox(owner, shape, Vector3(i, 0, 0), Vector3.ZERO)
		assert_int(id).is_greater_equal(0)
		created_ids.append(id)

	assert_int(_system.get_active_hitbox_count()).is_equal(PhysicsCollisionSystem.MAX_HITBOXES)


## =========================================================================
## AC-1 Edge: 超过池容量 → 返回 -1
## GIVEN 池已满（18 个活跃 hitbox）
## WHEN 尝试创建第 19 个
## THEN 返回 -1，活跃数量仍为 18
## =========================================================================
func test_hitbox_budget_overflow_returns_negative() -> void:
	var shape := SphereShape3D.new()
	var owner: Node3D = auto_free(Node3D.new())
	add_child(owner)

	# 填满池
	for i in range(PhysicsCollisionSystem.MAX_HITBOXES):
		_system.create_hitbox(owner, shape, Vector3(i, 0, 0), Vector3.ZERO)

	# 第 19 个应失败
	var overflow_id = _system.create_hitbox(owner, shape, Vector3(99, 0, 0), Vector3.ZERO)
	assert_int(overflow_id).is_equal(-1)
	assert_int(_system.get_active_hitbox_count()).is_equal(PhysicsCollisionSystem.MAX_HITBOXES)


## =========================================================================
## AC-1: 混合碰撞层场景 — 3 player + 10 enemy + 5 attack
## GIVEN 典型战斗场景的 hitbox 分布
## WHEN 全部创建
## THEN 总数 ≤ 18
## =========================================================================
func test_hitbox_budget_mixed_scenario() -> void:
	var shape := SphereShape3D.new()
	var player_owner: Node3D = auto_free(Node3D.new())
	var enemy_owner: Node3D = auto_free(Node3D.new())
	var attack_owner: Node3D = auto_free(Node3D.new())
	add_child(player_owner)
	add_child(enemy_owner)
	add_child(attack_owner)

	var created_ids: Array[int] = []

	# 3 player hitboxes
	for i in range(3):
		var id = _system.create_hitbox(player_owner, shape, Vector3(i, 0, 0), Vector3.ZERO)
		created_ids.append(id)

	# 10 enemy hitboxes
	for i in range(10):
		var id = _system.create_hitbox(enemy_owner, shape, Vector3(i, 1, 0), Vector3.ZERO)
		created_ids.append(id)

	# 5 attack hitboxes
	for i in range(5):
		var id = _system.create_hitbox(attack_owner, shape, Vector3(i, 2, 0), Vector3.ZERO)
		created_ids.append(id)

	assert_int(_system.get_active_hitbox_count()).is_equal(PhysicsCollisionSystem.MAX_HITBOXES)
	assert_int(created_ids.size()).is_equal(PhysicsCollisionSystem.MAX_HITBOXES)

	# 所有 ID 有效
	for id in created_ids:
		assert_int(id).is_greater_equal(0)


## =========================================================================
## AC-1: 销毁后释放容量
## GIVEN 18 个活跃 hitbox
## WHEN 销毁 5 个
## THEN get_active_hitbox_count() == 13, get_remaining_hitbox_capacity() == 5
## =========================================================================
func test_hitbox_destroy_frees_capacity() -> void:
	var shape := SphereShape3D.new()
	var owner: Node3D = auto_free(Node3D.new())
	add_child(owner)

	var created_ids: Array[int] = []
	for i in range(PhysicsCollisionSystem.MAX_HITBOXES):
		var id = _system.create_hitbox(owner, shape, Vector3(i, 0, 0), Vector3.ZERO)
		created_ids.append(id)

	# 销毁前 5 个
	for i in range(5):
		_system.destroy_hitbox(created_ids[i])

	# 等待物理帧处理 pending_destroy
	await get_tree().physics_frame

	assert_int(_system.get_active_hitbox_count()).is_equal(PhysicsCollisionSystem.MAX_HITBOXES - 5)
	assert_int(_system.get_remaining_hitbox_capacity()).is_equal(5)

	# 确认可以重新创建
	var new_id = _system.create_hitbox(owner, shape, Vector3(100, 0, 0), Vector3.ZERO)
	assert_int(new_id).is_greater_equal(0)
	assert_int(_system.get_active_hitbox_count()).is_equal(PhysicsCollisionSystem.MAX_HITBOXES - 5 + 1)


## =========================================================================
## AC-1: 池回收复用
## GIVEN 销毁后的 hitbox 池
## WHEN 重新创建
## THEN 复用池中的空闲槽位
## =========================================================================
func test_hitbox_pool_reuse() -> void:
	var shape := SphereShape3D.new()
	var owner: Node3D = auto_free(Node3D.new())
	add_child(owner)

	# 创建 3 个并全部销毁
	var ids: Array[int] = []
	for i in range(3):
		ids.append(_system.create_hitbox(owner, shape, Vector3(i, 0, 0), Vector3.ZERO))
	for id in ids:
		_system.destroy_hitbox(id)

	await get_tree().physics_frame

	# 重新创建 — 应复用池中的槽位
	var new_id = _system.create_hitbox(owner, shape, Vector3.ZERO, Vector3.ZERO)
	assert_int(new_id).is_greater_equal(0)
	assert_int(_system.get_active_hitbox_count()).is_equal(1)


## =========================================================================
## AC-2: Web 30fps 性能
## DEFERRED — 需 Web 导出后手动验证。
## 本地测试无法模拟 Web 端 30fps 限制。
## 性能监控方法 get_active_hitbox_count() 已提供，供 Web 端帧率监测使用。
## =========================================================================
