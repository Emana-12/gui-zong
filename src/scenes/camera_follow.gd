## CameraFollow — 轻量级摄像机跟随脚本
##
## 如果需要更简单的跟随逻辑，可替代 CameraController。
## 当前主场景使用 CameraController（完整功能：跟随 + 效果 + 状态驱动）。
## 此脚本仅作为备选或独立场景的简单跟随需求。
##
## 使用方式:
##   var follow := CameraFollow.new()
##   follow.set_target(player_node)
##
## @see CameraController (完整摄像机系统)
class_name CameraFollow
extends Node3D

## 跟随插值速度
const FOLLOW_SPEED: float = 5.0

## 相机俯角（度）
const TILT_DEG: float = 45.0

## 相机高度（米）
const HEIGHT: float = 6.0

## 相机距离（米）
const DISTANCE: float = 8.0

## 相机 FOV
const FOV: float = 60.0

## 跟随目标
var _target: Node3D = null

## Camera3D 子节点
var _camera: Camera3D = null


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.position = Vector3(0.0, HEIGHT, DISTANCE)
	_camera.rotation_degrees.x = -TILT_DEG
	add_child(_camera)


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var target_pos := _target.global_position
	var new_x := lerpf(global_position.x, target_pos.x, FOLLOW_SPEED * delta)
	var new_z := lerpf(global_position.z, target_pos.z, FOLLOW_SPEED * delta)
	global_position = Vector3(new_x, HEIGHT, new_z)


## 设置跟随目标
func set_target(target: Node3D) -> void:
	_target = target


## 获取 Camera3D 引用
func get_camera() -> Camera3D:
	return _camera
