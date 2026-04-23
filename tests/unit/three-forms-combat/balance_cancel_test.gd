## balance_cancel_test.gd — ThreeFormsCombat DPS 均衡与死亡取消测试
##
## 覆盖 story-003-balance-cancel 全部 2 个 AC
extends GdUnitTestSuite

var _combat: ThreeFormsCombat
var _physics_system: PhysicsCollisionSystem


func before_test() -> void:
	_physics_system = auto_free(PhysicsCollisionSystem.new())
	_physics_system.name = "PhysicsCollisionSystem"
	add_child(_physics_system)

	_combat = auto_free(ThreeFormsCombat.new())
	_combat.name = "ThreeFormsCombat"
	var owner_node := auto_free(Node3D.new())
	owner_node.name = "Owner"
	add_child(owner_node)
	_combat.owner = owner_node
	add_child(_combat)


func after_test() -> void:
	_combat.cancel_current()


# ──────────────────────────────────────────────
# AC-1: DPS 均衡 — 三式 DPS 差异 ≤ 50%
# ──────────────────────────────────────────────

## 计算游剑式 DPS = 1 / (0.3 + 0.1 + 0.2) = 1.67
func test_you_dps_calculation() -> void:
	var data: Dictionary = ThreeFormsCombat.FORM_DATA[ThreeFormsCombat.Form.YOU]
	var cycle_time: float = data["execute_time"] + data["recovery_time"] + data["cooldown_time"]
	var dps: float = data["damage"] / cycle_time
	assert_float(dps).is_equal_approx(1.67, 0.01)


## 计算钻剑式 DPS = 3 / (0.5 + 0.2 + 0.5) = 2.50
func test_zuan_dps_calculation() -> void:
	var data: Dictionary = ThreeFormsCombat.FORM_DATA[ThreeFormsCombat.Form.ZUAN]
	var cycle_time: float = data["execute_time"] + data["recovery_time"] + data["cooldown_time"]
	var dps: float = data["damage"] / cycle_time
	assert_float(dps).is_equal_approx(2.50, 0.01)


## 计算绕剑式 DPS = 2 / (0.4 + 0.15 + 0.3) = 2.35
func test_rao_dps_calculation() -> void:
	var data: Dictionary = ThreeFormsCombat.FORM_DATA[ThreeFormsCombat.Form.RAO]
	var cycle_time: float = data["execute_time"] + data["recovery_time"] + data["cooldown_time"]
	var dps: float = data["damage"] / cycle_time
	assert_float(dps).is_equal_approx(2.35, 0.01)


## 三式 DPS 差异 ≤ 50% — max_dps / min_dps ≤ 1.50
func test_dps_within_fifty_percent_range() -> void:
	var forms := [ThreeFormsCombat.Form.YOU, ThreeFormsCombat.Form.ZUAN, ThreeFormsCombat.Form.RAO]
	var dps_values: Array[float] = []
	for form in forms:
		var data: Dictionary = ThreeFormsCombat.FORM_DATA[form]
		var cycle_time: float = data["execute_time"] + data["recovery_time"] + data["cooldown_time"]
		dps_values.append(data["damage"] / cycle_time)
	var min_dps: float = dps_values.min()
	var max_dps: float = dps_values.max()
	assert_float(max_dps / min_dps).is_less_equal(1.50)


# ──────────────────────────────────────────────
# AC-2: 死亡取消 — cancel_current() 重置状态
# ──────────────────────────────────────────────

## cancel_current 重置 phase 到 IDLE
func test_cancel_current_resets_phase_to_idle() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	assert_bool(_combat.is_executing()).is_true()
	_combat.cancel_current()
	assert_bool(_combat.is_executing()).is_false()
	assert_int(_combat.get_active_form()).is_equal(ThreeFormsCombat.Form.NONE)


## cancel_current 重置 form 到 NONE
func test_cancel_current_resets_form_to_none() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.ZUAN)
	_combat.cancel_current()
	assert_int(_combat.get_active_form()).is_equal(ThreeFormsCombat.Form.NONE)


## cancel_current 在 IDLE 状态调用安全
func test_cancel_current_on_idle_is_safe() -> void:
	# 不应崩溃或抛出异常
	_combat.cancel_current()
	assert_bool(_combat.is_executing()).is_false()
	assert_int(_combat.get_active_form()).is_equal(ThreeFormsCombat.Form.NONE)


## cancel_current 后可重新执行新式
func test_cancel_allows_new_form_execution() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.RAO)
	_combat.cancel_current()
	var result: bool = _combat.execute_form(ThreeFormsCombat.Form.YOU)
	assert_bool(result).is_true()
	assert_int(_combat.get_active_form()).is_equal(ThreeFormsCombat.Form.YOU)


## cancel_current 在 RECOVERING 中也能取消
func test_cancel_during_recovering() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	_combat._test_advance_phase()  # EXECUTING → RECOVERING
	_combat.cancel_current()
	assert_bool(_combat.is_executing()).is_false()
	assert_int(_combat.get_active_form()).is_equal(ThreeFormsCombat.Form.NONE)


## cancel_current 在 COOLDOWN 中也能取消
func test_cancel_during_cooldown() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.ZUAN)
	_combat._test_advance_phase()  # EXECUTING → RECOVERING
	_combat._test_advance_phase()  # RECOVERING → COOLDOWN
	_combat.cancel_current()
	assert_bool(_combat.is_executing()).is_false()
	assert_int(_combat.get_active_form()).is_equal(ThreeFormsCombat.Form.NONE)
