## BattleHUD — 战斗界面层
##
## 管理战斗中的 HUD 显示：生命值墨滴、连击计数器、剑式指示器、蓄力环。
## 使用 CanvasLayer + Control 节点架构，信号订阅模式。
## 3 秒无受击自动淡出至 30% alpha，受伤后立即恢复全显。
##
## 设计参考:
## - design/gdd/hud-ui-system.md
## - docs/architecture/adr-0015-hud-ui-architecture.md
## - design/art/art-bible.md (Section 7: 墨迹侵蚀式)
##
## @see ADR-0015
## @see production/epics/hud-ui-system/story-001-combat-hud-display.md
## @see production/epics/hud-ui-system/story-002-hud-auto-fade.md
## @see production/epics/hud-ui-system/story-003-menu-game-over.md
class_name BattleHUD
extends CanvasLayer

## 自动淡出延迟（秒）— 超过此时间无受击则 HUD 半透明
const AUTO_FADE_DELAY: float = 3.0

## 自动淡出目标 alpha
const FADED_ALPHA: float = 0.3

## 全显 alpha
const FULL_ALPHA: float = 1.0

## 淡出速度（lerp 系数）
const FADE_SPEED: float = 3.0

## 最大墨滴数量（生命值上限）
const MAX_INK_DROPS: int = 3

## 最大墨点数量（连击视觉上限）
const MAX_INK_DOTS: int = 20

## 金墨颜色
const GOLD_COLOR: Color = Color(0.831, 0.659, 0.263)  # #D4A843

## CJK 字体路径
const CJK_FONT_PATH: String = "res://assets/fonts/NotoSansSC-Subset.ttf"

## 墨黑颜色
const INK_COLOR: Color = Color(0.102, 0.102, 0.18)  # #1A1A2E

## 死亡画面文字颜色（纯白，非金墨，确保灰阶背景对比度）
const DEATH_TEXT_COLOR: Color = Color.WHITE

## 死亡画面分数文字颜色（金墨色）
const SCORE_TEXT_COLOR: Color = Color(0.85, 0.65, 0.13)  # #D9A621

## 墨迹侵蚀动画时长（秒）
const INK_EROSION_DURATION: float = 0.5

## 游戏结束面板尺寸
const GAME_OVER_PANEL_SIZE: Vector2 = Vector2(400, 300)

## 信号
signal hud_faded()
signal hud_restored()

## 菜单打开时发出。参数: (menu_name: String)
signal menu_opened(menu_name: String)

## 菜单关闭时发出。参数: (menu_name: String)
signal menu_closed(menu_name: String)

## HUD 淡出状态改变时发出。参数: (alpha: float)
signal hud_fade_changed(alpha: float)

## HUD 根节点引用
var _hud_root: Control = null

## CJK 字体资源
var _cjk_font: FontFile = null

## 生命值墨滴节点列表
var _ink_drops: Array[Control] = []

## 连击数字标签
var _combo_label: Label = null

## 连击墨点容器
var _ink_dots_container: HBoxContainer = null

## 剑式指示器节点列表 [游, 钻, 绕]
var _form_indicators: Array[Control] = []

## 蓄力环节点
var _charge_ring: Control = null

## 当前 HUD alpha
var _current_alpha: float = 1.0

## 上次受击时间（引擎运行秒数）
var _last_hit_time: float = -100.0

## 目标 alpha
var _target_alpha: float = 1.0

## 是否已初始化
var _initialized: bool = false

## 菜单栈 — push/pop 语义
var _menu_stack: Array[String] = []

## 菜单节点映射 — menu_name -> Control
var _menu_nodes: Dictionary = {}

## 菜单层引用
var _menu_layer: Control = null

## 游戏结束面板（动态创建）
var _game_over_panel: PanelContainer = null


func _ready() -> void:
	layer = 10  # HUD 在最上层
	# 添加到 battle_hud group（SceneWiring 通过 group 查找）
	add_to_group("battle_hud")
	# 加载 CJK 字体
	if ResourceLoader.exists(CJK_FONT_PATH):
		_cjk_font = load(CJK_FONT_PATH) as FontFile
	_find_nodes()
	_apply_cjk_font_recursive(self)
	_initialized = true


func _process(delta: float) -> void:
	if not _initialized:
		return
	_update_auto_fade(delta)


