# SPDX-License-Identifier: MIT
# 命中反馈系统 — 场景节点，桥接命中信号到帧级反馈（顿帧、屏幕震动、材质反应、万剑归宗）。
class_name HitFeedbackSystem
extends Node3D

## 监听 hit_landed 信号，根据剑式和材质类型分发顿帧、震动和材质反应粒子。
## 万剑归宗触发时覆盖为最高优先级反馈（5 顿帧 + 强烈震动 + 全屏金色爆发）。
## 低帧率（fps < 30）时缩放顿帧数以保持可玩性。
##
## 设计参考:
## - docs/architecture/adr-0013-hit-feedback-architecture.md
## - design/gdd/hit-feedback.md
## - production/epics/hit-feedback/story-001-hit-stop-shake.md
## - production/epics/hit-feedback/story-002-material-reaction-pool.md
## - production/epics/hit-feedback/story-003-myriad-sword-feedback.md
##
## 依赖:
## - HitJudgment (hit_landed 信号源)
## - CameraController (set_camera_controller 注入)
## - ComboSystem (myriad_triggered 信号)
##
## @see ADR-0013

## 命中反馈信号。下游系统（HUD、音频）和测试用。
## @param form: int - HitJudgment.SwordForm 枚举值
## @param material_type: String - 材质类型名
## @param stop_frames: int - 实际顿帧数
signal feedback_triggered(form: int, material_type: String, stop_frames: int)

## 材质反应生成信号。音频系统可监听此信号播放对应音效。
## @param effect_type: String - 效果名 (gold_sparks, wood_crack, ink_splash)
## @param position: Vector3 - 生成位置
signal material_reaction_spawned(effect_type: String, position: Vector3)

## 万剑归宗反馈开始信号。
signal myriad_feedback_started

## 万剑归宗反馈结束信号。
signal myriad_feedback_finished

## 万剑归宗反馈优先级最高
const PRIO_ULTIMATE: int = 100

## 低帧率阈值（fps 低于此值时缩放顿帧）
const LOW_FPS_THRESHOLD: int = 30

## 默认帧率（引擎未初始化时回退）
const DEFAULT_FPS: int = 60

## 低帧率缩放系数：fps / 30 取 min 为 0.5
const LOW_FPS_SCALE_MIN: float = 0.5

## ── 对象池 ────────────────────────────────────────────────────────────────
## 材质反应对象池容量。同时活跃节点上限，保证 draw call <= 4/帧。
const POOL_CAPACITY: int = 4

## 材质反应自动回收时间（秒）。
const MATERIAL_REACTION_LIFETIME: float = 0.5

## ── 剑式→顿帧映射 ────────────────────────────────────────────────────────
## 基础顿帧 = 2 + floor(damage / 2)
## YOU(1) → damage 1 → 2; RAO(2) → damage 2 → 3; ZUAN(3) → damage 3 → 3
const FORM_BASE_STOP: Dictionary = {
	1: 2,  # YOU: 2 + floor(1/2) = 2
	2: 3,  # RAO: 2 + floor(2/2) = 3
	3: 3,  # ZUAN: 2 + floor(3/2) = 3
	0: 2,  # ENEMY: 2 + floor(1/2) = 2
}

## ── 剑式→震动参数 ────────────────────────────────────────────────────────
## { form: { "intensity": float, "duration": float } }
const FORM_SHAKE: Dictionary = {
	0: { "intensity": 0.3, "duration": 0.10 },  # ENEMY
	1: { "intensity": 0.4, "duration": 0.12 },  # YOU
	2: { "intensity": 0.5, "duration": 0.15 },  # RAO
	3: { "intensity": 0.6, "duration": 0.18 },  # ZUAN
}

## ── 材质→震动倍率 ────────────────────────────────────────────────────────
const MATERIAL_SHAKE_MULTIPLIER: Dictionary = {
	&"metal": 1.3,
	&"body": 1.0,
	&"ink": 0.8,
	&"wood": 1.1,
}

## ── 万剑归宗顿帧（覆盖所有剑式，优先级最高）─────────────────────────────
const ULTIMATE_STOP_FRAMES: int = 5
const ULTIMATE_SHAKE: Dictionary = {
	"intensity": 0.8,
	"duration": 0.25,
}

