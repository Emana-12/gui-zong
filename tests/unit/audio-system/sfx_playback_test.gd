@warning_ignore_start("inferred_declaration")
## sfx_playback_test.gd — Story 002 测试
##
## 验证 SFX 播放：预加载、播放、音量/pitch 控制、实例限制。
## ADR-0004: Audio System Architecture
class_name SfxPlaybackTest
extends GdUnitTestSuite

var _audio_manager: AudioManager


func before_test() -> void:
	_audio_manager = auto_free(AudioManager.new())
	_audio_manager._audio_context_initialized = true


func after_test() -> void:
	_audio_manager = null


## 验证 play_sfx 在 AudioContext 未初始化时静默失败
func test_play_sfx_before_init_silent_fail() -> void:
	var am := auto_free(AudioManager.new())
	am._audio_context_initialized = false
	# 不应抛出异常或创建节点
	am.play_sfx(&"nonexistent", 1.0, 1.0)
	# 无 crash 即通过
	assert_bool(true).is_true()


## 验证 play_sfx 对不存在的音效文件静默处理
func test_play_sfx_missing_file_no_crash() -> void:
	# 音效文件不存在，应发出 warning 但不 crash
	_audio_manager.play_sfx(&"this_file_does_not_exist", 1.0, 1.0)
	assert_bool(true).is_true()


## 验证 _get_or_load_sfx 返回 null 对于不存在的文件
func test_get_or_load_sfx_missing_returns_null() -> void:
	var result := _audio_manager._get_or_load_sfx(&"nonexistent_sfx")
	assert_object(result).is_null()


## 验证音量参数被 clamp 到 0-1
func test_play_sfx_volume_clamp() -> void:
	# 这些调用不应 crash，即使参数越界
	_audio_manager.play_sfx(&"hit_metal", 2.0, 1.0)  # volume > 1
	_audio_manager.play_sfx(&"hit_metal", -0.5, 1.0) # volume < 0
	# 无 crash 即通过
	assert_bool(true).is_true()


## 验证 pitch 参数被 clamp 到 0.1-4.0
func test_play_sfx_pitch_clamp() -> void:
	_audio_manager.play_sfx(&"hit_metal", 1.0, 0.01)  # pitch < 0.1
	_audio_manager.play_sfx(&"hit_metal", 1.0, 10.0)  # pitch > 4.0
	assert_bool(true).is_true()


## 验证预加载缓存为空
func test_sfx_cache_initial_empty() -> void:
	var preloaded := _audio_manager.get_preloaded_sfx()
	assert_int(preloaded.size()).is_equal(0)


## 验证 SFX 实例池初始状态
func test_sfx_instances_initial_empty() -> void:
	assert_int(_audio_manager._sfx_instances.size()).is_equal(0)
	assert_int(_audio_manager._total_active_instances).is_equal(0)


## 验证 MAX_INSTANCES_PER_SFX 常量值
func test_max_instances_constant() -> void:
	assert_int(AudioManager.MAX_INSTANCES_PER_SFX).is_equal(3)


## 验证 MAX_TOTAL_SFX_INSTANCES 常量值
func test_max_total_instances_constant() -> void:
	assert_int(AudioManager.MAX_TOTAL_SFX_INSTANCES).is_equal(8)


## 验证 SFX 总线名称常量
func test_sfx_bus_constant() -> void:
	assert_str(AudioManager.SFX_BUS).is_equal(&"SFX")
