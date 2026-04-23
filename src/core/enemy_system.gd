## EnemySystem — 敌人系统核心
##
## 管理敌人生成、AI 状态机更新、生命周期。
## 6 态状态机：IDLE → APPROACH → ATTACK → RECOVER → HIT_STUN → DEAD
##
## 职责边界：
## - 做：敌人生成/销毁、AI 决策、状态转换、参数化配置
## - 不做：碰撞检测（物理碰撞层）、伤害计算（命中判定层）、视觉效果
##
## @see docs/architecture/adr-0007
class_name EnemySystem
extends Node

## 敌人状态枚举
enum EnemyState { IDLE, APPROACH, ATTACK, RECOVER, HIT_STUN, DEAD }

## 敌人类型配置数据 (GDD: design/gdd/enemy-system.md, QA Plan: S03-04)
##
## 5 种敌人各有推荐克制剑式:
## - 松韧型(pine): 钻剑式克制 — 穿透松节弱点
## - 重甲型(stone): 绕剑式克制 — 化解硬力
## - 流动型(water): 游剑式克制 — 缠绕附着
## - 远程型(cloud): 钻剑式克制 — 穿透虚体
## - 敏捷型(bamboo): 绕剑式+游剑式 — 化解+缠绕
const ENEMY_TYPE_DATA: Dictionary = {
	"pine": {
		"hp": 5,
		"speed": 2.0,
		"attack_range": 2.0,
		"perception_range": 10.0,
		"attack_damage": 1,
		"attack_cooldown": 2.5,
		"counter_form": 3,  # SwordForm.ZUAN
	},
	"stone": {
		"hp": 8,
		"speed": 1.0,
		"attack_range": 2.5,
		"perception_range": 8.0,
		"attack_damage": 2,
		"attack_cooldown": 4.0,
		"counter_form": 2,  # SwordForm.RAO
	},
	"water": {
		"hp": 3,
		"speed": 4.0,
		"attack_range": 1.5,
		"perception_range": 12.0,
		"attack_damage": 1,
		"attack_cooldown": 1.5,
		"counter_form": 1,  # SwordForm.YOU
	},
	"ranged": {
		"hp": 2,
		"speed": 0.0,
		"attack_range": 10.0,
		"perception_range": 15.0,
		"attack_damage": 1,
		"attack_cooldown": 2.0,
		"counter_form": 3,  # SwordForm.ZUAN
	},
	"agile": {
		"hp": 4,
		"speed": 5.0,
		"attack_range": 1.8,
		"perception_range": 10.0,
		"attack_damage": 1,
		"attack_cooldown": 1.5,
		"counter_form": 2,  # SwordForm.RAO
	},
}

## 方向破绽配置（Quick Spec: three-forms-vulnerability-2026-04-23）
## direction: 破绽方向（"front"/"back"/"left"/"right"/"up"）
## form: 克制剑式（ThreeFormsCombat.Form 枚举值）
## multiplier: 破绽伤害倍率
const VULNERABILITY: Dictionary = {
	"pine":   { "direction": "front", "form": 3, "multiplier": 2.0 },  # 钻剑式正面破绽
	"stone":  { "direction": "up",    "form": 3, "multiplier": 2.0 },  # 钻剑式上方破绽
	"water":  { "direction": "side",  "form": 1, "multiplier": 2.0 },  # 游剑式侧面破绽
	"ranged": { "direction": "front", "form": 3, "multiplier": 2.0 },  # 钻剑式正面破绽
	"agile":  { "direction": "back",  "form": 2, "multiplier": 2.0 },  # 绕剑式背后破绽
}

## 最小接近距离（防止敌人重叠玩家）
const MIN_APPROACH_DISTANCE: float = 0.5

## 敌人生成信号
signal enemy_spawned(enemy_id: int, enemy_type: String, position: Vector3)

## 敌人状态变化信号
signal enemy_state_changed(enemy_id: int, old_state: EnemyState, new_state: EnemyState)

## 攻击 hitbox 创建信号
signal attack_hitbox_created(enemy_id: int, hitbox_id: int)

