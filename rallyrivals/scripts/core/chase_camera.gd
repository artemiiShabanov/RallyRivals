class_name ChaseCamera
extends Camera3D
## Smooth chase camera (promoted from the physics spike). Eases toward a point behind+above the
## target and looks at it — not rigidly parented, so spins don't whip the view.
##
## Free-look: mouse motion or the right stick (look_* actions) orbits the camera around the car
## (yaw all the way round, pitch clamped); after return_delay with no look input the view eases
## back behind the car. The car keeps driving normally while looking around.
##
## Convention: the car drives toward LOCAL +Z (vehicle_controller.gd), so "behind" is -Z.

@export var target_path: NodePath
@export var distance := 7.0
@export var height := 3.0
@export var look_height := 1.0
@export var follow_speed := 5.0

@export_group("Juice")
## Speed tremor band (art-vfx-juice). Below `rumble_from` the view is dead still.
@export var rumble_from := 22.0          ## m/s where the speed tremor starts
@export var rumble_full := 55.0          ## m/s where it reaches full amplitude

@export_group("Free look")
@export var mouse_sensitivity := 0.004   ## rad per mouse pixel
@export var stick_look_speed := 2.5      ## rad/s at full stick deflection
@export var return_delay := 0.8          ## s of no look input before the view eases back
@export var return_speed := 4.0          ## how fast the view eases back behind the car

var _target: Node3D
var _car: VehicleController   # the target when it's a car — the source of juice events
var _yaw := 0.0          # look-around offsets around the car (0 = straight behind)
var _pitch := 0.0
var _idle := 0.0         # seconds since the last look input
# The un-shaken camera position. Shake is added on top when writing global_position, never folded
# back in — otherwise each frame's smoothing would chase the previous frame's shake and the whole
# rig would wander.
var _base := Vector3.ZERO
var _has_base := false

func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	ScreenJuice.reset()          # a hit must never ring on from the previous scene
	_car = _target as VehicleController
	if _car != null:
		_car.impacted.connect(ScreenJuice.impact)
		_car.landed.connect(ScreenJuice.landing)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# screen_relative = raw pixels; .relative is scaled by the canvas_items stretch transform,
		# which would tie sensitivity to window size.
		_yaw = wrapf(_yaw - event.screen_relative.x * mouse_sensitivity, -PI, PI)
		_pitch = clampf(_pitch - event.screen_relative.y * mouse_sensitivity, -1.2, 1.2)
		_idle = 0.0

func _physics_process(delta: float) -> void:
	if _target == null:
		return
	# Right stick look; mouse arrives via _unhandled_input.
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick.length() > 0.05:
		_yaw = wrapf(_yaw - stick.x * stick_look_speed * delta, -PI, PI)
		_pitch = clampf(_pitch - stick.y * stick_look_speed * delta, -1.2, 1.2)
		_idle = 0.0
	else:
		_idle += delta
		if _idle > return_delay:
			var rw := 1.0 - exp(-return_speed * delta)
			_yaw = lerp_angle(_yaw, 0.0, rw)
			_pitch = lerpf(_pitch, 0.0, rw)

	var t := _target.global_transform
	# Horizontal behind-direction (flattened so slopes don't tilt the orbit), rotated by yaw.
	var fwd := t.basis.z; fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var behind := (-fwd).rotated(Vector3.UP, _yaw)
	# Pitch swings the camera on a constant-radius arc; base elevation comes from distance/height.
	var pitch := clampf(atan2(height, distance) + _pitch, -0.15, 1.35)
	var radius := Vector2(distance, height).length()
	var desired := t.origin + (behind * cos(pitch) + Vector3.UP * sin(pitch)) * radius
	var weight := 1.0 - exp(-follow_speed * delta)  # frame-rate-independent smoothing
	if not _has_base:
		_base = desired            # first frame: snap, don't ease in from the origin
		_has_base = true
	_base = _base.lerp(desired, weight)
	global_position = _base
	look_at(t.origin + Vector3.UP * look_height, Vector3.UP)

	# --- juice, applied AFTER look_at (which would otherwise cancel any offset) ---
	var speed := _car.linear_velocity.length() if _car != null else 0.0
	ScreenJuice.set_rumble(clampf((speed - rumble_from) / maxf(1.0, rumble_full - rumble_from), 0.0, 1.0))
	ScreenJuice.advance(delta)
	var jo := ScreenJuice.offset()
	if jo != Vector3.ZERO:
		global_position = _base + global_transform.basis * jo   # offset in VIEW space
	var jr := ScreenJuice.roll()
	if jr != 0.0:
		rotate_object_local(Vector3.FORWARD, jr)
