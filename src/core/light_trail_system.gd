## LightTrailSystem — 流光轨迹系统核心
##
## 管理剑气轨迹的生成、更新、淡出和销毁。
## 使用 MeshInstance3D + ImmediateMesh 渲染轨迹，
## 池化预创建 50 个节点避免运行时分配，
## 3 种共享材质（游/钻/绕各一种）确保 draw call 最小化。
##
## 设计参考:
## - design/gdd/light-trail-system.md
## - docs/architecture/adr-0008-light-trail-rendering-architecture.md
## - docs/architecture/control-manifest.md §Feature Layer
##
## 职责边界:
## - 做: 轨迹生成/更新/淡出/销毁、池化管理、共享材质
## - 不做: 剑招逻辑（三式剑招系统）、碰撞检测（物理碰撞层）

class_name LightTrailSystem
extends Node

# --- 常量 ---

## 最大同时活跃轨迹数
const MAX_ACTIVE_TRAILS: int = 50

## 轨迹最大点数（防止无限增长）
const MAX_POINTS_PER_TRAIL: int = 200

## 轨迹宽度默认值（米）
const DEFAULT_TRAIL_WIDTH: float = 0.05

## 淡出最小 alpha 阈值（低于此值视为完全透明）
const FADE_ALPHA_THRESHOLD: float = 0.01

## 剑式名称常量
const FORM_YOU: StringName = &"you"
const FORM_ZUAN: StringName = &"zuan"
const FORM_RAO: StringName = &"rao"

## 轨迹配置表 — 每种剑式的视觉参数
const FORM_TRAIL_CONFIG: Dictionary = {
	FORM_YOU: {
		"color": Color(0.831, 0.659, 0.263, 0.8),  # 金墨 #D4A843
		"width": 0.1,
		"fade_time": 0.6,
	},
	FORM_ZUAN: {
		"color": Color(0.961, 0.902, 0.722, 0.9),  # 金白 #F5E6B8
		"width": 0.3,
		"fade_time": 0.4,
	},
	FORM_RAO: {
		"color": Color(0.3, 0.3, 0.4, 0.7),         # 亮墨
		"width": 0.25,
		"fade_time": 0.8,
	},
}

# --- 信号 ---

## 轨迹创建信号
signal trail_created(trail_id: int, form: StringName)

## 轨迹完成信号（开始淡出）
signal trail_finished(trail_id: int)

## 轨迹销毁信号（淡出结束）
signal trail_destroyed(trail_id: int)

## 轨迹被拒绝信号（达到上限）
signal trail_rejected(form: StringName)

# --- 内部数据结构 ---

## 轨迹数据容器
class TrailData:
	var id: int = -1
	var form: StringName = &""
	var points: PackedVector3Array = PackedVector3Array()
	var active: bool = false
	var fading: bool = false
	var fade_timer: float = 0.0
	var fade_time: float = 0.0
	var alpha: float = 1.0
	var mesh_instance: MeshInstance3D = null
	var immediate_mesh: ImmediateMesh = null
	var material: ShaderMaterial = null
	var width: float = 0.05

# --- 池 ---

## 预创建的节点池（索引 = 节点）
var _node_pool: Array[MeshInstance3D] = []

## 可用池节点栈（索引 = 节点，取栈顶分配）
var _available_indices: Array[int] = []

## 活跃轨迹数据（trail_id -> TrailData）
var _active_trails: Dictionary = {}

## 自增 ID 计数器
var _next_trail_id: int = 0

## 共享材质缓存（form_name -> ShaderMaterial）
var _shared_materials: Dictionary = {}

## ShaderManager 引用（延迟获取）
var _shader_manager: Node = null

# --- 生命周期 ---

func _ready() -> void:
	# 获取 ShaderManager 引用（Autoload 单例）
	_shader_manager = get_node_or_null("/root/ShaderManager")

	# 初始化共享材质
	_init_shared_materials()

	# 预创建节点池
	_init_node_pool()


func _process(delta: float) -> void:
	_update_fading_trails(delta)


# --- 公共 API ---

