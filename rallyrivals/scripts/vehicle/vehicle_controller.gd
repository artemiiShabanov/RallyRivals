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
## Brake force applied while handbraking, as a fraction of max_brake. Deliberately not 1.0 — a
## fully locked car stops rotating, and the handbrake exists to start a drift, not to park.
@export var handbrake_brake_ratio := 0.5
@export var grip_falloff_start := 8.0    ## speed (m/s) where grip begins dropping
@export var grip_falloff_range := 12.0   ## m/s over which grip fades to the high-speed floor
@export var front_high_speed_grip := 0.8 ## front grip fraction at speed (stays grippy -> nose turns in)
@export var rear_high_speed_grip := 0.35 ## rear grip fraction at speed (lets go -> tail slides = oversteer)
@export var min_rear_grip_ratio := 0.3   ## rear floor as a FRACTION of the wheel's surface grip (relative, so it scales down on ice too)

@export_group("Anti-spin")
@export var max_yaw_rate := 1.3          ## rad/s — HARD cap on rotation speed; the car slides sideways instead of spinning to 180. Skipped while braking (deliberate rotation)

@export_group("Stability")
## Roll-righting assist (arcade anti-roll): a torque about the car's OWN forward axis that pulls its
## roll back to level — so it's much harder to tip in a turn, WITHOUT touching steering (yaw) or ramp
## pitch. Higher = harder to roll. This replaces a low centre-of-mass, which pushed the CoM below the
## suspension roll centre and made cars lean INTO turns and flip on slight steering.
@export var anti_roll := 22.0            ## roll-righting stiffness (0 = off)
@export var anti_roll_damp := 6.0        ## damping on roll velocity (settles the assist, no wobble)

@export_group("Damage")
## In-race damage (code-vehicle-damage, GDD §4). Any hard hit adds damage (impact impulse × the
## CarDef's damage_sensitivity); damage cuts top speed and bends the steering to one FIXED side (a bent
## chassis you learn to counter). There is NO repair — a fresh car each race starts pristine (damage
## defaults to 0), and reset_car does NOT clear it, so crashing can't be undone.
## SHOWN AS VFX, not as damaged sculpts (changed 2026-08-10). The old approach swapped the body to
## model_damaged_1/_2 at two thresholds, which needed two extra hand-made shells per car — 30 sculpts
## for a roster of 15, none of which existed. Smoke + judder costs nothing per car, applies to every
## car including any added later, and reads CONTINUOUSLY instead of popping at two thresholds.
@export var damage_per_ns := 0.000012    ## damage per N·s of impact (before damage_sensitivity) — tuned so it takes ~3 HARD hits to wreck, not one
@export var damage_speed_loss := 0.25    ## fraction of top speed lost at full damage
@export var damage_pull := 0.10          ## steering bias toward the bent side at full damage (of full lock)
@export var smoke_start := 0.30          ## damage below this: no smoke at all
@export var judder_start := 0.20         ## damage below this: the body sits perfectly still
@export var judder_max := 0.0125         ## peak body shake in metres at full damage (~0.4 of a voxel)

var damage := 0.0                        ## 0 pristine .. 1 wrecked — read by FX / gauges
var _pull_dir := 1.0                     ## which way the bent chassis pulls (fixed per car, set in _ready)
var _smoke: GPUParticles3D = null        ## built in code, NOT in car.tscn — see _setup_damage_fx
var _body_mi: MeshInstance3D = null      ## cached: _process runs per car per frame, every frame
var _body_rest := Transform3D.IDENTITY   ## the Body mesh's untouched transform, restored when undamaged
var _judder_t := 0.0

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

## Driver state, published for CarAudio (and any other observer). Set every physics frame.
var throttle_amount := 0.0
var is_braking := false
var is_handbraking := false