## 敌人死亡信号
signal enemy_died(enemy_id: int)

## 敌人攻击命中玩家信号
signal enemy_hit_player(enemy_id: int, damage: int)

## DEAD 状态缩小动画时长（秒）
const DEATH_SHRINK_DURATION: float = 0.3

## DEAD 状态缩小目标缩放
const DEATH_SHRINK_SCALE: float = 0.1

## 运行时敌人数据
class EnemyData:
	var id: int
	var type: String
	var hp: int
	var max_hp: int
	var state: EnemyState
	var state_timer: float
	var attack_cooldown_timer: float
	var speed: float
	var attack_range: float
	var perception_range: float
	var attack_damage: int
	var attack_cooldown: float
	var node: CharacterBody3D
	## 死亡 Tween 引用（用于防止重复动画）
	var death_tween: Tween = null
	## 攻击是否已命中（防止同一次 ATTACK 重复伤害）
	var attack_has_hit: bool = false

var _enemies: Dictionary = {}  # {enemy_id: EnemyData}
var _next_enemy_id: int = 0
var _player_ref: Node3D = null
var _game_state_manager: Node = null
var _physics_system: PhysicsCollisionSystem = null
var _is_game_active: bool = false
## 预分配数组，避免每帧分配
var _enemies_to_update: Array = []


func _ready() -> void:
	_physics_system = get_tree().root.find_child("PhysicsCollisionSystem", true, false)
	_game_state_manager = GameStateManager
	if _game_state_manager:
		_game_state_manager.state_changed.connect(_on_game_state_changed)
		_is_game_active = GameStateManager.get_current_state() == 1  # COMBAT


func _process(delta: float) -> void:
	if not _is_game_active:
		return
	if _player_ref == null:
		return

	# 预分配复用：收集需要更新的敌人（排除 DEAD）
	_enemies_to_update.clear()
	for enemy_id in _enemies:
		var data: EnemyData = _enemies[enemy_id]
		if data.state != EnemyState.DEAD:
			_enemies_to_update.append(data)

	for data in _enemies_to_update:
		_update_ai(data, delta)


## 生成位置与玩家重叠推离距离（GDD Edge Case #2）
const OVERLAP_PUSH_DISTANCE: float = 2.0

## 敌人类型颜色映射
const TYPE_COLORS: Dictionary = {
	"pine": Color(0.4, 0.55, 0.3),    # 松绿色
	"stone": Color(0.5, 0.5, 0.5),     # 石灰色
	"water": Color(0.3, 0.5, 0.7),     # 水蓝色
	"ranged": Color(0.7, 0.7, 0.8),    # 云白色
	"agile": Color(0.5, 0.65, 0.4),    # 竹青色
}


