## PlayerController — 玩家角色控制器 (CharacterBody3D)
##
## 实现 6 状态 FSM（IDLE, MOVING, DODGING, DODGE_COOLDOWN, HIT_STUN, DEAD）。
## Story 001: 移动和自动朝向（IDLE <-> MOVING 转换）
## Story 002: 闪避和无敌帧（IDLE/MOVING -> DODGING -> DODGE_COOLDOWN -> IDLE）
## Story 003: 生命值和死亡（take_damage/heal, HIT_STUN, DEAD）
##
## 设计参考:
## - docs/architecture/adr-0010-player-controller-architecture.md
## - design/gdd/player-controller.md
## - production/epics/player-controller/story-001-movement.md
## - production/epics/player-controller/story-002-dodge.md
## - production/epics/player-controller/story-003-health-death.md
##
## 依赖:
## - GameStateManager (Autoload): 提供游戏状态和 state_changed 信号
## - InputSystem (Autoload): 提供 get_move_direction() 查询接口
##
## @see ADR-0010
class_name PlayerController
extends CharacterBody3D

## 移动速度（常量，无加速曲线）。单位：米/秒。
const MOVE_SPEED: float = 5.0

## 闪避速度。单位：米/秒。闪避距离 = 15.0 × 0.2 = 3.0 米。
const DODGE_SPEED: float = 15.0

## 敌人检测组名，用于查找最近敌人。
const ENEMIES_GROUP: StringName = &"enemies"

## 玩家控制器内部状态枚举。
## 全部 6 个状态定义于此，Story 001 仅实现 IDLE 和 MOVING 的转换逻辑。
enum State {
	IDLE,           ## 静止，等待输入
	MOVING,         ## 根据输入方向移动
	DODGING,        ## 闪避中（Story 002）
	DODGE_COOLDOWN, ## 闪避冷却（Story 002）
	HIT_STUN,       ## 受击硬直（Story 003）
	DEAD,           ## 死亡（Story 003）
}

## 当前控制器状态。
var _state: State = State.IDLE

## GameStateManager 引用。运行时通过 _ready() 获取，测试时通过 set_game_state_manager() 注入。
var _game_state_manager: Node = null

## InputSystem 引用。运行时通过 _ready() 获取，测试时通过 set_input_system() 注入。
var _input_system: Node = null

## 闪避方向（进入 DODGING 时锁定）。
var _dodge_direction: Vector3 = Vector3.ZERO

## 闪避已用时间（秒）。
var _dodge_elapsed: float = 0.0

## 闪避冷却已用时间（秒）。
var _cooldown_elapsed: float = 0.0

## 无敌状态标志。DODGING 期间为 true。
var _invincible: bool = false

## 闪避尝试次数（每次进入 DODGING 时 +1）。
var dodge_attempts: int = 0

## 闪避成功次数（每次 DODGING 完成（未被打断）时 +1）。
var dodge_successes: int = 0

## ── Health System (Story 003) ──────────────────────────────────────────────

## 生命值变更信号。参数：当前生命值, 最大生命值。
signal health_changed(new_health: int, max_health: int)

## 玩家死亡信号。
signal player_died

## 当前生命值。
var health: int = 3

## 最大生命值。
var max_health: int = 3

## HIT_STUN 已用时间（秒）。
var _hit_stun_elapsed: float = 0.0

## 受击无敌计时器已用时间（秒）。InvincibleTimer = 0.65s。
var _invincible_timer_elapsed: float = 0.0


func _ready() -> void:
	_resolve_dependencies()
	_connect_game_state_signals()


## 解析运行时依赖。测试时可跳过此方法，通过 setter 注入 mock。
func _resolve_dependencies() -> void:
	# GameStateManager: 先尝试 Engine 单例注册，再尝试 /root 路径
	if Engine.has_singleton("GameStateManager"):
		_game_state_manager = Engine.get_singleton("GameStateManager")
	elif GameStateManager:
		_game_state_manager = GameStateManager

	# InputSystem: 先尝试 Engine 单例注册，再尝试 /root 路径
	if Engine.has_singleton("InputSystem"):
		_input_system = Engine.get_singleton("InputSystem")
	elif InputSystem:
		_input_system = InputSystem


## 连接 GameStateManager 的 state_changed 信号。
## 若依赖未注入则跳过。
func _connect_game_state_signals() -> void:
	if _game_state_manager and _game_state_manager.has_signal("state_changed"):
		_game_state_manager.state_changed.connect(_on_game_state_changed)


## 注入 GameStateManager 引用（用于测试）。
func set_game_state_manager(manager: Node) -> void:
	# 断开旧信号
	if _game_state_manager and _game_state_manager.has_signal("state_changed"):
		if _game_state_manager.state_changed.is_connected(_on_game_state_changed):
			_game_state_manager.state_changed.disconnect(_on_game_state_changed)
	_game_state_manager = manager
	_connect_game_state_signals()


