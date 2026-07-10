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
@export var base_grip := 10.5           ## fallback friction_slip when a wheel touches untagged ground (no SurfaceType)
@export var front_grip_floor := 5.0     ## front never grips LESS than this — arcade cheat so the nose stays turnable even on ice (drift, not plow)
@export var rear_grip_ratio := 0.7      ## rear grip vs surface (<1 = tail slides = drift-prone, not plow)
@export var handbrake_rear_ratio := 0.2 ## rear grip while handbraking (instant drift)
@export var grip_falloff_start := 8.0    ## speed (m/s) where grip begins dropping
@export var grip_falloff_range := 12.0   ## m/s over which grip fades to the high-speed floor
@export var front_high_speed_grip := 0.8 ## front grip fraction at speed (stays grippy -> nose turns in)
@export var rear_high_speed_grip := 0.35 ## rear grip fraction at speed (lets go -> tail slides = oversteer)
@export var min_rear_grip_ratio := 0.3   ## rear floor as a FRACTION of the wheel's surface grip (relative, so it scales down on ice too)

@export_group("Anti-spin")
@export var max_yaw_rate := 2.0          ## rad/s — HARD cap on rotation speed; the car slides sideways instead of spinning to 180

var _spawn_transform: Transform3D
var _wheels: Array[VehicleWheel3D] = []

func _ready() -> void:
	_spawn_transform = global_transform
	for child in get_children():
		if child is VehicleWheel3D:
			_wheels.append(child)

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

	# Grip layer: front stays grippy, rear grips less (drift), and much less on handbrake.
	_apply_grip(Input.is_action_pressed("handbrake"))
	_clamp_yaw()

	# Ease steering toward the target so input isn't twitchy.
	steering = move_toward(steering, max_steer * steer_input, steer_speed * delta)

	if Input.is_action_just_pressed("reset_car"):
		reset()

## Per-wheel, SURFACE-RELATIVE grip. Each wheel reads the grip of whatever surface it's touching
## (SurfaceType on the contact body; base_grip when untagged). The front is kept turnable via a
## floor so the nose always points in; the rear scales fully with the surface so low-grip surfaces
## make the tail slide (drift) instead of the whole car plowing. code-vehicle-stats scales grip
## by the grip stat on top of this later.
func _apply_grip(handbraking: bool) -> void:
	# Grip fades with speed, but MORE at the rear than the front: the front keeps biting (nose
	# turns in) while the rear lets go (tail rotates) -> fast corners oversteer/drift instead of
	# plowing. Slow corners stay grippy.
	var speed := linear_velocity.length()
	var t := clampf((speed - grip_falloff_start) / grip_falloff_range, 0.0, 1.0)
	for w in _wheels:
		var g := _surface_grip(w)  # grip of the surface under THIS wheel
		if w.use_as_steering:  # front — floor keeps it turnable on any surface (arcade cheat)
			var front := maxf(g, front_grip_floor)
			w.wheel_friction_slip = front * lerpf(1.0, front_high_speed_grip, t)
		else:  # rear — scales with the surface, so slippery surfaces drift
			var rear := g * (handbrake_rear_ratio if handbraking else rear_grip_ratio)
			w.wheel_friction_slip = maxf(rear * lerpf(1.0, rear_high_speed_grip, t), g * min_rear_grip_ratio)

## Grip of the surface a wheel is touching. The contact body carries its SurfaceType as node
## metadata ("surface"); the track generator / test scene tags each surface body. Airborne or
## untagged ground falls back to base_grip.
func _surface_grip(w: VehicleWheel3D) -> float:
	if w.is_in_contact():
		var body := w.get_contact_body()
		if body != null and body.has_meta("surface"):
			var s: SurfaceType = body.get_meta("surface")
			if s != null:
				return s.grip
	return base_grip

## Hard-cap the yaw rate: the car can never rotate faster than max_yaw_rate, so when the rear
## breaks loose it slides sideways at a held angle instead of whipping around to 180. Turns below
## the cap are untouched. (A direct cap beats a counter-torque, which the grippy steered front
## just overpowers.)
func _clamp_yaw() -> void:
	var up := global_transform.basis.y
	var yaw_rate := angular_velocity.dot(up)
	if absf(yaw_rate) > max_yaw_rate:
		angular_velocity -= up * (yaw_rate - signf(yaw_rate) * max_yaw_rate)

## Speed along the car's forward (+Z) axis in m/s. Negative when reversing.
func get_forward_speed() -> float:
	return linear_velocity.dot(global_transform.basis.z)

## Respawn at the car's starting transform with zero velocity.
func reset() -> void:
	global_transform = _spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
