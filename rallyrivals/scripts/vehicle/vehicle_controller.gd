class_name VehicleController
extends VehicleBody3D
## Arcade vehicle controller — production base (ADR-001: VehicleBody3D + thin custom layers).
##
## This is the CORE drivable car only: throttle, brake, reverse, eased steering, handbrake,
## and reset, with a single uniform wheel grip. The feel layers build on top as separate tasks:
##   - front/rear grip split + handbrake drift  -> code-vehicle-grip
##   - per-surface grip (SurfaceType)           -> code-vehicle-surface-grip
##   - stat-driven handling (the 5 stat bars)   -> code-vehicle-stats
##
## Convention: this VehicleBody3D drives toward LOCAL +Z (engine_force > 0 -> +Z). The
## steering/front wheels sit at +Z; a chase camera sits behind at -Z.
##
## Inputs (project.godot): accelerate, brake_reverse, steer_left, steer_right, handbrake, reset_car.

@export_group("Drive")
@export var max_engine_force := 2500.0  ## drive force at full throttle (also used for reverse)
@export var max_brake := 40.0           ## brake force (foot brake and handbrake)

@export_group("Steering")
@export var max_steer := 0.6            ## steering angle at full lock (radians)
@export var steer_speed := 4.0          ## how fast steering eases toward the target (lower = softer)

@export_group("Grip")
@export var base_grip := 10.5           ## uniform wheel friction_slip; placeholder, retuned by balance-handling-feel

var _spawn_transform: Transform3D
var _wheels: Array[VehicleWheel3D] = []

func _ready() -> void:
	_spawn_transform = global_transform
	for child in get_children():
		if child is VehicleWheel3D:
			_wheels.append(child)
			child.wheel_friction_slip = base_grip

func _physics_process(delta: float) -> void:
	var throttle := Input.get_action_strength("accelerate")
	var reverse := Input.get_action_strength("brake_reverse")
	var steer_input := Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")

	# brake_reverse brakes while rolling forward, and reverses once nearly stopped.
	if reverse > 0.0 and get_forward_speed() > 1.0:
		engine_force = 0.0
		brake = max_brake * reverse
	else:
		engine_force = max_engine_force * (throttle - reverse)
		brake = 0.0

	# Handbrake = plain hard brake for the base; the drift version is code-vehicle-grip.
	if Input.is_action_pressed("handbrake"):
		brake = max_brake

	# Ease steering toward the target so input isn't twitchy.
	steering = move_toward(steering, max_steer * steer_input, steer_speed * delta)

	if Input.is_action_just_pressed("reset_car"):
		reset()

## Speed along the car's forward (+Z) axis in m/s. Negative when reversing.
func get_forward_speed() -> float:
	return linear_velocity.dot(global_transform.basis.z)

## Respawn at the car's starting transform with zero velocity.
func reset() -> void:
	global_transform = _spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