## ── 材质反应分发表 ────────────────────────────────────────────────────────
## 剑式 × 材质 → 效果名。ADR-0013 Feedback Dispatch Table。
## { form: { material: effect_name } }
const REACTION_DISPATCH: Dictionary = {
	1: {  # YOU (游剑式)
		&"metal": &"gold_sparks",
		&"wood": &"wood_crack",
		&"body": &"ink_splash",
		&"ink": &"ink_splash",
	},
	2: {  # RAO (绕剑式)
		# 绕剑式始终产生墨点炸碎
		&"metal": &"ink_splash",
		&"wood": &"ink_splash",
		&"body": &"ink_splash",
		&"ink": &"ink_splash",
	},
	3: {  # ZUAN (钻剑式)
		# 钻剑式始终产生扇形冲击波
		&"metal": &"shockwave",
		&"wood": &"shockwave",
		&"body": &"shockwave",
		&"ink": &"shockwave",
	},
	0: {  # ENEMY
		&"metal": &"gold_sparks",
		&"wood": &"wood_crack",
		&"body": &"ink_splash",
		&"ink": &"ink_splash",
	},
}

## ── 万剑归宗全屏效果 ──────────────────────────────────────────────────────
## 金色爆发持续时间（秒）。
const MYRIAD_BURST_DURATION: float = 0.5

## 金色爆发颜色 (RGB, alpha 由 Tween 控制)。
const MYRIAD_BURST_COLOR: Color = Color(1.0, 0.85, 0.2, 1.0)

## ── 运行时状态 ────────────────────────────────────────────────────────────
var _camera_controller: CameraController = null
var _is_ultimate_active: bool = false

## 材质反应对象池：4 个 Sprite3D 节点。
var _reaction_pool: Array[Sprite3D] = []

## 活跃的材质反应节点（正在播放效果的节点）。
var _active_reactions: Array[Sprite3D] = []

## 万剑归宗全屏 CanvasLayer。
var _myriad_canvas: CanvasLayer = null

## 万剑归宗全屏 ColorRect。
var _myriad_color_rect: ColorRect = null

## 万剑归宗效果是否正在播放。
var _myriad_burst_active: bool = false


## ── 公开 API ──────────────────────────────────────────────────────────────

## 注入 CameraController 引用。由场景树组装时调用。
## @param controller: CameraController - 相机控制器
func set_camera_controller(controller: CameraController) -> void:
	_camera_controller = controller


## 启用万剑归宗模式（顿帧、震动均覆盖为最高优先级值）。
## 由 WanJianGuiZong 系统在归宗启动时调用。
func enable_ultimate_feedback() -> void:
	_is_ultimate_active = true


## 禁用万剑归宗模式，恢复普通剑式反馈。
func disable_ultimate_feedback() -> void:
	_is_ultimate_active = false


## 是否处于万剑归宗反馈模式。
## @return bool
func is_ultimate_active() -> bool:
	return _is_ultimate_active


## 触发万剑归宗特殊反馈。
## 5 顿帧帧 + 强烈震动 + 全屏金色爆发 + 优先级覆盖。
## 由 ComboSystem.myriad_triggered 信号调用。
##
## @param combo_count: int - 当前连击数（保留接口，当前未使用）
func trigger_myriad_feedback(combo_count: int = 0) -> void:
	# 标记万剑归宗激活
	_is_ultimate_active = true

	# 广播开始信号
	myriad_feedback_started.emit()

	# 1. 顿帧覆盖（5 帧，固定值）
	if _camera_controller != null:
		if _camera_controller.has_method("trigger_hit_stop"):
			_camera_controller.trigger_hit_stop(ULTIMATE_STOP_FRAMES)
		# 强烈震动：±0.3m (intensity 0.8 对应 ADR 规格的 ±0.3m 范围)，持续 0.3s
		if _camera_controller.has_method("trigger_shake"):
			_camera_controller.trigger_shake(0.3, 0.3)

	# 2. 全屏金色爆发
	_start_myriad_burst()

	# 3. 反馈信号（万剑归宗固定顿帧 = 5）
	feedback_triggered.emit(-1, "myriad", ULTIMATE_STOP_FRAMES)

	# 4. 0.5 秒后恢复
	var timer := get_tree().create_timer(MYRIAD_BURST_DURATION)
	timer.timeout.connect(_on_myriad_finished)


## 触发材质反应。从对象池中取出节点，放置在命中点，0.5 秒后自动回收。
## 若池满（4 个都在用），静默跳过。
##
## @param effect_type: StringName - 效果名 (gold_sparks, wood_crack, ink_splash, shockwave)
## @param position: Vector3 - 命中点世界坐标
func spawn_material_reaction(effect_type: StringName, position: Vector3) -> void:
	# 池满检查：静默跳过，优先保证帧率
	if _active_reactions.size() >= POOL_CAPACITY:
		return

	# 从池中取出一个空闲节点
	var node := _acquire_pool_node()
	if node == null:
		return

	# 定位并激活
	node.global_position = position
	node.visible = true
	node.set_meta(&"effect_type", effect_type)
	_active_reactions.append(node)

	# 广播信号（音频系统可监听）
	material_reaction_spawned.emit(String(effect_type), position)

	# 0.5 秒后自动回收
	var timer := get_tree().create_timer(MATERIAL_REACTION_LIFETIME)
	timer.timeout.connect(_recycle_node.bind(node))