## 生成敌人
## @param enemy_type: String - 敌人类型标识
## @param position: Vector3 - 生成位置（世界坐标）
## @return int - 敌人 ID，-1 表示生成失败
func spawn_enemy(enemy_type: String, position: Vector3) -> int:
	if not ENEMY_TYPE_DATA.has(enemy_type):
		push_warning("EnemySystem: Unknown enemy type '%s'" % enemy_type)
		return -1

	var type_data: Dictionary = ENEMY_TYPE_DATA[enemy_type]

	# GDD Edge Case #2: 生成位置与玩家重叠 → 自动推离 2m
	var spawn_pos := position
	if _player_ref != null:
		var dist := position.distance_to(_player_ref.position)
		if dist < OVERLAP_PUSH_DISTANCE:
			var push_dir := (position - _player_ref.position).normalized()
			if push_dir.length_squared() < 0.001:
				push_dir = Vector3.FORWARD  # 完全重叠时默认方向
			spawn_pos = _player_ref.position + push_dir * OVERLAP_PUSH_DISTANCE

	var enemy_node := CharacterBody3D.new()
	enemy_node.position = spawn_pos

	# 碰撞层：敌人在 layer 2，mask 接收玩家攻击 + 环境 + 其他敌人（防重叠）
	enemy_node.collision_layer = 2  # PhysicsCollisionSystem.CollisionLayer.ENEMY
	enemy_node.collision_mask = 2 | 4 | 16  # ENEMY | PLAYER_ATTACK | ENVIRONMENT

	# 添加到 enemies 组（PlayerController 自动朝向用）
	enemy_node.add_to_group("enemies")

	# 添加碰撞体
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.6
	col.shape = shape
	col.position.y = 0.8
	enemy_node.add_child(col)

	# 添加可见网格
	var mesh_inst := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.6
	mesh_inst.mesh = capsule
	mesh_inst.position.y = 0.8
	# 根据敌人类型设置颜色
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TYPE_COLORS.get(enemy_type, Color(0.8, 0.2, 0.2))
	mesh_inst.material_override = mat
	enemy_node.add_child(mesh_inst)

	add_child(enemy_node)

	var data := EnemyData.new()
	data.id = _next_enemy_id
	data.type = enemy_type
	data.hp = type_data["hp"]
	data.max_hp = type_data["hp"]
	data.state = EnemyState.IDLE
	data.state_timer = 0.0
	data.attack_cooldown_timer = 0.0
	data.speed = type_data["speed"]
	data.attack_range = type_data["attack_range"]
	data.perception_range = type_data["perception_range"]
	data.attack_damage = type_data["attack_damage"]
	data.attack_cooldown = type_data["attack_cooldown"]
	data.node = enemy_node
	# 存储 enemy_id 到节点 metadata（main.gd 通过此 ID 调用 take_damage）
	enemy_node.set_meta("enemy_id", data.id)

	_enemies[data.id] = data
	_next_enemy_id += 1

	enemy_spawned.emit(data.id, enemy_type, spawn_pos)
	return data.id


## 获取敌人类型
## @param enemy_id: int - 敌人 ID
## @return String - 敌人类型名，不存在返回 ""
func get_enemy_type(enemy_id: int) -> String:
	if not _enemies.has(enemy_id):
		return ""
	return (_enemies[enemy_id] as EnemyData).type


## 检查攻击是否击中方向破绽（通过节点直接调用）
## @param target_node: Node3D - 被攻击的敌人节点
## @param attacker_pos: Vector3 - 攻击者位置
## @param sword_form: int - 剑式（1=YOU, 2=RAO, 3=ZUAN）
## @return float - 破绽倍率（1.0=正常, 2.0=破绽命中）
func check_vulnerability_by_node(target_node: Node3D, attacker_pos: Vector3, sword_form: int) -> float:
	# 查找对应 EnemyData
	for id in _enemies:
		var data: EnemyData = _enemies[id]
		if data.node == target_node:
			return _check_vuln_for_data(data, attacker_pos, sword_form)
	return 1.0


## 检查指定敌人数据的破绽
func _check_vuln_for_data(data: EnemyData, attacker_pos: Vector3, sword_form: int) -> float:
	var vuln: Dictionary = VULNERABILITY.get(data.type, {})
	if vuln.is_empty():
		return 1.0
	if sword_form != vuln["form"]:
		return 1.0
	var direction := _get_attack_direction(data, attacker_pos)
	if direction != vuln["direction"]:
		return 1.0
	return vuln["multiplier"]


## 计算攻击来自敌人的哪个方向
## @return String: "front"/"back"/"left"/"right"/"up"
func _get_attack_direction(data: EnemyData, attacker_pos: Vector3) -> String:
	var enemy_pos: Vector3 = data.node.global_position
	var delta := attacker_pos - enemy_pos

	# 上方判定：Y 差 > 0.5m
	if delta.y > 0.5:
		return "up"

	# 水平方向判定（XZ 平面）
	var to_attacker := Vector3(delta.x, 0.0, delta.z)
	if to_attacker.length_squared() < 0.001:
		return "front"  # 完全重叠

	# 敌人朝向（朝向玩家，用 global_basis.z 的反方向）
	var enemy_forward := -data.node.global_basis.z
	var enemy_right := data.node.global_basis.x

	var forward_dot := enemy_forward.dot(to_attacker.normalized())
	var right_dot := enemy_right.dot(to_attacker.normalized())

	# 前方: forward_dot > cos(45°) ≈ 0.707
	if forward_dot > 0.707:
		return "front"
	# 后方: forward_dot < -cos(45°)
	if forward_dot < -0.707:
		return "back"
	# 侧面: side = left 或 right
	if absf(forward_dot) <= 0.707:
		if right_dot > 0.0:
			return "right"
		else:
			return "left"

	return "front"  # 回退


