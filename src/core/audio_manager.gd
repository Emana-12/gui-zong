## AudioManager — 音频系统管理器
##
## Foundation 层节点，通过 group "audio_manager" 访问。
## 非 Autoload（Autoload 上限 = 3），场景节点 + group 模式。
##
## 职责：
##   - 管理 3 条音频总线：Master → SFX + BGM
##   - SFX 播放（预加载、实例限制、音量/pitch）
##   - 循环音效管理（play_loop / stop_loop）
##   - BGM 管理（crossfade、流式加载）
##   - Web 平台 AudioContext 初始化
##
## 使用方式：
##   var audio_manager = get_tree().get_first_node_in_group("audio_manager")
##   audio_manager.play_sfx("hit_metal", 0.8, 1.0)
##
## 信号：
##   sfx_played(name) — 音效播放时发出
##   bgm_changed(name) — BGM 切换时发出
##   loop_started(name) — 循环音效启动时发出
##   loop_stopped(name) — 循环音效停止时发出
##
## ADR-0004: Audio System Architecture
## Stories: 001 (总线) + 002 (SFX) + 003 (BGM/循环) + 004 (Web AudioContext)
class_name AudioManager
extends Node

## SFX 播放时发出
signal sfx_played(name: StringName)

## BGM 切换时发出
signal bgm_changed(name: StringName)

## 循环音效启动时发出
signal loop_started(name: StringName)

## 循环音效停止时发出
signal loop_stopped(name: StringName)

## --- 配置常量 ---

## 音频总线名称
const MASTER_BUS := &"Master"
const SFX_BUS := &"SFX"
const BGM_BUS := &"BGM"

## 路径
const SFX_PATH := "res://assets/audio/sfx/"
const BGM_PATH := "res://assets/audio/bgm/"

## SFX 实例限制
const MAX_INSTANCES_PER_SFX := 3
const MAX_TOTAL_SFX_INSTANCES := 8

## BGM crossfade 时长（秒）
const BGM_CROSSFADE_DURATION := 1.0

## 最小音量线性值（低于此值视为静音）
const MIN_VOLUME_LINEAR := 0.0001

## --- 内部状态 ---

## SFX 预加载缓存: name -> AudioStream
var _sfx_cache: Dictionary = {}

## SFX 实例池: name -> Array[AudioStreamPlayer]
var _sfx_instances: Dictionary = {}

## 当前活跃的 SFX 实例总数
var _total_active_instances: int = 0

## 循环音效池: name -> AudioStreamPlayer
var _loop_instances: Dictionary = {}

## BGM 播放器
var _bgm_current: AudioStreamPlayer
var _bgm_next: AudioStreamPlayer

## BGM 资源缓存: name -> AudioStream
var _bgm_cache: Dictionary = {}

## BGM crossfade Tween
var _bgm_tween: Tween = null

## Web AudioContext 初始化标志
var _audio_context_initialized: bool = false

## 是否为 Web 平台
var _is_web: bool = false

## Web 模式下输入监听是否已连接
var _input_listener_connected: bool = false


## --- 生命周期 ---

func _ready() -> void:
	# 添加到 audio_manager group
	add_to_group("audio_manager")

	# 创建 BGM 播放器
	_bgm_current = AudioStreamPlayer.new()
	_bgm_current.bus = BGM_BUS
	_bgm_current.name = "BGMBus_Current"
	add_child(_bgm_current)

	_bgm_next = AudioStreamPlayer.new()
	_bgm_next.bus = BGM_BUS
	_bgm_next.name = "BGMBus_Next"
	add_child(_bgm_next)

	# 平台检测
	_is_web = OS.has_feature("web")

	# 初始化音频总线
	_setup_audio_buses()

	# Web 音频初始化
	if _is_web:
		_audio_context_initialized = false
		_connect_input_listener()
	else:
		# 非 Web 平台直接初始化
		init_audio_context()


func _input(event: InputEvent) -> void:
	# Web 平台：首次用户交互时自动初始化 AudioContext
	if _audio_context_initialized:
		return
	if event is InputEventMouseButton or event is InputEventKey:
		init_audio_context()


## --- 公共 API: 音频总线 ---

## 初始化 AudioContext。
## Web 平台需要用户手势后调用，非 Web 平台无副作用。
## 幂等：多次调用只执行一次。
func init_audio_context() -> void:
	if _audio_context_initialized:
		return
	_audio_context_initialized = true
	_disconnect_input_listener()


## 设置指定总线的音量。
## [param bus_name] 总线名称（MASTER_BUS / SFX_BUS / BGM_BUS）
## [param volume] 线性音量，范围 0-1
func set_bus_volume(bus_name: StringName, volume: float) -> void:
	var clamped := clampf(volume, 0.0, 1.0)
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		push_warning("AudioManager: Audio bus '%s' not found." % bus_name)
		return
	if clamped < MIN_VOLUME_LINEAR:
		AudioServer.set_bus_volume_db(bus_idx, -80.0)
	else:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clamped))


