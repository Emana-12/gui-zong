@warning_ignore_start("inferred_declaration")
# 命中判定系统单元测试
# 覆盖 Story 001 的 4 个 Acceptance Criteria
extends GdUnitTestSuite

var _hit_judgment: HitJudgment
var _attacker: FakeEntity
var _target: FakeEntity


func before_test() -> void:
	_hit_judgment = auto_free(HitJudgment.new())
	_attacker = auto_free(FakeEntity.new())
	_target = auto_free(FakeEntity.new())
	_attacker.name = "Attacker"
	_target.name = "Target"


func after_test() -> void:
	_hit_judgment._hit_registry.clear()
	_hit_judgment._last_hit = null


# =========================================================================
# Fake 辅助类
# =========================================================================

## 模拟实体 — 可配置无敌状态和节点组。
class FakeEntity extends Node3D:
	var _invincible: bool = false
	var _groups: Array[StringName] = []

	func is_invincible() -> bool:
		return _invincible

	func set_invincible(value: bool) -> void:
		_invincible = value

	func set_groups(groups: Array[StringName]) -> void:
		_groups = groups

	func is_in_group(group: StringName) -> bool:
		return group in _groups


# =========================================================================
# 辅助方法
# =========================================================================

## 创建一个 CollisionResult 测试夹具。
func _make_collision(attacker: Node3D, target: Node3D,
		hitbox_id: int = 0) -> CollisionResult:
	return CollisionResult.new(
		Vector3(1, 0, 0),        # hit_position
		Vector3(0, 1, 0),        # hit_normal
		target,                  # collider
		target.get_instance_id(),# collider_id
		hitbox_id                # hitbox_id
	)


# =========================================================================
# AC-1: Collision + not invincible → valid HitResult
# =========================================================================

## AC-1a: 非无敌目标被命中 → 返回非 null HitResult。
func test_valid_hit_returns_hit_result() -> void:
	# Arrange
	_target.set_invincible(false)
	var collision := _make_collision(_attacker, _target)

	# Act
	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	# Assert
	assert_object(result).is_not_null()


## AC-1b: HitResult 字段正确。
func test_valid_hit_result_has_correct_fields() -> void:
	_target.set_invincible(false)
	var collision := _make_collision(_attacker, _target)

	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	assert_object(result.attacker).is_equal(_attacker)
	assert_object(result.target).is_equal(_target)
	assert_int(result.sword_form).is_equal(HitJudgment.SwordForm.YOU)
	assert_int(result.damage).is_equal(1)
	assert_vector3(result.hit_position).is_equal(Vector3(1, 0, 0))
	assert_vector3(result.hit_normal).is_equal(Vector3(0, 1, 0))


## AC-1c: 各剑招伤害值正确。
func test_you_form_deals_1_damage() -> void:
	var collision := _make_collision(_attacker, _target)
	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)
	assert_int(result.damage).is_equal(1)


func test_zuan_form_deals_3_damage() -> void:
	var collision := _make_collision(_attacker, _target, 1)
	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.ZUAN)
	assert_int(result.damage).is_equal(3)


func test_rao_form_deals_2_damage() -> void:
	var collision := _make_collision(_attacker, _target, 2)
	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.RAO)
	assert_int(result.damage).is_equal(2)


func test_enemy_form_deals_1_damage() -> void:
	var collision := _make_collision(_attacker, _target, 3)
	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.ENEMY)
	assert_int(result.damage).is_equal(1)


## AC-1d: 材质类型检测正确（body 组）。
func test_material_type_body_detected() -> void:
	_target.set_groups([&"enemies"])
	var collision := _make_collision(_attacker, _target, 4)

	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	assert_that(result.material_type).is_equal(&"body")


## AC-1e: 金属材质检测。
func test_material_type_metal_detected() -> void:
	_target.set_groups([&"environment_metal"])
	var collision := _make_collision(_attacker, _target, 5)

	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	assert_that(result.material_type).is_equal(&"metal")


## AC-1f: 无匹配组时回退到 body。
func test_material_type_defaults_to_body() -> void:
	_target.set_groups([])
	var collision := _make_collision(_attacker, _target, 6)

	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	assert_that(result.material_type).is_equal(&"body")


# =========================================================================
# AC-2: Collision + is_invincible()=true → null
# =========================================================================

## AC-2a: 无敌目标被命中 → 返回 null。
func test_invincible_target_returns_null() -> void:
	# Arrange
	_target.set_invincible(true)
	var collision := _make_collision(_attacker, _target, 10)

	# Act
	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	# Assert
	assert_object(result).is_null()


## AC-2b: 无敌目标命中触发 hit_blocked 信号。
func test_invincible_target_emits_hit_blocked() -> void:
	_target.set_invincible(true)
	var collision := _make_collision(_attacker, _target, 11)

	var blocked_emitted := false
	var blocked_result: HitJudgment.HitResult = null
	_hit_judgment.hit_blocked.connect(func(r: HitJudgment.HitResult) -> void:
		blocked_emitted = true
		blocked_result = r
	)

	_hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	assert_bool(blocked_emitted).is_true()
	assert_object(blocked_result).is_not_null()
	assert_object(blocked_result.target).is_equal(_target)


