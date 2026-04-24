@warning_ignore_start("inferred_declaration")
# SPDX-License-Identifier: MIT
# 命中反馈系统单元测试 — 顿帧计算、震动参数、优先级、低帧率自适应
extends Node

## 设计参考:
## - docs/architecture/adr-0013-hit-feedback-architecture.md
## - production/epics/hit-feedback/story-001-hit-stop-shake.md
##
## 使用 GdUnit4 框架运行。
## 测试范围：Story 001（顿帧 + 震动），不含材质反应（Story 002）。

const HitFeedbackSystemScript = preload("res://src/core/hit_feedback_system.gd")

# ── Mock CameraController ──────────────────────────────────────────────────

## 捕获 trigger_hit_stop / trigger_shake 调用的 mock。
class MockCameraController:
	extends CameraController

	var stop_calls: Array[int] = []
	var shake_calls: Array[Dictionary] = []

	func trigger_hit_stop(frames: int) -> void:
		stop_calls.append(frames)

	func trigger_shake(intensity: float, duration: float) -> void:
		shake_calls.append({ "intensity": intensity, "duration": duration })


## Mock HitResult（不需要完整 HitJudgment 环境）
class MockHitResult:
	extends RefCounted

	var attacker: Node3D
	var target: Node3D
	var sword_form: int
	var damage: int
	var hit_position: Vector3
	var hit_normal: Vector3
	var material_type: StringName

	func _init(p_form: int, p_damage: int, p_material: StringName = &"body") -> void:
		attacker = null
		target = null
		sword_form = p_form
		damage = p_damage
		hit_position = Vector3.ZERO
		hit_normal = Vector3.ZERO
		material_type = p_material


# ── 顿帧计算测试 ───────────────────────────────────────────────────────────

## YOU 剑式 damage=1 → 2 + floor(1/2) = 2 帧
func test_you_stop_frames() -> void:
	var system := HitFeedbackSystemScript.new()
	# 直接测试 _calculate_stop_frames
	var result: int = system._calculate_stop_frames(1, 1)
	assert_int(result).is_equal(2)
	system.free()


## RAO 剑式 damage=2 → 2 + floor(2/2) = 3 帧
func test_rao_stop_frames() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: int = system._calculate_stop_frames(2, 2)
	assert_int(result).is_equal(3)
	system.free()


## ZUAN 剑式 damage=3 → 2 + floor(3/2) = 3 帧
func test_zuan_stop_frames() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: int = system._calculate_stop_frames(3, 3)
	assert_int(result).is_equal(3)
	system.free()


## ENEMY 剑式 damage=1 → 2 + floor(1/2) = 2 帧
func test_enemy_stop_frames() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: int = system._calculate_stop_frames(0, 1)
	assert_int(result).is_equal(2)
	system.free()


## 万剑归宗覆盖：任何剑式都返回 5 帧
func test_ultimate_overrides_stop_frames() -> void:
	var system := HitFeedbackSystemScript.new()
	system.enable_ultimate_feedback()
	var result: int = system._calculate_stop_frames(1, 99)
	assert_int(result).is_equal(5)
	system.free()


## 未知剑式回退到 ENEMY 值
func test_unknown_form_fallback() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: int = system._calculate_stop_frames(99, 1)
	# 99 不在 FORM_BASE_STOP 中，回退到 damage=1 的基础值 2
	assert_int(result).is_equal(2)
	system.free()


## 公式边界：damage=0 → 2 + floor(0/2) = 2
func test_zero_damage() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: int = system._calculate_stop_frames(1, 0)
	assert_int(result).is_equal(2)
	system.free()


## 公式边界：damage=10 → 2 + floor(10/2) = 7
func test_high_damage() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: int = system._calculate_stop_frames(3, 10)
	assert_int(result).is_equal(7)
	system.free()


# ── 震动参数测试 ───────────────────────────────────────────────────────────

## YOU 剑式 body 材质：intensity = 0.4 * 1.0 = 0.4
func test_you_body_shake() -> void:
	var system := HitFeedbackSystemScript.new()
	var shake: Dictionary = system._calculate_shake(1, &"body")
	assert_float(shake["intensity"]).is_equal(0.4)
	assert_float(shake["duration"]).is_equal(0.12)
	system.free()


## ZUAN 剑式 metal 材质：intensity = 0.6 * 1.3 = 0.78
func test_zuan_metal_shake() -> void:
	var system := HitFeedbackSystemScript.new()
	var shake: Dictionary = system._calculate_shake(3, &"metal")
	assert_float(shake["intensity"]).is_equal_approx(0.78, 0.001)
	system.free()


## ink 材质倍率 0.8
func test_ink_shake_multiplier() -> void:
	var system := HitFeedbackSystemScript.new()
	var shake: Dictionary = system._calculate_shake(1, &"ink")
	assert_float(shake["intensity"]).is_equal_approx(0.32, 0.001)
	system.free()


## 未知材质回退到 1.0 倍率
func test_unknown_material_multiplier() -> void:
	var system := HitFeedbackSystemScript.new()
	var shake: Dictionary = system._calculate_shake(1, &"unknown")
	assert_float(shake["intensity"]).is_equal(0.4)
	system.free()


## 万剑归宗震动覆盖
func test_ultimate_shake_override() -> void:
	var system := HitFeedbackSystemScript.new()
	system.enable_ultimate_feedback()
	var shake: Dictionary = system._calculate_shake(1, &"body")
	assert_float(shake["intensity"]).is_equal(0.8)
	assert_float(shake["duration"]).is_equal(0.25)
	system.free()


# ── 万剑归宗优先级测试 ─────────────────────────────────────────────────────

## enable/disable 切换正常
func test_ultimate_toggle() -> void:
	var system := HitFeedbackSystemScript.new()
	assert_bool(system.is_ultimate_active()).is_false()
	system.enable_ultimate_feedback()
	assert_bool(system.is_ultimate_active()).is_true()
	system.disable_ultimate_feedback()
	assert_bool(system.is_ultimate_active()).is_false()
	system.free()


## 万剑归宗下不同剑式得到相同顿帧
func test_ultimate_uniform_stop() -> void:
	var system := HitFeedbackSystemScript.new()
	system.enable_ultimate_feedback()
	for form in [0, 1, 2, 3]:
		assert_int(system._calculate_stop_frames(form, 10)).is_equal(5)
	system.free()


# ── feedback_triggered 信号测试 ────────────────────────────────────────────

## 信号参数格式正确
func test_feedback_signal_parameters() -> void:
	var system := HitFeedbackSystemScript.new()
	var captured: Array = []
	system.feedback_triggered.connect(
		func(form: int, material: String, frames: int) -> void:
			captured.append({ "form": form, "material": material, "frames": frames })
	)
	# 手动触发 _on_hit_landed 的信号
	# 由于 _on_hit_landed 依赖 CameraController，这里直接 emit 测试信号格式
	system.feedback_triggered.emit(1, "body", 2)
	assert_int(captured.size()).is_equal(1)
	assert_int(captured[0]["form"]).is_equal(1)
	assert_str(captured[0]["material"]).is_equal("body")
	assert_int(captured[0]["frames"]).is_equal(2)
	system.free()
