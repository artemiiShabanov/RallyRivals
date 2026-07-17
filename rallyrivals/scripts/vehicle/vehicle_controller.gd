class_name VehicleController
extends VehicleBody3D
## Arcade vehicle controller (ADR-001: VehicleBody3D + a thin custom handling layer).
##
## Handles throttle / brake / reverse, eased steering, handbrake, reset, and the arcade grip model:
## a front/rear grip split with a front floor (nose stays turnable), speed-sensitive falloff, and a
## hard yaw-rate cap for anti-spin. Grip is SURFACE-RELATIVE per wheel (see _apply_grip /
## _surface_grip).
##
## STATS (code-vehicle-stats): assign a CarDef and apply_car_def() derives the tuning from the
## five 1-10 bars via the endpoint tables below — balance-handling-classes tunes ENDPOINTS,
## never individual cars. Bar ~5 == the hand-tuned feel this controller shipped with. Forces are
## mass-compensated (bars never lie; mass = contact/momentum identity). Speed adds a top-speed
## cap: engine force tapers as 1-(v/max)^4. With car == null the scene's exported values apply
## unchanged.
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
@export var rear_grip_ratio := 0.85      ## rear grip vs surface (<1 = tail slides = drift-prone, not plow)
@export var handbrake_rear_ratio := 0.2 ## rear grip while handbraking (instant drift)
@export var grip_falloff_start := 8.0    ## speed (m/s) where grip begins dropping
@export var grip_falloff_range := 12.0   ## m/s over which grip fades to the high-speed floor
@export var front_high_speed_grip := 0.8 ## front grip fraction at speed (stays grippy -> nose turns in)
@export var rear_high_speed_grip := 0.35 ## rear grip fraction at speed (lets go -> tail slides = oversteer)
@export var min_rear_grip_ratio := 0.3   ## rear floor as a FRACTION of the wheel's surface grip (relative, so it scales down on ice too)

@export_group("Anti-spin")
@export var max_yaw_rate := 1.3          ## rad/s — HARD cap on rotation speed; the car slides sideways instead of spinning to 180. Skipped while braking (deliberate rotation)

@export_group("Stats")
@export var car: CarDef                  ## the roster car this body drives as (null = raw scene tuning)

# Bar-endpoint tables (bar 1 -> bar 10, lerped): the ONLY place stats meet physics numbers.
const ACCEL_FORCE := [1600.0, 3600.0]    # N at REF_MASS, scaled by mass (same m/s^2 in any car)
const BRAKE_FORCE := [24.0, 62.0]        # at REF_MASS, mass-scaled
const STEER_ANGLE := [0.45, 0.78]        # rad at full lock
const STEER_SPEED := [2.8, 6.5]
const YAW_RATE := [1.05, 1.65]           # rad/s anti-spin cap — steering cars may rotate faster
const GRIP_SCALE := [0.80, 1.22]         # multiplies SURFACE grip (stays situational, GDD 7)
const SPEED_KMH := [110.0, 210.0]        # top speed; engine tapers approaching it
const REF_MASS := 800.0                  # the mass all force/suspension baselines were tuned at

var grip_scale := 1.0
var max_speed := INF                     # m/s; INF = uncapped (no CarDef)

var _spawn_transform: Transform3D
var _wheels: Array[VehicleWheel3D] = []
var _base_stiffness := {}                # wheel -> scene-authored suspension baseline (REF_MASS)
var _base_max_force := {}
var _headlights_on := false
var _headlights: Array[Node3D] = []
var _taillights: Array[OmniLight3D] = []

func _ready() -> void:
	add_to_group("vehicles")
	_spawn_transform = global_transform
	for child in get_children():
		if child is VehicleWheel3D:
			_wheels.append(child)
			_base_stiffness[child] = child.suspension_stiffness
			_base_max_force[child] = child.suspension_max_force
	for lamp in ["HeadlightL", "HeadlightR"]:
		var n := get_node_or_null(lamp) as Node3D
		if n != null:
			_headlights.append(n)
	for lamp in ["TaillightL", "TaillightR"]:
		var n := get_node_or_null(lamp) as OmniLight3D
		if n != null:
			_taillights.append(n)
	apply_car_def()
	set_headlights(LightingPreset.current_headlights)

## Derive handling from the CarDef bars. Safe to call again (live car swap): suspension scales
## from the captured scene baselines, never compounds.
func apply_car_def() -> void:
	if car == null:
		return
	var m := car.mass / REF_MASS
	mass = car.mass
	max_engine_force = _bar(car.accel, ACCEL_FORCE) * m
	max_brake = _bar(car.braking, BRAKE_FORCE) * m
	max_steer = _bar(car.steering, STEER_ANGLE)
	steer_speed = _bar(car.steering, STEER_SPEED)
	max_yaw_rate = _bar(car.steering, YAW_RATE)
	grip_scale = _bar(car.grip, GRIP_SCALE)
	max_speed = _bar(car.speed, SPEED_KMH) / 3.6
	# the grip-vs-speed curve spans THIS car's envelope, not one fixed car's
	grip_falloff_start = max_speed * 0.2
	grip_falloff_range = max_speed * 0.3
	for w in _wheels:
		w.suspension_stiffness = _base_stiffness[w] * m
		w.suspension_max_force = _base_max_force[w] * m
	_apply_models()