## 查找子节点（延迟绑定，不依赖场景结构）
func _find_nodes() -> void:
	_hud_root = find_child("HUDRoot", true, false) as Control
	if _hud_root == null:
		# 如果没有 HUDRoot，自身就是根
		_hud_root = null

	# 查找菜单层
	_menu_layer = find_child("MenuLayer", true, false) as Control
	if _menu_layer:
		_menu_layer.visible = false

	# 查找连击标签
	_combo_label = find_child("ComboLabel", true, false) as Label

	# 查找墨点容器
	_ink_dots_container = find_child("InkDotsContainer", true, false) as HBoxContainer

	# 查找蓄力环
	_charge_ring = find_child("ChargeRing", true, false) as Control

	# 查找生命值墨滴
	_ink_drops.clear()
	for i in range(MAX_INK_DROPS):
		var drop := find_child("InkDrop%d" % (i + 1), true, false) as Control
		if drop:
			_ink_drops.append(drop)

	# 查找剑式指示器
	_form_indicators.clear()
	for form_name in ["You", "Zuan", "Rao"]:
		var indicator := find_child("FormIndicator%s" % form_name, true, false) as Control
		if indicator:
			_form_indicators.append(indicator)


## 更新生命值显示
## @param current_hp: int — 当前生命值
## @param max_hp: int — 最大生命值
func update_health_display(current_hp: int, max_hp: int) -> void:
	# 受伤后立即恢复 HUD 全显
	_last_hit_time = Time.get_ticks_msec() / 1000.0
	_target_alpha = FULL_ALPHA

	for i in range(_ink_drops.size()):
		var drop := _ink_drops[i]
		if i < current_hp:
			drop.visible = true
			# 墨滴缩放：根据生命值比例
			var scale_factor := clampf(float(current_hp) / float(maxi(max_hp, 1)), 0.3, 1.0)
			drop.scale = Vector2(scale_factor, scale_factor)
		else:
			drop.visible = false


## 更新连击显示
## @param combo_count: int — 当前连击数
func update_combo_display(combo_count: int) -> void:
	if _combo_label:
		if combo_count > 0:
			_combo_label.text = str(combo_count)
			_combo_label.add_theme_color_override("font_color", GOLD_COLOR)
			_combo_label.visible = true
		else:
			_combo_label.visible = false

	# 更新墨点
	_update_ink_dots(combo_count)


## 更新墨点显示
func _update_ink_dots(combo_count: int) -> void:
	if _ink_dots_container == null:
		return

	var children := _ink_dots_container.get_children()
	var visible_count := mini(combo_count, children.size())

	for i in range(children.size()):
		var child := children[i] as Control
		if child:
			child.visible = i < visible_count


## 更新剑式指示器
## @param active_form: int — 当前活跃剑式 (0=游, 1=钻, 2=绕)
func update_form_display(active_form: int) -> void:
	for i in range(_form_indicators.size()):
		var indicator := _form_indicators[i]
		if indicator:
			# 活跃剑式全显，其他半透明
			if i == active_form:
				indicator.modulate = Color(1, 1, 1, 1.0)
			else:
				indicator.modulate = Color(1, 1, 1, 0.3)


## 更新蓄力环
## @param progress: float — 蓄力进度 (0.0-1.0)
func update_charge_display(progress: float) -> void:
	if _charge_ring:
		_charge_ring.visible = progress > 0.0
		# 通过 scale 或自定义属性控制蓄力环显示
		_charge_ring.scale = Vector2(progress, progress)


## 更新波次显示
## @param wave_number: int — 波次编号
func update_wave_display(wave_number: int, _enemy_count: int = 0) -> void:
	var wave_label := find_child("WaveCount", true, false) as Label
	if wave_label:
		wave_label.text = "波 " + str(wave_number)
		wave_label.add_theme_color_override("font_color", GOLD_COLOR)


## 淡出 HUD
## @param to_alpha: float — 目标透明度
## @param duration: float — 淡出时长（秒，当前未使用，通过 lerp 速度控制）
func fade_hud(to_alpha: float, _duration: float) -> void:
	_target_alpha = maxf(to_alpha, 0.0)


## 立即恢复 HUD 全显
func restore_hud() -> void:
	_target_alpha = FULL_ALPHA
	_last_hit_time = Time.get_ticks_msec() / 1000.0


## 万剑归宗效果 — HUD 淡出
func trigger_myriad_hud_effect() -> void:
	fade_hud(0.0, 0.3)


