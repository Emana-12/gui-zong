## ArenaWaveSystem — 竞技场波次系统核心
##
## 管理无限波次的敌人生成节奏、难度递增和波间间歇。
## 使用公式生成每波敌人数量，加权随机选择敌人类型，
## 生成队列确保同时活跃敌人不超过上限（10）。
##
## 设计参考:
## - design/gdd/arena-wave-system.md
## - docs/architecture/adr-0014-arena-wave-architecture.md
##
## 职责边界:
## - 做: 波次生成、难度递增、生成队列、间歇管理、波次完成检测
## - 不做: 敌人 AI（EnemySystem）、碰撞检测（物理层）、计分（ScoringSystem）
##
## 依赖:
## - EnemySystem (ADR-0007): spawn_enemy(), get_alive_count(), enemy_died
## - GameStateManager (ADR-0001): state_changed 信号

class_name ArenaWaveSystem
extends Node

# --- 常量 ---

## 同时活跃敌人上限（性能预算）
const MAX_ACTIVE_ENEMIES: int = 10

## 波次公式: base_count + floor(wave_number * scaling_factor)
const BASE_ENEMY_COUNT: int = 2
const DEFAULT_SCALING_FACTOR: float = 0.8

## 波间间歇时长（秒）
const DEFAULT_INTERMISSION_DURATION: float = 3.0

## 竞技场半径（米），用于计算生成位置
const ARENA_RADIUS: float = 12.0

## 玩家最小生成距离（米）
const MIN_SPAWN_DISTANCE_FROM_PLAYER: float = 5.0

## 敌人类型解锁波次表 (GDD: design/gdd/enemy-system.md)
## 波次 1: water only
## 波次 2: + pine
## 波次 4: + ranged
## 波次 6: + stone
## 波次 8: + agile
const TYPE_UNLOCK_WAVES: Dictionary = {
	"water": 1,
	"pine": 2,
	"ranged": 4,
	"stone": 6,
	"agile": 8,
}

## 敌人类型生成权重（加权随机用）
const TYPE_WEIGHTS: Dictionary = {
	"water": 4.0,   # 流动型 — 始终可用，最常见
	"pine": 3.0,    # 松韧型 — 波次 2+
	"ranged": 2.0,  # 远程型 — 波次 4+
	"stone": 1.5,   # 重甲型 — 波次 6+
	"agile": 1.0,   # 敏捷型 — 波次 8+
}

# --- 信号 ---

## 波次开始: (波次编号, 敌人总数)
signal wave_started(wave_number: int, enemy_count: int)

## 波次完成: (波次编号)
signal wave_completed(wave_number: int)

## 间歇开始: (刚完成的波次编号)
signal intermission_started(wave_number: int)

## 敌人被生成: (敌人类型, 生成位置)
signal enemy_spawned(enemy_type: String, position: Vector3)

# --- 导出参数 ---

## 缩放系数（每波增加的敌人数）
@export_range(0.5, 1.5, 0.1) var scaling_factor: float = DEFAULT_SCALING_FACTOR

## 间歇时长（秒）
@export_range(1.0, 10.0, 0.5) var intermission_duration: float = DEFAULT_INTERMISSION_DURATION

## 是否自动进入下一波（间歇结束后无需手动触发）
@export var intermission_auto_advance: bool = false

# --- 运行时状态 ---

## 当前波次编号
var _current_wave: int = 0

## 当前波总敌人数量（含已生成 + 待生成）
var _total_enemies_in_wave: int = 0

## 当前波已击杀敌人数量
var _kills_in_wave: int = 0

## 当前波已生成敌人数量
var _spawned_in_wave: int = 0

## 生成队列: [{type: String, position: Vector3}]
var _spawn_queue: Array[Dictionary] = []

## 间歇计时器
var _intermission_timer: Timer

## 生成检查计时器（控制生成节奏）
var _spawn_timer: Timer

