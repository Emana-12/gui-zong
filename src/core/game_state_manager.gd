## GameStateManager — 游戏状态有限状态机 (Autoload 单例)
##
## 管理游戏全局状态: TITLE, COMBAT, INTERMISSION, DEATH, RESTART。
## 所有状态转换通过 [method change_state] 进行，受转换矩阵约束。
##
## 注册方式: Project Settings > Autoload，命名为 GameStateManager。
##
## 信号:
## - [signal state_changed]: 每次状态转换时广播 (old_state, new_state)
##
## RESTART 状态特性:
## 进入 RESTART 后会立即（同一帧）自动转换为 COMBAT。
## 外部系统会观察到两次信号: (DEATH→RESTART) 和 (RESTART→COMBAT)。
##
## @experimental
extends Node

## 游戏状态枚举
enum State {
	TITLE,      ## 标题画面
	COMBAT,     ## 战斗中
	INTERMISSION, ## 波间休息
	DEATH,      ## 玩家死亡
	RESTART,    ## 重新开始（内部自动转 COMBAT）
}

## 状态转换时发出。参数: (old_state: State, new_state: State)
signal state_changed(old_state: State, new_state: State)

## 死亡延迟时间（秒），可在编辑器中调整。
## 进入 DEATH 后需等待此时间才允许转到 RESTART。
@export_range(0.1, 5.0, 0.1) var death_delay: float = 0.5

## 当前状态（只读，通过 get_current_state() 访问）
var _current_state: State = State.TITLE

## DEATH 状态下是否已完成死亡延迟等待
var _death_delay_elapsed: bool = false

## 合法状态转换矩阵。键为源状态，值为允许的目标状态数组。
var _valid_transitions: Dictionary = {
	State.TITLE: [State.COMBAT],
	State.COMBAT: [State.INTERMISSION, State.DEATH],
	State.INTERMISSION: [State.COMBAT, State.DEATH],
	State.DEATH: [State.RESTART],
	State.RESTART: [State.COMBAT],
}

## 死亡延迟计时器（_ready 中创建）
var _death_timer: Timer

## 重入保护锁 — 防止信号监听者间接触发 change_state 导致无限递归
var _transitioning: bool = false

## 暂停状态变化时发出。参数: (paused: bool)
signal game_paused(paused: bool)

## 是否在浏览器标签页失去焦点时自动暂停
@export var pause_on_focus_loss: bool = true

## 当前暂停状态
var _is_paused: bool = false


func _ready() -> void:
	# 确保暂停状态下仍能响应 resume_game()
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 创建死亡延迟计时器
	_death_timer = Timer.new()
	_death_timer.one_shot = true
	_death_timer.wait_time = death_delay
	_death_timer.timeout.connect(_on_death_timer_timeout)
	# 暂停期间死亡延迟继续计时
	_death_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_death_timer)

	_death_delay_elapsed = false


## 尝试将状态转换为 [param new_state]。
## [br][br]
## 返回 [code]true[/code] 表示转换成功，[code]false[/code] 表示被拒绝。
## 合法转换由 [member _valid_transitions] 矩阵约束。
## [br][br]
## 特殊行为:
## - RESTART 状态: 进入后立即自动转为 COMBAT（同一帧内发出两次信号）
## - DEATH 状态: 启动死亡延迟计时器，延迟未完成前拒绝 RESTART
## - 同状态: 返回 false，不发出信号
func change_state(new_state: State) -> bool:
	# 重入保护 — 防止信号监听者递归调用
	if _transitioning:
		push_warning("Recursive state change blocked: attempted %s -> %s during transition" % [
			State.keys()[_current_state],
			State.keys()[new_state],
		])
		return false

	# 同状态不转换
	if new_state == _current_state:
		return false

	# DEATH 状态特殊处理：检查死亡延迟是否完成
	if _current_state == State.DEATH and new_state == State.RESTART:
		if not _death_delay_elapsed:
			return false

	# 转换矩阵校验
	var allowed: Array = _valid_transitions.get(_current_state, [])
	if new_state not in allowed:
		push_warning("Invalid state transition: %s -> %s" % [
			State.keys()[_current_state],
			State.keys()[new_state],
		])
		return false

	# 执行转换
	_transitioning = true
	var old_state: State = _current_state
	_current_state = new_state
	state_changed.emit(old_state, new_state)
	_transitioning = false

	# 进入 DEATH 时：启动延迟计时器，重置完成标记
	if new_state == State.DEATH:
		_death_delay_elapsed = false
		_death_timer.wait_time = death_delay
		_death_timer.start()

	# RESTART 特性：同一帧自动转为 COMBAT
	if new_state == State.RESTART:
		change_state(State.COMBAT)

	return true


## 返回当前游戏状态。
func get_current_state() -> State:
	return _current_state


## 死亡延迟计时器回调
func _on_death_timer_timeout() -> void:
	_death_delay_elapsed = true


## 暂停游戏。
## [br][br]
## 冻结所有节点的 [method Node._process] 和 [method Node._physics_process]
##（除 [constant Node.PROCESS_MODE_ALWAYS] 节点外）。
## [br][br]
## 发出 [signal game_paused] 信号，参数为 [code]true[/code]。
## [br][br]
## 重复调用不会产生副作用。
func pause_game() -> void:
	if _is_paused:
		return
	_is_paused = true
	get_tree().paused = true
	game_paused.emit(true)


## 恢复游戏。
## [br][br]
## 解除 [method pause_game] 造成的冻结。
## 发出 [signal game_paused] 信号，参数为 [code]false[/code]。
## [br][br]
## 未暂停时调用不会产生副作用。
func resume_game() -> void:
	if not _is_paused:
		return
	_is_paused = false
	get_tree().paused = false
	game_paused.emit(false)


## 返回当前是否处于暂停状态。
func is_paused() -> bool:
	return _is_paused


## 处理应用焦点通知（Web 平台标签页切换）。
func _notification(what: int) -> void:
	if not pause_on_focus_loss:
		return
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			pause_game()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			resume_game()


## 外部系统连接此方法以接收 wave_completed 信号。
## 仅在 COMBAT 状态下有效，其他状态静默忽略。
## [br][br]
## [param wave_number]: 完成的波次编号，由竞技场波次系统传递。
func _on_wave_completed(wave_number: int) -> void:
	if _current_state != State.COMBAT:
		return
	change_state(State.INTERMISSION)
