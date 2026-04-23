@warning_ignore_start("inferred_declaration")
# 自动降级系统测试
# 覆盖 Story 004: FPS 降级、ink_steps 降低、防抖、不自动恢复
# Story Type: Logic | Gate: BLOCKING
extends GdUnitTestSuite

var _shader_manager: ShaderManager


func before_test() -> void:
	_shader_manager = auto_free(ShaderManager.new())
	_shader_manager._ready()


func after_test() -> void:
	_shader_manager._material_pool.clear()
	_shader_manager._pool_count = 0


# =========================================================================
# 降级阈值常量验证
# =========================================================================

## DEGRADE_FPS_THRESHOLD = 30。
func test_degrade_threshold_is_30() -> void:
	assert_int(ShaderManager.DEGRADE_FPS_THRESHOLD).is_equal(30)


## CRITICAL_FPS_THRESHOLD = 20。
func test_critical_threshold_is_20() -> void:
	assert_int(ShaderManager.CRITICAL_FPS_THRESHOLD).is_equal(20)


## DEGRADED_INK_STEPS = 2。
func test_degraded_ink_steps_is_2() -> void:
	assert_int(ShaderManager.DEGRADED_INK_STEPS).is_equal(2)


# =========================================================================
# AC-6: 自动降级触发验证
# =========================================================================

## 初始状态未降级。
func test_initial_state_not_degraded() -> void:
	assert_bool(_shader_manager.is_degraded()).is_false()


## 初始状态后处理启用。
func test_initial_post_process_enabled() -> void:
	assert_bool(_shader_manager._post_process_enabled).is_true()


## FPS < 20 触发 Level 2 降级 → ink_steps 降至 2，后处理关闭。
func test_critical_fps_triggers_level2_degradation() -> void:
	# Arrange — 模拟低帧率
	_shader_manager._cached_fps = 15

	# Act
	_shader_manager._check_degradation()

	# Assert
	assert_bool(_shader_manager.is_degraded()).is_true()
	assert_bool(_shader_manager._post_process_enabled).is_false()

	# 验证 environment_degraded 的 ink_steps 已降为 2
	var env_mat := _shader_manager._material_pool.get(&"environment_degraded")
	if env_mat:
		var steps: int = env_mat.get_shader_parameter("ink_steps")
		assert_int(steps).is_equal(2)


## FPS < 30 但 >= 20 → Level 1 降级（关闭后处理，不降 ink_steps）。
func test_low_fps_triggers_level1_degradation() -> void:
	_shader_manager._cached_fps = 25

	_shader_manager._check_degradation()

	assert_bool(_shader_manager.is_degraded()).is_true()
	assert_bool(_shader_manager._post_process_enabled).is_false()


## FPS >= 30 → 不触发降级。
func test_normal_fps_no_degradation() -> void:
	_shader_manager._cached_fps = 60

	_shader_manager._check_degradation()

	assert_bool(_shader_manager.is_degraded()).is_false()
	assert_bool(_shader_manager._post_process_enabled).is_true()


## FPS 刚好 30 → 不触发降级。
func test_fps_exactly_30_no_degradation() -> void:
	_shader_manager._cached_fps = 30

	_shader_manager._check_degradation()

	assert_bool(_shader_manager.is_degraded()).is_false()
	assert_bool(_shader_manager._post_process_enabled).is_true()


## FPS 从 60 突降到 15 → 直接触发 Level 2。
func test_fps_drop_to_critical_triggers_level2() -> void:
	# 正常运行
	_shader_manager._cached_fps = 60
	_shader_manager._check_degradation()
	assert_bool(_shader_manager.is_degraded()).is_false()

	# 突降
	_shader_manager._cached_fps = 15
	_shader_manager._check_degradation()

	assert_bool(_shader_manager.is_degraded()).is_true()
	assert_bool(_shader_manager._post_process_enabled).is_false()


# =========================================================================
# 降级不自动恢复
# =========================================================================

## 已触发降级后帧率恢复 → 降级状态不变。
func test_degradation_does_not_auto_recover() -> void:
	# 触发降级
	_shader_manager._cached_fps = 15
	_shader_manager._check_degradation()
	assert_bool(_shader_manager.is_degraded()).is_true()

	# 帧率恢复
	_shader_manager._cached_fps = 60
	_shader_manager._check_degradation()

	# 降级状态不应恢复
	assert_bool(_shader_manager.is_degraded()).is_true()
	assert_bool(_shader_manager._post_process_enabled).is_false()


## reset_degradation 可手动重置降级状态。
func test_reset_degradation_restores_state() -> void:
	# 触发降级
	_shader_manager._cached_fps = 15
	_shader_manager._check_degradation()
	assert_bool(_shader_manager.is_degraded()).is_true()

	# 手动重置
	_shader_manager.reset_degradation()

	assert_bool(_shader_manager.is_degraded()).is_false()
	assert_bool(_shader_manager._post_process_enabled).is_true()


# =========================================================================
# 降级只触发一次
# =========================================================================

## 已降级后再次检查低帧率 → 不重复降级（无副作用）。
func test_degradation_only_triggers_once() -> void:
	_shader_manager._cached_fps = 15
	_shader_manager._check_degradation()

	# 记录降级后的状态
	var pool_count_before := _shader_manager._pool_count

	# 再次检查
	_shader_manager._check_degradation()

	# 池计数不应变化（不重复创建材质）
	assert_int(_shader_manager._pool_count).is_equal(pool_count_before)


# =========================================================================
# get_fps 接口
# =========================================================================

## get_fps 返回 _cached_fps 值。
func test_get_fps_returns_cached_value() -> void:
	_shader_manager._cached_fps = 42
	assert_int(_shader_manager.get_fps()).is_equal(42)


## FPS 采样窗口常量为 60。
func test_fps_sample_window_is_60() -> void:
	assert_int(ShaderManager.FPS_SAMPLE_WINDOW).is_equal(60)