## 创建指定剑式的轨迹
## @param form: StringName — 剑式名称 (you/zuan/rao)
## @param start_pos: Vector3 — 轨迹起始位置
## @return int — 轨迹 ID，池满时返回 -1
func create_trail(form: StringName, start_pos: Vector3) -> int:
	# 上限检查
	if _active_trails.size() >= MAX_ACTIVE_TRAILS:
		push_warning("LightTrailSystem: 活跃轨迹已达上限 (%d/%d)，拒绝创建 '%s'" % [_active_trails.size(), MAX_ACTIVE_TRAILS, form])
		trail_rejected.emit(form)
		return -1

	# 验证剑式
	if not FORM_TRAIL_CONFIG.has(form):
		push_warning("LightTrailSystem: 未知剑式 '%s'" % form)
		return -1

	# 从池中取节点
	var pool_node := _acquire_pool_node()
	if pool_node == null:
		push_warning("LightTrailSystem: 池中无可用节点，拒绝创建轨迹")
		trail_rejected.emit(form)
		return -1

	# 创建轨迹数据
	var trail_id := _next_trail_id
	_next_trail_id += 1

	var config: Dictionary = FORM_TRAIL_CONFIG[form]
	var trail := TrailData.new()
	trail.id = trail_id
	trail.form = form
	trail.active = true
	trail.fading = false
	trail.alpha = 1.0
	trail.width = config["width"]
	trail.fade_time = config["fade_time"]
	trail.mesh_instance = pool_node
	trail.immediate_mesh = pool_node.mesh as ImmediateMesh
	trail.material = _shared_materials.get(form) as ShaderMaterial
	trail.points.append(start_pos)

	# 配置池节点
	_setup_trail_node(trail)

	_active_trails[trail_id] = trail
	trail_created.emit(trail_id, form)
	return trail_id


## 更新轨迹点位置
## @param trail_id: int — 轨迹 ID
## @param pos: Vector3 — 新的轨迹点位置
func update_trail(trail_id: int, pos: Vector3) -> void:
	if not _active_trails.has(trail_id):
		return

	var trail: TrailData = _active_trails[trail_id]
	if not trail.active or trail.fading:
		return

	# 点数上限检查
	if trail.points.size() >= MAX_POINTS_PER_TRAIL:
		return

	trail.points.append(pos)
	_rebuild_trail_mesh(trail)


## 结束轨迹（冻结并开始淡出）
## @param trail_id: int — 轨迹 ID
func finish_trail(trail_id: int) -> void:
	if not _active_trails.has(trail_id):
		return

	var trail: TrailData = _active_trails[trail_id]
	if not trail.active or trail.fading:
		return

	trail.active = false
	trail.fading = true
	trail.fade_timer = trail.fade_time
	trail.alpha = 1.0

	# 如果 fade_time 为 0 或极小，立即销毁
	if trail.fade_time <= 0.0:
		_destroy_trail(trail_id)
		return

	trail_finished.emit(trail_id)


## 获取当前活跃轨迹数量
## @return int — 活跃轨迹数（包括正在淡出的）
func get_active_trail_count() -> int:
	return _active_trails.size()


## 获取指定剑式的共享材质
## @param form: StringName — 剑式名称
## @return ShaderMaterial 或 null
func get_shared_material(form: StringName) -> ShaderMaterial:
	return _shared_materials.get(form) as ShaderMaterial


## 检查是否达到轨迹上限
## @return bool
func is_at_capacity() -> bool:
	return _active_trails.size() >= MAX_ACTIVE_TRAILS


## 强制销毁所有轨迹（场景切换时使用）
func clear_all_trails() -> void:
	var trail_ids := _active_trails.keys()
	for trail_id in trail_ids:
		_destroy_trail(trail_id as int)
	_active_trails.clear()


