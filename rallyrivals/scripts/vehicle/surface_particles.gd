class_name SurfaceParticles
extends Node3D
## Cube kick-up under the rear wheels (ADR-003: every particle is a cube). Same model as the skid
## marks and the same shared VehicleController.skid_intensity(), so dust, mark and screech all
## swell together: faint while rolling on loose ground, bursting on a slide. Each surface throws its
## own thing — gravel chunks, dirt billows, sand a fine kick, snow a soft float, tarmac/ice nothing.
## A wet surface (the rr_wetness weather global) adds a spray rooster-tail on top of the dry effect.
##
## Per rear wheel: one ground emitter (reconfigured when the surface under it changes) and one wet
## emitter, both parked at that wheel's own contact point — spray throws off the tyres, not from
## under the car's belly. All follow the car; particles live in world space (local_coords off), so
## each puff stays put and the car trails settling dust. GPU-side, so it's cheap.

const REACH := 0.45             # m below the wheel the ground ray looks
const LIFT := 0.06              # spawn just above the ground
const FULL_SPEED := 14.0        # m/s where kick-up reaches full density
const MIN_INTENSITY := 0.02
const THROW_ANGLE := 45.0       # deg above horizontal the cone is aimed — a backward rooster tail

var _car: VehicleController
var _space: PhysicsDirectSpaceState3D
var _ground: Array[GPUParticles3D] = []
var _ground_surface: Array[String] = []
var _wet: Array[GPUParticles3D] = []
var _burst := 0.0                # seconds of forced full kick-up left after a landing

func _ready() -> void:
	_car = get_parent() as VehicleController
	if _car == null:
		push_warning("SurfaceParticles expects a VehicleController parent")
		set_physics_process(false)
		return
	_car.landed.connect(_on_landed)

## A touchdown throws up a puff whatever the speed (art-vfx-juice) — the existing emitters already
## carry the right colour and cube size for the surface landed on, so this just forces them to full
## for a moment instead of adding a second set of particles.
func _on_landed(strength: float) -> void:
	_burst = maxf(_burst, 0.10 + 0.16 * clampf(strength, 0.0, 1.0))

func _make_emitter() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.local_coords = false          # emitted cubes stay in the world as the car drives on
	p.top_level = true              # position it in world coords directly
	p.emitting = false
	p.amount = 64
	p.explosiveness = 0.0
	# CRITICAL with local_coords off: the emitter moves with the car but the cubes stay behind in
	# world space. The default culling box is centred on the (moving) node, so trailing cubes fall
	# outside it and get culled — invisible. A generous fixed AABB keeps the whole trail on screen.
	p.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	add_child(p)
	return p

func _physics_process(dt: float) -> void:
	_burst = maxf(0.0, _burst - dt)
	# Rear wheels aren't known until the controller's _ready (runs after ours), so build lazily.
	if _ground.is_empty():
		for _w in _car.rear_wheels():
			_ground.append(_make_emitter())
			_ground_surface.append("")
			var we := _make_emitter()     # this wheel's own spray
			we.process_material = _wet_material()
			we.draw_pass_1 = _cube(0.045)
			we.amount = 90
			_wet.append(we)
		if _ground.is_empty():
			return
	_space = get_world_3d().direct_space_state

	var speed := _car.linear_velocity.length()
	var speed_f := clampf((speed - 1.0) / FULL_SPEED, 0.0, 1.0)
	var skid := _car.skid_intensity()
	var wheels := _car.rear_wheels()
	var wet_i := WeatherFX.current_wetness * speed_f
	# Cone aimed opposite the car's motion, THROW_ANGLE above horizontal — the cubes fly out behind
	# the wheels. Emitters keep an identity basis (only their position is moved), so this world
	# vector goes straight into ParticleProcessMaterial.direction.
	var _throw := _throw_dir()

	for i in wheels.size():
		if i >= _ground.size():
			break
		var hit := _ground_hit(wheels[i])
		var e := _ground[i]
		var we := _wet[i]
		if hit.is_empty():
			e.emitting = false
			we.emitting = false
			continue
		var point: Vector3 = hit["point"]

		# Wet rooster-tail off THIS wheel. Independent of the dry effect — wet tarmac throws
		# spray even though it has no dust — so it's handled before the dust_amount bail-out.
		if wet_i > MIN_INTENSITY:
			we.global_position = point + Vector3.UP * LIFT
			we.amount_ratio = clampf(wet_i, 0.0, 1.0)
			we.emitting = true
			(we.process_material as ParticleProcessMaterial).direction = _throw
		else:
			we.emitting = false

		var surf: SurfaceType = hit["surface"]
		if surf == null or surf.dust_amount <= 0:
			e.emitting = false
			continue
		if surf.id != _ground_surface[i]:
			_configure_ground(e, surf)
			_ground_surface[i] = surf.id
		var frac: float = clampf(surf.dust_baseline + (1.0 - surf.dust_baseline) * skid, 0.0, 1.0)
		var intensity := frac * speed_f
		if _burst > 0.0:
			intensity = maxf(intensity, 0.9)   # a landing puffs even from a standstill
		e.global_position = point + Vector3.UP * LIFT
		e.amount_ratio = clampf(intensity, 0.0, 1.0)
		e.emitting = intensity > MIN_INTENSITY
		var pm := e.process_material as ParticleProcessMaterial
		if pm != null:
			pm.direction = _throw