## 生成间隔（秒）
const SPAWN_INTERVAL: float = 0.5

## 活跃状态标记（COMBAT 时为 true）
var _is_active: bool = false

## 等待下一波标记（间歇后需要 start_wave 被调用）
var _awaiting_next_wave: bool = false

## 随机数生成器（可设种子以支持测试）
var _rng: RandomNumberGenerator

# --- 依赖引用 ---

## EnemySystem 引用（延迟获取）
var _enemy_system: EnemySystem = null

## GameStateManager 引用（延迟获取）
var _game_state_manager: Node = null

## 玩家引用（用于生成位置计算）
var _player_ref: Node3D = null


# --- 生命周期 ---

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

	# 查找依赖系统
	_enemy_system = get_tree().root.find_child("EnemySystem", true, false) as EnemySystem
	_game_state_manager = GameStateManager

	# 创建间歇计时器
	_intermission_timer = Timer.new()
	_intermission_timer.one_shot = true
	_intermission_timer.timeout.connect(_on_intermission_timeout)
	add_child(_intermission_timer)

	# 创建生成检查计时器
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = SPAWN_INTERVAL
	_spawn_timer.timeout.connect(_process_spawn_queue)
	add_child(_spawn_timer)

	# 连接游戏状态信号
	if _game_state_manager:
		_game_state_manager.state_changed.connect(_on_state_changed)

	# 连接敌人死亡信号
	if _enemy_system:
		_enemy_system.enemy_died.connect(_on_enemy_died)


func _process(_delta: float) -> void:
	# 如果当前波的敌人全部死亡（包括 万剑归宗 一帧全杀的情况）
	# 且仍有待生成敌人在队列中，则队列应继续出队
	# 如果队列空且活跃敌人为 0，则波次完成
	if not _is_active:
		return
	if _current_wave <= 0:
		return
	if _spawn_queue.size() > 0:
		_process_spawn_queue()
		return
	if _enemy_system and _enemy_system.get_alive_count() <= 0:
		_complete_wave()


# --- 公共 API ---

## 获取当前波次编号
## @return int
func get_current_wave() -> int:
	return _current_wave


## 获取当前波进度（已击杀数, 总敌人数）
## @return Vector2 — (kills, total)
func get_wave_progress() -> Vector2:
	return Vector2(_kills_in_wave, _total_enemies_in_wave)


## 获取当前活跃敌人数量
## @return int
func get_active_enemy_count() -> int:
	if _enemy_system:
		return _enemy_system.get_alive_count()
	return 0


## 获取生成队列长度
## @return int
func get_spawn_queue_size() -> int:
	return _spawn_queue.size()


## 开始指定波次
## @param wave_number: int — 波次编号（从 1 开始）
func start_wave(wave_number: int) -> void:
	if wave_number < 1:
		push_warning("ArenaWaveSystem: 波次编号必须 >= 1，收到 %d" % wave_number)
		return

	_current_wave = wave_number
	_kills_in_wave = 0
	_spawned_in_wave = 0
	_spawn_queue.clear()

	# 计算敌人总数
	var enemy_count := _calculate_enemy_count(wave_number)
	_total_enemies_in_wave = enemy_count

	# 生成类型列表
	var types := _generate_enemy_types(wave_number, enemy_count)

	# 构建生成队列
	for enemy_type in types:
		var spawn_pos := _get_spawn_position()
		_spawn_queue.append({"type": enemy_type, "position": spawn_pos})

	_is_active = true
	_awaiting_next_wave = false

	# 启动生成检查计时器
	_spawn_timer.start()

	wave_started.emit(wave_number, enemy_count)

	# 立即尝试出队第一批
	_process_spawn_queue()


## 获取指定波次的数据（预览用，不改变状态）
## @param wave_number: int
## @return Dictionary — {count: int, types: Array[String]}
func get_wave_data(wave_number: int) -> Dictionary:
	var count := _calculate_enemy_count(wave_number)
	var types := _generate_enemy_types(wave_number, count)
	return {"count": count, "types": types}


