@warning_ignore_start("inferred_declaration")
## SpawnPointsTest — LevelSceneManager 生成点与 Web 超时测试
##
## 测试覆盖: Story 002 的验收标准
## - get_spawn_points() 返回场景中所有 Marker3D 的位置
## - Web 超时（>5秒）回退到默认场景
## - 边界场景：无 Marker3D、Marker3D 有旋转不影响位置
##
## 依赖: GDUnit4 测试框架
@tool
extends GdUnitTestSuite

## 被测实例
var _manager: LevelSceneManager

## 模拟 ActiveScene 容器
var _active_scene_container: Node3D

## 模拟场景实例（替代真实的 PackedScene）
var _mock_scene_instance: Node3D


func before_test() -> void:
	# 创建 SceneManager 实例
	_manager = auto_free(LevelSceneManager.new())
	_manager.name = "SceneManager"

	# 创建 ActiveScene 容器
	_active_scene_container = auto_free(Node3D.new())
	_active_scene_container.name = "ActiveScene"
	_manager.add_child(_active_scene_container)

	# 创建 FadeOverlay + FadeRect（虽然此测试不测 fade，但 _ready 需要）
	var overlay: CanvasLayer = auto_free(CanvasLayer.new())
	overlay.name = "FadeOverlay"
	overlay.layer = 100
	_manager.add_child(overlay)

	var fade_rect: ColorRect = auto_free(ColorRect.new())
	fade_rect.name = "FadeRect"
	fade_rect.visible = false
	overlay.add_child(fade_rect)

	# 创建模拟场景实例（带有 Marker3D 子节点）
	_mock_scene_instance = auto_free(Node3D.new())
	_mock_scene_instance.name = "MockArena"
	_manager._active_scene_container = _active_scene_container
	_manager._active_instance = _mock_scene_instance
	_manager._current_scene = "mountain"
	_active_scene_container.add_child(_mock_scene_instance)


# ============================================================
# get_spawn_points() 测试 — AC-1
# ============================================================

## 验证 get_spawn_points() 返回场景中所有 Marker3D 的 global_position
## Given: 场景中有 5 个 Marker3D 节点
## When: 调用 get_spawn_points()
## Then: 返回包含 5 个 Vector3 的数组
func test_get_spawn_points_returns_all_markers() -> void:
	# Arrange: 添加 5 个 Marker3D 节点
	var expected_positions: Array[Vector3] = []
	for i in range(5):
		var marker: Marker3D = auto_free(Marker3D.new())
		marker.name = "SpawnPoint_%d" % i
		marker.position = Vector3(i * 2.0, 0.0, i * 3.0)
		_mock_scene_instance.add_child(marker)
		expected_positions.append(marker.global_position)

	# Act
	var points: PackedVector3Array = _manager.get_spawn_points()

	# Assert
	assert_int(points.size()).is_equal(5)
	for i in range(5):
		assert_vector3(points[i]).is_equal(expected_positions[i])


## 验证无 Marker3D 时返回空数组
## Given: 场景中没有 Marker3D 节点
## When: 调用 get_spawn_points()
## Then: 返回空数组
func test_get_spawn_points_empty_when_no_markers() -> void:
	var points: PackedVector3Array = _manager.get_spawn_points()
	assert_int(points.size()).is_equal(0)


## 验证只收集 SpawnPoint_ 前缀的 Marker3D
## Given: 场景中有 SpawnPoint_0 和 OtherMarker 两个 Marker3D
## When: 调用 get_spawn_points()
## Then: 只返回 SpawnPoint_0 的位置
func test_get_spawn_points_only_prefixed_markers() -> void:
	# Arrange
	var sp: Marker3D = auto_free(Marker3D.new())
	sp.name = "SpawnPoint_0"
	sp.position = Vector3(1, 0, 0)
	_mock_scene_instance.add_child(sp)

	var other: Marker3D = auto_free(Marker3D.new())
	other.name = "OtherMarker"
	other.position = Vector3(99, 0, 0)
	_mock_scene_instance.add_child(other)

	# Act
	var points: PackedVector3Array = _manager.get_spawn_points()

	# Assert
	assert_int(points.size()).is_equal(1)
	assert_vector3(points[0]).is_equal(Vector3(1, 0, 0))