## Unit vector opposite the car's motion, tilted THROW_ANGLE above horizontal. Falls back to the
## car's backward axis when nearly stopped (velocity too small to give a heading).
func _throw_dir() -> Vector3:
	var v := _car.linear_velocity
	v.y = 0.0
	var back: Vector3 = (-v).normalized() if v.length() > 0.5 else -_car.global_transform.basis.z
	back.y = 0.0
	if back.length() < 0.01:
		back = Vector3.BACK
	back = back.normalized()
	var a := deg_to_rad(THROW_ANGLE)
	return (back * cos(a) + Vector3.UP * sin(a)).normalized()

func _ground_hit(wheel: VehicleWheel3D) -> Dictionary:
	var origin := wheel.global_position + Vector3.UP * 0.1
	var q := PhysicsRayQueryParameters3D.create(
		origin, origin - Vector3.UP * (wheel.wheel_radius + REACH), 1)
	q.exclude = [_car.get_rid()]
	var hit := _space.intersect_ray(q)
	if hit.is_empty():
		return {}
	return {"point": hit["position"], "surface": _car.surface_of(hit["collider"], hit["position"].x, hit["position"].z)}

func _configure_ground(e: GPUParticles3D, s: SurfaceType) -> void:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.12
	m.direction = Vector3.UP
	m.spread = s.dust_spread
	m.initial_velocity_min = s.dust_rise * 0.55
	m.initial_velocity_max = s.dust_rise
	m.gravity = Vector3(0.0, s.dust_gravity, 0.0)
	m.scale_min = 0.6
	m.scale_max = 1.3
	# Billowing surfaces swell as they drift (sand). Note the curve runs 1/growth -> 1 over the
	# FINAL size, rather than 1 -> growth over the spawn size: both give the same result, but this
	# way every curve value stays <= 1, so it cannot be clipped by the texture the curve bakes into.
	# Particles still start at exactly dust_size; only their growth changes.
	if s.dust_growth > 1.001:
		m.scale_min *= s.dust_growth
		m.scale_max *= s.dust_growth
		var g := Curve.new()
		g.add_point(Vector2(0.0, 1.0 / s.dust_growth))
		g.add_point(Vector2(1.0, 1.0))
		var gt := CurveTexture.new()
		gt.curve = g
		m.scale_curve = gt
	m.color = s.dust_color
	m.color_ramp = _fade_ramp()     # alpha to 0 over life, so cubes dissolve rather than blink out
	e.process_material = m
	e.draw_pass_1 = _cube(s.dust_size)
	e.lifetime = s.dust_lifetime
	e.amount = s.dust_amount

func _wet_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.14
	m.direction = Vector3.UP
	m.spread = 34.0
	m.initial_velocity_min = 1.4
	m.initial_velocity_max = 2.6
	m.gravity = Vector3(0.0, -3.5, 0.0)   # spray arcs and falls
	m.scale_min = 0.5
	m.scale_max = 1.1
	m.color = Color(0.72, 0.80, 0.90, 0.5)
	m.color_ramp = _fade_ramp()
	return m

func _fade_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

func _cube(edge: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(edge, edge, edge)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true   # particle colour drives albedo
	b.material = mat
	return b

## Stop everything (respawn/reset) so a cloud doesn't hang where the car used to be.
## restart() clears the live cubes but re-arms emission, so emitting must be cleared AFTER it.
func clear() -> void:
	for e in _ground:
		e.restart()
		e.emitting = false
	for w in _wet:
		w.restart()
		w.emitting = false