## 注入 InputSystem 引用（用于测试）。
func set_input_system(input_system: Node) -> void:
	_input_system = input_system


## 获取当前内部状态（只读）。
func get_state() -> State:
	return _state


## 物理帧处理。根据内部状态分发逻辑。
func _physics_process(delta: float) -> void:
	if not _is_gameplay_active():
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# 受击无敌计时器：在非 HIT_STUN 状态下继续倒计时（0.15s buffer）
	if _invincible and _state != State.HIT_STUN and _invincible_timer_elapsed > 0.0:
		_invincible_timer_elapsed += delta
		if _invincible_timer_elapsed >= 0.65:
			_invincible = false
			_invincible_timer_elapsed = 0.0

	match _state:
		State.IDLE:
			_process_idle(delta)
		State.MOVING:
			_process_moving(delta)
		State.DODGING:
			_process_dodging(delta)
		State.DODGE_COOLDOWN:
			_process_dodge_cooldown(delta)
		State.HIT_STUN:
			_process_hit_stun(delta)
		State.DEAD:
			_process_dead(delta)


## 检查游戏状态是否允许玩家控制器更新。
## 仅 COMBAT 状态（GameStateManager.State.COMBAT == 1）时返回 true。
func _is_gameplay_active() -> bool:
	if _game_state_manager == null:
		return true  # 依赖未注入时，允许默认行为（向后兼容）
	if not _game_state_manager.has_method("get_current_state"):
		return true
	return _game_state_manager.get_current_state() == 1  # State.COMBAT


## IDLE 状态处理：检查是否有移动输入，有则切换到 MOVING 并立即执行本帧移动。
func _process_idle(_delta: float) -> void:
	# 闪避输入优先于移动输入
	if _try_start_dodge():
		return

	var direction := _get_move_direction_3d()
	if direction.length_squared() > 0.0:
		_change_state(State.MOVING)
		# 立即执行本帧移动，避免状态切换导致的 1 帧延迟
		velocity = direction * MOVE_SPEED
		move_and_slide()
		_update_facing()
	else:
		velocity = Vector3.ZERO
		move_and_slide()


## MOVING 状态处理：应用移动并更新朝向。
func _process_moving(_delta: float) -> void:
	# 闪避输入优先于移动输入
	if _try_start_dodge():
		return

	var direction := _get_move_direction_3d()

	if direction.length_squared() <= 0.0:
		_change_state(State.IDLE)
		velocity = Vector3.ZERO
		move_and_slide()
		return

	velocity = direction * MOVE_SPEED
	move_and_slide()
	_update_facing()


## 获取 3D 移动方向。将 InputSystem 的 2D 向量映射到 XZ 平面。
## InputSystem.get_move_direction() 返回 Vector2(x, y)，
## 其中 x 对应左右，y 对应前后（负 Y = 前进）。
## 映射规则: Vector3(x, 0, y)。注意 Godot 的 forward 是 -Z。
func _get_move_direction_3d() -> Vector3:
	if _input_system == null:
		return Vector3.ZERO
	if not _input_system.has_method("get_move_direction"):
		return Vector3.ZERO
	var dir2d: Vector2 = _input_system.get_move_direction()
	return Vector3(dir2d.x, 0.0, dir2d.y)


## 尝试启动闪避。如果 InputSystem 支持 dodge 输入且非冷却状态，则进入 DODGING。
## 返回 true 表示成功启动闪避。
func _try_start_dodge() -> bool:
	if _input_system == null:
		return false
	if not _input_system.has_method("is_action_just_pressed"):
		return false
	if not _input_system.is_action_just_pressed("dodge"):
		return false
	# HIT_STUN 和 DEAD 状态不能闪避
	if _state == State.HIT_STUN or _state == State.DEAD:
		return false
	# 锁定闪避方向：当前移动方向，无输入则用角色朝向
	var direction := _get_move_direction_3d()
	if direction.length_squared() > 0.0:
		_dodge_direction = direction.normalized()
	else:
		_dodge_direction = -global_basis.z
	_dodge_elapsed = 0.0
	_invincible = true
	dodge_attempts += 1
	_change_state(State.DODGING)
	return true


## DODGING 状态处理：沿锁定方向高速移动 0.2 秒，前 0.15 秒无敌。
func _process_dodging(delta: float) -> void:
	_dodge_elapsed += delta
	velocity = _dodge_direction * DODGE_SPEED
	move_and_slide()

	# 无敌帧在 0.15s 后结束（闪避仍在进行但不再无敌）
	if _dodge_elapsed > 0.15:
		_invincible = false

	if _dodge_elapsed >= 0.2:
		# 闪避成功完成（未被打断）
		dodge_successes += 1
		_invincible = false
		_cooldown_elapsed = 0.0
		_change_state(State.DODGE_COOLDOWN)


