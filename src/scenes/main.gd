## MainScene — 主场景脚本
##
## 负责将所有系统节点信号串联、初始化游戏循环。
## 不持有游戏状态，只做信号桥接和初始化顺序管理。
##
## 信号连接链:
##   HitJudgment.hit_landed → ComboSystem.on_hit_landed
##   HitJudgment.hit_landed → HitFeedback (顿帧)
##   HitJudgment.hit_landed → AudioManager.play_sfx
##   ComboSystem.combo_changed → BattleHUD.update_combo_display
##   ComboSystem.charge_changed → BattleHUD.update_charge_display
##   ComboSystem.myriad_triggered → LightTrailSystem (批量轨迹)
##   ComboSystem.myriad_triggered → HitFeedback.enable_ultimate_feedback
##   ComboSystem.myriad_triggered → BattleHUD.trigger_myriad_hud_effect
##   ThreeFormsCombat.form_activated → BattleHUD.update_form_display
##   ThreeFormsCombat.form_activated → LightTrailSystem.create_trail
##   GameStateManager.state_changed → BattleHUD (显示/隐藏)
##   ArenaWaveSystem.enemy_spawned → Player.enemies 注册
##
## ADR-0001 ~ ADR-0018: 全系统集成
extends Node

## 波次开始延迟（秒）— 给玩家准备时间
const WAVE_START_DELAY: float = 2.0

## Player 节点引用
var _player: CharacterBody3D = null

## CameraController 引用
var _camera_controller: CameraController = null

## BattleHUD 引用
var _battle_hud: BattleHUD = null

## ThreeFormsCombat 引用
var _three_forms: ThreeFormsCombat = null

## ComboSystem 引用
var _combo_system: Node = null

## LightTrailSystem 引用
var _light_trail_system: Node = null

## HitFeedbackSystem 引用
var _hit_feedback_system: Node = null

## ArenaWaveSystem 引用
var _arena_wave_system: Node = null

## EnemySystem 引用
var _enemy_system: Node = null

## AudioManager 引用
var _audio_manager: Node = null

## PhysicsCollisionSystem 引用
var _physics_collision_system: Node = null

## TuningMetrics 引用
var _tuning_metrics: Node = null

## 是否已完成初始化
var _initialized: bool = false

## 调试：上一帧的缓冲攻击动作
var _last_buffered_action: StringName = &""


func _ready() -> void:
	# 等一帧确保所有节点 _ready() 完成
	await get_tree().process_frame

	_resolve_all_references()
	_connect_signal_chain()
	_initialize_systems()
	_initialized = true

	# 切换到 COMBAT 状态（默认 TITLE 不允许操作）
	if GameStateManager:
		GameStateManager.change_state(1)  # COMBAT

	# 启动第一波（延迟给玩家反应时间）
	_start_first_wave()


## 每帧轮询 InputSystem 缓冲的攻击动作，确保 JKL 攻击一定触发
## ThreeFormsCombat._input() 可能在某些情况下不被调用，此方法作为保障
func _process(_delta: float) -> void:
	if not _initialized or _three_forms == null:
		return

	var input_system := get_node_or_null("/root/InputSystem")
	if input_system == null:
		return

	var buffered: StringName = input_system.get_buffered_action()
	if buffered == &"":
		_last_buffered_action = &""  # 缓冲清空时重置，允许下次按键
		return
	if buffered == _last_buffered_action:
		return  # 同一次按键已处理

	_last_buffered_action = buffered

	# 映射动作名到剑式
	var form_map := {
		&"attack_you": 1,  # Form.YOU
		&"attack_zuan": 3, # Form.ZUAN
		&"attack_rao": 2,  # Form.RAO
	}
	var form_id: int = form_map.get(buffered, 0)
	if form_id > 0:
		_three_forms.execute_form(form_id as ThreeFormsCombat.Form)
		# 清空缓冲防止重复触发
		_last_buffered_action = &""


## 解析所有子系统节点引用
func _resolve_all_references() -> void:
	_player = %Player as CharacterBody3D
	_camera_controller = %CameraController as CameraController
	_battle_hud = %BattleHUD as BattleHUD
	_three_forms = %ThreeFormsCombat as ThreeFormsCombat
	_combo_system = %ComboSystem
	_light_trail_system = %LightTrailSystem
	_hit_feedback_system = %HitFeedbackSystem
	_arena_wave_system = %ArenaWaveSystem
	_enemy_system = %EnemySystem
	_audio_manager = get_tree().get_first_node_in_group("audio_manager")
	_physics_collision_system = %PhysicsCollisionSystem
	_tuning_metrics = %TuningMetrics


