class_name SkidMarks
extends Node3D
## Tyre marks laid on the ground where a rear wheel slides. The visual twin of the skid audio —
## driven from the same VehicleController.skid_amount() — so a mark and its screech arrive together.
##
## Add as a child of the car. Each rear wheel gets a ribbon: while the wheel slips, quads are laid
## from its last contact point to the current one, tinted by that surface's mark_color and faded by
## slip strength. The ribbon lives in WORLD space (its mesh is top_level), so marks stay on the
## ground as the car drives away. It's a bounded ring — past MAX_QUADS the oldest drop, so a long
## race can't grow the mesh without limit. Pure surface decal: no decals, no physics, one mesh.

const MAX_QUADS := 260          # per wheel; ~0.12 m apart -> ~30 m of trail before it recycles
const SEG_DIST := 0.12          # m of travel between quads — framerate-independent density
const HALF_WIDTH := 0.16        # tyre is ~0.3 m wide
const LIFT := 0.04              # m above the contact point, so it doesn't z-fight the terrain
const SLIP_MIN := 0.2           # below this the tyre is gripping — no mark
const HANDBRAKE_SLIP := 0.75    # handbrake always lays a bold mark, whatever the solver reports
const FADE_HEAD := 0.18         # oldest fraction of a ribbon that tapers out, so recycling doesn't pop

var _car: VehicleController
var _mesh: MeshInstance3D
var _im: ImmediateMesh
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
	var speed := _car.linear_velocity.length()
	var slip := _car.skid_amount()
	if _car.is_handbraking:
		slip = maxf(slip, HANDBRAKE_SLIP)
	var wheels := _car.rear_wheels()

	for i in wheels.size():
		if i >= _ribbons.size():
			break
		var wheel := wheels[i]
		var rib: Dictionary = _ribbons[i]
		var marking := speed > 2.0 and slip > SLIP_MIN and wheel.is_in_contact()
		if not marking:
			rib["down"] = false           # pen up: next mark starts a fresh, disconnected stroke
			continue

		var contact := wheel.global_position - Vector3.UP * wheel.wheel_radius + Vector3.UP * LIFT
		if not rib["down"]:
			rib["last"] = contact
			rib["down"] = true
			continue
		if contact.distance_to(rib["last"]) < SEG_DIST:
			continue

		_add_quad(rib, rib["last"], contact, slip, wheel)
		rib["last"] = contact

	if _dirty:
		_rebuild()
		_dirty = false

# A quad from the previous contact to the current one, width perpendicular to travel, laid flat.
func _add_quad(rib: Dictionary, from: Vector3, to: Vector3, slip: float, wheel: VehicleWheel3D) -> void:
	var dir := to - from
	dir.y = 0.0
	if dir.length() < 0.001:
		return
	var right := dir.normalized().cross(Vector3.UP).normalized() * HALF_WIDTH
	var surf := _car.surface_under(wheel)
	var base: Color = surf.mark_color if surf != null else Color(0.05, 0.05, 0.06, 0.55)
	var col := base
	col.a = base.a * clampf((slip - SLIP_MIN) / (1.0 - SLIP_MIN), 0.0, 1.0)

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
			var q: Dictionary = quads[qi]
			var c: Color = q["col"]
			if qi < head:                 # taper the oldest so dropping them doesn't pop
				c.a *= float(qi + 1) / float(head + 1)
			_tri(q["a"], q["b"], q["c"], c)
			_tri(q["a"], q["c"], q["d"], c)
	_im.surface_end()

func _tri(p0: Vector3, p1: Vector3, p2: Vector3, c: Color) -> void:
	_im.surface_set_color(c); _im.surface_add_vertex(p0)
	_im.surface_set_color(c); _im.surface_add_vertex(p1)
	_im.surface_set_color(c); _im.surface_add_vertex(p2)

## Wipe every mark (e.g. on respawn/reset).
func clear() -> void:
	for rib in _ribbons:
		(rib["quads"] as Array).clear()
		rib["down"] = false
	_im.clear_surfaces()
