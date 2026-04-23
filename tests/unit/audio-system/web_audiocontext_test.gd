## web_audiocontext_test.gd — Story 004 测试
##
## 验证 Web AudioContext 初始化：init_audio_context()、首次交互自动初始化、
## 非 Web 平台无副作用。
## ADR-0004: Audio System Architecture
class_name WebAudiocontextTest
extends GdUnitTestSuite


## 验证 init_audio_context 存在且可调用 (AC-1)
func test_init_audio_context_exists() -> void:
	var am := auto_free(AudioManager.new())
	am.init_audio_context()
	assert_bool(am.is_audio_context_initialized()).is_true()


## 验证 init_audio_context 幂等 (AC-1 edge case)
func test_init_audio_context_idempotent() -> void:
	var am := auto_free(AudioManager.new())
	am.init_audio_context()
	assert_bool(am.is_audio_context_initialized()).is_true()
	am.init_audio_context()
	assert_bool(am.is_audio_context_initialized()).is_true()
	am.init_audio_context()
	assert_bool(am.is_audio_context_initialized()).is_true()


## 验证非 Web 平台 _ready 后自动初始化 (AC-5)
func test_non_web_auto_init_on_ready() -> void:
	var am := auto_free(AudioManager.new())
	# 模拟 _ready 中非 Web 平台的逻辑
	am._is_web = false
	am._audio_context_initialized = false
	am.init_audio_context()
	assert_bool(am.is_audio_context_initialized()).is_true()


## 验证 init_audio_context 不报错即无副作用 (AC-5)
func test_init_audio_context_no_side_effects() -> void:
	var am := auto_free(AudioManager.new())
	am.init_audio_context()
	am.init_audio_context()
	# 无 crash 即通过
	assert_bool(true).is_true()


## 验证 Web 模式下未初始化时 play_sfx 静默失败 (AC-2)
func test_web_mode_play_sfx_silent_fail() -> void:
	var am := auto_free(AudioManager.new())
	am._is_web = true
	am._audio_context_initialized = false
	# 不应抛出异常
	am.play_sfx(&"hit_metal", 0.8, 1.0)
	assert_bool(true).is_true()


## 验证 Web 模式下未初始化时 play_loop 静默失败 (AC-2 edge case)
func test_web_mode_play_loop_silent_fail() -> void:
	var am := auto_free(AudioManager.new())
	am._is_web = true
	am._audio_context_initialized = false
	am.play_loop(&"ambient", 0.5)
	assert_bool(true).is_true()


## 验证 Web 模式下未初始化时 play_bgm 静默失败 (AC-2 edge case)
func test_web_mode_play_bgm_silent_fail() -> void:
	var am := auto_free(AudioManager.new())
	am._is_web = true
	am._audio_context_initialized = false
	am.play_bgm(&"boss_theme", 1.0)
	assert_bool(true).is_true()


## 验证初始化后播放正常 (AC-4)
func test_play_after_init() -> void:
	var am := auto_free(AudioManager.new())
	am._is_web = false
	am.init_audio_context()
	assert_bool(am.is_audio_context_initialized()).is_true()
	# 文件不存在会 warning 但不 crash
	am.play_sfx(&"hit_metal", 0.8, 1.0)
	assert_bool(true).is_true()


## 验证 _input 中 InputEventMouseButton 触发初始化 (AC-3)
func test_input_mouse_click_triggers_init() -> void:
	var am := auto_free(AudioManager.new())
	am._is_web = true
	am._audio_context_initialized = false
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	am._input(event)
	assert_bool(am.is_audio_context_initialized()).is_true()


## 验证 _input 中 InputEventKey 触发初始化 (AC-3)
func test_input_key_triggers_init() -> void:
	var am := auto_free(AudioManager.new())
	am._is_web = true
	am._audio_context_initialized = false
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_SPACE
	am._input(event)
	assert_bool(am.is_audio_context_initialized()).is_true()


## 验证已初始化后 _input 不重复初始化 (AC-3 edge case)
func test_input_after_init_no_reinit() -> void:
	var am := auto_free(AudioManager.new())
	am._is_web = true
	am.init_audio_context()
	assert_bool(am.is_audio_context_initialized()).is_true()
	# 再次输入不应报错
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ENTER
	am._input(event)
	assert_bool(am.is_audio_context_initialized()).is_true()