## 万剑归宗结束 — 恢复 HUD
func restore_hud_from_myriad() -> void:
	restore_hud()


## 更新自动淡出
func _update_auto_fade(delta: float) -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	var time_since_hit := current_time - _last_hit_time

	# 3 秒无受击 → 自动半透明
	if time_since_hit > AUTO_FADE_DELAY and _target_alpha >= FULL_ALPHA:
		_target_alpha = FADED_ALPHA

	# 平滑插值
	_current_alpha = lerpf(_current_alpha, _target_alpha, FADE_SPEED * delta)

	# 应用到 HUD 根节点
	var root := _hud_root if _hud_root else self as Node
	if root is CanvasItem:
		(root as CanvasItem).modulate = Color(1, 1, 1, _current_alpha)
	elif root is Control:
		(root as Control).modulate = Color(1, 1, 1, _current_alpha)

	# 信号
	if _current_alpha <= FADED_ALPHA + 0.05 and _target_alpha <= FADED_ALPHA:
		hud_faded.emit()
	elif _current_alpha >= FULL_ALPHA - 0.05 and _target_alpha >= FULL_ALPHA:
		hud_restored.emit()

	hud_fade_changed.emit(_current_alpha)


## =========================================================================
## 菜单系统 (Story 003)
## =========================================================================

## 推入菜单到栈顶。
## 如果菜单栈中已有同名菜单则跳过（幂等）。
## @param menu_name: String — 菜单名称
func show_menu(menu_name: String) -> void:
	# 幂等检查 — 栈顶已是同名菜单时不重复推入
	if _menu_stack.size() > 0 and _menu_stack[-1] == menu_name:
		return

	# 获取菜单节点（如果是预注册的）
	var menu: Control = _menu_nodes.get(menu_name, null) as Control

	# 菜单层可见
	if _menu_layer:
		_menu_layer.visible = true

	if menu:
		menu.visible = true

	_menu_stack.append(menu_name)
	menu_opened.emit(menu_name)


## 弹出栈顶菜单。
## 空栈安全 — 不崩溃。
func hide_menu() -> void:
	if _menu_stack.is_empty():
		return

	var menu_name: String = _menu_stack.pop_back()

	# 隐藏该菜单节点
	var menu: Control = _menu_nodes.get(menu_name, null) as Control
	if menu:
		menu.visible = false

	# 栈空则隐藏菜单层
	if _menu_stack.is_empty() and _menu_layer:
		_menu_layer.visible = false

	menu_closed.emit(menu_name)


## 隐藏所有菜单并清空栈。
func hide_all_menus() -> void:
	# 逐个隐藏所有已注册菜单节点
	for menu_name in _menu_nodes:
		var menu: Control = _menu_nodes[menu_name] as Control
		if menu:
			menu.visible = false

	_menu_stack.clear()

	if _menu_layer:
		_menu_layer.visible = false


## 显示游戏结束画面。
## 创建纯白文字面板，墨迹侵蚀动画从边缘向中心展开。
## @param score: int — 游戏得分
func show_game_over(score: int) -> void:
	# 如果已存在先移除
	if _game_over_panel:
		_game_over_panel.queue_free()

	_game_over_panel = _create_game_over_panel(score)

	# 添加到菜单层
	if _menu_layer:
		_menu_layer.add_child(_game_over_panel)
		_menu_layer.visible = true

	# 推入菜单栈
	_menu_stack.append("game_over")
	menu_opened.emit("game_over")

	# 墨迹侵蚀动画 — 从边缘向中心展开
	_play_ink_erosion_animation(_game_over_panel)