## 获取指定总线的线性音量。
## [param bus_name] 总线名称
## [return] 线性音量 0-1
func get_bus_volume(bus_name: StringName) -> float:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return 0.0
	var db := AudioServer.get_bus_volume_db(bus_idx)
	if db <= -79.0:
		return 0.0
	return db_to_linear(db)


## --- 公共 API: SFX 播放 ---

## 播放一个 SFX 音效。
## [param name] 音效名称（对应 res://assets/audio/sfx/{name}.ogg）
## [param volume] 线性音量 0-1，默认 1.0
## [param pitch] 音调倍率，默认 1.0
func play_sfx(name: StringName, volume: float = 1.0, pitch: float = 1.0) -> void:
	if not _audio_context_initialized:
		return

	# 实例数检查
	if _get_active_sfx_instance_count(name) >= MAX_INSTANCES_PER_SFX:
		return
	if _total_active_instances >= MAX_TOTAL_SFX_INSTANCES:
		return

	# 加载/获取音频流
	var stream: AudioStream = _get_or_load_sfx(name)
	if stream == null:
		return

	# 创建播放实例
	var clamped_volume := clampf(volume, 0.0, 1.0)
	var clamped_pitch := clampf(pitch, 0.1, 4.0)
	var player := _acquire_sfx_player(name)
	player.stream = stream
	player.volume_db = linear_to_db(clamped_volume) if clamped_volume >= MIN_VOLUME_LINEAR else -80.0
	player.pitch_scale = clamped_pitch
	player.play()
	sfx_played.emit(name)


## 播放循环音效。
## [param name] 循环音效名称
## [param volume] 线性音量 0-1，默认 1.0
func play_loop(name: StringName, volume: float = 1.0) -> void:
	if not _audio_context_initialized:
		return

	# 已在播放则先停止
	if _loop_instances.has(name):
		stop_loop(name)

	var stream: AudioStream = _get_or_load_sfx(name)
	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.name = "Loop_%s" % name
	player.bus = SFX_BUS
	player.stream = stream
	var clamped := clampf(volume, 0.0, 1.0)
	player.volume_db = linear_to_db(clamped) if clamped >= MIN_VOLUME_LINEAR else -80.0

	# 确保音频流循环模式
	_set_loop_enabled(stream, true)

	player.play()
	add_child(player)
	_loop_instances[name] = player
	loop_started.emit(name)


## 停止循环音效。
## [param name] 循环音效名称
func stop_loop(name: StringName) -> void:
	if not _loop_instances.has(name):
		return
	var player: AudioStreamPlayer = _loop_instances[name]
	_loop_instances.erase(name)
	if is_instance_valid(player):
		player.stop()
		player.queue_free()
	loop_stopped.emit(name)


## --- 公共 API: BGM ---

## 播放 BGM，带 1 秒 crossfade。
## [param name] BGM 名称（对应 res://assets/audio/bgm/{name}.ogg）
## [param volume] 线性音量 0-1，默认 1.0
func play_bgm(name: StringName, volume: float = 1.0) -> void:
	if not _audio_context_initialized:
		return

	var stream: AudioStream = _get_or_load_bgm(name)
	if stream == null:
		return

	var clamped := clampf(volume, 0.0, 1.0)
	var target_db := linear_to_db(clamped) if clamped >= MIN_VOLUME_LINEAR else -80.0

	# 停止上一次 crossfade
	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()

	# 设置下一个播放器
	_bgm_next.stream = stream
	_bgm_next.volume_db = -80.0
	_bgm_next.play()

	# crossfade 动画
	_bgm_tween = create_tween()
	_bgm_tween.set_parallel(true)
	_bgm_tween.tween_property(_bgm_next, "volume_db", target_db, BGM_CROSSFADE_DURATION)

	# 淡出当前（如果有音频正在播放）
	if _bgm_current.playing:
		_bgm_tween.tween_property(_bgm_current, "volume_db", -80.0, BGM_CROSSFADE_DURATION)

	# crossfade 完成后清理旧 player
	_bgm_tween.chain()
	_bgm_tween.tween_callback(_on_bgm_crossfade_finished)

	bgm_changed.emit(name)


## 停止 BGM，带 1 秒淡出。
func stop_bgm() -> void:
	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()

	if not _bgm_current.playing and not _bgm_next.playing:
		return

	_bgm_tween = create_tween()
	_bgm_tween.set_parallel(true)

	if _bgm_current.playing:
		_bgm_tween.tween_property(_bgm_current, "volume_db", -80.0, BGM_CROSSFADE_DURATION)
	if _bgm_next.playing:
		_bgm_tween.tween_property(_bgm_next, "volume_db", -80.0, BGM_CROSSFADE_DURATION)

	_bgm_tween.chain()
	_bgm_tween.tween_callback(_on_bgm_fadeout_finished)