## Collision impulse in N·s, once per hit. CarAudio picks light vs heavy from the magnitude.
signal impacted(strength: float)
## Any contact with another car — all sides, a side rub counts too. Impulse in N·s. `rear` is true when
## the strongest car-contact landed on the BACK of this car (you got rear-ended), so the race rule can
## spare you the penalty for a hit that wasn't your doing. Officials races turn a non-rear contact into
## a flat time penalty (code-race-contact); Wilds ignore it. Walls/props fire `impacted`, never this.
signal rammed(impulse: float, rear: bool)
const IMPACT_MIN := 900.0                # below this it's a scrape, not a hit
const REAR_ZONE := 0.5                   # m behind the car's centre: a car-contact past this is "rear"
const IMPACT_COOLDOWN := 0.12            # s — one contact spans several physics frames
var _impact_cool := 0.0
var _touching := 0                       # bodies in contact right now (scrape source)

## Touchdown after every wheel left the ground. `strength` is 0..1, from how fast the car was
## FALLING — a long float onto a downslope should thump less than a short drop off a ledge.
## Consumed by ScreenJuice (camera dip) and SurfaceParticles (dust burst).
## This is only the air detection the landing FX need; the base controller's own jump handling
## (GDD §4) is considered sufficient, so there is no separate air-control task.
signal landed(strength: float)
const AIR_MIN := 0.18                    # s off the ground before a touchdown counts as a landing
const LANDING_FULL := 12.0               # m/s of descent that makes the hardest thump
var _air := 0.0                          # seconds with no wheel touching
var _fall := 0.0                         # fastest descent seen during this flight (negative)

var _spawn_transform: Transform3D
var _wheels: Array[VehicleWheel3D] = []
var _base_stiffness := {}                # wheel -> scene-authored suspension baseline (REF_MASS)
var _base_max_force := {}
var _headlights_on := false
var _headlights: Array[Node3D] = []
var _taillights: Array[OmniLight3D] = []

func _ready() -> void:
	add_to_group("vehicles")
	_pull_dir = 1.0 if randf() < 0.5 else -1.0   # this chassis bends one way; you learn to hold against it
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
	_apply_collision()
	_setup_damage_fx()

# Resize the body box to THIS car's shell. The shared 2x1x4 box predates the voxel cars and no longer
# fits any of them — the Crowbar is 1.21 m longer than it, so a quarter of that car (its boot) could not
# be hit at all, and the Mule's whole greenhouse sat above the box.
# ALWAYS build a NEW BoxShape3D: the one in car.tscn is a scene SubResource shared by every instance, so
# resizing it in place would give every car on the grid whichever size was applied last.
func _apply_collision() -> void:
	if car == null or car.collision_size == Vector3.ZERO:
		return                                      # no baked model yet -> keep the scene's box
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs == null:
		return
	var box := BoxShape3D.new()
	box.size = car.collision_size
	cs.shape = box
	cs.position = Vector3(0.0, car.collision_offset_y, 0.0)

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

## Driver input gate. The race director sets this false to park the car (brake held, no throttle or
## steer) at the grid, through the 3·2·1 countdown, and again at the finish.
var input_enabled := true

## Optional non-human driver (code-ai-rival). When set, the controller PULLS its controls from
## driver.poll(self, delta) each physics frame instead of the local Input actions — one seam so an AI
## rival drives this exact body and physics, no parallel sim. Pull (not push) so controls are always
## computed the same frame they're used, regardless of node order. Duck-typed: any object with
## `poll(car, delta) -> Dictionary { throttle, reverse, steer, handbrake }`. Gated by input_enabled
## exactly like the human, so the AI is parked at the grid / countdown / finish too. null = human.
var driver = null

