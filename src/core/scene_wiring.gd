# SPDX-License-Identifier: MIT
## SceneWiring — 场景信号串联层
##
## 负责在场景树组装阶段连接跨系统的 deferred 信号。
## 不含业务逻辑，只做信号桥接。
##
## 4 处 deferred 连接 (S03-02):
## 1. combo_system.myriad_triggered → battle_hud 万剑归宗效果
## 2. combo_system.myriad_feedback_finished → battle_hud 恢复
## 3. game_state_manager.state_changed → battle_hud 非 COMBAT 隐藏
## 4. game_state_manager.state_changed(DEATH) → battle_hud.show_game_over
## 5. hit_feedback_system.feedback_triggered → audio_manager 音效
##
## @see production/sprints/sprint-03.md S03-02
## @see docs/architecture/adr-0001-game-state-architecture.md
## @see docs/architecture/adr-0013-hit-feedback-architecture.md
class_name SceneWiring
extends Node

## 连接完成信号。测试用。
signal wiring_completed

## 当前连接的系统引用
var _combo_system: ComboSystem = null
var _game_state_manager: Node = null
var _battle_hud: BattleHUD = null
var _hit_feedback_system: HitFeedbackSystem = null
var _audio_manager: AudioManager = null
var _scoring_system: Node = null

## 连接状态追踪
var _connections: Dictionary = {}


func _ready() -> void:
	# 延迟一帧等待所有 Autoload 和场景节点就绪
	await get_tree().process_frame
	_connect_all_signals()


## 连接所有 deferred 信号。
func _connect_all_signals() -> void:
	# 收集系统引用
	_combo_system = get_node_or_null("/root/ComboSystem") as ComboSystem
	_game_state_manager = get_node_or_null("/root/GameStateManager")
	_battle_hud = get_tree().get_first_node_in_group("battle_hud") as BattleHUD
	_hit_feedback_system = get_tree().get_first_node_in_group("hit_feedback") as HitFeedbackSystem
	_audio_manager = get_tree().get_first_node_in_group("audio_manager") as AudioManager
	_scoring_system = get_node_or_null("/root/ScoringSystem")

	# 连接 1: combo → HUD 万剑归宗效果
	_connect_combo_to_hud()

	# 连接 2: game state → HUD 状态响应
	_connect_state_to_hud()

	# 连接 3: hit feedback → audio
	_connect_feedback_to_audio()

	# 连接 4: combo → scoring
	_connect_combo_to_scoring()

	# 连接 5: 碰撞 → 命中判定 (核心战斗链路)
	_connect_collision_to_hit_judgment()

	# 连接 6: 命中 → 连击
	_connect_hit_to_combo()

	wiring_completed.emit()


## 连接 1: 连击系统 → HUD 万剑归宗
func _connect_combo_to_hud() -> void:
	if _combo_system == null or _battle_hud == null:
		push_warning("SceneWiring: ComboSystem or BattleHUD not found for myriad wiring")
		return

	# myriad_triggered → trigger_myriad_hud_effect
	if not _combo_system.myriad_triggered.is_connected(_battle_hud.trigger_myriad_hud_effect):
		_combo_system.myriad_triggered.connect(_battle_hud.trigger_myriad_hud_effect)
		_connections["combo_myriad_to_hud"] = true

	# myriad_feedback_finished → restore_hud_from_myriad（通过 HitFeedbackSystem）
	var hfs := get_tree().get_first_node_in_group("hit_feedback") as HitFeedbackSystem
	if hfs != null:
		if not hfs.myriad_feedback_finished.is_connected(_battle_hud.restore_hud_from_myriad):
			hfs.myriad_feedback_finished.connect(_battle_hud.restore_hud_from_myriad)
			_connections["myriad_finish_to_hud"] = true


## 连接 2: 游戏状态 → HUD 响应
func _connect_state_to_hud() -> void:
	if _game_state_manager == null or _battle_hud == null:
		push_warning("SceneWiring: GameStateManager or BattleHUD not found for state wiring")
		return

	if not _game_state_manager.state_changed.is_connected(_on_game_state_changed):
		_game_state_manager.state_changed.connect(_on_game_state_changed)
		_connections["gsm_to_hud"] = true


## 连接 3: 命中反馈 → 音频
func _connect_feedback_to_audio() -> void:
	if _hit_feedback_system == null or _audio_manager == null:
		push_warning("SceneWiring: HitFeedbackSystem or AudioManager not found for audio wiring")
		return

	if not _hit_feedback_system.feedback_triggered.is_connected(_on_feedback_triggered):
		_hit_feedback_system.feedback_triggered.connect(_on_feedback_triggered)
		_connections["feedback_to_audio"] = true


## 连接 4: 连击系统 → 计分系统
func _connect_combo_to_scoring() -> void:
	if _combo_system == null or _scoring_system == null:
		# 计分系统在 S03-03 实现，此连接在 S03-03 后生效
		push_warning("SceneWiring: ScoringSystem not found — deferred to S03-03")
		return

	if _scoring_system.has_method("on_myriad_triggered"):
		if not _combo_system.myriad_triggered.is_connected(_scoring_system.on_myriad_triggered):
			_combo_system.myriad_triggered.connect(_scoring_system.on_myriad_triggered)
			_connections["combo_to_scoring"] = true


