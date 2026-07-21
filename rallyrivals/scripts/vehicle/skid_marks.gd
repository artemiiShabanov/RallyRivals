class_name SkidMarks
extends Node3D
## Tyre marks laid on the ground under the rear wheels. Two things blend into one ribbon:
##   - a faint rolling RUT on soft ground (gravel, dirt, sand, snow) — left just by driving, always
##   - the darker SKID mark when a wheel slides — black rubber on tarmac, a deeper groove elsewhere
## Opacity = surface.mark_baseline (rolling) scaled up to full by skid intensity. On tarmac the
## baseline is 0, so clean asphalt only marks when you actually slide.
##
## The skid component uses VehicleController.skid_intensity() — the SAME value the skid AUDIO reads
## — so a mark and its screech begin and end together.
##
## Each rear wheel raycasts straight down for the ground rather than trusting suspension contact:
## in a hard corner weight transfers off the inner wheel and its contact drops, which used to leave
## only the outer wheel marking. The ray still finds the ground just below, so both wheels mark.
##
## One world-space ImmediateMesh (top_level), a bounded ring per wheel — a long race can't grow it.

const MAX_QUADS := 320          # per wheel; ~0.12 m apart -> ~38 m of trail before it recycles
const SEG_DIST := 0.12          # m of travel between quads — framerate-independent density
const HALF_WIDTH := 0.16        # tyre is ~0.3 m wide
const LIFT := 0.04              # m above the ground hit, so it doesn't z-fight the terrain
const REACH := 0.45             # m below the wheel the ground ray looks (radius + lean slack)
const MIN_ALPHA := 0.02         # below this a quad is invisible — don't lay it (keeps tarmac clean)
const FADE_HEAD := 0.15         # oldest fraction of a ribbon that tapers out, so recycling doesn't pop

var _car: VehicleController
var _mesh: MeshInstance3D
var _im: ImmediateMesh
var _space: PhysicsDirectSpaceState3D
# One ribbon per wheel: a ring of quads {a, b, c, d, col} plus the last pen-down state.
var _ribbons: Array = []
var _dirty := false

func _ready() -> void:
	_car = get_parent() as VehicleController
	if _car == null:
		push_warning("SkidMarks expects a VehicleController parent")
		set_physics_process(false)
		return

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED   # flat translucent — don't write depth
	_im = ImmediateMesh.new()
	_mesh = MeshInstance3D.new()
	_mesh.name = "SkidRibbon"
	_mesh.mesh = _im
	_mesh.material_override = mat
	_mesh.top_level = true                                     # world space — marks don't follow the car
	_mesh.transform = Transform3D.IDENTITY
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)

func _physics_process(_dt: float) -> void:
	# The controller fills _wheels in ITS _ready, which runs after ours (children ready first), so
	# the ribbons can't be built until the first physics frame.
	if _ribbons.is_empty():
		for _w in _car.rear_wheels():
			_ribbons.append({"quads": [], "last": Vector3.ZERO, "down": false})
		if _ribbons.is_empty():
			return
	_space = get_world_3d().direct_space_state   # legal here: _physics_process IS the physics step

	var moving := _car.linear_velocity.length() > 1.0
	var skid := _car.skid_intensity()
	var wheels := _car.rear_wheels()

	for i in wheels.size():
		if i >= _ribbons.size():
			break
		_update_wheel(wheels[i], _ribbons[i], moving, skid)

	if _dirty:
		_rebuild()
		_dirty = false

func _update_wheel(wheel: VehicleWheel3D, rib: Dictionary, moving: bool, skid: float) -> void:
	if not moving:
		rib["down"] = false
		return
	# Look straight down for the ground, independent of suspension contact.
	var origin := wheel.global_position + Vector3.UP * 0.1
	var q := PhysicsRayQueryParameters3D.create(
		origin, origin - Vector3.UP * (wheel.wheel_radius + REACH), 1)   # mask 1 = world
	q.exclude = [_car.get_rid()]
	var hit := _space.intersect_ray(q)
	if hit.is_empty():
		rib["down"] = false                     # airborne — break the stroke so it doesn't smear
		return

	var point: Vector3 = hit["position"] + Vector3.UP * LIFT
	var surf := _car.surface_of(hit["collider"], point.x, point.z)
	if surf == null:
		rib["down"] = false
		return
	# baseline while rolling, rising to full alpha as the wheel slides.
	var frac: float = clampf(surf.mark_baseline + (1.0 - surf.mark_baseline) * skid, 0.0, 1.0)
	var alpha := surf.mark_color.a * frac
	if alpha < MIN_ALPHA:
		rib["down"] = false                     # nothing to draw here (clean tarmac) — pen up
		return

	if not rib["down"]:
		rib["last"] = point
		rib["down"] = true
		return
	if point.distance_to(rib["last"]) < SEG_DIST:
		return

	var col := surf.mark_color
	col.a = alpha
	_add_quad(rib, rib["last"], point, col)
	rib["last"] = point

# A quad from the previous ground point to the current one, width perpendicular to travel, flat.
func _add_quad(rib: Dictionary, from: Vector3, to: Vector3, col: Color) -> void:
	var dir := to - from
	dir.y = 0.0
	if dir.length() < 0.001:
		return
	var right := dir.normalized().cross(Vector3.UP).normalized() * HALF_WIDTH
	var quads: Array = rib["quads"]
	quads.append({"a": from - right, "b": from + right, "c": to + right, "d": to - right, "col": col})
	if quads.size() > MAX_QUADS:
		quads.pop_front()
	_dirty = true

func _rebuild() -> void:
	_im.clear_surfaces()
	var any := false
	for rib in _ribbons:
		if not (rib["quads"] as Array).is_empty():
			any = true
			break
	if not any:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mesh.material_override)
	for rib in _ribbons:
		var quads: Array = rib["quads"]
		var head := int(quads.size() * FADE_HEAD)
		for qi in quads.size():
			var qd: Dictionary = quads[qi]
			var c: Color = qd["col"]
			if qi < head:                 # taper the oldest so dropping them doesn't pop
				c.a *= float(qi + 1) / float(head + 1)
			_tri(qd["a"], qd["b"], qd["c"], c)
			_tri(qd["a"], qd["c"], qd["d"], c)
	_im.surface_end()

func _tri(p0: Vector3, p1: Vector3, p2: Vector3, c: Color) -> void:
	_im.surface_set_color(c); _im.surface_add_vertex(p0)
	_im.surface_set_color(c); _im.surface_add_vertex(p1)
	_im.surface_set_color(c); _im.surface_add_vertex(p2)

## Wipe every mark (respawn/reset), so a trail doesn't streak from the old spot to the new one.
func clear() -> void:
	for rib in _ribbons:
		(rib["quads"] as Array).clear()
		rib["down"] = false
	_im.clear_surfaces()
