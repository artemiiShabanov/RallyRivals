extends VehicleBody3D
## ADR-001 Spike A — drive Godot's built-in VehicleBody3D and jot feel notes.
## THROWAWAY prototype (not production). Tune the exports in the inspector while playing,
## then record impressions in docs/adr/ADR-001.
##
## Drive: W/RT accelerate · S/LT brake then reverse · A,D / stick steer · Space/A handbrake
##        R reset

@export var max_engine_force := 2500.0  ## drive force at full throttle
@export var max_brake := 40.0           ## brake force
@export var max_steer := 0.6            ## radians at full lock
@export var steer_speed := 4.0          ## how fast steering eases toward target (lower = softer)
@export var default_grip := 5.5        ## wheel friction_slip on a surface with no grip_slip meta (asphalt)
@export var rear_grip_ratio := 0.7      ## rear grip vs front (<1 = tail slides = drift-prone, not plow)
@export var handbrake_rear_ratio := 0.2 ## rear grip while handbraking (instant drift)

var _spawn_transform: Transform3D
var _wheels: Array[VehicleWheel3D] = []
var _front_wheels: Array[VehicleWheel3D] = []

func _ready() -> void:
	_spawn_transform = global_transform
	for child in get_children():
		if child is VehicleWheel3D:
			_wheels.append(child)
			if child.use_as_steering:
				_front_wheels.append(child)

func _physics_process(delta: float) -> void:
	var throttle := Input.get_action_strength("accelerate")
	var reverse := Input.get_action_strength("brake_reverse")
	var steer_input := Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")

	# Per-wheel surface grip, with a FRONT/REAR split so loose surfaces drift (oversteer) instead
	# of plowing (understeer): the front keeps grip to point the nose, the rear lets go to slide.
	# (NOTE: surface PhysicsMaterial.friction does NOT affect wheel grip in Godot Physics —
	# verified empirically; that's why we drive wheel_friction_slip directly.)
	var handbraking := Input.is_action_pressed("handbrake")
	for w in _wheels:
		var base := default_grip
		if w.is_in_contact():
			var body := w.get_contact_body()
			if body and body.has_meta("grip_slip"):
				base = float(body.get_meta("grip_slip"))
		var is_front: bool = w.use_as_steering
		var s := base if is_front else base * rear_grip_ratio
		if handbraking and not is_front:
			s = base * handbrake_rear_ratio   # break the rear loose for an instant drift
		w.wheel_friction_slip = s

	# This VehicleBody3D drives toward +Z, so forward is +basis.z.
	var forward_speed := linear_velocity.dot(global_transform.basis.z)

	# brake_reverse = brake while rolling forward, reverse once nearly stopped.
	if reverse > 0.0 and forward_speed > 1.0:
		engine_force = 0.0
		brake = max_brake * reverse
	else:
		engine_force = max_engine_force * (throttle - reverse)
		brake = 0.0

	# (Handbrake no longer hard-brakes; it slashes rear grip above for a drift instead.)

	# Ease steering toward target so input isn't twitchy.
	var target_steer := max_steer * steer_input
	steering = move_toward(steering, target_steer, steer_speed * delta)

	if Input.is_action_just_pressed("reset_car"):
		_reset()

func _reset() -> void:
	global_transform = _spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
