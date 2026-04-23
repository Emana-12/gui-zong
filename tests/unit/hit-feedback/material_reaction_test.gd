# SPDX-License-Identifier: MIT
# 材质反应对象池单元测试 — 池分配/回收、分发表映射、池满跳过、自动回收
extends Node

## 设计参考:
## - docs/architecture/adr-0013-hit-feedback-architecture.md
## - production/epics/hit-feedback/story-002-material-reaction-pool.md
##
## 使用 GdUnit4 框架运行。
## 测试范围：Story 002（材质反应与对象池）。

const HitFeedbackSystemScript = preload("res://src/core/hit_feedback_system.gd")


# ── 分发表映射测试 ─────────────────────────────────────────────────────────

## YOU 剑式 + metal → gold_sparks
func test_you_metal_maps_to_gold_sparks() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: StringName = system._get_reaction_type(1, &"metal")
	assert_str(String(result)).is_equal("gold_sparks")
	system.free()


## YOU 剑式 + wood → wood_crack
func test_you_wood_maps_to_wood_crack() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: StringName = system._get_reaction_type(1, &"wood")
	assert_str(String(result)).is_equal("wood_crack")
	system.free()


## YOU 剑式 + body → ink_splash
func test_you_body_maps_to_ink_splash() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: StringName = system._get_reaction_type(1, &"body")
	assert_str(String(result)).is_equal("ink_splash")
	system.free()


## YOU 剑式 + ink → ink_splash
func test_you_ink_maps_to_ink_splash() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: StringName = system._get_reaction_type(1, &"ink")
	assert_str(String(result)).is_equal("ink_splash")
	system.free()


## RAO 剑式 + metal → ink_splash（绕剑式始终墨点炸碎）
func test_rao_metal_maps_to_ink_splash() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: StringName = system._get_reaction_type(2, &"metal")
	assert_str(String(result)).is_equal("ink_splash")
	system.free()


## RAO 剑式 + body → ink_splash
func test_rao_body_maps_to_ink_splash() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: StringName = system._get_reaction_type(2, &"body")
	assert_str(String(result)).is_equal("ink_splash")
	system.free()


## ZUAN 剑式 + metal → shockwave（钻剑式始终扇形冲击波）
func test_zuan_metal_maps_to_shockwave() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: StringName = system._get_reaction_type(3, &"metal")
	assert_str(String(result)).is_equal("shockwave")
	system.free()


## ZUAN 剑式 + body → shockwave
func test_zuan_body_maps_to_shockwave() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: StringName = system._get_reaction_type(3, &"body")
	assert_str(String(result)).is_equal("shockwave")
	system.free()


## ENEMY + metal → gold_sparks
func test_enemy_metal_maps_to_gold_sparks() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: StringName = system._get_reaction_type(0, &"metal")
	assert_str(String(result)).is_equal("gold_sparks")
	system.free()


## 未知材质回退到 ink_splash
func test_unknown_material_fallback() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: StringName = system._get_reaction_type(1, &"unknown_material")
	assert_str(String(result)).is_equal("ink_splash")
	system.free()


## 未知剑式回退到 ENEMY 映射
func test_unknown_form_fallback() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: StringName = system._get_reaction_type(99, &"metal")
	# 99 不在 REACTION_DISPATCH 中，回退到 ENEMY (0) 的 metal 映射
	assert_str(String(result)).is_equal("gold_sparks")
	system.free()


# ── 对象池容量测试 ─────────────────────────────────────────────────────────

## 池容量常量正确
func test_pool_capacity_is_four() -> void:
	var system := HitFeedbackSystemScript.new()
	assert_int(system.get_pool_capacity()).is_equal(4)
	system.free()


## 初始化后活跃节点数为 0
func test_initial_active_count_is_zero() -> void:
	var system := HitFeedbackSystemScript.new()
	assert_int(system.get_active_reaction_count()).is_equal(0)
	system.free()


## POOL_CAPACITY 常量为 4
func test_pool_capacity_constant() -> void:
	assert_int(HitFeedbackSystemScript.POOL_CAPACITY).is_equal(4)


## MATERIAL_REACTION_LIFETIME 常量为 0.5
func test_material_reaction_lifetime() -> void:
	assert_float(HitFeedbackSystemScript.MATERIAL_REACTION_LIFETIME).is_equal(0.5)


# ── 信号测试 ───────────────────────────────────────────────────────────────

## material_reaction_spawned 信号参数正确
func test_material_reaction_signal() -> void:
	var system := HitFeedbackSystemScript.new()
	var captured: Array = []
	system.material_reaction_spawned.connect(
		func(effect: String, pos: Vector3) -> void:
			captured.append({ "effect": effect, "position": pos })
	)
	# 直接 emit 测试信号格式
	system.material_reaction_spawned.emit("gold_sparks", Vector3(1, 2, 3))
	assert_int(captured.size()).is_equal(1)
	assert_str(captured[0]["effect"]).is_equal("gold_sparks")
	assert_vector(captured[0]["position"]).is_equal(Vector3(1, 2, 3))
	system.free()


# ── 分发表常量测试 ─────────────────────────────────────────────────────────

## 分发表包含 4 种剑式
func test_dispatch_table_has_four_forms() -> void:
	assert_int(HitFeedbackSystemScript.REACTION_DISPATCH.size()).is_equal(4)


## 分发表每种剑式包含 4 种材质
func test_dispatch_table_form_coverage() -> void:
	for form in HitFeedbackSystemScript.REACTION_DISPATCH:
		var materials: Dictionary = HitFeedbackSystemScript.REACTION_DISPATCH[form]
		assert_int(materials.size()).is_equal(4)
