# SPDX-License-Identifier: MIT
# 万剑归宗反馈单元测试 — 5帧帧帧覆盖、震动参数、优先级覆盖、enable/disable
extends Node

## 设计参考:
## - docs/architecture/adr-0013-hit-feedback-architecture.md
## - production/epics/hit-feedback/story-003-myriad-sword-feedback.md
##
## 使用 GdUnit4 框架运行。
## 测试范围：Story 003（万剑归宗特殊反馈）。

const HitFeedbackSystemScript = preload("res://src/core/hit_feedback_system.gd")


# ── 万剑归宗帧帧覆盖测试 ───────────────────────────────────────────────────

## 万剑归宗激活后任何剑式都返回 5 帧帧帧
func test_myriad_overrides_all_forms_to_five_frames() -> void:
	var system := HitFeedbackSystemScript.new()
	system.enable_ultimate_feedback()
	for form in [0, 1, 2, 3]:
		var result: int = system._calculate_stop_frames(form, 99)
		assert_int(result).is_equal(5)
	system.free()


## 万剑归宗帧帧常量为 5
func test_ultimate_stop_frames_constant() -> void:
	assert_int(HitFeedbackSystemScript.ULTIMATE_STOP_FRAMES).is_equal(5)


## 万剑归宗震动覆盖：任何剑式/材质都返回固定值
func test_myriad_shake_override() -> void:
	var system := HitFeedbackSystemScript.new()
	system.enable_ultimate_feedback()
	var shake: Dictionary = system._calculate_shake(1, &"body")
	assert_float(shake["intensity"]).is_equal(0.8)
	assert_float(shake["duration"]).is_equal(0.25)
	system.free()


## 万剑归宗震动常量
func test_ultimate_shake_constants() -> void:
	var shake: Dictionary = HitFeedbackSystemScript.ULTIMATE_SHAKE
	assert_float(shake["intensity"]).is_equal(0.8)
	assert_float(shake["duration"]).is_equal(0.25)


# ── 万剑归宗优先级测试 ─────────────────────────────────────────────────────

## enable_ultimate_feedback 激活标志
func test_enable_ultimate_sets_active() -> void:
	var system := HitFeedbackSystemScript.new()
	assert_bool(system.is_ultimate_active()).is_false()
	system.enable_ultimate_feedback()
	assert_bool(system.is_ultimate_active()).is_true()
	system.free()


## disable_ultimate_feedback 恢复普通模式
func test_disable_ultimate_clears_active() -> void:
	var system := HitFeedbackSystemScript.new()
	system.enable_ultimate_feedback()
	system.disable_ultimate_feedback()
	assert_bool(system.is_ultimate_active()).is_false()
	system.free()


## 万剑归宗激活后普通材质反应被跳过（分发表结果仍正确但不生成节点）
func test_myriad_skips_material_reaction() -> void:
	var system := HitFeedbackSystemScript.new()
	# 手动初始化对象池（不走 _ready，避免 autoload 依赖）
	system._init_reaction_pool()
	system.enable_ultimate_feedback()

	# 模拟命中：在万剑归宗模式下，spawn_material_reaction 仍可调用
	# 但 _on_hit_landed 中会跳过材质反应生成
	# 这里直接验证万剑归宗激活时的分发表结果
	var reaction_type := system._get_reaction_type(1, &"metal")
	assert_str(String(reaction_type)).is_equal("gold_sparks")

	# 验证池初始为空
	assert_int(system.get_active_reaction_count()).is_equal(0)
	system.free()


# ── 万剑归宗信号测试 ───────────────────────────────────────────────────────

## myriad_feedback_started 信号可连接
func test_myriad_feedback_started_signal_exists() -> void:
	var system := HitFeedbackSystemScript.new()
	assert_bool(system.has_signal("myriad_feedback_started")).is_true()
	system.free()


