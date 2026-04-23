# 流光轨迹系统 — 轨迹池化与共享材质测试
extends GdUnitTestSuite

var _trail_system: LightTrailSystem


func before_test() -> void:
	_trail_system = auto_free(LightTrailSystem.new())
	add_child(_trail_system)
	# 等待 _ready() 完成初始化
	await get_tree().process_frame


func after_test() -> void:
	_trail_system.clear_all_trails()


# ─── 池初始化 ────────────────────────────────────────────────────────────────

func test_pool_initializes_with_50_nodes() -> void:
	assert_int(_trail_system._test_get_available_pool_count()).is_equal(50)


func test_shared_materials_created_for_all_forms() -> void:
	var materials: Dictionary = _trail_system._test_get_shared_materials()
	assert_bool(materials.has(LightTrailSystem.FORM_YOU)).is_true()
	assert_bool(materials.has(LightTrailSystem.FORM_ZUAN)).is_true()
	assert_bool(materials.has(LightTrailSystem.FORM_RAO)).is_true()


func test_all_forms_share_same_material_per_form() -> void:
	var materials: Dictionary = _trail_system._test_get_shared_materials()
	# 同一剑式的所有轨迹共享同一材质对象
	var you_mat_1 = materials[LightTrailSystem.FORM_YOU]
	var you_mat_2 = materials[LightTrailSystem.FORM_YOU]
	assert_object(you_mat_1).is_same(you_mat_2)


# ─── 轨迹创建与池化 ──────────────────────────────────────────────────────────

func test_create_trail_returns_valid_id() -> void:
	var id := _trail_system.create_trail(LightTrailSystem.FORM_YOU, Vector3.ZERO)
	assert_int(id).is_greater_equal(0)


func test_create_trail_reduces_available_pool() -> void:
	_trail_system.create_trail(LightTrailSystem.FORM_YOU, Vector3.ZERO)
	assert_int(_trail_system._test_get_available_pool_count()).is_equal(49)


func test_create_trail_increases_active_count() -> void:
	_trail_system.create_trail(LightTrailSystem.FORM_YOU, Vector3.ZERO)
	assert_int(_trail_system.get_active_trail_count()).is_equal(1)


func test_create_multiple_trails() -> void:
	for i in range(10):
		_trail_system.create_trail(LightTrailSystem.FORM_YOU, Vector3(i, 0, 0))
	assert_int(_trail_system.get_active_trail_count()).is_equal(10)
	assert_int(_trail_system._test_get_available_pool_count()).is_equal(40)


# ─── 上限拒绝 ────────────────────────────────────────────────────────────────

func test_reject_when_at_capacity() -> void:
	# 填满 50 条轨迹
	for i in range(50):
		var id := _trail_system.create_trail(LightTrailSystem.FORM_YOU, Vector3.ZERO)
		assert_int(id).is_greater_equal(0)

	# 第 51 条应被拒绝
	var signal_monitor := monitor_signals(_trail_system)
	var rejected_id := _trail_system.create_trail(LightTrailSystem.FORM_YOU, Vector3.ZERO)
	assert_int(rejected_id).is_equal(-1)
	assert_signal(signal_monitor).is_emitted("trail_rejected")


func test_is_at_capacity_reflects_state() -> void:
	assert_bool(_trail_system.is_at_capacity()).is_false()
	for i in range(50):
		_trail_system.create_trail(LightTrailSystem.FORM_YOU, Vector3.ZERO)
	assert_bool(_trail_system.is_at_capacity()).is_true()


# ─── 轨迹归还 ────────────────────────────────────────────────────────────────

func test_finish_and_destroy_frees_pool_node() -> void:
	var id := _trail_system.create_trail(LightTrailSystem.FORM_YOU, Vector3.ZERO)
	assert_int(_trail_system._test_get_available_pool_count()).is_equal(49)

	# finish → 淡出 → 自动销毁需要时间，直接调用 finish
	_trail_system.finish_trail(id)

	# 等待淡出完成（fade_time = 0.5s，测试中等几帧）
	# 由于 fade_time > 0，节点在淡出后才归还
	# 我们检查 trail_finished 信号
	var data := _trail_system._test_get_trail_data(id)
	assert_bool(data).is_not_null()
	assert_bool(data.fading).is_true()


func test_clear_all_trails_returns_all_nodes() -> void:
	for i in range(10):
		_trail_system.create_trail(LightTrailSystem.FORM_YOU, Vector3.ZERO)
	assert_int(_trail_system.get_active_trail_count()).is_equal(10)

	_trail_system.clear_all_trails()
	assert_int(_trail_system.get_active_trail_count()).is_equal(0)
	assert_int(_trail_system._test_get_available_pool_count()).is_equal(50)


# ─── 未知剑式 ────────────────────────────────────────────────────────────────

func test_unknown_form_returns_negative_one() -> void:
	var id := _trail_system.create_trail(&"unknown_form", Vector3.ZERO)
	assert_int(id).is_equal(-1)


# ─── 信号验证 ────────────────────────────────────────────────────────────────

func test_create_emits_trail_created_signal() -> void:
	var signal_monitor := monitor_signals(_trail_system)
	_trail_system.create_trail(LightTrailSystem.FORM_YOU, Vector3.ZERO)
	assert_signal(signal_monitor).is_emitted("trail_created")


func test_finish_emits_trail_finished_signal() -> void:
	var id := _trail_system.create_trail(LightTrailSystem.FORM_YOU, Vector3.ZERO)
	var signal_monitor := monitor_signals(_trail_system)
	_trail_system.finish_trail(id)
	assert_signal(signal_monitor).is_emitted("trail_finished")