# Swap the body shell + wheel meshes to this CarDef's models (assets/voxels). Wheel objs are
# authored axle-along-X, so the placeholder cylinder's corrective rotation must be cleared.
func _apply_models() -> void:
	if car.model != null:
		var body := get_node_or_null("Body") as MeshInstance3D
		if body != null:
			body.mesh = car.model
	if car.wheel_model != null:
		for w in _wheels:
			var mi := w.get_node_or_null("Mesh") as MeshInstance3D
			if mi != null:
				mi.mesh = car.wheel_model
				mi.transform = Transform3D.IDENTITY
				mi.set_surface_override_material(0, null)

func _bar(value: int, endpoints: Array) -> float:
	return lerpf(endpoints[0], endpoints[1], (clampi(value, 1, 10) - 1) / 9.0)

func _physics_process(delta: float) -> void:
	var throttle := Input.get_action_strength("accelerate")
	var reverse := Input.get_action_strength("brake_reverse")
	var steer_input := Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")

	# brake_reverse brakes while rolling forward, and reverses once nearly stopped.
	if reverse > 0.0 and get_forward_speed() > 1.0:
		engine_force = 0.0
		brake = max_brake * reverse
	else:
		# top-speed cap: force tapers to zero approaching max_speed (the last km/h are earned)
		var headroom := 1.0 - pow(clampf(absf(get_forward_speed()) / max_speed, 0.0, 1.0), 4.0)
		engine_force = max_engine_force * (throttle - reverse) * headroom
		brake = 0.0

	# Grip layer: front stays grippy, rear grips less (drift), and much less on handbrake.
	var handbraking := Input.is_action_pressed("handbrake")
	_update_taillights(brake > 0.0 or handbraking)
	_apply_grip(handbraking)
	# Anti-spin cap only while NOT braking: braking into a corner (esp. handbrake) is a
	# deliberate request to rotate — the clamp would fight the drift the player asked for.
	if not handbraking and brake == 0.0:
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
		# the car's grip stat scales the SURFACE grip — situational, never a replacement
		var g := _surface_grip(w) * grip_scale
		if w.use_as_steering:  # front — floor keeps it turnable on any surface (arcade cheat)
			var front := maxf(g, front_grip_floor * grip_scale)
			w.wheel_friction_slip = front * lerpf(1.0, front_high_speed_grip, t)
		else:  # rear — scales with the surface, so slippery surfaces drift
			var rear := g * (handbrake_rear_ratio if handbraking else rear_grip_ratio)
			w.wheel_friction_slip = maxf(rear * lerpf(1.0, rear_high_speed_grip, t), g * min_rear_grip_ratio)

## Grip of the surface a wheel is touching. Two tagging schemes on the contact body:
##   - meta "surface" (SurfaceType): a whole body IS one surface (a single-surface static body).
##   - meta "surface_map" (SurfaceMap): one body, many surfaces — sample by wheel position (baked
##     tracks, whose collision is a single HeightMapShape3D). Airborne / untagged -> base_grip.
func _surface_grip(w: VehicleWheel3D) -> float:
	if w.is_in_contact():
		var body := w.get_contact_body()
		if body != null:
			if body.has_meta("surface"):
				var s: SurfaceType = body.get_meta("surface")
				if s != null:
					return s.grip
			if body.has_meta("surface_map"):
				var m: SurfaceMap = body.get_meta("surface_map")
				if m != null:
					var pos := w.global_position
					return m.grip_at(pos.x, pos.z)
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

## Headlight beams (toggled by the LightingPreset in effect — on at night).
func set_headlights(on: bool) -> void:
	_headlights_on = on
	for h in _headlights:
		h.visible = on

# Taillights: bright on braking (any time of day), dim running glow at night, off otherwise.
func _update_taillights(braking: bool) -> void:
	var energy := 3.5 if braking else (1.3 if _headlights_on else 0.0)
	for t in _taillights:
		t.light_energy = energy
		t.visible = energy > 0.0

## Speed along the car's forward (+Z) axis in m/s. Negative when reversing.
func get_forward_speed() -> float:
	return linear_velocity.dot(global_transform.basis.z)

## Respawn at the car's starting transform with zero velocity.
func reset() -> void:
	respawn_at(_spawn_transform)

## Teleport with zeroed motion (checkpoint respawn, debug). _spawn_transform is untouched.
func respawn_at(t: Transform3D) -> void:
	global_transform = t
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