func _physics_process(delta: float) -> void:
	var throttle := 0.0
	var reverse := 0.0
	var steer_input := 0.0
	var handbraking := false
	var want_reset := false
	if input_enabled:
		if driver != null:
			var c: Dictionary = driver.poll(self, delta)
			throttle = clampf(c.get("throttle", 0.0), 0.0, 1.0)
			reverse = clampf(c.get("reverse", 0.0), 0.0, 1.0)
			steer_input = clampf(c.get("steer", 0.0), -1.0, 1.0)
			handbraking = bool(c.get("handbrake", false))
		else:
			throttle = Input.get_action_strength("accelerate")
			reverse = Input.get_action_strength("brake_reverse")
			steer_input = Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")
			handbraking = Input.is_action_pressed("handbrake")
			want_reset = Input.is_action_just_pressed("reset_car")

	# brake_reverse brakes while rolling forward, and reverses once nearly stopped.
	if reverse > 0.0 and get_forward_speed() > 1.0:
		engine_force = 0.0
		brake = max_brake * reverse
	else:
		# top-speed cap: force tapers to zero approaching max_speed (the last km/h are earned). Damage
		# lowers that cap, so a wrecked car coasts down to a slower top end (GDD §4 "reduced speed").
		var cap := max_speed * (1.0 - damage_speed_loss * damage)
		var headroom := 1.0 - pow(clampf(absf(get_forward_speed()) / cap, 0.0, 1.0), 4.0)
		engine_force = max_engine_force * (throttle - reverse) * headroom
		brake = 0.0

	if not input_enabled:                # grid / countdown / finish — hold the car parked
		engine_force = 0.0
		brake = max_brake

	# Grip layer: front stays grippy, rear grips less (drift), and much less on handbrake.
	throttle_amount = throttle
	is_braking = brake > 0.0
	is_handbraking = handbraking
	# The handbrake cuts drive and drags. Without this it was only a grip modifier, so holding it
	# with the throttle down kept accelerating — you could handbrake and still pull away.
	if handbraking:
		engine_force = 0.0
		brake = maxf(brake, max_brake * handbrake_brake_ratio)
	_impact_cool = maxf(0.0, _impact_cool - delta)
	_track_landing(delta)
	_update_taillights(brake > 0.0 or handbraking)
	_apply_grip(handbraking)
	# Anti-spin cap only while NOT braking: braking into a corner (esp. handbrake) is a
	# deliberate request to rotate — the clamp would fight the drift the player asked for.
	if not handbraking and brake == 0.0:
		_clamp_yaw()
	_apply_anti_roll()

	# Ease steering toward the target so input isn't twitchy. Damage adds a constant pull to the bent
	# side (GDD §4) — you hold against it to drive straight.
	var steer_target := clampf(steer_input + _pull_dir * damage_pull * damage, -1.0, 1.0)
	steering = move_toward(steering, max_steer * steer_target, steer_speed * delta)

	if want_reset:
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
	# surface x car grip stat x weather (GDD 7: weather stacks on surface, instant, readable)
	var wgrip := grip_scale * WeatherFX.current_grip_multiplier
	for w in _wheels:
		var g := _surface_grip(w) * wgrip
		if w.use_as_steering:  # front — floor keeps it turnable on any surface (arcade cheat)
			var front := maxf(g, front_grip_floor * wgrip)
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

## The SurfaceType a wheel is touching (null when airborne or on untagged ground).
func _surface_at(w: VehicleWheel3D) -> SurfaceType:
	if w.is_in_contact():
		return surface_of(w.get_contact_body(), w.global_position.x, w.global_position.z)
	return null

## The SurfaceType a body carries at a world XZ. Two tagging schemes: meta "surface" (the whole
## body is one surface) or meta "surface_map" (a baked track's single collision, sampled by
## position). SkidMarks calls this with a raycast hit so each wheel gets its own surface.
func surface_of(body: Object, x: float, z: float) -> SurfaceType:
	if body == null:
		return null
	if body.has_meta("surface"):
		return body.get_meta("surface") as SurfaceType
	if body.has_meta("surface_map"):
		var m: SurfaceMap = body.get_meta("surface_map")
		if m != null:
			return m.surface_at(x, z)
	return null

