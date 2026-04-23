@warning_ignore_start("inferred_declaration")
## switching_cooldown_test.gd — ThreeFormsCombat 式切换与冷却测试
##
## 覆盖 story-002-switching-cooldown 全部 4 个 AC
extends GdUnitTestSuite

var _combat: ThreeFormsCombat
var _physics_system: PhysicsCollisionSystem


func before_test() -> void:
	_physics_system = auto_free(PhysicsCollisionSystem.new())
	_physics_system.name = "PhysicsCollisionSystem"
	add_child(_physics_system)

	_combat = auto_free(ThreeFormsCombat.new())
	_combat.name = "ThreeFormsCombat"
	var owner_node: Node3D = auto_free(Node3D.new())
	owner_node.name = "Owner"
	add_child(owner_node)
	_combat.owner = owner_node
	add_child(_combat)


func after_test() -> void:
	_combat.cancel_current()


# ──────────────────────────────────────────────
# AC-1: EXECUTING → 新式输入被忽略
# ──────────────────────────────────────────────

## 执行中不可打断 — YOU 执行中输入 ZUAN 被忽略
func test_execute_during_executing_ignored() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	var result: bool = _combat.execute_form(ThreeFormsCombat.Form.ZUAN)
	assert_bool(result).is_false()


## 执行中不可打断 — 保持原剑式不变
func test_execute_during_executing_keeps_original_form() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	_combat.execute_form(ThreeFormsCombat.Form.ZUAN)  # 被忽略
	assert_int(_combat.get_active_form()).is_equal(ThreeFormsCombat.Form.YOU)


## 执行中不可打断 — RAO 执行中输入 YOU 被忽略
func test_execute_rao_during_executing_ignored() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.RAO)
	var result: bool = _combat.execute_form(ThreeFormsCombat.Form.YOU)
	assert_bool(result).is_false()


# ──────────────────────────────────────────────
# AC-2: RECOVERING → 新式输入取消恢复，切换到新式
# ──────────────────────────────────────────────

## RECOVERING 中可打断 — 成功返回 true
func test_execute_during_recovering_succeeds() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	_combat._test_advance_phase()  # EXECUTING → RECOVERING
	assert_bool(_combat.is_executing()).is_false()
	var result: bool = _combat.execute_form(ThreeFormsCombat.Form.ZUAN)
	assert_bool(result).is_true()


## RECOVERING 中可打断 — 切换到新剑式
func test_execute_during_recovering_switches_form() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	_combat._test_advance_phase()  # EXECUTING → RECOVERING
	_combat.execute_form(ThreeFormsCombat.Form.ZUAN)
	assert_int(_combat.get_active_form()).is_equal(ThreeFormsCombat.Form.ZUAN)


## RECOVERING 中可打断 — 新式进入 EXECUTING
func test_execute_during_recovering_enters_executing() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.RAO)
	_combat._test_advance_phase()  # EXECUTING → RECOVERING
	_combat.execute_form(ThreeFormsCombat.Form.ZUAN)
	assert_bool(_combat.is_executing()).is_true()


## RECOVERING 中打断 — form_activated 信号发出
func test_execute_during_recovering_emits_form_activated() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	_combat._test_advance_phase()  # EXECUTING → RECOVERING
	var monitor := await monitor_signals(_combat)
	_combat.execute_form(ThreeFormsCombat.Form.ZUAN)
	await assert_signal(monitor).is_emitted("form_activated", [ThreeFormsCombat.Form.ZUAN])


# ──────────────────────────────────────────────
# AC-3: 同式冷却中 → 输入被忽略
# ──────────────────────────────────────────────

## 同式冷却中输入被忽略
func test_execute_on_cooldown_returns_false() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	_combat._test_advance_phase()  # EXECUTING → RECOVERING
	_combat._test_advance_phase()  # RECOVERING → COOLDOWN
	assert_bool(_combat.is_on_cooldown(ThreeFormsCombat.Form.YOU)).is_true()
	var result: bool = _combat.execute_form(ThreeFormsCombat.Form.YOU)
	assert_bool(result).is_false()


