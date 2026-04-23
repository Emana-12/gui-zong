## InputSystem — 输入映射与查询 API (Autoload 单例)
##
## 封装 Godot 内置 [Input] 单例，提供带禁用过滤的查询接口。
## 使用 [method Node._input] 回调捕获输入（比 [method Node._process] 少 1 帧 Web 延迟）。
##
## 注册方式: Project Settings > Autoload，命名为 InputSystem。
##
## 信号:
## - input_device_changed: 手柄连接/断开时发出（无参数）
##
## @experimental
extends Node

## 手柄连接状态变更时发出。无参数。
## 用于通知外部系统切换输入模式（如 UI 提示图标切换）。
signal input_device_changed

## 缓冲窗口帧数。攻击输入在此窗口内可被后续操作消费。
@export var buffer_window_frames: int = 6

## 被禁用的动作字典。键为动作名，值为 [code]true[/code] 表示禁用。
var _disabled_actions: Dictionary = {}

## 当前缓冲的攻击动作
var _buffered_action: StringName = &""

## 缓冲动作已持续帧数
var _buffer_frame_count: int = 0

## 所有已注册的动作名（_ready 时从 InputMap 收集）
var _all_actions: Array[StringName] = []


## GameStateManager 引用（用于 DEATH 状态清空缓冲）
var _game_state_manager: Node = null


func _ready() -> void:
	# 收集 InputMap 中所有注册的动作
	for action in InputMap.get_actions():
		_all_actions.append(action)

	# 连接手柄连接状态变更信号（AC-4: 手柄断开时自动切换到键盘模式）
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

	# 连接 GameStateManager 信号以处理 DEATH 状态
	if Engine.has_singleton("GameStateManager"):
		_game_state_manager = Engine.get_singleton("GameStateManager")
	elif GameStateManager:
		_game_state_manager = GameStateManager
	if _game_state_manager and _game_state_manager.has_signal("state_changed"):
		_game_state_manager.state_changed.connect(_on_game_state_changed)


## 捕获输入事件。仅缓冲攻击动作（以 "attack_" 开头）。
## [br][br]
## 使用 [method Node._input] 而非 [method Node._process]，
## 确保在渲染帧之前处理输入，减少 Web 平台 1 帧延迟。
func _input(event: InputEvent) -> void:
	for action in _all_actions:
		if _disabled_actions.get(action, false):
			continue
		if event.is_action_pressed(action):
			if action.begins_with("attack_"):
				_buffered_action = action
				_buffer_frame_count = 0


## 每帧递增缓冲计数，超时后清空缓冲。
func _process(_delta: float) -> void:
	if _buffered_action != &"":
		_buffer_frame_count += 1
		if _buffer_frame_count >= buffer_window_frames:
			_buffered_action = &""


## 返回动作是否正在被按下。
## [br][br]
## 委托给 [method Input.is_action_pressed]，但在返回前检查禁用过滤。
## 禁用的动作始终返回 [code]false[/code]。
func is_action_pressed(action: StringName) -> bool:
	if _disabled_actions.get(action, false):
		return false
	return Input.is_action_pressed(action)


## 返回动作是否在当前帧被按下（仅按下后第一帧返回 [code]true[/code]）。
## [br][br]
## 委托给 [method Input.is_action_just_pressed]，带禁用过滤。
func is_action_just_pressed(action: StringName) -> bool:
	if _disabled_actions.get(action, false):
		return false
	return Input.is_action_just_pressed(action)


## 返回动作是否在当前帧被释放（仅释放后第一帧返回 [code]true[/code]）。
## [br][br]
## 委托给 [method Input.is_action_just_released]，带禁用过滤。
## 禁用时不会触发释放事件——按住的键被禁用后，
## [method is_action_just_released] 返回 [code]false[/code]。
func is_action_just_released(action: StringName) -> bool:
	if _disabled_actions.get(action, false):
		return false
	return Input.is_action_just_released(action)


## 获取移动方向向量。
## [br][br]
## 使用 [method Input.get_vector] 从四个方向动作合成归一化向量。
## [method Input.get_vector] 自动应用 Input Map 中配置的死区：
## - 摇杆偏移 < deadzone 时返回 [code]Vector2.ZERO[/code]（AC-1）
## - 摇杆偏移 >= deadzone 时返回归一化方向向量（AC-2）
## 返回值长度不超过 1.0。
func get_move_direction() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


## 手柄连接状态变更回调（AC-4）。
## [br][br]
## 手柄断开时发出 [signal input_device_changed] 信号，通知外部系统切换输入模式。
## 参数 [param device] 为设备索引，[param connected] 为是否连接。
func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if not connected:
		# 手柄断开：重置所有输入状态
		_buffered_action = &""
		_buffer_frame_count = 0
	input_device_changed.emit()


func _on_game_state_changed(_old_state: int, new_state: int) -> void:
	# DEATH 状态清空攻击缓冲（Edge Case: 死亡时缓冲输入不执行）
	# GameStateManager.State.DEATH == 3
	if new_state == 3:
		_buffered_action = &""
		_buffer_frame_count = 0


## 获取当前缓冲的攻击动作。
## [br][br]
## 返回缓冲中的动作名，无缓冲时返回空 [StringName]。
## 获取后不清空缓冲（非消耗式）。
func get_buffered_action() -> StringName:
	# 防御性检查：若 GameStateManager 处于 DEATH 状态则清空缓冲
	if _game_state_manager and _game_state_manager.has_method("get_current_state"):
		if _game_state_manager.get_current_state() == 3:
			_buffered_action = &""
			_buffer_frame_count = 0
	return _buffered_action


## 启用或禁用指定动作。
## [br][br]
## 禁用后，[method is_action_pressed]、[method is_action_just_pressed]、
## [method is_action_just_released] 均返回 [code]false[/code]。
## [br][br]
## 禁用不会触发 [method is_action_just_released] 事件。
func enable_action(action: StringName, enabled: bool) -> void:
	_disabled_actions[action] = not enabled


## 设置缓冲窗口帧数。
## [br][br]
## [param frames]: 新的缓冲窗口帧数。设为 0 禁用缓冲。
func set_buffer_window(frames: int) -> void:
	buffer_window_frames = frames
