@warning_ignore_start("inferred_declaration")
# 流光轨迹材质测试
# 覆盖 Story 003: 轨迹材质创建、颜色/透明度、三式剑招对应
# Story Type: Integration | Gate: BLOCKING
extends GdUnitTestSuite

var _shader_manager: ShaderManager


func before_test() -> void:
	_shader_manager = auto_free(ShaderManager.new())
	_shader_manager._ready()


func after_test() -> void:
	_shader_manager._material_pool.clear()
	_shader_manager._pool_count = 0


# =========================================================================
# 轨迹着色器预加载
# =========================================================================

## 流光轨迹着色器预加载成功。
func test_light_trail_shader_is_loaded() -> void:
	var shader: Shader = ShaderManager.SHD_LIGHT_TRAIL
	assert_object(shader).is_not_null()


## 流光轨迹着色器代码非空。
func test_light_trail_shader_code_not_empty() -> void:
	var code := ShaderManager.SHD_LIGHT_TRAIL.code
	assert_bool(code.length() > 0).is_true()


# =========================================================================
# create_trail_material 基础功能
# =========================================================================

## 创建轨迹材质 → 使用正确的着色器。
func test_trail_material_uses_light_trail_shader() -> void:
	var mat := _shader_manager.create_trail_material(Color("#D4A843"), 0.8)
	assert_object(mat.shader).is_same(ShaderManager.SHD_LIGHT_TRAIL)


## 轨迹材质 trail_color 参数正确设置。
func test_trail_material_color_set_correctly() -> void:
	var color := Color("#D4A843")
	var mat := _shader_manager.create_trail_material(color, 0.8)

	var trail_color: Vector3 = mat.get_shader_parameter("trail_color")
	assert_float(trail_color.x).is_equal(color.r)
	assert_float(trail_color.y).is_equal(color.g)
	assert_float(trail_color.z).is_equal(color.b)


## 轨迹材质 trail_alpha 参数正确设置。
func test_trail_material_alpha_set_correctly() -> void:
	var mat := _shader_manager.create_trail_material(Color("#D4A843"), 0.6)

	var trail_alpha: float = mat.get_shader_parameter("trail_alpha")
	assert_float(trail_alpha).is_equal(0.6)


# =========================================================================
# 三式剑招颜色对应
# =========================================================================

## 绕剑式 = 墨色轨迹 (#1A1A2E)。
func test_rao_form_uses_dark_ink_color() -> void:
	var rao_color := Color("#1A1A2E")
	var mat := _shader_manager.create_trail_material(rao_color, 0.8)

	var trail_color: Vector3 = mat.get_shader_parameter("trail_color")
	assert_float(trail_color.x).is_equal_approx(rao_color.r, 0.001)
	assert_float(trail_color.y).is_equal_approx(rao_color.g, 0.001)
	assert_float(trail_color.z).is_equal_approx(rao_color.b, 0.001)


## 游剑式 = 金色轨迹 (#D4A843)。
func test_you_form_uses_gold_color() -> void:
	var you_color := Color("#D4A843")
	var mat := _shader_manager.create_trail_material(you_color, 0.8)

	var trail_color: Vector3 = mat.get_shader_parameter("trail_color")
	assert_float(trail_color.x).is_equal_approx(you_color.r, 0.001)
	assert_float(trail_color.y).is_equal_approx(you_color.g, 0.001)
	assert_float(trail_color.z).is_equal_approx(you_color.b, 0.001)


## 钻剑式 = 金白轨迹 (#F5E6B8)。
func test_zuan_form_uses_gold_white_color() -> void:
	var zuan_color := Color("#F5E6B8")
	var mat := _shader_manager.create_trail_material(zuan_color, 0.8)

	var trail_color: Vector3 = mat.get_shader_parameter("trail_color")
	assert_float(trail_color.x).is_equal_approx(zuan_color.r, 0.001)
	assert_float(trail_color.y).is_equal_approx(zuan_color.g, 0.001)
	assert_float(trail_color.z).is_equal_approx(zuan_color.b, 0.001)