## 获取所有敌人
## @return Array - 敌人数据数组
func get_all_enemies() -> Array:
	return _enemies.values()


## 获取存活敌人数量
## @return int - HP > 0 的敌人数量
func get_alive_count() -> int:
	var count := 0
	for data in _enemies.values():
		if data.hp > 0:
			count += 1
	return count


## 杀死所有敌人
func kill_all() -> void:
	for data in _enemies.values():
		data.hp = 0
		_change_state(data, EnemyState.DEAD)


## 对敌人造成伤害
## @param enemy_id: int - 敌人 ID
## @param amount: int - 伤害值（必须 > 0）
func take_damage(enemy_id: int, amount: int) -> void:
	if not _enemies.has(enemy_id):
		return
	var data: EnemyData = _enemies[enemy_id]
	if data.state == EnemyState.DEAD:
		return
	if amount <= 0:
		return
	data.hp = maxi(data.hp - amount, 0)
	if data.hp <= 0:
		_change_state(data, EnemyState.DEAD)
		enemy_died.emit(enemy_id)
	else:
		_change_state(data, EnemyState.HIT_STUN)


## 指定敌人是否存活
## @param enemy_id: int - 敌人 ID
## @return bool - 是否存活
func is_alive(enemy_id: int) -> bool:
	if not _enemies.has(enemy_id):
		return false
	return (_enemies[enemy_id] as EnemyData).hp > 0


## 获取敌人位置
## @param enemy_id: int - 敌人 ID
## @return Vector3 - 敌人位置
func get_enemy_position(enemy_id: int) -> Vector3:
	if not _enemies.has(enemy_id):
		return Vector3.ZERO
	return (_enemies[enemy_id] as EnemyData).node.position


## 获取敌人当前状态
## @param enemy_id: int - 敌人 ID
## @return EnemyState - 敌人状态
func get_enemy_state(enemy_id: int) -> EnemyState:
	if not _enemies.has(enemy_id):
		return EnemyState.DEAD
	return (_enemies[enemy_id] as EnemyData).state


## 设置玩家引用（依赖注入）
## @param player: Node3D - 玩家节点引用
func set_player_ref(player: Node3D) -> void:
	_player_ref = player


## 设置游戏状态管理器
## @param gsm: GameStateManager - 游戏状态管理器引用
func set_game_state_manager(gsm: Node) -> void:
	if _game_state_manager and _game_state_manager.state_changed.is_connected(_on_game_state_changed):
		_game_state_manager.state_changed.disconnect(_on_game_state_changed)
	_game_state_manager = gsm
	if _game_state_manager:
		_game_state_manager.state_changed.connect(_on_game_state_changed)
		_is_game_active = _game_state_manager.get_current_state() == 1  # COMBAT


## 获取游戏状态管理器引用
## @return GameStateManager - 当前关联的管理器
func get_game_state_manager() -> Node:
	return _game_state_manager


## 测试辅助：手动更新指定敌人 AI（绕过 _process 依赖场景树）
## @param enemy_id: int - 敌人 ID
## @param delta: float - 帧间隔
func update_enemy_ai(enemy_id: int, delta: float) -> void:
	if not _enemies.has(enemy_id):
		return
	var data: EnemyData = _enemies[enemy_id]
	if data.state == EnemyState.DEAD:
		return
	if _player_ref == null:
		return
	_update_ai(data, delta)


## 游戏状态变化回调
func _on_game_state_changed(_old_state: int, new_state: int) -> void:
	_is_game_active = new_state == 1  # COMBAT