## 连接信号链 — 跨系统通信的核心桥梁
func _connect_signal_chain() -> void:
	var hit_judgment := HitJudgment
	var game_state_manager := GameStateManager

	# ── HitJudgment → ComboSystem / HitFeedback / AudioManager / EnemyDamage ──
	if hit_judgment and hit_judgment.has_signal("hit_landed"):
		if _combo_system and _combo_system.has_method("on_hit_landed"):
			hit_judgment.hit_landed.connect(_on_hit_landed_forward_to_combo)
		if _hit_feedback_system:
			hit_judgment.hit_landed.connect(_on_hit_landed_forward_to_feedback)
		if _audio_manager:
			hit_judgment.hit_landed.connect(_on_hit_landed_play_sfx)
		# 命中 → 敌人扣血
		hit_judgment.hit_landed.connect(_on_hit_landed_apply_damage)

	# ── PhysicsCollisionSystem → HitJudgment (核心战斗链路) ──
	if _physics_collision_system and _physics_collision_system.has_signal("collision_detected"):
		_physics_collision_system.collision_detected.connect(_on_collision_forward_to_hit_judgment)

	# ── ComboSystem → HUD / LightTrail / HitFeedback ──
	if _combo_system:
		if _combo_system.has_signal("combo_changed"):
			_combo_system.combo_changed.connect(_battle_hud.update_combo_display)
		if _combo_system.has_signal("charge_changed"):
			_combo_system.charge_changed.connect(_battle_hud.update_charge_display)
		if _combo_system.has_signal("myriad_triggered"):
			_combo_system.myriad_triggered.connect(_on_myriad_triggered)

	# ── ThreeFormsCombat → HUD / LightTrail ──
	if _three_forms and _three_forms.has_signal("form_activated"):
		_three_forms.form_activated.connect(_on_form_activated)

	# ── GameStateManager → HUD ──
	if game_state_manager and game_state_manager.has_signal("state_changed"):
		game_state_manager.state_changed.connect(_on_game_state_changed)

	# ── ArenaWaveSystem → Player enemies 注册 ──
	if _arena_wave_system and _arena_wave_system.has_signal("enemy_spawned"):
		_arena_wave_system.enemy_spawned.connect(_on_enemy_spawned)

	# ── EnemySystem → ComboSystem (敌人死亡断连) ──
	if _enemy_system and _enemy_system.has_signal("enemy_died"):
		# 敌人死亡不断连，但可在此扩展
		pass

	# ── Player → HUD (生命值) ──
	if _player and _player.has_signal("health_changed"):
		_player.health_changed.connect(_battle_hud.update_health_display)

	# ── Player → HUD (死亡) ──
	if _player and _player.has_signal("player_died"):
		_player.player_died.connect(_on_player_died)

	# ── ArenaWaveSystem → HUD (波次) ──
	if _arena_wave_system and _arena_wave_system.has_signal("wave_started"):
		_arena_wave_system.wave_started.connect(_battle_hud.update_wave_display)


## 初始化各系统依赖注入
func _initialize_systems() -> void:
	# CameraController 跟随玩家
	if _camera_controller and _player:
		_camera_controller.set_follow_target(_player)

	# HitFeedbackSystem 注入 CameraController
	if _hit_feedback_system and _camera_controller:
		if _hit_feedback_system.has_method("set_camera_controller"):
			_hit_feedback_system.set_camera_controller(_camera_controller)

	# ArenaWaveSystem 注入 Player 和 EnemySystem
	if _arena_wave_system:
		if _player and _arena_wave_system.has_method("set_player_ref"):
			_arena_wave_system.set_player_ref(_player)
		if _enemy_system and _arena_wave_system.has_method("set_enemy_system"):
			_arena_wave_system.set_enemy_system(_enemy_system)
		# 开启间歇后自动推进下一波
		_arena_wave_system.intermission_auto_advance = true

	# EnemySystem 注入 Player
	if _enemy_system and _player:
		if _enemy_system.has_method("set_player_ref"):
			_enemy_system.set_player_ref(_player)

	# 初始化 HUD 显示
	if _battle_hud and _player:
		if _player.has_method("get_health"):
			_battle_hud.update_health_display(_player.get_health(), 3)
		else:
			_battle_hud.update_health_display(3, 3)
		_battle_hud.update_combo_display(0)
		_battle_hud.update_form_display(0)
		_battle_hud.update_charge_display(0.0)


## 延迟启动第一波
func _start_first_wave() -> void:
	await get_tree().create_timer(WAVE_START_DELAY).timeout
	if _arena_wave_system and _arena_wave_system.has_method("start_wave"):
		_arena_wave_system.start_wave(1)


## =========================================================================
## 信号转发回调
## =========================================================================

## HitJudgment.hit_landed → ComboSystem.on_hit_landed
func _on_hit_landed_forward_to_combo(result: Object) -> void:
	if _combo_system and _combo_system.has_method("on_hit_landed"):
		# 从 HitResult 提取 sword_form
		var sword_form: int = 0
		if result.has_method("get"):
			sword_form = result.get("sword_form") if result.get("sword_form") != null else 0
		elif "sword_form" in result:
			sword_form = result.sword_form
		_combo_system.on_hit_landed(sword_form)


## PhysicsCollisionSystem.collision_detected → HitJudgment.process_collision
## 将碰撞事件转换为命中判定，使用 ThreeFormsCombat 当前激活的剑式
func _on_collision_forward_to_hit_judgment(result: CollisionResult) -> void:
	if _three_forms == null:
		return
	var form: int = _three_forms.get_active_form()
	if form <= 0:
		return
	var hit_result = HitJudgment.process_collision(result, _three_forms, form)