## Canonical skid intensity (0 gripping, 1 fully sliding), the ONE source both the skid audio and
## the skid marks read so they can never drift out of sync. Handbrake forces a floor — pulling it
## is a deliberate slide even if the solver hasn't caught up.
const HANDBRAKE_SKID := 0.6
func skid_intensity() -> float:
	var s := skid_amount()
	if is_handbraking:
		s = maxf(s, HANDBRAKE_SKID)
	return s

## The rear wheels, in scene order — SkidMarks lays a ribbon under each.
func rear_wheels() -> Array[VehicleWheel3D]:
	var out: Array[VehicleWheel3D] = []
	for w in _wheels:
		if not w.use_as_steering:
			out.append(w)
	return out

## The surface a specific wheel is touching (public wrapper for _surface_at).
func surface_under(w: VehicleWheel3D) -> SurfaceType:
	return _surface_at(w)

## What the car is driving on: the surface under the first rear wheel in contact (the rears carry
## the weight and do the sliding, so they define the sound).
func current_surface() -> SurfaceType:
	for w in _wheels:
		if not w.use_as_steering:
			var s := _surface_at(w)
			if s != null:
				return s
	return null

## 0 = full grip, 1 = fully sliding. VehicleWheel3D reports skidinfo per wheel (1 = no slip).
func skid_amount() -> float:
	var worst := 1.0
	for w in _wheels:
		if w.is_in_contact():
			worst = minf(worst, w.get_skidinfo())
	return 1.0 - worst

## Airborne -> touchdown. Strength comes from peak descent speed rather than air time, so a gentle
## crest that lifts the wheels for a moment doesn't thump like a real drop.
func _track_landing(delta: float) -> void:
	if wheels_on_ground() == 0:
		_air += delta
		_fall = minf(_fall, linear_velocity.y)
		return
	if _air > AIR_MIN:
		landed.emit(clampf(absf(_fall) / LANDING_FULL, 0.0, 1.0))
	_air = 0.0
	_fall = 0.0

func wheels_on_ground() -> int:
	var n := 0
	for w in _wheels:
		if w.is_in_contact():
			n += 1
	return n

func is_scraping() -> bool:
	return _touching > 0

## Collision impulses come from the solver, so this is the only place they exist. A single knock
## spans several physics frames, hence the cooldown — without it one hit fires a burst of sounds.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_touching = state.get_contact_count()
	if _impact_cool > 0.0:
		return
	var strongest := 0.0
	var car_hit := false
	var car_impulse := 0.0            # strongest CAR contact, to classify which side got hit
	var car_local := Vector3.ZERO     # its contact point in this car's local frame
	for i in state.get_contact_count():
		var imp := state.get_contact_impulse(i).length()
		strongest = maxf(strongest, imp)
		if state.get_contact_collider_object(i) is VehicleController:
			car_hit = true          # contact with another car, any side
			if imp >= car_impulse:  # track the hardest car-contact for the front/rear test
				car_impulse = imp
				car_local = global_transform.affine_inverse() * state.get_contact_local_position(i)
	if strongest >= IMPACT_MIN:
		_impact_cool = IMPACT_COOLDOWN
		impacted.emit(strongest)
		if car_hit:
			# Local +Z is forward, so a contact well behind the centre is a rear-end (not your fault).
			rammed.emit(strongest, car_local.z < -REAR_ZONE)
		# Any hard hit (wall, prop or car) damages the car, scaled by impulse × the car's sensitivity.
		# Accumulate the float here (safe in the physics callback); the mesh swap happens in _process.
		var sens: float = car.damage_sensitivity if car != null else 1.0
		damage = clampf(damage + strongest * damage_per_ns * sens, 0.0, 1.0)