## 连接 5: 碰撞检测 → 命中判定（核心战斗链路）
## PhysicsCollisionSystem.collision_detected → HitJudgment.process_collision
func _connect_collision_to_hit_judgment() -> void:
	var physics_system := get_tree().root.find_child("PhysicsCollisionSystem", true, false) as PhysicsCollisionSystem
	var hit_judgment := get_node_or_null("/root/HitJudgment")
	var three_forms := get_tree().root.find_child("ThreeFormsCombat", true, false) as ThreeFormsCombat

	if physics_system == null or hit_judgment == null:
		push_warning("SceneWiring: PhysicsCollisionSystem or HitJudgment not found — combat chain broken")
		return

	# 连接碰撞信号到命中判定，ThreeFormsCombat 作为攻击者
	if not physics_system.collision_detected.is_connected(_on_collision_detected):
		physics_system.collision_detected.connect(_on_collision_detected)
		_connections["collision_to_hit_judgment"] = true


## 碰撞回调 → 命中判定
func _on_collision_detected(result: CollisionResult) -> void:
	var hit_judgment := get_node_or_null("/root/HitJudgment")
	var three_forms := get_tree().root.find_child("ThreeFormsCombat", true, false) as ThreeFormsCombat
	if hit_judgment == null or three_forms == null:
		return
	# 确定剑式（从 ThreeFormsCombat 当前激活的剑式）
	var form: int = three_forms.get_active_form()
	if form <= 0:
		return  # 没有激活的剑式
	hit_judgment.process_collision(result, three_forms, form)


## 连接 6: 命中判定 → 连击系统
## HitJudgment.hit_landed → ComboSystem.on_hit_landed
func _connect_hit_to_combo() -> void:
	var hit_judgment := get_node_or_null("/root/HitJudgment")
	var combo_system := get_node_or_null("/root/ComboSystem")

	if hit_judgment == null or combo_system == null:
		push_warning("SceneWiring: HitJudgment or ComboSystem not found — combo chain broken")
		return

	if not hit_judgment.hit_landed.is_connected(_on_hit_landed_for_combo):
		hit_judgment.hit_landed.connect(_on_hit_landed_for_combo)
		_connections["hit_to_combo"] = true


## 命中回调 → 连击计数
func _on_hit_landed_for_combo(result: Object) -> void:
	var combo_system := get_node_or_null("/root/ComboSystem")
	if combo_system == null:
		return
	combo_system.on_hit_landed(result.sword_form)


## 游戏状态变化回调
## 非 COMBAT 状态隐藏 HUD，DEATH 状态显示游戏结束画面
func _on_game_state_changed(old_state: int, new_state: int) -> void:
	if _battle_hud == null:
		return

	# GameStateManager.State 枚举值: TITLE=0, COMBAT=1, INTERMISSION=2, DEATH=3, RESTART=4
	if new_state == 1:  # COMBAT
		_battle_hud.restore_hud()
	elif new_state == 3:  # DEATH
		# 显示游戏结束画面（获取当前分数）
		var score := 0
		if _scoring_system != null and _scoring_system.has_method("get_current_score"):
			var score_data = _scoring_system.get_current_score()
			if score_data is Object and score_data.has_method("get"):
				score = score_data.get("highest_wave", 0) * 100 + score_data.get("longest_combo", 0) * 10
		_battle_hud.show_game_over(score)
	elif new_state == 4:  # RESTART
		_battle_hud.hide_all_menus()
		_battle_hud.restore_hud()


## 命中反馈回调 → 播放对应音效
func _on_feedback_triggered(form: int, material_type: String, stop_frames: int) -> void:
	if _audio_manager == null:
		return

	# 根据剑式和材质选择音效
	var sfx_name := _get_hit_sfx_name(form, material_type)
	if sfx_name != "":
		_audio_manager.play_sfx(sfx_name, 0.8, 1.0)


## 根据剑式和材质映射音效名称
func _get_hit_sfx_name(form: int, material_type: String) -> String:
	# 剑式 × 材质 → 音效名
	# form: 0=ENEMY, 1=YOU(游), 2=RAO(绕), 3=ZUAN(钻)
	var prefix := ""
	match form:
		1: prefix = "hit_you"
		2: prefix = "hit_rao"
		3: prefix = "hit_zuan"
		_: prefix = "hit_generic"

	# 材质后缀
	var suffix := ""
	match material_type:
		"metal": suffix = "_metal"
		"wood": suffix = "_wood"
		"ink": suffix = "_ink"
		"body": suffix = "_body"
		_: suffix = ""

	return prefix + suffix


## 检查指定连接是否已建立（测试用）
## @param connection_name: String — 连接名
## @return bool
func is_connection_active(connection_name: String) -> bool:
	return _connections.get(connection_name, false)


## 获取已建立的连接数（测试用）
## @return int
func get_connection_count() -> int:
	return _connections.size()