## DODGE_COOLDOWN 状态处理：冷却期间允许正常移动但不能闪避，持续 0.5 秒。
func _process_dodge_cooldown(delta: float) -> void:
	_cooldown_elapsed += delta

	# 冷却期间允许正常移动
	var direction := _get_move_direction_3d()
	if direction.length_squared() > 0.0:
		velocity = direction * MOVE_SPEED
		move_and_slide()
		_update_facing()
	else:
		velocity = Vector3.ZERO
		move_and_slide()

	if _cooldown_elapsed >= 0.5:
		_change_state(State.IDLE)


## ── Health System (Story 003) ──────────────────────────────────────────────

## 受到伤害。amount 为伤害值（正整数）。
## 检查顺序：已死则忽略、无敌则忽略、扣血、触发信号、HP≤0 则死亡。
func take_damage(amount: int) -> void:
	if health <= 0:
		return  # Already dead
	if _invincible:
		return  # 无敌中（闪避或受击无敌）
	health = max(health - amount, 0)
	health_changed.emit(health, max_health)
	if health <= 0:
		player_died.emit()
		_change_state(State.DEAD)
	else:
		# 进入受击硬直，同时激活受击无敌
		_hit_stun_elapsed = 0.0
		_invincible_timer_elapsed = 0.0
		_invincible = true
		_change_state(State.HIT_STUN)


## 恢复生命值。amount 为恢复量（正整数），不超过 max_health。
func heal(amount: int) -> void:
	health = min(health + amount, max_health)
	health_changed.emit(health, max_health)


## 获取当前生命值。
func get_health() -> int:
	return health


## 获取最大生命值。
func get_max_health() -> int:
	return max_health


## HIT_STUN 状态处理：受击硬直 0.5s，期间可移动但不能闪避。
## InvincibleTimer = 0.65s（0.5s stun + 0.15s buffer），由 _physics_process 顶层管理。
func _process_hit_stun(delta: float) -> void:
	_hit_stun_elapsed += delta
	_invincible_timer_elapsed += delta

	# 受击硬直期间允许正常移动（但不能闪避，由 _try_start_dodge 检查状态阻止）
	var direction := _get_move_direction_3d()
	if direction.length_squared() > 0.0:
		velocity = direction * MOVE_SPEED
		move_and_slide()
		_update_facing()
	else:
		velocity = Vector3.ZERO
		move_and_slide()

	# 0.5s 硬直结束，回到 IDLE（无敌计时器由 _physics_process 顶层继续管理）
	if _hit_stun_elapsed >= 0.5:
		_change_state(State.IDLE)


## DEAD 状态处理：速度归零，忽略所有输入。
func _process_dead(_delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()


## ── Query Methods ──────────────────────────────────────────────────────────
func is_invincible() -> bool:
	return _invincible


## 返回角色当前是否正在闪避。
func is_dodging() -> bool:
	return _state == State.DODGING


## 返回闪避成功率（0.0 ~ 1.0）。无尝试时返回 0.0。
func get_dodge_success_rate() -> float:
	if dodge_attempts == 0:
		return 0.0
	return float(dodge_successes) / float(dodge_attempts)


## 更新朝向：自动朝向最近的敌人。无敌人时保持上一次朝向。
func _update_facing() -> void:
	var nearest := _find_nearest_enemy()
	if nearest:
		var target_pos := nearest.global_position
		target_pos.y = global_position.y  # 保持在同一水平面
		look_at(target_pos, Vector3.UP)


## 查找 enemies 组中距离最近的节点。
## 无敌人或组为空时返回 null。
func _find_nearest_enemy() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var enemies := tree.get_nodes_in_group(ENEMIES_GROUP)
	if enemies.is_empty():
		return null

	var nearest: Node3D = null
	var nearest_dist_sq: float = INF

	for enemy in enemies:
		if not enemy is Node3D:
			continue
		var dist_sq: float = global_position.distance_squared_to(enemy.global_position)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = enemy

	return nearest


## 内部状态转换。在进入新状态时执行必要的重置。
func _change_state(new_state: State) -> void:
	_state = new_state
	# 进入 DEAD 状态时重置无敌状态
	if new_state == State.DEAD:
		_invincible = false


## 游戏状态变更回调。非 COMBAT 状态冻结控制器。
func _on_game_state_changed(_old_state: int, _new_state: int) -> void:
	# 非 COMBAT 状态时重置为 IDLE，等待下一次 COMBAT 激活
	if _new_state != 1:  # 不是 COMBAT
		_change_state(State.IDLE)
		velocity = Vector3.ZERO


## 重置玩家状态（游戏重启时调用）
func reset_player() -> void:
	health = max_health
	_change_state(State.IDLE)
	_invincible = false	
	_invincible_timer_elapsed = 0.0
	velocity = Vector3.ZERO
	global_position = Vector3.ZERO
	health_changed.emit(health, max_health)
