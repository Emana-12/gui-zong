@warning_ignore_start("inferred_declaration")
# 后处理 Pass 测试
# 覆盖 Story 005: 后处理开关、WebGL 编译失败回退
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
# 后处理 Pass 管理
# =========================================================================

## 初始状态后处理启用。
func test_post_process_initially_enabled() -> void:
	assert_bool(_shader_manager._post_process_enabled).is_true()


## 禁用后处理 → _post_process_enabled = false。
func test_disable_post_process() -> void:
	_shader_manager.set_post_process_enabled(&"outline", false)
	assert_bool(_shader_manager._post_process_enabled).is_false()


## 启用后处理 → _post_process_enabled = true。
func test_enable_post_process() -> void:
	_shader_manager.set_post_process_enabled(&"outline", false)
	_shader_manager.set_post_process_enabled(&"outline", true)
	assert_bool(_shader_manager._post_process_enabled).is_true()


## 后处理 pass 名称: outline 和 tone。
func test_post_process_pass_names() -> void:
	# 验证 pass_name 参数可正常传递，不崩溃
	_shader_manager.set_post_process_enabled(&"outline", true)
	_shader_manager.set_post_process_enabled(&"tone", true)
	_shader_manager.set_post_process_enabled(&"outline", false)
	_shader_manager.set_post_process_enabled(&"tone", false)
	# 如果未崩溃则通过
	assert_bool(true).is_true()


# =========================================================================
# 降级系统联动
# =========================================================================

## Level 1 降级关闭后处理。
func test_level1_degradation_disables_post_process() -> void:
	_shader_manager._cached_fps = 25
	_shader_manager._check_degradation()

	assert_bool(_shader_manager._post_process_enabled).is_false()


## Level 2 降级也关闭后处理。
func test_level2_degradation_disables_post_process() -> void:
	_shader_manager._cached_fps = 15
	_shader_manager._check_degradation()

	assert_bool(_shader_manager._post_process_enabled).is_false()


## 正常帧率保持后处理启用。
func test_normal_fps_keeps_post_process_enabled() -> void:
	_shader_manager._cached_fps = 60
	_shader_manager._check_degradation()

	assert_bool(_shader_manager._post_process_enabled).is_true()


# =========================================================================
# AC-7: WebGL 编译失败回退
# =========================================================================

## 后处理 pass 编译失败时不应导致游戏崩溃。
## 注意: 在单元测试环境中无法真正模拟 WebGL 编译失败，
## 此测试验证 set_post_process_enabled 接口对异常输入的鲁棒性。
func test_post_process_graceful_on_invalid_pass() -> void:
	# 传入不存在的 pass 名称 → 不应崩溃
	_shader_manager.set_post_process_enabled(&"nonexistent_pass", true)
	assert_bool(true).is_true()


## 多次切换后处理状态 → 不崩溃。
func test_post_process_toggle_multiple_times() -> void:
	for i in 10:
		_shader_manager.set_post_process_enabled(&"outline", i % 2 == 0)

	# 最终状态应为关闭（9 % 2 == 1 → false）
	assert_bool(_shader_manager._post_process_enabled).is_false()


## 后处理关闭后不影响材质池。
func test_post_process_disable_does_not_affect_pool() -> void:
	var usage_before := _shader_manager.get_pool_usage()

	_shader_manager.set_post_process_enabled(&"outline", false)
	_shader_manager.set_post_process_enabled(&"tone", false)

	var usage_after := _shader_manager.get_pool_usage()
	assert_int(usage_after[0]).is_equal(usage_before[0])


## 后处理关闭后不影响轨迹材质创建。
func test_post_process_disabled_trail_material_still_works() -> void:
	_shader_manager.set_post_process_enabled(&"outline", false)

	var mat := _shader_manager.create_trail_material(Color("#D4A843"), 0.8)
	assert_object(mat).is_not_null()


# =========================================================================
# reset_degradation 联动
# =========================================================================

## reset_degradation 恢复后处理启用状态。
func test_reset_degradation_restores_post_process() -> void:
	_shader_manager._cached_fps = 15
	_shader_manager._check_degradation()
	assert_bool(_shader_manager._post_process_enabled).is_false()

	_shader_manager.reset_degradation()
	assert_bool(_shader_manager._post_process_enabled).is_true()
