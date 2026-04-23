## 水墨着色器测试场景脚本
## S02-01: Ink-Wash Shader Prototype
##
## 程序化创建测试几何体并应用三种着色器材质。
## 在 Godot 编辑器中打开 shader_test.tscn 运行。
## @see S02-01

extends Node3D

## ShaderManager 引用
var _shader_manager: Node

## 测试用材质
var _character_mat: ShaderMaterial
var _environment_mat: ShaderMaterial
var _trail_mat: ShaderMaterial

## FPS 标签
@onready var _fps_label: Label = $UI/FPSLabel
@onready var _info_label: Label = $UI/InfoLabel


func _ready() -> void:
	# 获取 ShaderManager autoload
	_shader_manager = get_node("/root/ShaderManager")

	if _shader_manager == null:
		push_error("ShaderManager autoload 未找到。请在项目设置中添加。")
		return

	_setup_character_test()
	_setup_environment_test()
	_setup_trail_test()
	_update_info()


func _process(_delta: float) -> void:
	if _shader_manager and _fps_label:
		_fps_label.text = "FPS: %d | Pool: %s | Degraded: %s" % [
			_shader_manager.get_fps(),
			str(_shader_manager.get_pool_usage()),
			str(_shader_manager.is_degraded())
		]


func _setup_character_test() -> void:
	## 角色着色器测试 — 球体 + toon ramp + rim light
	_character_mat = _shader_manager.get_material(&"character_test")
	if _character_mat == null:
		return

	var sphere := $CharacterTest/MeshInstance3D as MeshInstance3D
	if sphere:
		sphere.material_override = _character_mat
		# 设置角色参数
		_character_mat.set_shader_parameter("base_color", Vector3(0.102, 0.102, 0.18))
		_character_mat.set_shader_parameter("highlight_color", Vector3(0.831, 0.659, 0.263))
		_character_mat.set_shader_parameter("highlight_intensity", 0.5)
		_character_mat.set_shader_parameter("ink_edge_softness", 0.2)
		_character_mat.set_shader_parameter("rim_light_power", 3.0)


func _setup_environment_test() -> void:
	## 环境着色器测试 — 地面平面 + stepped lighting
	_environment_mat = _shader_manager.get_material(&"environment_test")
	if _environment_mat == null:
		return

	var ground := $EnvironmentTest/Floor as MeshInstance3D
	if ground:
		ground.material_override = _environment_mat
		_environment_mat.set_shader_parameter("base_color", Vector3(0.29, 0.29, 0.369))
		_environment_mat.set_shader_parameter("ink_dark", Vector3(0.102, 0.102, 0.18))
		_environment_mat.set_shader_parameter("ink_steps", 4)

	# 墙面也用环境着色器
	var wall := $EnvironmentTest/Wall as MeshInstance3D
	if wall:
		wall.material_override = _environment_mat


func _setup_trail_test() -> void:
	## 轨迹着色器测试 — 透明平面 + additive blend + fade
	_trail_mat = _shader_manager.create_trail_material(
		Color(0.831, 0.659, 0.263),
		0.8
	)
	if _trail_mat == null:
		return

	var trail := $TrailTest/TrailMesh as MeshInstance3D
	if trail:
		trail.material_override = _trail_mat
		_trail_mat.set_shader_parameter("fade_speed", 1.0)
		_trail_mat.set_shader_parameter("glow_intensity", 0.3)


func _update_info() -> void:
	if _info_label:
		_info_label.text = (
			"Ink-Wash Shader Test\n"
			+ "左: 角色着色器 (toon ramp + rim light)\n"
			+ "中: 环境着色器 (stepped lighting)\n"
			+ "右: 轨迹着色器 (additive glow + fade)\n"
			+ "\n按键: [1] 高光切换 [2] ink_steps +/- [3] 辉光切换"
		)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	match event.keycode:
		KEY_1:
			# 切换角色高光
			if _character_mat:
				var current: float = _character_mat.get_shader_parameter("highlight_intensity")
				var next := 0.0 if current > 0.0 else 1.0
				_character_mat.set_shader_parameter("highlight_intensity", next)
				_shader_manager.set_character_highlight(next)

		KEY_2:
			# 循环 ink_steps: 2 → 3 → 4 → 5 → 2
			if _environment_mat:
				var current: int = _environment_mat.get_shader_parameter("ink_steps")
				var next := (current + 1) if current < 5 else 2
				_environment_mat.set_shader_parameter("ink_steps", next)

		KEY_3:
			# 切换轨迹辉光
			if _trail_mat:
				var current: float = _trail_mat.get_shader_parameter("glow_intensity")
				var next := 0.0 if current > 0.0 else 0.8
				_trail_mat.set_shader_parameter("glow_intensity", next)