## 设置玩家引用（依赖注入）
## @param player: Node3D
func set_player_ref(player: Node3D) -> void:
	_player_ref = player


## 设置 EnemySystem 引用（依赖注入）
## @param enemy_system: EnemySystem
func set_enemy_system(enemy_system: EnemySystem) -> void:
	# 断开旧连接
	if _enemy_system and _enemy_system.enemy_died.is_connected(_on_enemy_died):
		_enemy_system.enemy_died.disconnect(_on_enemy_died)
	_enemy_system = enemy_system
	if _enemy_system:
		_enemy_system.enemy_died.connect(_on_enemy_died)


## 设置 GameStateManager 引用（依赖注入）
## @param gsm: GameStateManager
func set_game_state_manager(gsm: Node) -> void:
	if _game_state_manager and _game_state_manager.state_changed.is_connected(_on_state_changed):
		_game_state_manager.state_changed.disconnect(_on_state_changed)
	_game_state_manager = gsm
	if _game_state_manager:
		_game_state_manager.state_changed.connect(_on_state_changed)


## 设置 RNG 种子（测试用，确保确定性）
## @param seed_value: int
func set_rng_seed(seed_value: int) -> void:
	_rng.seed = seed_value


## 强制重置波次状态（场景切换/重启时调用）
func reset_waves() -> void:
	_current_wave = 0
	_total_enemies_in_wave = 0
	_kills_in_wave = 0
	_spawned_in_wave = 0
	_spawn_queue.clear()
	_is_active = false
	_awaiting_next_wave = false
	_spawn_timer.stop()
	_intermission_timer.stop()


# --- 内部方法 ---

## 波次敌人数量公式: base_count + floor(wave_number * scaling_factor)
## @param wave_number: int
## @return int
func _calculate_enemy_count(wave_number: int) -> int:
	return BASE_ENEMY_COUNT + floori(wave_number * scaling_factor)


## 生成敌人类型列表（加权随机）
## @param wave_number: int — 波次编号
## @param count: int — 敌人总数
## @return Array[String]
func _generate_enemy_types(wave_number: int, count: int) -> Array[String]:
	var available_types: Array[String] = []
	var weights: PackedFloat32Array = PackedFloat32Array()

	# 收集已解锁的类型及其权重
	for type_name in TYPE_UNLOCK_WAVES:
		var unlock_wave: int = TYPE_UNLOCK_WAVES[type_name]
		if wave_number >= unlock_wave:
			available_types.append(type_name)
			weights.append(TYPE_WEIGHTS[type_name])

	# 计算权重总和
	var total_weight := 0.0
	for w in weights:
		total_weight += w

	# 加权随机选择
	var result: Array[String] = []
	for i in range(count):
		var roll := _rng.randf() * total_weight
		var cumulative := 0.0
		var selected := available_types[0]  # fallback
		for j in range(available_types.size()):
			cumulative += weights[j]
			if roll <= cumulative:
				selected = available_types[j]
				break
		result.append(selected)

	return result


## 处理生成队列 — 将队列中的敌人生成到场上
func _process_spawn_queue() -> void:
	if _spawn_queue.is_empty():
		return
	if _enemy_system == null:
		return

	# 逐个出队直到达到活跃上限或队列空
	while _spawn_queue.size() > 0:
		if _enemy_system.get_alive_count() >= MAX_ACTIVE_ENEMIES:
			break

		var entry: Dictionary = _spawn_queue.pop_front()
		var enemy_type: String = entry["type"]
		var position: Vector3 = entry["position"]

		var enemy_id := _enemy_system.spawn_enemy(enemy_type, position)
		if enemy_id >= 0:
			_spawned_in_wave += 1
			enemy_spawned.emit(enemy_type, position)


