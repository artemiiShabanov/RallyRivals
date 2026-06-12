extends RigidBody3D
## ADR-001 Spike B — custom raycast "arcade" car. THROWAWAY prototype.
## The chassis is this RigidBody; four down-rays do everything by hand:
##   1. suspension (spring push per wheel)   2. grip (cancel sideways slip)   3. drive/brake.
## Steering is emergent: turning the front wheels redirects their grip force, which yaws
## the car — the real raycast-car behavior. Tune the exports while driving.
##
## Forward is +Z here (to match Spike A's camera so the A/B is fair) — an arbitrary choice.
## Drive: W/RT accelerate · S/LT brake then reverse · A,D / stick steer · Space/A handbrake · R reset

@export var suspension_rest := 0.5
@export var wheel_radius := 0.3
@export var suspension_stiffness := 20000.0
@export var suspension_damping := 2500.0
@export var drive_force := 9000.0          ## forward push at full throttle
@export var brake_force := 6000.0
@export var front_grip := 0.9              ## 0..1 lateral slip cancelled per step (front)
@export var rear_grip := 0.5              ## rear grip; lower = more oversteer / drift
@export var handbrake_rear_grip := 0.15    ## rear grip while handbraking (drift)
@export var max_steer_deg := 20.0
@export var steer_speed := 6.0
@export var drag := 1.2                     ## linear drag → soft top-speed cap
@export var upright_strength := 40.0        ## how hard the car springs back upright (anti-flip)
@export var upright_damp := 8.0             ## damping on tilt so it doesn't wobble

var _spawn := Transform3D()
var _front: Array[RayCast3D] = []
var _all: Array[RayCast3D] = []
var _steer := 0.0

func _ready() -> void:
	_spawn = global_transform
	can_sleep = false
	for c in get_children():
		if c is RayCast3D:
			_all.append(c)
			if c.name.begins_with("RayF"):
				_front.append(c)

func _point_velocity(world_point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(world_point - global_position)

func _physics_process(delta: float) -> void:
	var throttle := Input.get_action_strength("accelerate")
	var reverse := Input.get_action_strength("brake_reverse")
	var steer_input := Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")
	var handbraking := Input.is_action_pressed("handbrake")

	# Ease steering, apply it to the front wheels (rotating their grip direction).
	var target := deg_to_rad(max_steer_deg) * steer_input
	_steer = move_toward(_steer, target, steer_speed * delta)
	for w in _front:
		w.rotation.y = _steer

	var grounded := 0
	for w in _all:
		if not w.is_colliding():
			continue
		grounded += 1
		var origin := w.global_position
		var up := global_transform.basis.y
		var dist := origin.distance_to(w.get_collision_point())
		var rest_len := suspension_rest + wheel_radius
		var vel := _point_velocity(origin)

		# 1. Suspension spring (push only — never pulls the car down).
		var spring := (rest_len - dist) * suspension_stiffness - up.dot(vel) * suspension_damping
		if spring > 0.0:
			apply_force(up * spring, origin - global_position)

		# 2. Lateral grip — cancel a fraction of sideways slip.
		var right := w.global_transform.basis.x
		var g := front_grip if _front.has(w) else rear_grip
		if handbraking and not _front.has(w):
			g = handbrake_rear_grip
		var lateral := right.dot(vel)
		# Apply at COM HEIGHT (zero the vertical lever): still yaws the car for steering,
		# but produces no roll torque, so a hard grip force can't flip it.
		var grip_offset := origin - global_position
		grip_offset.y = 0.0
		apply_force(right * (-lateral * g * mass * 0.25 / delta), grip_offset)

	# 3. Drive / brake / reverse along chassis forward, scaled by how many wheels are down.
	if grounded > 0:
		var fwd := global_transform.basis.z
		var speed := fwd.dot(linear_velocity)
		var traction := float(grounded) / float(_all.size())
		if reverse > 0.0 and speed > 1.0:
			apply_central_force(-fwd * brake_force * reverse * traction)
		else:
			apply_central_force(fwd * (throttle - reverse) * drive_force * traction)

	# Soft top-speed cap.
	apply_central_force(-linear_velocity * drag * mass * 0.01)

	# Anti-flip: spring the car's up-vector toward world up. Acts on TILT only (pitch/roll),
	# never on yaw, so steering is untouched. Guarantees the car can't roll over.
	var up := global_transform.basis.y
	var tilt_axis := up.cross(Vector3.UP)                       # axis that rotates up -> world up
	var yaw_rate := angular_velocity.dot(Vector3.UP)
	var tilt_rate := angular_velocity - Vector3.UP * yaw_rate   # angular velocity minus yaw
	apply_torque((tilt_axis * upright_strength - tilt_rate * upright_damp) * mass)

	if Input.is_action_just_pressed("reset_car"):
		global_transform = _spawn
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