## 获取对象池中活跃节点数（测试用）。
## @return int - 当前活跃反应节点数
func get_active_reaction_count() -> int:
	return _active_reactions.size()


## 获取对象池总容量（测试用）。
## @return int - 池容量
func get_pool_capacity() -> int:
	return POOL_CAPACITY


## ── 生命周期 ──────────────────────────────────────────────────────────────

func _ready() -> void:
	# 添加到 hit_feedback group（SceneWiring 通过 group 查找）
	add_to_group("hit_feedback")

	# 自动查找 HitJudgment Autoload 并连接信号
	var hj: Node = HitJudgment
	if hj == null:
		push_warning("HitFeedbackSystem: HitJudgment autoload not found")
		return
	if not hj.hit_landed.is_connected(_on_hit_landed):
		hj.hit_landed.connect(_on_hit_landed)

	# 自动查找 ComboSystem 并连接万剑归宗信号
	var cs: Node = get_node_or_null("/root/ComboSystem")
	if cs != null and cs.has_signal("myriad_triggered"):
		if not cs.myriad_triggered.is_connected(_on_myriad_triggered):
			cs.myriad_triggered.connect(_on_myriad_triggered)

	# 初始化材质反应对象池
	_init_reaction_pool()

	# 初始化万剑归宗全屏效果层
	_init_myriad_overlay()


func _exit_tree() -> void:
	# 清理信号连接
	var hj: Node = HitJudgment
	if hj != null and hj.hit_landed.is_connected(_on_hit_landed):
		hj.hit_landed.disconnect(_on_hit_landed)

	var cs: Node = get_node_or_null("/root/ComboSystem")
	if cs != null and cs.has_signal("myriad_triggered"):
		if cs.myriad_triggered.is_connected(_on_myriad_triggered):
			cs.myriad_triggered.disconnect(_on_myriad_triggered)


## ── 信号回调 ──────────────────────────────────────────────────────────────

## 接收 HitJudgment.hit_landed 信号，计算并分发顿帧、震动和材质反应。
func _on_hit_landed(result: Object) -> void:
	var form: int = result.sword_form
	var material: StringName = result.material_type
	var damage: int = result.damage

	var stop_frames: int = _calculate_stop_frames(form, damage)
	var shake_data: Dictionary = _calculate_shake(form, material)

	# 低帧率自适应：fps < 30 时缩放顿帧
	var current_fps: int = Engine.get_frames_per_second()
	if current_fps < LOW_FPS_THRESHOLD and current_fps > 0:
		var scale: float = float(current_fps) / float(LOW_FPS_THRESHOLD)
		scale = maxf(scale, LOW_FPS_SCALE_MIN)
		stop_frames = maxi(1, int(round(float(stop_frames) * scale)))

	# 应用顿帧
	if _camera_controller != null and _camera_controller.has_method("trigger_hit_stop"):
		_camera_controller.trigger_hit_stop(stop_frames)

	# 应用震动
	if _camera_controller != null and _camera_controller.has_method("trigger_shake"):
		_camera_controller.trigger_shake(
			shake_data["intensity"],
			shake_data["duration"]
		)

	# 生成材质反应（万剑归宗模式下跳过普通材质反应）
	if not _is_ultimate_active:
		var effect_type := _get_reaction_type(form, material)
		spawn_material_reaction(effect_type, result.hit_position)

	# 广播反馈信号
	feedback_triggered.emit(form, String(material), stop_frames)


## 接收 ComboSystem.myriad_triggered 信号。
func _on_myriad_triggered(trail_count: int, damage: float, radius: float) -> void:
	trigger_myriad_feedback()


## ── 材质反应分发 ──────────────────────────────────────────────────────────

## 根据剑式和材质类型查找对应的效果名。
## @param form: int - SwordForm 枚举值
## @param material: StringName - 材质类型
## @return StringName - 效果名
func _get_reaction_type(form: int, material: StringName) -> StringName:
	var form_reactions: Dictionary = REACTION_DISPATCH.get(form, REACTION_DISPATCH.get(0, {}))
	return form_reactions.get(material, &"ink_splash")