## Build the damage smoke emitter. Deliberately created in CODE rather than added to car.tscn: the rig
## scene is shared by every car and hand-maintained, so anything the controller can build itself should
## not become a node someone has to keep in sync. Called from apply_car_def, after the collision box is
## known — the box is the only per-car measurement available at runtime, so it is what places the
## emitter over the bonnet (nose is +z; the bake puts model z=0 at positive rig z).
func _setup_damage_fx() -> void:
	_body_mi = get_node_or_null("Body") as MeshInstance3D
	if _body_mi != null:
		_body_rest = _body_mi.transform
	if _smoke != null:
		_place_smoke()
		return
	var p := GPUParticles3D.new()
	p.name = "DamageSmoke"
	p.emitting = false
	p.amount = 24
	p.lifetime = 1.3
	p.local_coords = false                        # smoke is LEFT BEHIND, not dragged along with the car
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 26.0
	mat.initial_velocity_min = 0.4
	mat.initial_velocity_max = 1.2
	mat.gravity = Vector3(0.0, 0.5, 0.0)          # positive: smoke rises rather than falls
	# Born over a small volume, not a point — a point source reads as a jet, not a leak.
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.12
	# Each puff spawns at a random roll and keeps turning, so no two are the same and the billboards
	# never line up into a visible grid.
	mat.angle_min = -180.0
	mat.angle_max = 180.0
	mat.angular_velocity_min = -35.0
	mat.angular_velocity_max = 35.0
	mat.scale_min = 0.5
	mat.scale_max = 0.8
	mat.scale_curve = _ramp_curve()               # puffs EXPAND as they cool and drift
	mat.color_ramp = _smoke_gradient()            # dark at the leak -> pale and gone
	mat.turbulence_enabled = true                 # breaks the plume up so it is not a clean cone
	mat.turbulence_noise_strength = 0.22
	mat.turbulence_noise_scale = 1.6
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.62, 0.62)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# BILLBOARD_PARTICLES, not BILLBOARD_ENABLED: the particle variant honours per-particle rotation
	# and scale. Plain billboarding would ignore the spin set above and every puff would sit square-on.
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true          # so color_ramp actually tints the puff
	sm.albedo_texture = _puff_texture()
	quad.material = sm
	p.draw_pass_1 = quad
	add_child(p)
	_smoke = p
	_place_smoke()

## A quad with flat alpha IS a visible square — that is the whole reason the first pass looked blocky.
## This gives each puff a soft radial falloff with a WOBBLY edge (two low-frequency angular terms), so
## it reads as a torn ball of smoke rather than a disc or a box. Built once and shared by every car:
## a 64x64 image per vehicle per race would be pure waste.
static var _puff_tex: ImageTexture = null
static func _puff_texture() -> ImageTexture:
	if _puff_tex != null:
		return _puff_tex
	const N := 64
	var img := Image.create(N, N, false, Image.FORMAT_RGBAF)
	for y in N:
		for x in N:
			var dx := (float(x) + 0.5) / N * 2.0 - 1.0
			var dy := (float(y) + 0.5) / N * 2.0 - 1.0
			var r := sqrt(dx * dx + dy * dy)
			var ang := atan2(dy, dx)
			var wob := 1.0 + 0.17 * sin(ang * 3.0 + 1.1) + 0.11 * sin(ang * 5.0 + 2.7)
			var a := clampf(1.0 - r / maxf(0.94 * wob, 0.01), 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)               # smoothstep: no hard rim
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_puff_tex = ImageTexture.create_from_image(img)
	return _puff_tex

## Dark and fairly opaque where it leaves the bonnet, pale and gone by the end of its life.
static var _smoke_grad: GradientTexture1D = null
static func _smoke_gradient() -> GradientTexture1D:
	if _smoke_grad != null:
		return _smoke_grad
	var g := Gradient.new()
	g.set_offset(0, 0.0); g.set_color(0, Color(0.17, 0.17, 0.19, 0.62))
	g.add_point(0.35, Color(0.30, 0.30, 0.32, 0.42))
	g.add_point(1.0, Color(0.55, 0.55, 0.58, 0.0))
	var t := GradientTexture1D.new()
	t.gradient = g
	_smoke_grad = t
	return _smoke_grad