## 创建游戏结束面板（纯白文字，非金墨）
func _create_game_over_panel(score: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = GAME_OVER_PANEL_SIZE
	panel.anchors_preset = Control.PRESET_CENTER
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -GAME_OVER_PANEL_SIZE.x / 2.0
	panel.offset_top = -GAME_OVER_PANEL_SIZE.y / 2.0
	panel.offset_right = GAME_OVER_PANEL_SIZE.x / 2.0
	panel.offset_bottom = GAME_OVER_PANEL_SIZE.y / 2.0
	panel.pivot_offset = GAME_OVER_PANEL_SIZE / 2.0

	# 墨色背景
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.08, 0.92)  # 近墨色半透明
	style.border_color = Color(0.25, 0.25, 0.25, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	# 垂直布局
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	# "剑已断" 标题 — 纯白文字（非金墨）
	var title_label := Label.new()
	title_label.text = "剑已断"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", DEATH_TEXT_COLOR)
	_apply_cjk_font(title_label)
	vbox.add_child(title_label)

	# 间距
	var spacer1 := Control.new()
	spacer1.custom_minimum_size.y = 20
	vbox.add_child(spacer1)

	# 得分标签 — 金墨色
	var score_label := Label.new()
	score_label.text = str(score)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 48)
	score_label.add_theme_color_override("font_color", SCORE_TEXT_COLOR)
	_apply_cjk_font(score_label)
	vbox.add_child(score_label)

	# "分" 标签 — 纯白
	var score_desc := Label.new()
	score_desc.text = "分"
	score_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_desc.add_theme_font_size_override("font_size", 18)
	score_desc.add_theme_color_override("font_color", DEATH_TEXT_COLOR)
	_apply_cjk_font(score_desc)
	vbox.add_child(score_desc)

	# 间距
	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 30
	vbox.add_child(spacer2)

	# 重新开始按钮 — 纯白文字
	var restart_btn := Button.new()
	restart_btn.text = "重新开始"
	restart_btn.custom_minimum_size = Vector2(160, 48)
	restart_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 按钮样式 — 墨色背景，纯白文字
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.15, 0.15)
	btn_normal.set_corner_radius_all(6)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.25, 0.25, 0.25)
	btn_hover.set_corner_radius_all(6)

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.1, 0.1, 0.1)
	btn_pressed.set_corner_radius_all(6)

	restart_btn.add_theme_stylebox_override("normal", btn_normal)
	restart_btn.add_theme_stylebox_override("hover", btn_hover)
	restart_btn.add_theme_stylebox_override("pressed", btn_pressed)
	restart_btn.add_theme_color_override("font_color", DEATH_TEXT_COLOR)
	restart_btn.add_theme_color_override("font_hover_color", DEATH_TEXT_COLOR)
	_apply_cjk_font(restart_btn)

	restart_btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart_btn)

	return panel


## 重新开始按钮回调 — 隐藏菜单并通知 GameStateManager
func _on_restart_pressed() -> void:
	# 隐藏游戏结束面板
	hide_menu()
	hide_all_menus()

	# 恢复 HUD
	restore_hud()

	# 通知游戏状态管理器
	var gsm := GameStateManager
	if gsm:
		gsm.change_state(4)  # RESTART


## 播放墨迹侵蚀动画 — 从边缘向中心展开
func _play_ink_erosion_animation(panel: PanelContainer) -> void:
	# 初始状态 — 缩放为 0（从中心点展开）
	panel.scale = Vector2.ZERO
	panel.modulate.a = 0.0

	# Tween 动画
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(panel, "scale", Vector2.ONE, INK_EROSION_DURATION)
	tween.tween_property(panel, "modulate:a", 1.0, INK_EROSION_DURATION * 0.6)


## =========================================================================
## 字体辅助
## =========================================================================

## 递归将 CJK 字体应用到所有 Label 和 Button 节点
func _apply_cjk_font_recursive(node: Node) -> void:
	if _cjk_font == null:
		return
	if node is Label or node is Button:
		node.add_theme_font_override("font", _cjk_font)
	for child in node.get_children():
		_apply_cjk_font_recursive(child)


## 为动态创建的 Label/Button 设置 CJK 字体
func _apply_cjk_font(node: Control) -> void:
	if _cjk_font == null:
		return
	if node is Label or node is Button:
		node.add_theme_font_override("font", _cjk_font)


## =========================================================================
## 测试辅助方法（仅用于单元测试）
## =========================================================================

## 测试辅助：获取当前 alpha
func _test_get_current_alpha() -> float:
	return _current_alpha


## 测试辅助：获取目标 alpha
func _test_get_target_alpha() -> float:
	return _target_alpha


## 测试辅助：强制设置上次受击时间
func _test_set_last_hit_time(time: float) -> void:
	_last_hit_time = time


## 测试辅助：获取菜单栈副本
func _test_get_menu_stack() -> Array[String]:
	return _menu_stack.duplicate()


## 测试辅助：设置 is_faded 标记
func _test_set_is_faded(faded: bool) -> void:
	# 由 _update_auto_fade 自动管理，但测试可间接通过设置 last_hit_time 控制
	pass


## 测试辅助：获取 is_faded 状态
func _test_is_faded() -> bool:
	return _current_alpha < FULL_ALPHA - 0.1
