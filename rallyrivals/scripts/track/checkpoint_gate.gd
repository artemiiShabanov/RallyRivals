class_name CheckpointGate
extends Area3D
## One anti-shortcut gate: an invisible box standing across the road. Pure indexed trigger — the
## order logic lives in the parent TrackCheckpoints, which connects to body_entered. Baked by
## TrackBaker from an authored dot pair in race.png; hand-tunable after bake (move/resize/
## duplicate in the editor — just keep `index` values unique and in lap order).

@export var index := 0   ## position in the lap sequence; 0 = the start/finish line

func _ready() -> void:
	# Trigger-only: collides with nothing, invisible to queries, sees only vehicles (layer 2).
	collision_layer = 0
	collision_mask = 2
	monitorable = false
