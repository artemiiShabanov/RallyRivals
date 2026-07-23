class_name CarView
extends SubViewportContainer
## 3D car preview (code-ui-car-view): a slow turntable of a CarDef's meshes (body + wheels) for the
## shop / garage / pre-race. Renders in its own transparent SubViewport world (so the blue OSD shows
## behind) with a key light + ambient; the menu's VHS filter sits over the whole thing. set_car()
## rebuilds the model — mesh assignment mirrors VehicleController._apply_models (wheel objs are
## axle-along-X, placed at the car's wheel offsets, no corrective rotation).

const WHEELS := [
	Vector3(-0.85, -0.5, 1.4), Vector3(0.85, -0.5, 1.4),
	Vector3(-0.85, -0.5, -1.4), Vector3(0.85, -0.5, -1.4),
]
const SPIN := 0.5   # rad/s

var _car: CarDef
var _turntable: Node3D
var _body: MeshInstance3D
var _wheels: Array[MeshInstance3D] = []

func _init() -> void:
	# stretch OFF: the container takes the SubViewport's size (fixed). With stretch on, a
	# SubViewport defaults to 512x512 and drives the container's minimum size — it balloons.
	stretch = false
	custom_minimum_size = Vector2(380, 260)
	size_flags_horizontal = SIZE_SHRINK_CENTER
	size_flags_vertical = SIZE_SHRINK_CENTER

func _ready() -> void:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(custom_minimum_size)   # render 1:1 at the size the caller asked for
	add_child(vp)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.78, 0.9)
	e.ambient_light_energy = 0.65
	env.environment = e
	vp.add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, -34, 0)
	key.light_energy = 1.4
	vp.add_child(key)

	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(2.9, 1.7, 3.8), Vector3(0.0, -0.15, 0.1), Vector3.UP)
	cam.fov = 42.0
	cam.current = true

	_turntable = Node3D.new()
	vp.add_child(_turntable)
	_body = MeshInstance3D.new()
	_turntable.add_child(_body)
	for pos in WHEELS:
		var w := MeshInstance3D.new()
		w.position = pos
		_turntable.add_child(w)
		_wheels.append(w)

	_refresh()   # apply any car set before _ready

func _process(delta: float) -> void:
	if _turntable != null:
		_turntable.rotate_y(SPIN * delta)

func set_car(def: CarDef) -> void:
	_car = def
	_refresh()

func _refresh() -> void:
	if _body == null:      # not built yet — _ready will call this again
		return
	_body.mesh = _car.model if _car != null else null
	for w in _wheels:
		w.mesh = _car.wheel_model if _car != null else null
