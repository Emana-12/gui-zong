@warning_ignore_start("inferred_declaration")
## audio_bus_test.gd — Story 001 测试
##
## 验证音频总线管理：Master/SFX/BGM 总线创建、独立音量控制。
## ADR-0004: Audio System Architecture
class_name AudioBusTest
extends GdUnitTestSuite

var _audio_manager: AudioManager


func before_test() -> void:
	# AudioManager 是场景节点，需要手动创建
	_audio_manager = auto_free(AudioManager.new())
	# 用作测试时直接模拟 group 添加
	_audio_manager._audio_context_initialized = true


func after_test() -> void:
	_audio_manager = null


func test_audio_manager_is_node() -> void:
	assert_bool(_audio_manager is Node).is_true()


## 验证 init_audio_context() 幂等
func test_init_audio_context_idempotent() -> void:
	var am := auto_free(AudioManager.new())
	# 非 Web 平台 _ready 中会调用 init_audio_context
	# 模拟多次调用不应报错
	am.init_audio_context()
	am.init_audio_context()
	am.init_audio_context()
	assert_bool(am.is_audio_context_initialized()).is_true()


## 验证 set_bus_volume 音量限制在 0-1 范围
func test_set_bus_volume_clamp() -> void:
	# 使用 SFX 总线做测试
	_audio_manager.set_bus_volume(AudioManager.SFX_BUS, 1.5)
	var vol := _audio_manager.get_bus_volume(AudioManager.SFX_BUS)
	assert_float(vol).is_less_equal(1.0)

	_audio_manager.set_bus_volume(AudioManager.SFX_BUS, -0.5)
	vol = _audio_manager.get_bus_volume(AudioManager.SFX_BUS)
	assert_float(vol).is_equal(0.0)


## 验证 set_bus_volume 0.5 约等于 -6dB
func test_set_bus_volume_half() -> void:
	_audio_manager.set_bus_volume(AudioManager.SFX_BUS, 0.5)
	var vol := _audio_manager.get_bus_volume(AudioManager.SFX_BUS)
	# 0.5 线性 -> -6.02dB，转回来应该接近 0.5
	assert_float(vol).is_equal_approx(0.5, 0.01)


## 验证 SFX 和 BGM 总线独立
func test_bus_independence() -> void:
	_audio_manager.set_bus_volume(AudioManager.SFX_BUS, 0.8)
	_audio_manager.set_bus_volume(AudioManager.BGM_BUS, 0.3)
	assert_float(_audio_manager.get_bus_volume(AudioManager.SFX_BUS)).is_equal_approx(0.8, 0.01)
	assert_float(_audio_manager.get_bus_volume(AudioManager.BGM_BUS)).is_equal_approx(0.3, 0.01)
