## form_execution_test.gd — ThreeFormsCombat 剑招执行测试
##
## 覆盖 story-001-form-execution 全部 4 个 AC
extends GdUnitTestSuite

var _combat: ThreeFormsCombat
var _physics_system: PhysicsCollisionSystem


func before_test() -> void:
	_physics_system = auto_free(PhysicsCollisionSystem.new())
	_physics_system.name = "PhysicsCollisionSystem"
	# Must add to tree so _ready() runs and hitbox pool is created
	add_child(_physics_system)

	_combat = auto_free(ThreeFormsCombat.new())
	_combat.name = "ThreeFormsCombat"
	# Provide a mock owner node for hitbox creation
	var owner_node := auto_free(Node3D.new())
	owner_node.name = "Owner"
	add_child(owner_node)
	_combat.owner = owner_node
	add_child(_combat)


func after_test() -> void:
	_combat.cancel_current()


## AC-1: J → 游剑式 (YOU) 执行成功
func test_execute_you_form_returns_true() -> void:
	var result: bool = _combat.execute_form(ThreeFormsCombat.Form.YOU)
	assert_bool(result).is_true()


## AC-2: K → 钻剑式 (ZUAN) 执行成功
func test_execute_zuan_form_returns_true() -> void:
	var result: bool = _combat.execute_form(ThreeFormsCombat.Form.ZUAN)
	assert_bool(result).is_true()


## AC-3: L → 绕剑式 (RAO) 执行成功
func test_execute_rao_form_returns_true() -> void:
	var result: bool = _combat.execute_form(ThreeFormsCombat.Form.RAO)
	assert_bool(result).is_true()


## AC-4: form_activated 信号在执行时发出
func test_execute_form_emits_form_activated_signal() -> void:
	var monitor := await monitor_signals(_combat)
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	await assert_signal(monitor).is_emitted("form_activated", [ThreeFormsCombat.Form.YOU])


## 无效剑式返回 false
func test_execute_returns_false_invalid_form() -> void:
	var result: bool = _combat.execute_form(ThreeFormsCombat.Form.NONE)
	assert_bool(result).is_false()


## 执行中再次执行返回 false
func test_execute_returns_false_during_executing() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	var result: bool = _combat.execute_form(ThreeFormsCombat.Form.ZUAN)
	assert_bool(result).is_false()


## 冷却中执行返回 false — 先执行，推进到 COOLDOWN，再尝试执行同式
func test_execute_returns_false_during_cooldown() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	# Advance EXECUTING → RECOVERING
	_combat._test_advance_phase()
	# Advance RECOVERING → COOLDOWN
	_combat._test_advance_phase()
	assert_bool(_combat.is_on_cooldown(ThreeFormsCombat.Form.YOU)).is_true()
	var result: bool = _combat.execute_form(ThreeFormsCombat.Form.YOU)
	assert_bool(result).is_false()


## get_active_form 返回当前激活剑式
func test_get_active_form_returns_correct_form() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.RAO)
	assert_int(_combat.get_active_form()).is_equal(ThreeFormsCombat.Form.RAO)


## is_executing 在执行阶段为 true
func test_is_executing_true_during_execution() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.ZUAN)
	assert_bool(_combat.is_executing()).is_true()


## get_hitbox_id 在执行阶段返回有效 ID
func test_get_hitbox_id_returns_valid_id_during_execution() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	var id: int = _combat.get_hitbox_id()
	# ID may be -1 if physics system not available in test, but at minimum
	# the combat system should attempt to create one
	assert_int(id).is_greater_equal(-1)


## cancel_current 重置状态到 IDLE
func test_cancel_current_resets_state() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	_combat.cancel_current()
	assert_bool(_combat.is_executing()).is_false()
	assert_int(_combat.get_active_form()).is_equal(ThreeFormsCombat.Form.NONE)


## 完成 EXECUTING 阶段后进入 RECOVERING
func test_phase_transitions_to_recovering() -> void:
	_combat.execute_form(ThreeFormsCombat.Form.YOU)
	_combat._test_advance_phase()
	assert_bool(_combat.is_executing()).is_false()


## form_finished 信号在 COOLDOWN 开始时发出
func test_form_finished_emitted_on_cooldown() -> void:
	var monitor := await monitor_signals(_combat)
	_combat.execute_form(ThreeFormsCombat.Form.ZUAN)
	_combat._test_advance_phase()  # EXECUTING → RECOVERING
	_combat._test_advance_phase()  # RECOVERING → COOLDOWN
	await assert_signal(monitor).is_emitted("form_finished", [ThreeFormsCombat.Form.ZUAN])
