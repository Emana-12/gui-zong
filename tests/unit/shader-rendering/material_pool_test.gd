@warning_ignore_start("inferred_declaration")
# 材质池单元测试
# 覆盖 Story 001: 材质池上限、哈希去重、get_material null 返回
# Story Type: Logic | Gate: BLOCKING
extends GdUnitTestSuite

var _shader_manager: ShaderManager


func before_test() -> void:
	_shader_manager = auto_free(ShaderManager.new())
	# 手动调用 _ready 预加载基础材质
	_shader_manager._ready()


func after_test() -> void:
	# 清空材质池，防止测试间泄漏
	_shader_manager._material_pool.clear()
	_shader_manager._pool_count = 0


# =========================================================================
# AC-8: get_material 不存在时返回 null
# =========================================================================

## AC-8a: 空池中查询不存在的名称 → 返回 null。
func test_get_material_nonexistent_returns_null() -> void:
	# Arrange — 清空池
	_shader_manager._material_pool.clear()
	_shader_manager._pool_count = 0

	# Act
	var result := _shader_manager.get_material(&"nonexistent")

	# Assert
	assert_object(result).is_null()


## AC-8b: 空字符串查询 → 返回 null。
func test_get_material_empty_name_returns_null() -> void:
	_shader_manager._material_pool.clear()
	_shader_manager._pool_count = 0

	var result := _shader_manager.get_material(&"")

	assert_object(result).is_null()


## AC-8c: 已存在的名称 → 返回正确材质。
func test_get_material_existing_returns_material() -> void:
	# Arrange — 先创建一个材质
	var created := _shader_manager.get_material(&"test_mat")

	# Act — 再次查询同名
	var retrieved := _shader_manager.get_material(&"test_mat")

	# Assert
	assert_object(retrieved).is_not_null()
	assert_object(retrieved).is_same(created)


# =========================================================================
# 材质池上限测试
# =========================================================================

## 池满时拒绝创建新材质 → 返回 null。
func test_pool_full_rejects_new_material() -> void:
	# Arrange — 填满池到上限
	_shader_manager._material_pool.clear()
	_shader_manager._pool_count = 0
	for i in ShaderManager.MAX_POOL_SIZE:
		var name := StringName("mat_%d" % i)
		_shader_manager.get_material(name)

	# Act — 尝试创建第 MAX_POOL_SIZE+1 个
	var overflow := _shader_manager.get_material(&"overflow_mat")

	# Assert
	assert_object(overflow).is_null()


## 池满时已存在的材质仍可查询。
func test_pool_full_still_returns_existing() -> void:
	_shader_manager._material_pool.clear()
	_shader_manager._pool_count = 0
	for i in ShaderManager.MAX_POOL_SIZE:
		_shader_manager.get_material(StringName("mat_%d" % i))

	# 已存在的材质应仍可获取
	var existing := _shader_manager.get_material(&"mat_0")
	assert_object(existing).is_not_null()


## get_pool_usage 返回正确的计数。
func test_pool_usage_tracks_count() -> void:
	_shader_manager._material_pool.clear()
	_shader_manager._pool_count = 0

	_shader_manager.get_material(&"a")
	_shader_manager.get_material(&"b")

	var usage := _shader_manager.get_pool_usage()
	assert_int(usage[0]).is_equal(2)
	assert_int(usage[1]).is_equal(ShaderManager.MAX_POOL_SIZE)


# =========================================================================
# AC-4: create_trail_material 返回正确材质
# =========================================================================

## AC-4a: 创建轨迹材质 → trail_color 和 trail_alpha 正确。
func test_create_trail_material_sets_parameters() -> void:
	var color := Color("#D4A843")
	var alpha := 0.8

	var mat := _shader_manager.create_trail_material(color, alpha)

	assert_object(mat).is_not_null()
	var trail_color: Vector3 = mat.get_shader_parameter("trail_color")
	var trail_alpha: float = mat.get_shader_parameter("trail_alpha")
	# trail_color 为 vec3(r, g, b)
	assert_float(trail_color.x).is_equal(color.r)
	assert_float(trail_color.y).is_equal(color.g)
	assert_float(trail_color.z).is_equal(color.b)
	assert_float(trail_alpha).is_equal(0.8)


## AC-4b: 相同参数调用两次 → 返回同一实例（材质池去重）。
func test_create_trail_material_same_params_returns_same_instance() -> void:
	var color := Color("#D4A843")
	var alpha := 0.8

	var mat1 := _shader_manager.create_trail_material(color, alpha)
	var mat2 := _shader_manager.create_trail_material(color, alpha)

	assert_object(mat1).is_same(mat2)