## 查询 AudioContext 是否已初始化。
func is_audio_context_initialized() -> bool:
	return _audio_context_initialized


## 获取已预加载的 SFX 名称列表。
func get_preloaded_sfx() -> Array[StringName]:
	return Array(_sfx_cache.keys(), TYPE_STRING_NAME, &"", null)


## 获取已预加载的 BGM 名称列表。
func get_preloaded_bgm() -> Array[StringName]:
	return Array(_bgm_cache.keys(), TYPE_STRING_NAME, &"", null)


## --- 内部方法: 音频总线 ---

func _setup_audio_buses() -> void:
	# 检查 Master 总线是否存在（始终存在）
	var master_idx := AudioServer.get_bus_index(MASTER_BUS)
	if master_idx == -1:
		push_error("AudioManager: Master bus not found. Audio system cannot initialize.")
		return

	# 创建 SFX 总线
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, SFX_BUS)
		AudioServer.set_bus_send(AudioServer.get_bus_index(SFX_BUS), MASTER_BUS)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(SFX_BUS), 0.0)

	# 创建 BGM 总线
	if AudioServer.get_bus_index(BGM_BUS) == -1:
		AudioServer.add_bus(AudioServer.get_bus_count())
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, BGM_BUS)
		AudioServer.set_bus_send(AudioServer.get_bus_index(BGM_BUS), MASTER_BUS)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BGM_BUS), 0.0)


## --- 内部方法: SFX ---

func _get_or_load_sfx(name: StringName) -> AudioStream:
	if _sfx_cache.has(name):
		return _sfx_cache[name]
	var path := SFX_PATH + name + ".ogg"
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: SFX '%s' not found at '%s'." % [name, path])
		return null
	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("AudioManager: Failed to load SFX '%s'." % name)
		return null
	_sfx_cache[name] = stream
	return stream


func _acquire_sfx_player(name: StringName) -> AudioStreamPlayer:
	# 尝试复用已播放完成的实例
	if _sfx_instances.has(name):
		for player: AudioStreamPlayer in _sfx_instances[name]:
			if not player.playing:
				return player

	# 创建新实例
	var player := AudioStreamPlayer.new()
	player.bus = SFX_BUS
	player.name = "SFX_%s_%d" % [name, _total_active_instances]
	player.finished.connect(_on_sfx_finished.bind(player, name))
	add_child(player)

	if not _sfx_instances.has(name):
		_sfx_instances[name] = []
	(_sfx_instances[name] as Array).append(player)
	_total_active_instances += 1
	return player


func _get_active_sfx_instance_count(name: StringName) -> int:
	if not _sfx_instances.has(name):
		return 0
	var count := 0
	for player: AudioStreamPlayer in _sfx_instances[name]:
		if player.playing:
			count += 1
	return count


func _on_sfx_finished(player: AudioStreamPlayer, name: StringName) -> void:
	_total_active_instances = maxi(0, _total_active_instances - 1)
	# 留在池中复用，不删除节点


## --- 内部方法: 循环音效 ---

func _set_loop_enabled(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = enabled
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED
	elif stream is AudioStreamMP3:
		stream.loop = enabled


## --- 内部方法: BGM ---

func _get_or_load_bgm(name: StringName) -> AudioStream:
	if _bgm_cache.has(name):
		return _bgm_cache[name]
	var path := BGM_PATH + name + ".ogg"
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: BGM '%s' not found at '%s'." % [name, path])
		return null
	var stream: AudioStream = load(path)
	if stream == null:
		push_warning("AudioManager: Failed to load BGM '%s'." % name)
		return null
	_bgm_cache[name] = stream
	return stream


func _on_bgm_crossfade_finished() -> void:
	_bgm_current.stop()
	_bgm_current.stream = null
	# 交换引用
	var temp := _bgm_current
	_bgm_current = _bgm_next
	_bgm_next = temp


func _on_bgm_fadeout_finished() -> void:
	_bgm_current.stop()
	_bgm_current.stream = null
	_bgm_next.stop()
	_bgm_next.stream = null


## --- 内部方法: Web AudioContext ---

func _connect_input_listener() -> void:
	if _input_listener_connected:
		return
	_input_listener_connected = true
	# set_process_input 在 _ready() 中已默认启用
	# _input() 会自动接收输入事件


func _disconnect_input_listener() -> void:
	_input_listener_connected = false
	# 不需要显式断开，_input() 会检查 _audio_context_initialized 标志