## AC-2c: 无敌目标命中不触发 hit_landed 信号。
func test_invincible_target_does_not_emit_hit_landed() -> void:
	_target.set_invincible(true)
	var collision := _make_collision(_attacker, _target, 12)

	var landed_emitted := false
	_hit_judgment.hit_landed.connect(func(_r: HitJudgment.HitResult) -> void:
		landed_emitted = true
	)

	_hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	assert_bool(landed_emitted).is_false()


# =========================================================================
# AC-3: attacker=target → null
# =========================================================================

## AC-3a: 自伤碰撞 → 返回 null。
func test_self_hit_returns_null() -> void:
	# Arrange
	_attacker.set_invincible(false)
	var collision := _make_collision(_attacker, _attacker, 20)

	# Act
	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	# Assert
	assert_object(result).is_null()


## AC-3b: 自伤碰撞不触发 hit_landed。
func test_self_hit_does_not_emit_hit_landed() -> void:
	var collision := _make_collision(_attacker, _attacker, 21)

	var landed_emitted := false
	_hit_judgment.hit_landed.connect(func(_r: HitJudgment.HitResult) -> void:
		landed_emitted = true
	)

	_hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	assert_bool(landed_emitted).is_false()


# =========================================================================
# AC-4: hit_landed signal with full HitResult data
# =========================================================================

## AC-4a: 有效命中触发 hit_landed 信号。
func test_valid_hit_emits_hit_landed() -> void:
	_target.set_invincible(false)
	var collision := _make_collision(_attacker, _target, 30)

	var landed_emitted := false
	_hit_judgment.hit_landed.connect(func(_r: HitJudgment.HitResult) -> void:
		landed_emitted = true
	)

	_hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	assert_bool(landed_emitted).is_true()


## AC-4b: hit_landed 信号携带完整的 HitResult（7 个字段）。
func test_hit_landed_signal_carries_full_data() -> void:
	_target.set_groups([&"enemies"])
	var collision := _make_collision(_attacker, _target, 31)

	var received_result: HitJudgment.HitResult = null
	_hit_judgment.hit_landed.connect(func(r: HitJudgment.HitResult) -> void:
		received_result = r
	)

	_hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.ZUAN)

	assert_object(received_result).is_not_null()
	assert_object(received_result.attacker).is_equal(_attacker)
	assert_object(received_result.target).is_equal(_target)
	assert_int(received_result.sword_form).is_equal(HitJudgment.SwordForm.ZUAN)
	assert_int(received_result.damage).is_equal(3)
	assert_vector3(received_result.hit_position).is_equal(Vector3(1, 0, 0))
	assert_vector3(received_result.hit_normal).is_equal(Vector3(0, 1, 0))
	assert_that(received_result.material_type).is_equal(&"body")


# =========================================================================
# 去重测试
# =========================================================================

## 同一 hitbox 命中同一目标两次 → 第二次返回 null。
func test_duplicate_hit_returns_null() -> void:
	var collision := _make_collision(_attacker, _target, 40)

	# 第一次命中
	_hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	# 第二次命中（同 hitbox 同 target）
	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	assert_object(result).is_null()


## 清除去重记录后可再次命中。
func test_clear_hit_records_allows_second_hit() -> void:
	var hitbox_id := 50
	var collision := _make_collision(_attacker, _target, hitbox_id)

	_hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)
	_hit_judgment.clear_hit_records(hitbox_id)

	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	assert_object(result).is_not_null()


## 不同 hitbox 命中同一目标 → 均有效。
func test_different_hitboxes_can_hit_same_target() -> void:
	var collision_a := _make_collision(_attacker, _target, 60)
	var collision_b := _make_collision(_attacker, _target, 61)

	var result_a := _hit_judgment.process_collision(collision_a, _attacker, HitJudgment.SwordForm.YOU)
	var result_b := _hit_judgment.process_collision(collision_b, _attacker, HitJudgment.SwordForm.YOU)

	assert_object(result_a).is_not_null()
	assert_object(result_b).is_not_null()


# =========================================================================
# API 测试
# =========================================================================

## get_last_hit 返回最近一次有效命中。
func test_get_last_hit_returns_most_recent() -> void:
	var collision := _make_collision(_attacker, _target, 70)
	assert_object(_hit_judgment.get_last_hit()).is_null()

	_hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.RAO)

	var last := _hit_judgment.get_last_hit()
	assert_object(last).is_not_null()
	assert_int(last.sword_form).is_equal(HitJudgment.SwordForm.RAO)
	assert_int(last.damage).is_equal(2)


## calculate_damage 返回正确的基础伤害。
func test_calculate_damage_returns_correct_values() -> void:
	assert_int(_hit_judgment.calculate_damage(HitJudgment.SwordForm.YOU)).is_equal(1)
	assert_int(_hit_judgment.calculate_damage(HitJudgment.SwordForm.ZUAN)).is_equal(3)
	assert_int(_hit_judgment.calculate_damage(HitJudgment.SwordForm.RAO)).is_equal(2)
	assert_int(_hit_judgment.calculate_damage(HitJudgment.SwordForm.ENEMY)).is_equal(1)


## register_hit / is_already_hit 正常工作。
func test_register_and_check_hit() -> void:
	var hitbox_id := 80
	var target_id := _target.get_instance_id()

	assert_bool(_hit_judgment.is_already_hit(hitbox_id, target_id)).is_false()

	_hit_judgment.register_hit(hitbox_id, target_id)

	assert_bool(_hit_judgment.is_already_hit(hitbox_id, target_id)).is_true()