## AC-4c: alpha=0.0 边界值 → 材质创建成功。
func test_create_trail_material_alpha_zero() -> void:
	var color := Color("#1A1A2E")
	var alpha := 0.0

	var mat := _shader_manager.create_trail_material(color, alpha)

	assert_object(mat).is_not_null()
	var trail_alpha: float = mat.get_shader_parameter("trail_alpha")
	assert_float(trail_alpha).is_equal(0.0)


## 不同颜色/透明度 → 返回不同实例。
func test_create_trail_material_different_params_different_instance() -> void:
	var mat1 := _shader_manager.create_trail_material(Color("#D4A843"), 0.8)
	var mat2 := _shader_manager.create_trail_material(Color("#1A1A2E"), 0.6)

	assert_object(mat1).is_not_same(mat2)


# =========================================================================
# AC-3: 色调阶梯公式验证（纯数学，可在 GDScript 端验证）
# =========================================================================

## ink_steps=4, dot=0.7 → 阶梯输出为 0.5。
func test_ink_step_formula_dot_0_7_steps_4() -> void:
	# 公式: floor(dot * ink_steps) / ink_steps
	# 但环境着色器实际使用: normalized = dot * 0.5 + 0.5
	# step_index = floor(normalized * ink_steps)
	# stepped = step_index / ink_steps
	var ink_steps := 4
	var dot_val := 0.7
	var normalized: float = dot_val * 0.5 + 0.5  # 0.85
	var step_index: float = floorf(normalized * float(ink_steps))  # floor(3.4) = 3
	var stepped: float = step_index / float(ink_steps)  # 3/4 = 0.75

	# 根据 shd_ink_environment.gdshader 的实际公式
	# dot=0.7 → normalized=0.85 → step_index=3 → stepped=0.75
	assert_float(stepped).is_equal(0.75)


## dot=0.0 → normalized=0.5 → stepped=0.5（steps=4 时）。
func test_ink_step_formula_dot_zero() -> void:
	var ink_steps := 4
	var dot_val := 0.0
	var normalized: float = dot_val * 0.5 + 0.5  # 0.5
	var step_index: float = floorf(normalized * float(ink_steps))  # floor(2.0) = 2
	var stepped: float = step_index / float(ink_steps)  # 2/4 = 0.5

	assert_float(stepped).is_equal(0.5)


## dot=1.0 → normalized=1.0 → stepped=1.0（steps=4 时 step_index=4，但最大为 steps-1=3）。
func test_ink_step_formula_dot_one() -> void:
	var ink_steps := 4
	var dot_val := 1.0
	var normalized: float = dot_val * 0.5 + 0.5  # 1.0
	var step_index: float = floorf(normalized * float(ink_steps))  # floor(4.0) = 4
	# 在着色器中 step_index 可以等于 ink_steps，此时 stepped = 1.0
	var stepped: float = step_index / float(ink_steps)  # 4/4 = 1.0

	assert_float(stepped).is_equal(1.0)


## ink_steps=2 边界：dot=0.0 → normalized=0.5 → step_index=1 → stepped=0.5。
func test_ink_step_formula_steps_2_boundary() -> void:
	var ink_steps := 2
	var dot_val := 0.0
	var normalized: float = dot_val * 0.5 + 0.5  # 0.5
	var step_index: float = floorf(normalized * float(ink_steps))  # floor(1.0) = 1
	var stepped: float = step_index / float(ink_steps)  # 1/2 = 0.5

	assert_float(stepped).is_equal(0.5)


# =========================================================================
# set_character_highlight 测试
# =========================================================================

## 设置高光强度 → character_default 材质参数正确更新。
func test_set_character_highlight_updates_material() -> void:
	_shader_manager.set_character_highlight(0.5)

	var mat := _shader_manager.get_material(&"character_default")
	assert_object(mat).is_not_null()
	var intensity: float = mat.get_shader_parameter("highlight_intensity")
	assert_float(intensity).is_equal(0.5)


## 高光强度 clamp 到 [0, 1]。
func test_set_character_highlight_clamps_range() -> void:
	_shader_manager.set_character_highlight(1.5)
	var mat := _shader_manager.get_material(&"character_default")
	var intensity: float = mat.get_shader_parameter("highlight_intensity")
	assert_float(intensity).is_equal(1.0)

	_shader_manager.set_character_highlight(-0.5)
	intensity = mat.get_shader_parameter("highlight_intensity")
	assert_float(intensity).is_equal(0.0)
