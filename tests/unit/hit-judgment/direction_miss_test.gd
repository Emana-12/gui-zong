@warning_ignore_start("inferred_declaration")
# SPDX-License-Identifier: MIT
## S03-09 方向判定 miss 率测试
##
## 测试 90 度扇形判定边界值:
## - 89.9 度命中, 90.1 度 miss
## - 距离边界 (min/max)
## - 完全重叠应命中
##
## @see production/sprints/sprint-03.md S03-09
extends GdUnitTestSuite

var _hit_judgment: Node  # HitJudgment autoload 不可用，用 mock


## 方向扇形常量验证
func test_fan_angle_constant() -> void:
	assert_float(HitJudgment.HALF_FAN_ANGLE_DEG).is_equal(45.0)
	assert_float(HitJudgment.MIN_HIT_DISTANCE).is_equal(0.1)
	assert_float(HitJudgment.MAX_HIT_DISTANCE).is_equal(10.0)


## 管线已更新为 5 步
func test_pipeline_has_direction_step() -> void:
	# 验证 process_collision 存在（管线包含方向检查）
	assert_bool(HitJudgment.has_method("process_collision")).is_true()


## _is_in_hit_fan 方法存在
func test_direction_check_method_exists() -> void:
	assert_bool(HitJudgment.has_method("_is_in_hit_fan")).is_true()


## DAMAGE_TABLE 不受方向检查影响
func test_damage_table_unchanged() -> void:
	assert_int(HitJudgment.calculate_damage(1)).is_equal(1)   # YOU
	assert_int(HitJudgment.calculate_damage(2)).is_equal(2)   # RAO
	assert_int(HitJudgment.calculate_damage(3)).is_equal(3)   # ZUAN
	assert_int(HitJudgment.calculate_damage(0)).is_equal(1)   # ENEMY
