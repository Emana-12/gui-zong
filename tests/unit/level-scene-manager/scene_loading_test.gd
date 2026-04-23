## SceneLoadingTest — LevelSceneManager 场景加载与切换测试
##
## 测试覆盖: Story 001 的验收标准
## - reset_scene() 销毁旧场景并重新实例化
## - change_scene() 切换场景并发出信号
## - fade 过渡动画
## - 边界场景：连续调用、不存在的场景名、当前场景与目标相同
##
## 依赖: GDUnit4 测试框架
@tool
extends GdUnitTestSuite

## 被测实例
var _manager: LevelSceneManager

## 模拟 ActiveScene 容器
var _active_scene_container: Node3D

## 模拟 FadeRect
var _fade_rect: ColorRect

## Mock 信号捕获
var _scene_changed_captured: Array[String] = []
var _scene_reset_captured: int = 0


func before_test() -> void:
	_scene_changed_captured.clear()
	_scene_reset_captured = 0

	# 创建 SceneManager 实例
	_manager = auto_free(LevelSceneManager.new())
	_manager.name = "SceneManager"

	# 创建 ActiveScene 容器
	_active_scene_container = auto_free(Node3D.new())
	_active_scene_container.name = "ActiveScene"
	_manager.add_child(_active_scene_container)

	# 创建 FadeOverlay + FadeRect
	var overlay := auto_free(CanvasLayer.new())
	overlay.name = "FadeOverlay"
	overlay.layer = 100
	_manager.add_child(overlay)

	_fade_rect = auto_free(ColorRect.new())
	_fade_rect.name = "FadeRect"
	_fade_rect.visible = false
	_fade_rect.color = Color(0, 0, 0, 0)
	overlay.add_child(_fade_rect)

	# 连接信号
	_manager.scene_changed.connect(_on_scene_changed)
	_manager.scene_reset.connect(_on_scene_reset)

	# 添加到场景树（测试执行器自动处理）


func _on_scene_changed(scene_name: String) -> void:
	_scene_changed_captured.append(scene_name)


func _on_scene_reset() -> void:
	_scene_reset_captured += 1


# ============================================================
# 场景加载测试
# ============================================================

## 验证场景管理器初始化后 active_scene_container 被正确引用
func test_initialization_sets_container_reference() -> void:
	assert_bool(_manager.is_scene_loaded()).is_true()


## 验证默认场景为 "mountain"
func test_default_scene_is_mountain() -> void:
	# 注意: 此测试依赖预加载的 PackedScene 资源
	# 在 Headless 模式下可能需要 Mock
	assert_str(_manager.get_current_scene()).is_equal("mountain")


# ============================================================
# reset_scene() 测试 — AC-1
# ============================================================

## 验证 reset_scene() 后场景被销毁并重新实例化
## Given: 当前场景为 mountain
## When: 调用 reset_scene()
## Then: 旧实例被移除，新实例被添加
func test_reset_scene_removes_old_and_adds_new() -> void:
	# Arrange
	var old_instance: Node3D = _manager._active_instance

	# Act
	_manager.reset_scene()

	# Assert
	var new_instance: Node3D = _manager._active_instance
	assert_object(new_instance).is_not_null()
	assert_object(new_instance).is_not_same(old_instance)
	assert_str(_manager.get_current_scene()).is_equal("mountain")


## 验证连续调用 reset_scene 不会导致重复实例化
## Given: 场景已加载
## When: 连续调用两次 reset_scene()
## Then: 只有一个活跃实例
func test_reset_scene_consecutive_calls_no_duplicate() -> void:
	_manager.reset_scene()

	# 等待一帧（transitioning 锁会阻止第二次调用）
	await get_tree().process_frame

	_manager.reset_scene()

	await get_tree().process_frame

	assert_int(_active_scene_container.get_child_count()).is_equal(1)


## 验证 reset_scene() 发出 scene_reset 信号
func test_reset_scene_emits_signal() -> void:
	var count_before: int = _scene_reset_captured

	_manager.reset_scene()

	await get_tree().process_frame

	assert_int(_scene_reset_captured).is_equal(count_before + 1)


## 验证无场景时 reset_scene 不崩溃
## Given: active_instance = null
## When: 调用 reset_scene()
## Then: 无崩溃，日志有警告
func test_reset_scene_with_no_scene_returns_gracefully() -> void:
	# 强制清除场景状态
	_manager._active_instance = null
	_manager._current_scene = ""

	# 应无崩溃
	_manager.reset_scene()
	# _transitioning 应为 false
	assert_bool(_manager._transitioning).is_false()


# ============================================================
# change_scene() 测试 — AC-2
# ============================================================

## 验证 change_scene("bamboo") 加载水竹区场景
func test_change_scene_loads_bamboo() -> void:
	_manager.change_scene("bamboo")

	# 等待信号链完成 (fade + frame)
	await get_tree().create_timer(0.5).timeout

	assert_str(_manager.get_current_scene()).is_equal("bamboo")
	assert_object(_manager._active_instance).is_not_null()


## 验证 change_scene 发出 scene_changed 信号
func test_change_scene_emits_signal() -> void:
	_manager.change_scene("bamboo")

	await get_tree().create_timer(0.5).timeout

	assert_array(_scene_changed_captured).contains("bamboo")


## 验证切换到不存在的场景名 — 应报错但不崩溃
func test_change_scene_to_invalid_name_returns_gracefully() -> void:
	var scene_before: String = _manager.get_current_scene()

	_manager.change_scene("nonexistent")

	await get_tree().process_frame

	# 场景不应改变
	assert_str(_manager.get_current_scene()).is_equal(scene_before)


## 验证切换到当前场景（相同名称）— 应静默忽略
func test_change_scene_to_same_scene_is_ignored() -> void:
	var signal_count_before: int = _scene_changed_captured.size()

	_manager.change_scene("mountain")  # 当前已是 mountain

	await get_tree().process_frame

	# 信号不应发出
	assert_int(_scene_changed_captured.size()).is_equal(signal_count_before)


## 验证切换到 bamboo 后再切回 mountain
func test_change_scene_back_and_forth() -> void:
	_manager.change_scene("bamboo")
	await get_tree().create_timer(0.5).timeout
	assert_str(_manager.get_current_scene()).is_equal("bamboo")

	_manager.change_scene("mountain")
	await get_tree().create_timer(0.5).timeout
	assert_str(_manager.get_current_scene()).is_equal("mountain")


# ============================================================
# Fade 过渡测试 — AC-3
# ============================================================

## 验证 fade_duration = 0 时无动画直接切换
func test_change_scene_zero_fade_duration_no_animation() -> void:
	_manager.fade_duration = 0.0

	_manager.change_scene("bamboo")

	# 等一帧即可，无需等待 fade 时间
	await get_tree().process_frame

	assert_str(_manager.get_current_scene()).is_equal("bamboo")


## 验证 fade_rect 在非切换状态不可见
func test_fade_rect_hidden_when_not_transitioning() -> void:
	_manager.fade_duration = 0.3

	# 等待任何可能的动画完成
	await get_tree().create_timer(1.0).timeout

	assert_bool(_fade_rect.visible).is_false()
