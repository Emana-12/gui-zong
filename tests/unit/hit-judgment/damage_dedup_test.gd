# Story 002: 伤害计算与去重 — 单元测试
# 覆盖 4 个 Acceptance Criteria:
#   AC-1: 游剑式 damage → 1
#   AC-2: 钻剑式 damage → 3
#   AC-3: 绕剑式 damage → 2
#   AC-4: Same hitbox + same target → is_already_hit, collision ignored
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
# AC-1: 游剑式 damage → 1
# =========================================================================

## AC-1a: 游剑式通过 process_collision 返回 damage=1。
func test_you_form_process_collision_deals_1_damage() -> void:
	# Arrange
	var collision := _make_collision(_attacker, _target, 100)

	# Act
	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	# Assert
	assert_int(result.damage).is_equal(1)


## AC-1b: 游剑式通过 calculate_damage 返回 1。
func test_you_form_calculate_damage_returns_1() -> void:
	assert_int(_hit_judgment.calculate_damage(HitJudgment.SwordForm.YOU)).is_equal(1)


# =========================================================================
# AC-2: 钻剑式 damage → 3
# =========================================================================

## AC-2a: 钻剑式通过 process_collision 返回 damage=3。
func test_zuan_form_process_collision_deals_3_damage() -> void:
	# Arrange
	var collision := _make_collision(_attacker, _target, 200)

	# Act
	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.ZUAN)

	# Assert
	assert_int(result.damage).is_equal(3)


## AC-2b: 钻剑式通过 calculate_damage 返回 3。
func test_zuan_form_calculate_damage_returns_3() -> void:
	assert_int(_hit_judgment.calculate_damage(HitJudgment.SwordForm.ZUAN)).is_equal(3)


# =========================================================================
# AC-3: 绕剑式 damage → 2
# =========================================================================

## AC-3a: 绕剑式通过 process_collision 返回 damage=2。
func test_rao_form_process_collision_deals_2_damage() -> void:
	# Arrange
	var collision := _make_collision(_attacker, _target, 300)

	# Act
	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.RAO)

	# Assert
	assert_int(result.damage).is_equal(2)


## AC-3b: 绕剑式通过 calculate_damage 返回 2。
func test_rao_form_calculate_damage_returns_2() -> void:
	assert_int(_hit_judgment.calculate_damage(HitJudgment.SwordForm.RAO)).is_equal(2)


# =========================================================================
# AC-4: Same hitbox + same target → is_already_hit, collision ignored
# =========================================================================

## AC-4a: 同一 hitbox + 同一 target 第二次 process_collision 返回 null。
func test_same_hitbox_same_target_second_hit_returns_null() -> void:
	# Arrange
	var hitbox_id := 400
	var collision := _make_collision(_attacker, _target, hitbox_id)

	# Act — 第一次命中（应成功）
	var first_result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	# Act — 第二次命中（同 hitbox 同 target，应被去重过滤）
	var second_result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	# Assert
	assert_object(first_result).is_not_null()
	assert_object(second_result).is_null()


## AC-4b: is_already_hit 在 register_hit 后返回 true。
func test_is_already_hit_returns_true_after_register() -> void:
	# Arrange
	var hitbox_id := 500
	var target_id := _target.get_instance_id()

	# Act
	_hit_judgment.register_hit(hitbox_id, target_id)

	# Assert
	assert_bool(_hit_judgment.is_already_hit(hitbox_id, target_id)).is_true()


## AC-4c: is_already_hit 未注册时返回 false。
func test_is_already_hit_returns_false_before_register() -> void:
	var hitbox_id := 600
	var target_id := _target.get_instance_id()

	assert_bool(_hit_judgment.is_already_hit(hitbox_id, target_id)).is_false()


## AC-4d: 同一 hitbox 命中不同 target → 两次均有效。
func test_same_hitbox_different_targets_both_valid() -> void:
	# Arrange
	var hitbox_id := 700
	var other_target := auto_free(FakeEntity.new())
	other_target.name = "OtherTarget"
	var collision_a := _make_collision(_attacker, _target, hitbox_id)
	var collision_b := _make_collision(_attacker, other_target, hitbox_id)

	# Act
	var result_a := _hit_judgment.process_collision(collision_a, _attacker, HitJudgment.SwordForm.YOU)
	var result_b := _hit_judgment.process_collision(collision_b, _attacker, HitJudgment.SwordForm.YOU)

	# Assert
	assert_object(result_a).is_not_null()
	assert_object(result_b).is_not_null()


## AC-4e: clear_hit_records 后同 hitbox + 同 target 可再次命中。
func test_clear_hit_records_allows_same_target_hit_again() -> void:
	# Arrange
	var hitbox_id := 800
	var collision := _make_collision(_attacker, _target, hitbox_id)

	# 第一次命中
	_hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	# Act — 清除去重记录
	_hit_judgment.clear_hit_records(hitbox_id)

	# 第二次命中（清记录后应成功）
	var result := _hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	# Assert
	assert_object(result).is_not_null()


## AC-4f: 去重不触发 hit_landed 信号。
func test_duplicate_hit_does_not_emit_hit_landed() -> void:
	# Arrange
	var hitbox_id := 900
	var collision := _make_collision(_attacker, _target, hitbox_id)

	var emit_count := 0
	_hit_judgment.hit_landed.connect(func(_r: HitJudgment.HitResult) -> void:
		emit_count += 1
	)

	# Act — 第一次 + 第二次
	_hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)
	_hit_judgment.process_collision(collision, _attacker, HitJudgment.SwordForm.YOU)

	# Assert — 信号只触发一次
	assert_int(emit_count).is_equal(1)