## HitJudgment.hit_landed → HitFeedback 顿帧
func _on_hit_landed_forward_to_feedback(result: Object) -> void:
	if _hit_feedback_system and _hit_feedback_system.has_method("trigger_hit_stop"):
		var frames: int = 2
		if "sword_form" in result:
			# 钻式顿帧 3 帧，其余 2 帧
			frames = 3 if result.sword_form == 1 else 2
		_hit_feedback_system.trigger_hit_stop(frames)


## HitJudgment.hit_landed → 敌人扣血
func _on_hit_landed_apply_damage(result: Object) -> void:
	if result == null or not "target" in result or not "damage" in result:
		return
	var target: Node = result.target
	if target == null:
		return
	# 通过节点 metadata 获取 enemy_id，调用 EnemySystem.take_damage
	if target.has_meta("enemy_id"):
		var enemy_id: int = target.get_meta("enemy_id")
		if _enemy_system and _enemy_system.has_method("take_damage"):
			_enemy_system.take_damage(enemy_id, result.damage)


## HitJudgment.hit_landed → AudioManager.play_sfx
func _on_hit_landed_play_sfx(result: Object) -> void:
	if _audio_manager == null:
		return
	var mat_type: String = "metal"
	if "material_type" in result:
		mat_type = result.material_type
	_audio_manager.play_sfx(&"hit_%s" % mat_type, 0.8, 1.0)


## 万剑归宗触发 → LightTrail + HitFeedback + HUD
func _on_myriad_triggered(trail_count: int, damage: float, radius: float) -> void:
	if _light_trail_system and _light_trail_system.has_method("create_myriad_trails"):
		_light_trail_system.create_myriad_trails(trail_count, _player.global_position if _player else Vector3.ZERO)
	if _hit_feedback_system and _hit_feedback_system.has_method("trigger_myriad_feedback"):
		_hit_feedback_system.trigger_myriad_feedback()
	if _battle_hud:
		_battle_hud.trigger_myriad_hud_effect()
		# 延迟恢复 HUD（万剑归宗效果持续约 1.5 秒）
		get_tree().create_timer(1.5).timeout.connect(func():
			if _battle_hud:
				_battle_hud.restore_hud_from_myriad()
		)
	if _camera_controller:
		_camera_controller.trigger_hit_stop(5)
		_camera_controller.trigger_shake(0.3, 0.3)


## 剑式切换 → HUD + LightTrail
func _on_form_activated(form: int) -> void:
	if _battle_hud:
		_battle_hud.update_form_display(form - 1)  # Form 枚举 1/2/3 → 数组索引 0/1/2
	# 剑式激活时创建对应轨迹
	if _light_trail_system and _player and _light_trail_system.has_method("create_trail"):
		var form_names: Array[StringName] = [&"you", &"zuan", &"rao"]
		if form >= 0 and form < form_names.size():
			_light_trail_system.create_trail(form_names[form], _player.global_position)


## 游戏状态切换 → HUD / 系统
func _on_game_state_changed(old_state: int, new_state: int) -> void:
	match new_state:
		1:  # COMBAT
			if _battle_hud:
				_battle_hud.restore_hud()
		3:  # DEATH
			pass  # 由 _on_player_died 处理
		4:  # RESTART
			_restart_game()


## 敌人生成 → 注册到 Player.enemies
func _on_enemy_spawned(enemy_type: String, position: Vector3) -> void:
	# 敌人节点通过 EnemySystem 创建，自动加入 "enemies" group
	# PlayerController 通过 get_tree().get_nodes_in_group(ENEMIES_GROUP) 获取
	# 此处仅做调试日志
	pass


## 玩家死亡 → 显示游戏结束画面
func _on_player_died() -> void:
	if _battle_hud:
		var score := 0
		if _combo_system and _combo_system.has_method("get_total_score"):
			score = _combo_system.get_total_score()
		_battle_hud.show_game_over(score)

	var game_state_manager := GameStateManager
	if game_state_manager:
		game_state_manager.change_state(3)  # State.DEATH


## 重新开始游戏
func _restart_game() -> void:
	# 重置所有系统
	if _combo_system and _combo_system.has_method("reset_combo"):
		_combo_system.reset_combo()
	if _light_trail_system and _light_trail_system.has_method("clear_all_trails"):
		_light_trail_system.clear_all_trails()
	if _arena_wave_system and _arena_wave_system.has_method("reset_waves"):
		_arena_wave_system.reset_waves()

	# 重置玩家
	if _player and _player.has_method("reset_player"):
		_player.reset_player()

	# 重置 HUD
	if _battle_hud:
		_battle_hud.hide_all_menus()
		_battle_hud.restore_hud()
		_battle_hud.update_combo_display(0)
		_battle_hud.update_charge_display(0.0)

	# 切换到 COMBAT
	var game_state_manager := GameStateManager
	if game_state_manager:
		game_state_manager.change_state(1)  # State.COMBAT

	# 启动新一波
	_start_first_wave()
