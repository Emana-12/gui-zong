## AccessibilityManager — 无障碍设置管理系统
##
## 管理所有无障碍设置：独立音量控制、闪屏减弱、运动减弱、
## 亮度调节、按住/切换闪避模式。设置持久化到 user://accessibility.cfg。
##
## 设计参考:
## - design/accessibility-requirements.md
## - docs/architecture/adr-0015-hud-ui-architecture.md
##
## @see S02-05
class_name AccessibilityManager
extends Node

## 配置文件路径
const CONFIG_PATH: String = "user://accessibility.cfg"

## 音量范围
const VOLUME_MIN: float = 0.0
const VOLUME_MAX: float = 100.0

## 亮度范围（-25% 到 +25%）
const BRIGHTNESS_MIN: float = -0.25
const BRIGHTNESS_MAX: float = 0.25

## 音频总线名称
const BUS_MUSIC: String = "Music"
const BUS_SFX: String = "SFX"

# ─── 信号 ───────────────────────────────────────────────────────────────────────

## 音量变更 (bus_name: String, volume_percent: float)
signal volume_changed(bus_name: String, volume_percent: float)

## 运动减弱模式变更
signal motion_reduction_changed(enabled: bool)

## 闪屏减弱模式变更
signal flash_reduction_changed(enabled: bool)

## 按住切换模式变更
signal hold_to_toggle_changed(enabled: bool)

## 亮度变更
signal brightness_changed(brightness: float)

## 光敏警告已显示（UI 系统监听此信号显示警告界面）
signal photosensitivity_warning_shown()

## 光敏警告已跳过/确认
signal photosensitivity_warning_dismissed()

# ─── 设置状态 ─────────────────────────────────────────────────────────────────────

## 音乐音量 (0-100)
var music_volume: float = 80.0

## 音效音量 (0-100)
var sfx_volume: float = 100.0

## 运动减弱模式（减弱/关闭屏幕震动和顿帧）
var reduced_motion: bool = false

## 闪屏减弱模式（减弱闪烁 VFX）
var flash_reduction: bool = false

## 按住切换模式（闪避无需长按）
var hold_to_toggle: bool = false

## 亮度偏移 (-0.25 到 +0.25)
var brightness: float = 0.0

## 光敏警告是否已确认（首次启动需显示）
var photosensitivity_acknowledged: bool = false

# ─── 内部状态 ─────────────────────────────────────────────────────────────────────

## 配置文件引用
var _config: ConfigFile = ConfigFile.new()

## 运动减弱系数（0.0 = 完全关闭，0.5 = 减弱，1.0 = 正常）
var _motion_scale: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	_load_settings()
	_apply_all_settings()


## 设置音频总线（首次运行时创建 Music 和 SFX 总线）
func _setup_audio_buses() -> void:
	# 检查 Music 总线是否已存在
	if AudioServer.get_bus_index(BUS_MUSIC) == -1:
		var music_idx := AudioServer.bus_count
		AudioServer.add_bus(music_idx)
		AudioServer.set_bus_name(music_idx, BUS_MUSIC)
		AudioServer.set_bus_send(music_idx, "Master")

	# 检查 SFX 总线是否已存在
	if AudioServer.get_bus_index(BUS_SFX) == -1:
		var sfx_idx := AudioServer.bus_count
		AudioServer.add_bus(sfx_idx)
		AudioServer.set_bus_name(sfx_idx, BUS_SFX)
		AudioServer.set_bus_send(sfx_idx, "Master")


## 从配置文件加载设置
func _load_settings() -> void:
	var err := _config.load(CONFIG_PATH)
	if err != OK:
		# 首次运行 — 使用默认值，无需加载
		return

	music_volume = _config.get_value("audio", "music_volume", 80.0)
	sfx_volume = _config.get_value("audio", "sfx_volume", 100.0)
	reduced_motion = _config.get_value("visual", "reduced_motion", false)
	flash_reduction = _config.get_value("visual", "flash_reduction", false)
	hold_to_toggle = _config.get_value("input", "hold_to_toggle", false)
	brightness = _config.get_value("visual", "brightness", 0.0)
	photosensitivity_acknowledged = _config.get_value("visual", "photosensitivity_acknowledged", false)


## 将设置保存到配置文件
func _save_settings() -> void:
	_config.set_value("audio", "music_volume", music_volume)
	_config.set_value("audio", "sfx_volume", sfx_volume)
	_config.set_value("visual", "reduced_motion", reduced_motion)
	_config.set_value("visual", "flash_reduction", flash_reduction)
	_config.set_value("input", "hold_to_toggle", hold_to_toggle)
	_config.set_value("visual", "brightness", brightness)
	_config.set_value("visual", "photosensitivity_acknowledged", photosensitivity_acknowledged)
	_config.save(CONFIG_PATH)