## ── 对象池管理 ────────────────────────────────────────────────────────────

## 初始化材质反应对象池。预创建 POOL_CAPACITY 个 Sprite3D 节点。
func _init_reaction_pool() -> void:
	for i in POOL_CAPACITY:
		var sprite := Sprite3D.new()
		sprite.visible = false
		# 所有 Sprite3D 共享默认材质，保证 1 个 draw call 批次
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.modulate = Color.WHITE
		add_child(sprite)
		_reaction_pool.append(sprite)


## 从池中取出一个空闲节点。若无空闲节点返回 null。
## @return Sprite3D - 空闲节点或 null
func _acquire_pool_node() -> Sprite3D:
	for node in _reaction_pool:
		if not _active_reactions.has(node):
			return node
	return null


## 回收节点到池中。隐藏节点并从活跃列表移除。
## @param node: Sprite3D - 要回收的节点
func _recycle_node(node: Sprite3D) -> void:
	if node == null:
		return
	node.visible = false
	_active_reactions.erase(node)


## ── 万剑归宗全屏效果 ──────────────────────────────────────────────────────

## 初始化万剑归宗全屏效果层（CanvasLayer + ColorRect）。
func _init_myriad_overlay() -> void:
	_myriad_canvas = CanvasLayer.new()
	_myriad_canvas.layer = 128  # 最高层
	_myriad_canvas.visible = false
	add_child(_myriad_canvas)

	_myriad_color_rect = ColorRect.new()
	_myriad_color_rect.color = MYRIAD_BURST_COLOR
	# 全屏覆盖
	_myriad_color_rect.anchors_preset = Control.PRESET_FULL_RECT
	_myriad_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_myriad_canvas.add_child(_myriad_color_rect)


## 启动全屏金色爆发效果。从透明渐变到金色，再渐隐。
func _start_myriad_burst() -> void:
	if _myriad_canvas == null or _myriad_color_rect == null:
		return

	_myriad_burst_active = true
	_myriad_canvas.visible = true

	# 从透明开始，快速淡入到金色
	var start_color := Color(MYRIAD_BURST_COLOR.r, MYRIAD_BURST_COLOR.g, MYRIAD_BURST_COLOR.b, 0.0)
	_myriad_color_rect.color = start_color

	var tween := create_tween()
	# 前 0.15s 淡入
	tween.tween_property(_myriad_color_rect, "color:a", 1.0, 0.15)
	# 后 0.35s 淡出
	tween.tween_property(_myriad_color_rect, "color:a", 0.0, 0.35)


## 万剑归宗效果完成回调。
func _on_myriad_finished() -> void:
	_myriad_burst_active = false
	_is_ultimate_active = false

	# 隐藏全屏效果层
	if _myriad_canvas != null:
		_myriad_canvas.visible = false

	# 恢复颜色（下次使用时从透明开始）
	if _myriad_color_rect != null:
		_myriad_color_rect.color = Color(MYRIAD_BURST_COLOR.r, MYRIAD_BURST_COLOR.g, MYRIAD_BURST_COLOR.b, 0.0)

	myriad_feedback_finished.emit()


## ── 内部计算 ──────────────────────────────────────────────────────────────

## 计算顿帧数。万剑归宗覆盖为固定值，否则用基础表 + 伤害微调。
## @param form: int - SwordForm 枚举值
## @param damage: int - 伤害值
## @return int - 顿帧数（>= 1）
func _calculate_stop_frames(form: int, damage: int) -> int:
	if _is_ultimate_active:
		return ULTIMATE_STOP_FRAMES

	# 公式: 2 + floor(damage / 2)
	var frames: int = 2 + (damage / 2)

	# 回退：未知剑式用 ENEMY 值
	if not FORM_BASE_STOP.has(form):
		frames = FORM_BASE_STOP[0]

	return maxi(1, frames)


## 计算震动参数。万剑归宗覆盖为固定值，否则用剑式 + 材质倍率。
## @param form: int - SwordForm 枚举值
## @param material: StringName - 材质类型
## @return Dictionary - { "intensity": float, "duration": float }
func _calculate_shake(form: int, material: StringName) -> Dictionary:
	if _is_ultimate_active:
		return {
			"intensity": ULTIMATE_SHAKE["intensity"],
			"duration": ULTIMATE_SHAKE["duration"],
		}

	var base: Dictionary = FORM_SHAKE.get(form, FORM_SHAKE[0])
	var multiplier: float = MATERIAL_SHAKE_MULTIPLIER.get(material, 1.0)

	return {
		"intensity": base["intensity"] * multiplier,
		"duration": base["duration"],
	}
