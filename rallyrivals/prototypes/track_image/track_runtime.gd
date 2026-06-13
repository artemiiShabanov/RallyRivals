extends Node3D
## Runtime for a baked image-track: per-wheel surface grip by sampling surface.png at the
## car's position (the single-mesh ground has no per-body meta). THROWAWAY prototype.

@export var surface_image_path := "res://prototypes/track_image/surface.png"
@export var meters_per_pixel := 3.0
@export var image_size := 160
@export var off_road_grip := 5.0
@export var rear_grip_ratio := 0.7
@export var handbrake_rear_ratio := 0.2

const GRASS := Color(0.28, 0.40, 0.20)
const ASPHALT := Color(0.18, 0.18, 0.20)
const DIRT := Color(0.45, 0.30, 0.16)
const ICE := Color(0.82, 0.90, 0.96)

var _surf: Image
var _wheels: Array[VehicleWheel3D] = []

func _ready() -> void:
	process_physics_priority = 100
	_surf = Image.load_from_file(ProjectSettings.globalize_path(surface_image_path))
	var car := get_node_or_null("Car")
	if car:
		for c in car.get_children():
			if c is VehicleWheel3D:
				_wheels.append(c)

func _grip_at(wx: float, wz: float) -> float:
	if _surf == null:
		return off_road_grip
	var px := int(round(wx / meters_per_pixel + image_size * 0.5))
	var py := int(round(wz / meters_per_pixel + image_size * 0.5))
	if px < 0 or py < 0 or px >= image_size or py >= image_size:
		return off_road_grip
	var col := _surf.get_pixel(px, py)
	# Nearest palette entry wins.
	var best := INF
	var grip := off_road_grip
	for entry in [[GRASS, off_road_grip], [ASPHALT, 10.5], [DIRT, 6.0], [ICE, 3.0]]:
		var pc: Color = entry[0]
		var d := Vector3(col.r - pc.r, col.g - pc.g, col.b - pc.b).length()
		if d < best:
			best = d
			grip = entry[1]
	return grip

func _physics_process(_dt: float) -> void:
	if _wheels.is_empty():
		return
	var handbraking := Input.is_action_pressed("handbrake")
	for w in _wheels:
		var wp := w.global_position
		var base := _grip_at(wp.x, wp.z)
		var is_front: bool = w.use_as_steering
		var s := base if is_front else base * rear_grip_ratio
		if handbraking and not is_front:
			s = base * handbrake_rear_ratio
		w.wheel_friction_slip = s
