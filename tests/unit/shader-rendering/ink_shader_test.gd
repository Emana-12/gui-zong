@warning_ignore_start("inferred_declaration")
# 水墨着色器测试
# 覆盖 Story 002: 着色器加载、参数设置
# Story Type: Visual/Feel — 本文件覆盖可自动化验证的参数逻辑部分
# Gate: ADVISORY（视觉验证需截图签名）
extends GdUnitTestSuite

var _shader_manager: ShaderManager


func before_test() -> void:
	_shader_manager = auto_free(ShaderManager.new())
	_shader_manager._ready()


func after_test() -> void:
	_shader_manager._material_pool.clear()
	_shader_manager._pool_count = 0


# =========================================================================
# 着色器预加载验证
# =========================================================================

## 角色着色器预加载成功。
func test_ink_character_shader_is_loaded() -> void:
	var shader: Shader = ShaderManager.SHD_INK_CHARACTER
	assert_object(shader).is_not_null()


## 环境着色器预加载成功。
func test_ink_environment_shader_is_loaded() -> void:
	var shader: Shader = ShaderManager.SHD_INK_ENVIRONMENT
	assert_object(shader).is_not_null()


## 预加载的着色器代码非空。
func test_shader_code_not_empty() -> void:
	var code := ShaderManager.SHD_INK_CHARACTER.code
	assert_bool(code.length() > 0).is_true()

	code = ShaderManager.SHD_INK_ENVIRONMENT.code
	assert_bool(code.length() > 0).is_true()


# =========================================================================
# character_default 材质参数验证
# =========================================================================

## character_default 材质使用正确的着色器。
func test_character_default_uses_ink_character_shader() -> void:
	var mat = _shader_manager.get_material(&"character_default")
	assert_object(mat).is_not_null()
	assert_object(mat.shader).is_same(ShaderManager.SHD_INK_CHARACTER)


## character_default 的 highlight_intensity 默认值为 0.0。
func test_character_default_highlight_intensity_default() -> void:
	var mat = _shader_manager.get_material(&"character_default")
	var intensity: float = mat.get_shader_parameter("highlight_intensity")
	assert_float(intensity).is_equal(0.0)


## 设置 highlight_intensity 后参数正确反映。
func test_character_highlight_intensity_set() -> void:
	_shader_manager.set_character_highlight(0.75)

	var mat = _shader_manager.get_material(&"character_default")
	var intensity: float = mat.get_shader_parameter("highlight_intensity")
	assert_float(intensity).is_equal(0.75)


# =========================================================================
# environment_default 材质参数验证
# =========================================================================

## environment_default 材质使用正确的着色器。
func test_environment_default_uses_ink_environment_shader() -> void:
	var mat = _shader_manager.get_material(&"environment_default")
	assert_object(mat).is_not_null()
	assert_object(mat.shader).is_same(ShaderManager.SHD_INK_ENVIRONMENT)


## environment_degraded 材质使用正确的着色器。
func test_environment_degraded_uses_ink_environment_shader() -> void:
	var mat = _shader_manager.get_material(&"environment_degraded")
	assert_object(mat).is_not_null()
	assert_object(mat.shader).is_same(ShaderManager.SHD_INK_ENVIRONMENT)


# =========================================================================
# 着色器 uniform 参数范围验证
# =========================================================================

## 角色着色器 ink_edge_softness 参数在材质上可读取。
func test_character_shader_has_ink_edge_softness() -> void:
	var mat = _shader_manager.get_material(&"character_default")
	# 默认值应为 0.2（根据着色器定义）
	var softness: float = mat.get_shader_parameter("ink_edge_softness")
	assert_float(softness).is_equal(0.2)


## 角色着色器 rim_light_power 参数在材质上可读取。
func test_character_shader_has_rim_light_power() -> void:
	var mat = _shader_manager.get_material(&"character_default")
	var power: float = mat.get_shader_parameter("rim_light_power")
	assert_float(power).is_equal(3.0)


## 环境着色器 ink_steps 参数默认值为 4。
func test_environment_shader_ink_steps_default() -> void:
	var mat = _shader_manager.get_material(&"environment_default")
	var steps: int = mat.get_shader_parameter("ink_steps")
	assert_int(steps).is_equal(4)


## 环境着色器 ink_steps 可修改。
func test_environment_shader_ink_steps_settable() -> void:
	var mat = _shader_manager.get_material(&"environment_default")
	mat.set_shader_parameter("ink_steps", 2)
	var steps: int = mat.get_shader_parameter("ink_steps")
	assert_int(steps).is_equal(2)


# =========================================================================
# 着色器代码中关键公式存在性检查
# =========================================================================

## 环境着色器包含色调阶梯公式。
func test_environment_shader_has_stepped_lighting_formula() -> void:
	var code := ShaderManager.SHD_INK_ENVIRONMENT.code
	# 验证关键公式片段存在于着色器代码中
	assert_bool(code.contains("floor(normalized * float(ink_steps))")).is_true()
	assert_bool(code.contains("step_index / float(ink_steps)")).is_true()


## 角色着色器包含 toon ramp 实现。
func test_character_shader_has_toon_ramp() -> void:
	var code := ShaderManager.SHD_INK_CHARACTER.code
	assert_bool(code.contains("smoothstep")).is_true()
	assert_bool(code.contains("floor(toon_step * 3.0)")).is_true()


## 角色着色器包含 rim light 实现。
func test_character_shader_has_rim_light() -> void:
	var code := ShaderManager.SHD_INK_CHARACTER.code
	assert_bool(code.contains("1.0 - dot(NORMAL, VIEW)")).is_true()