## 验证 Marker3D 有旋转不影响位置值
## Given: Marker3D 有旋转和位置
## When: 调用 get_spawn_points()
## Then: 返回的 Vector3 只包含位置，不包含旋转
func test_get_spawn_points_rotation_ignored() -> void:
	var marker: Marker3D = auto_free(Marker3D.new())
	marker.name = "SpawnPoint_0"
	marker.position = Vector3(5.0, 2.0, 3.0)
	marker.rotation = Vector3(0.5, 1.2, 0.8)
	_mock_scene_instance.add_child(marker)

	var points: PackedVector3Array = _manager.get_spawn_points()

	assert_int(points.size()).is_equal(1)
	# global_position 不包含旋转信息
	assert_float(points[0].x).is_equal(5.0)
	assert_float(points[0].y).is_equal(2.0)
	assert_float(points[0].z).is_equal(3.0)


## 验证非 Marker3D 节点被忽略
## Given: 场景中有 MeshInstance3D 和 Marker3D
## When: 调用 get_spawn_points()
## Then: 只返回 Marker3D 的位置
func test_get_spawn_points_ignores_non_markers() -> void:
	var mesh: MeshInstance3D = auto_free(MeshInstance3D.new())
	mesh.name = "ArenaFloor"
	mesh.position = Vector3(100, 100, 100)
	_mock_scene_instance.add_child(mesh)

	var marker: Marker3D = auto_free(Marker3D.new())
	marker.name = "SpawnPoint_0"
	marker.position = Vector3(1, 0, 0)
	_mock_scene_instance.add_child(marker)

	var points: PackedVector3Array = _manager.get_spawn_points()
	assert_int(points.size()).is_equal(1)
	assert_vector3(points[0]).is_equal(Vector3(1, 0, 0))


## 验证无活跃场景实例时返回空数组
## Given: active_instance = null
## When: 调用 get_spawn_points()
## Then: 返回空数组
func test_get_spawn_points_no_active_scene_returns_empty() -> void:
	_manager._active_scene_container.remove_child(_mock_scene_instance)
	_manager._active_instance = null

	var points: PackedVector3Array = _manager.get_spawn_points()
	assert_int(points.size()).is_equal(0)


# ============================================================
# is_scene_loaded() 测试
# ============================================================

## 验证有场景实例时 is_scene_loaded 返回 true
func test_is_scene_loaded_true() -> void:
	assert_bool(_manager.is_scene_loaded()).is_true()


## 验证无场景实例时 is_scene_loaded 返回 false
func test_is_scene_loaded_false() -> void:
	_manager._active_scene_container.remove_child(_mock_scene_instance)
	_manager._active_instance = null
	_manager._current_scene = ""
	assert_bool(_manager.is_scene_loaded()).is_false()


# ============================================================
# 超时回退测试 — AC-2
# ============================================================

## 验证超时计时器初始化
## Given: SceneManager 完成 _ready()
## When: 检查超时计时器
## Then: Timer 存在且配置正确
func test_timeout_timer_exists_and_configured() -> void:
	assert_object(_manager._timeout_timer).is_not_null()
	assert_bool(_manager._timeout_timer.one_shot).is_true()


## 验证超时回退将场景恢复为默认场景
## Given: 当前场景为 bamboo，手动触发超时回调
## When: _on_load_timeout() 被调用
## Then: 当前场景变为 mountain
func test_timeout_fallback_to_default_scene() -> void:
	_manager._current_scene = "bamboo"
	_manager._transitioning = true

	# 清除当前实例
	_manager._active_scene_container.remove_child(_mock_scene_instance)
	_manager._active_instance = null

	# 手动调用超时回调
	_manager._on_load_timeout()

	assert_str(_manager.get_current_scene()).is_equal("mountain")
	assert_bool(_manager._transitioning).is_false()


## 验证超时回调清除旧的半加载场景
## Given: 有一个活跃实例（模拟部分加载的场景）
## When: _on_load_timeout() 被调用
## Then: 旧实例被移除
func test_timeout_clears_partial_loaded_scene() -> void:
	_manager._transitioning = true
	_manager._on_load_timeout()

	await get_tree().process_frame

	# 活跃实例应该是新创建的默认场景实例
	assert_object(_manager._active_instance).is_not_null()
	assert_str(_manager.get_current_scene()).is_equal("mountain")