## 万剑归宗批量轨迹创建
## @param count: int — 轨迹数量
## @param center: Vector3 — 中心位置
func create_myriad_trails(count: int, center: Vector3) -> void:
	var actual_count := mini(count, MAX_ACTIVE_TRAILS - _active_trails.size())
	for i in range(actual_count):
		var angle := TAU * i / actual_count
		var radius := 1.0 + randf() * 3.0
		var offset := Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		var trail_id := create_trail(FORM_YOU, center + offset)
		if trail_id >= 0:
			# 立即添加第二个点使轨迹可见
			update_trail(trail_id, center + offset * 1.5)
			# 短延迟后结束轨迹（淡出）
			var fade_time := FORM_TRAIL_CONFIG[FORM_YOU]["fade_time"]
			get_tree().create_timer(0.5 + randf() * 0.5).timeout.connect(
				func(): finish_trail(trail_id)
			)


# --- 内部方法 ---

## 初始化共享材质（3 种剑式各一种）
func _init_shared_materials() -> void:
	# 尝试加载着色器
	var shader: Shader = null
	var shader_path := "res://shaders/shd_light_trail.gdshader"
	if ResourceLoader.exists(shader_path):
		shader = load(shader_path) as Shader

	for form_name in FORM_TRAIL_CONFIG:
		var config: Dictionary = FORM_TRAIL_CONFIG[form_name]
		var color: Color = config["color"]

		var mat: Material = null
		if _shader_manager and _shader_manager.has_method("create_trail_material"):
			mat = _shader_manager.create_trail_material(color, 1.0)
		elif shader:
			# 使用着色器材质
			var shader_mat := ShaderMaterial.new()
			shader_mat.shader = shader
			shader_mat.set_shader_parameter("trail_color", Vector3(color.r, color.g, color.b))
			shader_mat.set_shader_parameter("trail_alpha", 1.0)
			shader_mat.set_shader_parameter("use_vertex_color", 1.0)
			mat = shader_mat
		else:
			# 最终回退：StandardMaterial3D
			mat = _create_fallback_material(color)

		_shared_materials[form_name] = mat


## 回退材质创建（着色器不可用时）
func _create_fallback_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	return mat


## 初始化节点池（预创建 50 个 MeshInstance3D）
func _init_node_pool() -> void:
	for i in range(MAX_ACTIVE_TRAILS):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.visible = false

		# 创建 ImmediateMesh
		var imm_mesh := ImmediateMesh.new()
		mesh_instance.mesh = imm_mesh

		# 添加到场景树（作为子节点）
		add_child(mesh_instance)

		# 入池
		_node_pool.append(mesh_instance)
		_available_indices.append(i)


## 从池中获取一个可用节点
## @return MeshInstance3D 或 null
func _acquire_pool_node() -> MeshInstance3D:
	if _available_indices.is_empty():
		return null

	var pool_index: int = _available_indices.pop_back()
	var node: MeshInstance3D = _node_pool[pool_index]
	node.visible = true
	return node


## 归还节点到池中
## @param node: MeshInstance3D — 要归还的节点
func _release_pool_node(node: MeshInstance3D) -> void:
	if node == null:
		return

	# 清空 ImmediateMesh
	var imm_mesh := node.mesh as ImmediateMesh
	if imm_mesh:
		imm_mesh.clear_surfaces()

	# 设为不可见
	node.visible = false

	# 找到池索引并归还
	var pool_index := _node_pool.find(node)
	if pool_index >= 0:
		_available_indices.append(pool_index)


## 配置轨迹节点（设置材质、可见性等）
## @param trail: TrailData — 轨迹数据
func _setup_trail_node(trail: TrailData) -> void:
	if trail.mesh_instance == null:
		return

	# 设置共享材质
	if trail.immediate_mesh and trail.material:
		# ImmediateMesh 在首次 surface_begin 时创建表面，之后才能设置材质
		# 这里先不设置，等 _rebuild_trail_mesh 时处理
		pass

	trail.mesh_instance.visible = true