## 冷却中 is_on_cooldown 返回 true
func test_is_on_cooldown_true_after_cooldown_entry() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.ZUAN)
	_combat._test_advance_phase()  # EXECUTING → RECOVERING
	_combat._test_advance_phase()  # RECOVERING → COOLDOWN
	assert_bool(_combat.is_on_cooldown(ThreeFormsCombat.Form.ZUAN)).is_true()


## 非冷却中 is_on_cooldown 返回 false
func test_is_on_cooldown_false_for_unused_form() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	assert_bool(_combat.is_on_cooldown(ThreeFormsCombat.Form.ZUAN)).is_false()


# ──────────────────────────────────────────────
# AC-4: 不同式未冷却 → 正常执行
# ──────────────────────────────────────────────

## 不同式未冷却正常执行 — YOU 冷却中 ZUAN 可执行
func test_different_form_not_on_cooldown_executes() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	_combat._test_advance_phase()  # EXECUTING → RECOVERING
	_combat._test_advance_phase()  # RECOVERING → COOLDOWN (YOU 冷却中)
	var result: bool = _combat.execute_form(ThreeFormsCombat.Form.ZUAN)
	assert_bool(result).is_true()


## 不同式未冷却正常执行 — 切换到新式
func test_different_form_switches_active_form() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	_combat._test_advance_phase()  # EXECUTING → RECOVERING
	_combat._test_advance_phase()  # RECOVERING → COOLDOWN
	_combat.execute_form(ThreeFormsCombat.Form.RAO)
	assert_int(_combat.get_active_form()).is_equal(ThreeFormsCombat.Form.RAO)


## 独立冷却 — RAO 冷却中 ZUAN 可执行
func test_independent_cooldown_rao_zuan() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.RAO)
	_combat._test_advance_phase()  # EXECUTING → RECOVERING
	_combat._test_advance_phase()  # RECOVERING → COOLDOWN (RAO 冷却中)
	assert_bool(_combat.is_on_cooldown(ThreeFormsCombat.Form.RAO)).is_true()
	assert_bool(_combat.is_on_cooldown(ThreeFormsCombat.Form.ZUAN)).is_false()
	var result: bool = _combat.execute_form(ThreeFormsCombat.Form.ZUAN)
	assert_bool(result).is_true()


# ──────────────────────────────────────────────
# 边界测试
# ──────────────────────────────────────────────

## RECOVERING 中打断后完整执行新式流程
func test_recovering_interrupt_full_lifecycle() -> void:
	# RAO 执行中 → 进入 RECOVERING
	_combat.execute_form(ThreeFormsCombat.Form.RAO)
	_combat._test_advance_phase()  # EXECUTING → RECOVERING
	# ZUAN 打断 RECOVERING
	_combat.execute_form(ThreeFormsCombat.Form.ZUAN)
	assert_bool(_combat.is_executing()).is_true()
	# ZUAN 完整生命周期
	_combat._test_advance_phase()  # EXECUTING → RECOVERING
	_combat._test_advance_phase()  # RECOVERING → COOLDOWN
	assert_bool(_combat.is_on_cooldown(ThreeFormsCombat.Form.ZUAN)).is_true()


## 冷却过期后可重新执行
func test_cooldown_expires_allows_reexecute() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	_combat._test_advance_phase()  # EXECUTING → RECOVERING
	_combat._test_advance_phase()  # RECOVERING → COOLDOWN
	# 模拟冷却时间流逝
	var data: Dictionary = _combat.FORM_DATA[ThreeFormsCombat.Form.YOU]
	_combat._cooldown_timers[ThreeFormsCombat.Form.YOU] = 0.0
	_combat._test_advance_phase()  # COOLDOWN → IDLE
	var result: bool = _combat.execute_form(ThreeFormsCombat.Form.YOU)
	assert_bool(result).is_true()