## 应用所有设置到引擎
func _apply_all_settings() -> void:
	_apply_volume(BUS_MUSIC, music_volume)
	_apply_volume(BUS_SFX, sfx_volume)
	_apply_motion_scale()
	_apply_brightness()


## 将百分比音量应用到指定总线
func _apply_volume(bus_name: String, volume_percent: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		push_warning("[AccessibilityManager] Audio bus not found: %s" % bus_name)
		return
	# 线性百分比转 dB：0% = -60dB (静音), 100% = 0dB
	var db: float
	if volume_percent <= 0.0:
		db = -60.0
	else:
		db = linear_to_db(clampf(volume_percent / 100.0, 0.0, 1.0))
	AudioServer.set_bus_volume_db(idx, db)


## 更新运动减弱系数
func _apply_motion_scale() -> void:
	_motion_scale = 0.0 if reduced_motion else 1.0


## 应用亮度设置（通过 Environment 调整）
func _apply_brightness() -> void:
	# 亮度通过 WorldEnvironment 的 environment.adjustment_brightness 实现
	# 如果没有 WorldEnvironment，则跳过（Web 端可能需要 CSS filter 备选方案）
	var world_env := get_tree().current_scene
	if world_env == null:
		return
	# 遍历场景树查找 WorldEnvironment
	for child in world_env.get_children():
		if child is WorldEnvironment:
			var env: Environment = child.environment
			if env:
				env.adjustment_enabled = true
				env.adjustment_brightness = 1.0 + brightness
				return
	# 如果当前场景没有 WorldEnvironment，尝试全局查找
	var we := get_tree().get_first_node_in_group("world_environment")
	if we and we is WorldEnvironment:
		var env: Environment = we.environment
		if env:
			env.adjustment_enabled = true
			env.adjustment_brightness = 1.0 + brightness

# ─── 公共 API ─────────────────────────────────────────────────────────────────────

## 设置音乐音量 (0-100)
func set_music_volume(volume_percent: float) -> void:
	music_volume = clampf(volume_percent, VOLUME_MIN, VOLUME_MAX)
	_apply_volume(BUS_MUSIC, music_volume)
	_save_settings()
	volume_changed.emit(BUS_MUSIC, music_volume)


## 设置音效音量 (0-100)
func set_sfx_volume(volume_percent: float) -> void:
	sfx_volume = clampf(volume_percent, VOLUME_MIN, VOLUME_MAX)
	_apply_volume(BUS_SFX, sfx_volume)
	_save_settings()
	volume_changed.emit(BUS_SFX, sfx_volume)


## 设置运动减弱模式
func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	_apply_motion_scale()
	_save_settings()
	motion_reduction_changed.emit(enabled)


## 设置闪屏减弱模式
func set_flash_reduction(enabled: bool) -> void:
	flash_reduction = enabled
	_save_settings()
	flash_reduction_changed.emit(enabled)


## 设置按住切换模式（闪避）
func set_hold_to_toggle(enabled: bool) -> void:
	hold_to_toggle = enabled
	_save_settings()
	hold_to_toggle_changed.emit(enabled)


## 设置亮度偏移 (-0.25 到 +0.25)
func set_brightness(value: float) -> void:
	brightness = clampf(value, BRIGHTNESS_MIN, BRIGHTNESS_MAX)
	_apply_brightness()
	_save_settings()
	brightness_changed.emit(brightness)


## 确认光敏警告（首次启动后调用）
func acknowledge_photosensitivity_warning() -> void:
	photosensitivity_acknowledged = true
	_save_settings()
	photosensitivity_warning_dismissed.emit()


## 显示光敏警告（如果尚未确认）
## 返回 true 表示需要显示警告
func check_photosensitivity_warning() -> bool:
	if not photosensitivity_acknowledged:
		photosensitivity_warning_shown.emit()
		return true
	return false


## 获取运动减弱系数（供 CameraController 等系统查询）
## 返回 0.0（减弱模式）或 1.0（正常模式）
func get_motion_scale() -> float:
	return _motion_scale


## 获取闪屏减弱系数（供 VFX 系统查询）
## 返回 0.0（减弱模式）或 1.0（正常模式）
func get_flash_scale() -> float:
	return 0.0 if flash_reduction else 1.0


## 是否需要按住切换模式
func is_hold_to_toggle() -> bool:
	return hold_to_toggle


## 重置所有设置为默认值
func reset_to_defaults() -> void:
	music_volume = 80.0
	sfx_volume = 100.0
	reduced_motion = false
	flash_reduction = false
	hold_to_toggle = false
	brightness = 0.0
	photosensitivity_acknowledged = false
	_apply_all_settings()
	_save_settings()
	volume_changed.emit(BUS_MUSIC, music_volume)
	volume_changed.emit(BUS_SFX, sfx_volume)
	motion_reduction_changed.emit(reduced_motion)
	flash_reduction_changed.emit(flash_reduction)
	hold_to_toggle_changed.emit(hold_to_toggle)
	brightness_changed.emit(brightness)