## 重建轨迹网格（每帧添加点后调用）
## @param trail: TrailData — 轨迹数据
func _rebuild_trail_mesh(trail: TrailData) -> void:
	if trail.immediate_mesh == null:
		return
	if trail.points.size() < 2:
		return

	# 清空旧表面
	trail.immediate_mesh.clear_surfaces()

	# 开始新表面 — 使用三角带（TRIANGLE_STRIP）渲染轨迹宽度
	trail.immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var points := trail.points
	var point_count := points.size()

	for i in range(point_count):
		var pos: Vector3 = points[i]

		# 计算轨迹方向（前后两点连线方向）
		var forward := Vector3.ZERO
		if i < point_count - 1:
			forward = (points[i + 1] - pos).normalized()
		elif i > 0:
			forward = (pos - points[i - 1]).normalized()

		# 计算宽度方向（垂直于前进方向，在 XZ 平面上）
		var up := Vector3.UP
		var right := forward.cross(up).normalized()
		if right.length_squared() < 0.001:
			# forward 几乎与 UP 平行时的回退
			right = Vector3.RIGHT

		var half_width := trail.width * 0.5
		var offset := right * half_width

		# UV: x 从 0（起点）到 1（终点），用于着色器淡出
		var uv_x := float(i) / float(maxi(point_count - 1, 1))

		# 顶点颜色 = 轨迹颜色 × alpha（用于 StandardMaterial3D 渲染）
		var trail_color: Color = FORM_TRAIL_CONFIG.get(trail.form, {}).get("color", Color.WHITE)
		var vert_color := Color(trail_color.r, trail_color.g, trail_color.b, trail.alpha)

		# 三角带：每对顶点形成一条横截面，相邻横截面之间形成两个三角形
		trail.immediate_mesh.surface_set_color(vert_color)
		trail.immediate_mesh.surface_set_uv(Vector2(uv_x, 0.0))
		trail.immediate_mesh.surface_add_vertex(pos - offset)

		trail.immediate_mesh.surface_set_color(vert_color)
		trail.immediate_mesh.surface_set_uv(Vector2(uv_x, 1.0))
		trail.immediate_mesh.surface_add_vertex(pos + offset)

	trail.immediate_mesh.surface_end()

	# 设置共享材质（只设置一次，不修改 uniform）
	if trail.material and trail.immediate_mesh.get_surface_count() > 0:
		trail.immediate_mesh.surface_set_material(0, trail.material)


## 更新淡出轨迹
## @param delta: float — 帧间隔
func _update_fading_trails(delta: float) -> void:
	# 收集需要销毁的 ID（避免遍历时修改字典）
	var to_destroy: Array[int] = []

	for trail_id in _active_trails:
		var trail: TrailData = _active_trails[trail_id]
		if not trail.fading:
			continue

		trail.fade_timer -= delta
		var progress := 1.0 - (trail.fade_timer / trail.fade_time) if trail.fade_time > 0.0 else 1.0
		trail.alpha = 1.0 - progress

		# 淡出完成
		if trail.fade_timer <= 0.0 or trail.alpha <= FADE_ALPHA_THRESHOLD:
			to_destroy.append(trail_id)
		else:
			# 重建网格 — 通过顶点颜色 alpha 传递给着色器
			# 共享材质的 trail_alpha 保持 1.0，不被修改
			_rebuild_trail_mesh(trail)

	# 销毁完成的轨迹
	for trail_id in to_destroy:
		_destroy_trail(trail_id)


## 销毁轨迹（归还节点到池中）
## @param trail_id: int — 轨迹 ID
func _destroy_trail(trail_id: int) -> void:
	if not _active_trails.has(trail_id):
		return

	var trail: TrailData = _active_trails[trail_id]

	# 重置材质透明度（共享材质，影响同式其他轨迹）
	# 注意：归还节点前不要重置共享材质的 alpha，因为其他活跃轨迹也在用
	# 每个轨迹的 alpha 由 _update_fading_trails 逐帧设置

	# 归还节点
	_release_pool_node(trail.mesh_instance)

	# 移除数据
	_active_trails.erase(trail_id)

	trail_destroyed.emit(trail_id)


# --- 测试辅助 ---

## 获取指定 ID 的轨迹数据（仅测试用）
## @param trail_id: int
## @return TrailData 或 null
func _test_get_trail_data(trail_id: int) -> TrailData:
	return _active_trails.get(trail_id) as TrailData


## 获取池可用节点数（仅测试用）
## @return int
func _test_get_available_pool_count() -> int:
	return _available_indices.size()


## 获取共享材质字典（仅测试用）
## @return Dictionary
func _test_get_shared_materials() -> Dictionary:
	return _shared_materials