## 完成当前波次
func _complete_wave() -> void:
	_is_active = false
	_spawn_timer.stop()

	var completed_wave := _current_wave
	wave_completed.emit(completed_wave)

	# 进入间歇
	_start_intermission(completed_wave)


## 开始间歇
## @param completed_wave: int — 刚完成的波次编号
func _start_intermission(completed_wave: int) -> void:
	_awaiting_next_wave = true
	_intermission_timer.wait_time = intermission_duration
	_intermission_timer.start()
	intermission_started.emit(completed_wave)


## 间歇计时器回调
func _on_intermission_timeout() -> void:
	if intermission_auto_advance:
		# 自动模式：直接开始下一波
		start_wave(_current_wave + 1)
	else:
		# 手动模式：通知 GameStateManager 进入下一波
		# GameStateManager._on_wave_completed 会将 COMBAT→INTERMISSION
		# 间歇结束需要外部请求 COMBAT 才能触发下一波
		# 这里不做状态切换，等待外部调用
		pass


## 游戏状态变化回调
func _on_state_changed(_old_state: int, new_state: int) -> void:
	match new_state:
		1:  # COMBAT
			# 从 INTERMISSION 回到 COMBAT → 开始下一波
			if _awaiting_next_wave:
				start_wave(_current_wave + 1)
			# 从 RESTART 或 TITLE → COMBAT → 开始第一波
			elif _current_wave == 0:
				start_wave(1)

		3:  # DEATH
			# 玩家死亡 → 停止一切
			_is_active = false
			_spawn_queue.clear()
			_spawn_timer.stop()
			_intermission_timer.stop()

		4:  # RESTART
			# 重置波次状态
			reset_waves()


## 敌人死亡回调
func _on_enemy_died(_enemy_id: int) -> void:
	if not _is_active:
		return
	_kills_in_wave += 1
	# 波次完成检测在 _process 中进行


## 计算生成位置（竞技场边缘随机点，距离玩家 > MIN_SPAWN_DISTANCE_FROM_PLAYER）
## @return Vector3
func _get_spawn_position() -> Vector3:
	var player_pos := Vector3.ZERO
	if _player_ref:
		player_pos = _player_ref.position

	var attempts := 0
	while attempts < 20:
		var angle := _rng.randf_range(0.0, TAU)
		var pos := Vector3(
			cos(angle) * ARENA_RADIUS,
			0.0,
			sin(angle) * ARENA_RADIUS
		)

		# 检查与玩家距离
		if pos.distance_to(player_pos) >= MIN_SPAWN_DISTANCE_FROM_PLAYER:
			return pos
		attempts += 1

	# 回退：返回远离玩家的竞技场边缘点
	var away_angle := 0.0
	if _player_ref and _player_ref.position.length() > 0.1:
		away_angle = atan2(_player_ref.position.z, _player_ref.position.x) + PI
	return Vector3(cos(away_angle) * ARENA_RADIUS, 0.0, sin(away_angle) * ARENA_RADIUS)


# --- 测试辅助 ---

## 测试辅助：设置 EnemySystem 引用（无场景树时使用）
## @param mock: EnemySystem mock 或真实实例
func _test_set_enemy_system(mock: EnemySystem) -> void:
	_enemy_system = mock
	if _enemy_system and not _enemy_system.enemy_died.is_connected(_on_enemy_died):
		_enemy_system.enemy_died.connect(_on_enemy_died)


## 测试辅助：设置玩家引用位置
## @param pos: Vector3
func _test_set_player_position(pos: Vector3) -> void:
	if _player_ref == null:
		_player_ref = Node3D.new()
	_player_ref.position = pos


## 测试辅助：获取间歇计时器引用
## @return Timer
func _test_get_intermission_timer() -> Timer:
	return _intermission_timer


## 测试辅助：获取生成队列
## @return Array[Dictionary]
func _test_get_spawn_queue() -> Array[Dictionary]:
	return _spawn_queue
