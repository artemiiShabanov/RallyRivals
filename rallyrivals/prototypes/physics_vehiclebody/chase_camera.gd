extends Camera3D
## Minimal smooth chase camera for the physics spike (throwaway).
## Eases toward a point behind+above the target and looks at it — not rigidly parented,
## so spins don't whip the view. Real camera work happens in M1.

@export var target_path: NodePath
@export var distance := 7.0
@export var height := 3.0
@export var look_height := 1.0
@export var follow_speed := 5.0

var _target: Node3D

func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D

func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var t := _target.global_transform
	# This VehicleBody3D drives toward +Z, so behind the car is -Z.
	var desired := t.origin - t.basis.z * distance + Vector3.UP * height
	var weight := 1.0 - exp(-follow_speed * delta)  # frame-rate-independent smoothing
	global_position = global_position.lerp(desired, weight)
	look_at(t.origin + Vector3.UP * look_height, Vector3.UP)
