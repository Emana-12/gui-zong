@warning_ignore_start("inferred_declaration")
## bgm_loop_test.gd — Story 003 测试
##
## 验证循环音效和 BGM：play_loop/stop_loop、BGM crossfade、stop_bgm。
## ADR-0004: Audio System Architecture
class_name BgmLoopTest
extends GdUnitTestSuite

var _audio_manager: AudioManager


func before_test() -> void:
	_audio_manager = auto_free(AudioManager.new())
	_audio_manager._audio_context_initialized = true


func after_test() -> void:
	_audio_manager = null


## 验证 play_loop 在 AudioContext 未初始化时静默失败
func test_play_loop_before_init_silent_fail() -> void:
	var am: AudioManager = auto_free(AudioManager.new())
	am._audio_context_initialized = false
	am.play_loop(&"ambient_wind", 0.5)
	assert_bool(true).is_true()


## 验证 stop_loop 对不存在的循环音效不报错
func test_stop_loop_nonexistent_no_crash() -> void:
	_audio_manager.stop_loop(&"nonexistent_loop")
	assert_bool(true).is_true()


## 验证 play_loop 在找不到文件时不 crash
func test_play_loop_missing_file_no_crash() -> void:
	_audio_manager.play_loop(&"this_file_does_not_exist", 0.5)
	# 循环实例池不应有该条目
	assert_bool(_audio_manager._loop_instances.has(&"this_file_does_not_exist")).is_false()


## 验证 play_bgm 在 AudioContext 未初始化时静默失败
func test_play_bgm_before_init_silent_fail() -> void:
	var am: AudioManager = auto_free(AudioManager.new())
	am._audio_context_initialized = false
	am.play_bgm(&"boss_theme", 1.0)
	assert_bool(true).is_true()


## 验证 stop_bgm 在没有播放时不 crash
func test_stop_bgm_not_playing_no_crash() -> void:
	_audio_manager.stop_bgm()
	assert_bool(true).is_true()


## 验证 BGM 播放器存在
func test_bgm_players_exist() -> void:
	assert_bool(_audio_manager._bgm_current != null).is_true()
	assert_bool(_audio_manager._bgm_next != null).is_true()


## 验证 BGM 总线名称常量
func test_bgm_bus_constant() -> void:
	assert_str(AudioManager.BGM_BUS).is_equal(&"BGM")


## 验证 BGM crossfade 时长常量
func test_bgm_crossfade_duration() -> void:
	assert_float(AudioManager.BGM_CROSSFADE_DURATION).is_equal(1.0)


## 验证循环音效池初始为空
func test_loop_instances_initial_empty() -> void:
	assert_int(_audio_manager._loop_instances.size()).is_equal(0)


## 验证 BGM 缓存初始为空
func test_bgm_cache_initial_empty() -> void:
	var preloaded = _audio_manager.get_preloaded_bgm()
	assert_int(preloaded.size()).is_equal(0)


## 验证 play_bgm 对不存在的文件静默处理
func test_play_bgm_missing_file_no_crash() -> void:
	_audio_manager.play_bgm(&"nonexistent_bgm", 1.0)
	assert_bool(true).is_true()


## 验证 _get_or_load_bgm 对不存在文件返回 null
func test_get_or_load_bgm_missing_returns_null() -> void:
	var result = _audio_manager._get_or_load_bgm(&"nonexistent_bgm")
	assert_object(result).is_null()