## Puffs start small and expand — smoke cools and spreads, and a constant-size particle reads as a
## sprite being carried along rather than as gas.
static var _scale_curve: CurveTexture = null
static func _ramp_curve() -> CurveTexture:
	if _scale_curve != null:
		return _scale_curve
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.45))
	c.add_point(Vector2(0.45, 1.0))
	c.add_point(Vector2(1.0, 1.7))
	var t := CurveTexture.new()
	t.curve = c
	_scale_curve = t
	return _scale_curve

func _place_smoke() -> void:
	if _smoke == null:
		return
	var top := 0.45
	var fwd := 1.2
	if car != null and car.collision_size != Vector3.ZERO:
		top = car.collision_offset_y + car.collision_size.y * 0.5
		fwd = car.collision_size.z * 0.28          # over the bonnet, not the windscreen
	_smoke.position = Vector3(0.0, top - 0.08, fwd)

## Damage READ, per frame. Two channels, both continuous in `damage` so there is no threshold pop:
##  · SMOKE from the bonnet. amount_ratio scales emission WITHOUT restarting the system — restarting
##    would fire a fresh full puff every frame.
##  · JUDDER: the body shivers in place. Two sines at unrelated frequencies so it never settles into a
##    visible loop, on a squared ramp so it is a shiver at half damage and a shake at full. VISUAL ONLY
##    — it moves the Body MeshInstance3D, never the VehicleBody3D, so physics and the collision shape
##    are untouched and a damaged car still drives exactly as its stats say.
func _process(delta: float) -> void:
	if _smoke != null:
		var want := damage > smoke_start
		if _smoke.emitting != want:
			_smoke.emitting = want
		if want:
			_smoke.amount_ratio = clampf((damage - smoke_start) / maxf(1.0 - smoke_start, 0.001), 0.15, 1.0)
	if _body_mi == null:
		return
	var ramp := clampf((damage - judder_start) / maxf(1.0 - judder_start, 0.001), 0.0, 1.0)
	if ramp <= 0.0:
		if _body_mi.transform != _body_rest:
			_body_mi.transform = _body_rest  # snap back to rest rather than leaving it parked off-centre
		return
	_judder_t += delta
	var amp := judder_max * ramp * ramp
	var t := _body_rest
	t.origin += Vector3(sin(_judder_t * 47.0) * amp, sin(_judder_t * 61.0 + 1.7) * amp, 0.0)
	t.basis = t.basis.rotated(Vector3.FORWARD, sin(_judder_t * 53.0) * amp * 0.5)
	_body_mi.transform = t

## Roll-righting assist: a torque about the car's OWN forward axis that pulls its roll back to level.
## Only the roll axis, so steering (yaw) and ramp pitch are left alone — that's how cars stay hard to
## flip in turns without feeling glued. `lean` is the sideways tilt of the up-vector; the damping term
## opposes roll velocity so it settles instead of wobbling. Mass-scaled to be consistent across cars.
func _apply_anti_roll() -> void:
	if anti_roll <= 0.0:
		return
	var fwd := global_transform.basis.z
	var lean := global_transform.basis.y.cross(Vector3.UP).dot(fwd)
	var roll_rate := angular_velocity.dot(fwd)
	apply_torque(fwd * (lean * anti_roll - roll_rate * anti_roll_damp) * mass)

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
	var marks := get_node_or_null("SkidMarks") as SkidMarks
	if marks != null:
		marks.clear()   # don't leave a trail streaking from the old spot to the new one
	var dust := get_node_or_null("SurfaceParticles") as SurfaceParticles
	if dust != null:
		dust.clear()