## 三式轨迹材质互不相同（各自独立实例）。
func test_three_forms_use_different_materials() -> void:
	var rao := _shader_manager.create_trail_material(Color("#1A1A2E"), 0.8)
	var you := _shader_manager.create_trail_material(Color("#D4A843"), 0.8)
	var zuan := _shader_manager.create_trail_material(Color("#F5E6B8"), 0.8)

	assert_object(rao).is_not_same(you)
	assert_object(you).is_not_same(zuan)
	assert_object(rao).is_not_same(zuan)


# =========================================================================
# 透明度边界值
# =========================================================================

## alpha=0.0 完全透明 → 材质创建成功。
func test_trail_material_alpha_zero() -> void:
	var mat := _shader_manager.create_trail_material(Color("#D4A843"), 0.0)
	assert_object(mat).is_not_null()
	var alpha: float = mat.get_shader_parameter("trail_alpha")
	assert_float(alpha).is_equal(0.0)


## alpha=1.0 完全不透明 → 材质创建成功。
func test_trail_material_alpha_one() -> void:
	var mat := _shader_manager.create_trail_material(Color("#D4A843"), 1.0)
	assert_object(mat).is_not_null()
	var alpha: float = mat.get_shader_parameter("trail_alpha")
	assert_float(alpha).is_equal(1.0)


# =========================================================================
# 材质池去重
# =========================================================================

## 相同颜色和透明度 → 返回同一材质实例。
func test_same_trail_params_returns_same_instance() -> void:
	var color := Color("#D4A843")
	var alpha := 0.8

	var mat1 := _shader_manager.create_trail_material(color, alpha)
	var mat2 := _shader_manager.create_trail_material(color, alpha)

	assert_object(mat1).is_same(mat2)


## 不同透明度 → 返回不同实例。
func test_different_alpha_returns_different_instance() -> void:
	var color := Color("#D4A843")

	var mat1 := _shader_manager.create_trail_material(color, 0.8)
	var mat2 := _shader_manager.create_trail_material(color, 0.6)

	assert_object(mat1).is_not_same(mat2)


## 不同颜色 → 返回不同实例。
func test_different_color_returns_different_instance() -> void:
	var mat1 := _shader_manager.create_trail_material(Color("#D4A843"), 0.8)
	var mat2 := _shader_manager.create_trail_material(Color("#1A1A2E"), 0.8)

	assert_object(mat1).is_not_same(mat2)


# =========================================================================
# Draw call 预算验证（AC-5）
# =========================================================================

## 8 环境 + 4 角色 + 3 轨迹 + 2 后处理 ≤ 17 draw calls。
func test_draw_call_budget_within_limit() -> void:
	_shader_manager._material_pool.clear()
	_shader_manager._pool_count = 0

	# 模拟场景材质
	for i in 8:
		_shader_manager.get_material(StringName("env_%d" % i))
	for i in 4:
		_shader_manager.get_material(StringName("char_%d" % i))
	# 3 种轨迹材质（三式剑招）
	_shader_manager.create_trail_material(Color("#1A1A2E"), 0.8)
	_shader_manager.create_trail_material(Color("#D4A843"), 0.8)
	_shader_manager.create_trail_material(Color("#F5E6B8"), 0.8)

	# draw_calls = 环境材质 + 角色材质 + 轨迹材质 + 后处理 pass
	var total_materials: int = _shader_manager._pool_count  # 8 + 4 + 3 = 15
	var post_process_passes := 2
	var total_draw_calls := total_materials + post_process_passes

	assert_int(total_draw_calls).is_less_equal(17)


## 轨迹材质共享（同剑式同参数）不增加 draw call。
func test_trail_dedup_does_not_increase_draw_calls() -> void:
	_shader_manager._material_pool.clear()
	_shader_manager._pool_count = 0

	# 同一剑式创建多个轨迹 → 共享同一材质
	for i in 50:
		_shader_manager.create_trail_material(Color("#D4A843"), 0.8)

	# 应仅有 1 个轨迹材质实例
	var usage := _shader_manager.get_pool_usage()
	assert_int(usage[0]).is_equal(1)