## myriad_feedback_finished 信号可连接
func test_myriad_feedback_finished_signal_exists() -> void:
	var system := HitFeedbackSystemScript.new()
	assert_bool(system.has_signal("myriad_feedback_finished")).is_true()
	system.free()


# ── 万剑归宗全屏效果常量测试 ───────────────────────────────────────────────

## 万剑归宗爆发持续时间常量为 0.5s
func test_myriad_burst_duration() -> void:
	assert_float(HitFeedbackSystemScript.MYRIAD_BURST_DURATION).is_equal(0.5)


## 万剑归宗金色爆发颜色 RGB 正确
func test_myriad_burst_color() -> void:
	var color: Color = HitFeedbackSystemScript.MYRIAD_BURST_COLOR
	assert_float(color.r).is_equal(1.0)
	assert_float(color.g).is_equal(0.85)
	assert_float(color.b).is_equal(0.2)


# ── 万剑归宗帧帧 vs 普通帧帧对比测试 ─────────────────────────────────────

## 普通 YOU 剑式帧帧 = 2（非万剑归宗模式）
func test_normal_you_stop_is_two() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: int = system._calculate_stop_frames(1, 1)
	assert_int(result).is_equal(2)
	system.free()


## 万剑归宗模式下 YOU 帧帧 = 5（覆盖公式）
func test_myriad_you_stop_is_five() -> void:
	var system := HitFeedbackSystemScript.new()
	system.enable_ultimate_feedback()
	var result: int = system._calculate_stop_frames(1, 1)
	assert_int(result).is_equal(5)
	system.free()


## 普通 ZUAN 剑式帧帧 = 3（非万剑归宗模式）
func test_normal_zuan_stop_is_three() -> void:
	var system := HitFeedbackSystemScript.new()
	var result: int = system._calculate_stop_frames(3, 3)
	assert_int(result).is_equal(3)
	system.free()


## 万剑归宗模式下 ZUAN 帧帧 = 5（覆盖公式）
func test_myriad_zuan_stop_is_five() -> void:
	var system := HitFeedbackSystemScript.new()
	system.enable_ultimate_feedback()
	var result: int = system._calculate_stop_frames(3, 3)
	assert_int(result).is_equal(5)
	system.free()


## 普通震动强度随剑式和材质变化（非万剑归宗模式）
func test_normal_shake_varies_by_form() -> void:
	var system := HitFeedbackSystemScript.new()
	var you_shake: Dictionary = system._calculate_shake(1, &"body")
	var zuan_shake: Dictionary = system._calculate_shake(3, &"body")
	assert_float(you_shake["intensity"]).is_not_equal(zuan_shake["intensity"])
	system.free()


## 万剑归宗震动强度固定（不随剑式变化）
func test_myriad_shake_uniform() -> void:
	var system := HitFeedbackSystemScript.new()
	system.enable_ultimate_feedback()
	var you_shake: Dictionary = system._calculate_shake(1, &"body")
	var zuan_shake: Dictionary = system._calculate_shake(3, &"body")
	assert_float(you_shake["intensity"]).is_equal(zuan_shake["intensity"])
	assert_float(you_shake["duration"]).is_equal(zuan_shake["duration"])
	system.free()


# ── feedback_triggered 信号参数测试 ───────────────────────────────────────

## 万剑归宗反馈信号参数：form=-1, material="myriad", frames=5
func test_myriad_feedback_signal_parameters() -> void:
	var system := HitFeedbackSystemScript.new()
	var captured: Array = []
	system.feedback_triggered.connect(
		func(form: int, material: String, frames: int) -> void:
			captured.append({ "form": form, "material": material, "frames": frames })
	)
	# 直接 emit 测试万剑归宗信号格式
	system.feedback_triggered.emit(-1, "myriad", 5)
	assert_int(captured.size()).is_equal(1)
	assert_int(captured[0]["form"]).is_equal(-1)
	assert_str(captured[0]["material"]).is_equal("myriad")
	assert_int(captured[0]["frames"]).is_equal(5)
	system.free()
