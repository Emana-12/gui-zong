@warning_ignore_start("inferred_declaration")
# S02-05: Accessibility Basic Tier — Unit Tests
# Tests for AccessibilityManager public API
# Ref: production/epics/.../sprint-02.md S02-05
extends GdUnitTestSuite

var _manager: AccessibilityManager


func before_test() -> void:
	_manager = auto_free(AccessibilityManager.new())
	# Reset to known defaults before each test
	_manager.music_volume = 80.0
	_manager.sfx_volume = 100.0
	_manager.reduced_motion = false
	_manager.flash_reduction = false
	_manager.hold_to_toggle = false
	_manager.brightness = 0.0
	_manager.photosensitivity_acknowledged = false


# ─── Volume Control ─────────────────────────────────────────────────────────

func test_set_music_volume_clamps_to_range() -> void:
	_manager.set_music_volume(150.0)
	assert_float(_manager.music_volume).is_equal(100.0)

	_manager.set_music_volume(-10.0)
	assert_float(_manager.music_volume).is_equal(0.0)

	_manager.set_music_volume(50.0)
	assert_float(_manager.music_volume).is_equal(50.0)


func test_set_sfx_volume_clamps_to_range() -> void:
	_manager.set_sfx_volume(200.0)
	assert_float(_manager.sfx_volume).is_equal(100.0)

	_manager.set_sfx_volume(-5.0)
	assert_float(_manager.sfx_volume).is_equal(0.0)

	_manager.set_sfx_volume(75.0)
	assert_float(_manager.sfx_volume).is_equal(75.0)


func test_set_music_volume_emits_signal() -> void:
	var signal_monitor := monitor_signals(_manager)
	_manager.set_music_volume(60.0)
	assert_signal(signal_monitor).is_emitted("volume_changed", ["Music", 60.0])


func test_set_sfx_volume_emits_signal() -> void:
	var signal_monitor := monitor_signals(_manager)
	_manager.set_sfx_volume(80.0)
	assert_signal(signal_monitor).is_emitted("volume_changed", ["SFX", 80.0])


# ─── Motion Reduction ───────────────────────────────────────────────────────

func test_set_reduced_motion_enables() -> void:
	_manager.set_reduced_motion(true)
	assert_bool(_manager.reduced_motion).is_true()
	assert_float(_manager.get_motion_scale()).is_equal(0.0)


func test_set_reduced_motion_disables() -> void:
	_manager.set_reduced_motion(true)
	_manager.set_reduced_motion(false)
	assert_bool(_manager.reduced_motion).is_false()
	assert_float(_manager.get_motion_scale()).is_equal(1.0)


func test_motion_reduction_emits_signal() -> void:
	var signal_monitor := monitor_signals(_manager)
	_manager.set_reduced_motion(true)
	assert_signal(signal_monitor).is_emitted("motion_reduction_changed", [true])


# ─── Flash Reduction ────────────────────────────────────────────────────────

func test_set_flash_reduction_enables() -> void:
	_manager.set_flash_reduction(true)
	assert_bool(_manager.flash_reduction).is_true()
	assert_float(_manager.get_flash_scale()).is_equal(0.0)


func test_set_flash_reduction_disables() -> void:
	_manager.set_flash_reduction(true)
	_manager.set_flash_reduction(false)
	assert_bool(_manager.flash_reduction).is_false()
	assert_float(_manager.get_flash_scale()).is_equal(1.0)


func test_flash_reduction_emits_signal() -> void:
	var signal_monitor := monitor_signals(_manager)
	_manager.set_flash_reduction(true)
	assert_signal(signal_monitor).is_emitted("flash_reduction_changed", [true])


# ─── Hold to Toggle ─────────────────────────────────────────────────────────

func test_set_hold_to_toggle_enables() -> void:
	_manager.set_hold_to_toggle(true)
	assert_bool(_manager.hold_to_toggle).is_true()
	assert_bool(_manager.is_hold_to_toggle()).is_true()


func test_set_hold_to_toggle_disables() -> void:
	_manager.set_hold_to_toggle(true)
	_manager.set_hold_to_toggle(false)
	assert_bool(_manager.hold_to_toggle).is_false()
	assert_bool(_manager.is_hold_to_toggle()).is_false()


func test_hold_to_toggle_emits_signal() -> void:
	var signal_monitor := monitor_signals(_manager)
	_manager.set_hold_to_toggle(true)
	assert_signal(signal_monitor).is_emitted("hold_to_toggle_changed", [true])


# ─── Brightness ─────────────────────────────────────────────────────────────

func test_set_brightness_clamps_to_range() -> void:
	_manager.set_brightness(0.5)
	assert_float(_manager.brightness).is_equal(0.25)

	_manager.set_brightness(-0.5)
	assert_float(_manager.brightness).is_equal(-0.25)

	_manager.set_brightness(0.1)
	assert_float(_manager.brightness).is_equal(0.1)


func test_set_brightness_emits_signal() -> void:
	var signal_monitor := monitor_signals(_manager)
	_manager.set_brightness(0.15)
	assert_signal(signal_monitor).is_emitted("brightness_changed", [0.15])


# ─── Photosensitivity Warning ───────────────────────────────────────────────

func test_check_photosensitivity_warning_first_time() -> void:
	_manager.photosensitivity_acknowledged = false
	var signal_monitor := monitor_signals(_manager)
	var result := _manager.check_photosensitivity_warning()
	assert_bool(result).is_true()
	assert_signal(signal_monitor).is_emitted("photosensitivity_warning_shown")


func test_check_photosensitivity_warning_acknowledged() -> void:
	_manager.photosensitivity_acknowledged = true
	var result := _manager.check_photosensitivity_warning()
	assert_bool(result).is_false()


func test_acknowledge_photosensitivity_warning() -> void:
	var signal_monitor := monitor_signals(_manager)
	_manager.acknowledge_photosensitivity_warning()
	assert_bool(_manager.photosensitivity_acknowledged).is_true()
	assert_signal(signal_monitor).is_emitted("photosensitivity_warning_dismissed")


# ─── Reset to Defaults ──────────────────────────────────────────────────────

func test_reset_to_defaults_restores_all_values() -> void:
	_manager.set_music_volume(30.0)
	_manager.set_sfx_volume(50.0)
	_manager.set_reduced_motion(true)
	_manager.set_flash_reduction(true)
	_manager.set_hold_to_toggle(true)
	_manager.set_brightness(0.2)

	_manager.reset_to_defaults()

	assert_float(_manager.music_volume).is_equal(80.0)
	assert_float(_manager.sfx_volume).is_equal(100.0)
	assert_bool(_manager.reduced_motion).is_false()
	assert_bool(_manager.flash_reduction).is_false()
	assert_bool(_manager.hold_to_toggle).is_false()
	assert_float(_manager.brightness).is_equal(0.0)


# ─── Constants ──────────────────────────────────────────────────────────────

func test_volume_constants() -> void:
	assert_float(AccessibilityManager.VOLUME_MIN).is_equal(0.0)
	assert_float(AccessibilityManager.VOLUME_MAX).is_equal(100.0)


func test_brightness_constants() -> void:
	assert_float(AccessibilityManager.BRIGHTNESS_MIN).is_equal(-0.25)
	assert_float(AccessibilityManager.BRIGHTNESS_MAX).is_equal(0.25)
