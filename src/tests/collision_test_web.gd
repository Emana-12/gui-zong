## S02-04: Jolt Web Export — Collision Test Script
##
## Attach to the root node of collision_test_web.tscn.
## Run in Godot editor or exported build to verify Jolt physics behavior.
## Outputs results to console for manual verification.
##
## Usage: Open collision_test_web.tscn in Godot editor → Run Scene (F6)

extends Node3D

## Duration (seconds) to observe each scenario before logging results
const OBSERVE_DURATION := 3.0
## Threshold for "at rest" — velocity magnitude below this means settled
const REST_THRESHOLD := 0.05

@onready var _drop_sphere: RigidBody3D = $DropSphere
@onready var _bounce_sphere: RigidBody3D = $BounceSphere
@onready var _dynamic1: RigidBody3D = $DynamicSphere1
@onready var _dynamic2: RigidBody3D = $DynamicSphere2
@onready var _info_label: Label = $UI/InfoLabel

var _elapsed := 0.0
var _scenario := 0
var _floor_passed := false
var _wall_passed := false
var _dynamic_passed := false


func _ready() -> void:
	print("=== Jolt Collision Test (S02-04) ===")
	print("Physics engine: ", ProjectSettings.get_setting("physics/3d/physics_engine", "UNKNOWN"))
	_update_label("Initializing... Physics engine: " + str(ProjectSettings.get_setting("physics/3d/physics_engine", "UNKNOWN")))


func _physics_process(delta: float) -> void:
	_elapsed += delta

	if _elapsed >= OBSERVE_DURATION:
		_check_scenario()
		_elapsed = 0.0
		_scenario += 1

		if _scenario > 2:
			_print_results()
			set_physics_process(false)
			return

		_reset_scenario()


func _check_scenario() -> void:
	match _scenario:
		0:
			# Floor collision: drop sphere should be resting above floor (y > 0)
			var pos := _drop_sphere.global_position
			var vel := _drop_sphere.linear_velocity
			_floor_passed = pos.y > 0.1 and vel.length() < REST_THRESHOLD
			print("Scenario 1 (Floor): pos=", pos, " vel=", vel, " PASS=", _floor_passed)
		1:
			# Wall collision: bounce sphere should have stopped near/before wall (x < 5)
			var pos := _bounce_sphere.global_position
			var vel := _bounce_sphere.linear_velocity
			_wall_passed = pos.x < 4.8 and abs(vel.x) < 0.5
			print("Scenario 2 (Wall): pos=", pos, " vel=", vel, " PASS=", _wall_passed)
		2:
			# Dynamic collision: spheres should have exchanged or deflected momentum
			var vel1 := _dynamic1.linear_velocity
			var vel2 := _dynamic2.linear_velocity
			# After head-on collision, velocities should change direction
			var changed := (vel1.z < 0.5) or (vel2.z > -0.5)
			_dynamic_passed = changed and vel1.length() < 5.0 and vel2.length() < 5.0
			print("Scenario 3 (Dynamic): vel1=", vel1, " vel2=", vel2, " PASS=", _dynamic_passed)


func _reset_scenario() -> void:
	match _scenario:
		1:
			_update_label("Scenario 2: Bounce sphere → wall")
		2:
			_update_label("Scenario 3: Dynamic sphere collision")


func _update_label(text: String) -> void:
	if _info_label:
		_info_label.text = text


func _print_results() -> void:
	var all_pass := _floor_passed and _wall_passed and _dynamic_passed
	var results := "=== RESULTS ===\n"
	results += "Floor collision:    %s\n" % ("PASS" if _floor_passed else "FAIL")
	results += "Wall collision:     %s\n" % ("PASS" if _wall_passed else "FAIL")
	results += "Dynamic collision:  %s\n" % ("PASS" if _dynamic_passed else "FAIL")
	results += "Overall:            %s\n" % ("ALL PASS" if all_pass else "SOME FAILED")
	results += "Physics engine:     %s\n" % ProjectSettings.get_setting("physics/3d/physics_engine", "UNKNOWN")
	print(results)
	_update_label(results.replace("\n", "\n"))