## 更新单个敌人 AI
func _update_ai(data: EnemyData, delta: float) -> void:
	# 更新计时器
	if data.state_timer > 0.0:
		data.state_timer = maxf(data.state_timer - delta, 0.0)
	if data.attack_cooldown_timer > 0.0:
		data.attack_cooldown_timer = maxf(data.attack_cooldown_timer - delta, 0.0)

	var distance_to_player := data.node.position.distance_to(_player_ref.position)

	match data.state:
		EnemyState.IDLE:
			if distance_to_player <= data.perception_range:
				_change_state(data, EnemyState.APPROACH)

		EnemyState.APPROACH:
			if distance_to_player <= data.attack_range and data.attack_cooldown_timer <= 0.0:
				_change_state(data, EnemyState.ATTACK)
			elif distance_to_player > data.perception_range:
				_change_state(data, EnemyState.IDLE)
			elif distance_to_player > MIN_APPROACH_DISTANCE:
				var direction := (_player_ref.position - data.node.position).normalized()
				data.node.velocity = direction * data.speed
				data.node.move_and_slide()

		EnemyState.ATTACK:
			# 攻击命中：state_timer 过半时判定一次伤害
			if not data.attack_has_hit and data.state_timer <= 0.15:
				data.attack_has_hit = true
				_deal_attack_damage(data)
			if data.state_timer <= 0.0:
				_change_state(data, EnemyState.RECOVER)

		EnemyState.RECOVER:
			if data.state_timer <= 0.0:
				data.attack_cooldown_timer = data.attack_cooldown
				if distance_to_player <= data.attack_range:
					_change_state(data, EnemyState.ATTACK)
				else:
					_change_state(data, EnemyState.APPROACH)

		EnemyState.HIT_STUN:
			if data.state_timer <= 0.0:
				_change_state(data, EnemyState.APPROACH)


## 状态转换
func _change_state(data: EnemyData, new_state: EnemyState) -> void:
	var old_state := data.state
	data.state = new_state

	match new_state:
		EnemyState.APPROACH:
			data.state_timer = 0.0
		EnemyState.ATTACK:
			data.state_timer = 0.3
			data.attack_has_hit = false
			_create_attack_hitbox(data)
		EnemyState.RECOVER:
			data.state_timer = 0.2
		EnemyState.HIT_STUN:
			data.state_timer = 0.3
		EnemyState.DEAD:
			data.state_timer = 0.0
			_play_death_animation(data)

	enemy_state_changed.emit(data.id, old_state, new_state)


## 创建攻击 hitbox
func _create_attack_hitbox(data: EnemyData) -> void:
	if _physics_system == null:
		return
	var shape := SphereShape3D.new()
	shape.radius = data.attack_range
	var hitbox_id := _physics_system.create_hitbox(
		data.node, shape, data.node.position, Vector3.ZERO
	)
	if hitbox_id >= 0:
		attack_hitbox_created.emit(data.id, hitbox_id)


## 向玩家传递攻击伤害
## 通过 player.take_damage() 直接调用。
## 如果玩家引用实现了 take_damage(int) 方法则调用，否则发出 enemy_hit_player 信号。
func _deal_attack_damage(data: EnemyData) -> void:
	if _player_ref == null:
		return

	var damage: int = data.attack_damage

	# 优先直接调用 player.take_damage
	if _player_ref.has_method("take_damage"):
		_player_ref.take_damage(damage)

	enemy_hit_player.emit(data.id, damage)


## 播放死亡动画 — Tween 缩小至 DEATH_SHRINK_SCALE + queue_free
func _play_death_animation(data: EnemyData) -> void:
	# 取消已有死亡动画
	if data.death_tween and data.death_tween.is_valid():
		data.death_tween.kill()

	data.death_tween = create_tween()
	data.death_tween.set_trans(Tween.TRANS_CUBIC)
	data.death_tween.set_ease(Tween.EASE_IN)
	data.death_tween.tween_property(
		data.node, "scale", Vector3.ONE * DEATH_SHRINK_SCALE, DEATH_SHRINK_DURATION
	)
	data.death_tween.tween_callback(_destroy_enemy.bind(data))


## 销毁敌人节点（死亡动画完成后调用）
func _destroy_enemy(data: EnemyData) -> void:
	if data.node and is_instance_valid(data.node):
		data.node.queue_free()
