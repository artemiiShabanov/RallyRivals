class_name AmbientBed
extends Node
## The continuous ambience under a race: named layers that crossfade independently, so weather
## can change without touching the track's own bed. Two layers today —
##   "world"   track/venue bed (festival crowd, wind) — set by the race harness
##   "weather" precipitation bed (rain hiss, snow wind) — set by WeatherFX from the preset
## set_layer() fades the outgoing stream out while the incoming one fades in; a layer set to the
## stream it is already playing just retargets its level (no restart, no double-trigger).
## One per scene: find_or_create() locates it by group, matching the WeatherFX pattern.

const GROUP := "ambient_bed"
const SILENT_DB := -60.0
const SPAN_DB := 60.0     ## fade_time is measured across this range

var _layers := {}         # layer name -> Array of {player, target, fade}

static func find_or_create(tree: SceneTree) -> AmbientBed:
	if tree == null:
		return null
	var found := tree.get_first_node_in_group(GROUP) as AmbientBed
	if found != null:
		return found
	var bed := AmbientBed.new()
	bed.name = "AmbientBed"
	var host: Node = tree.current_scene if tree.current_scene != null else tree.root
	host.add_child(bed)
	return bed

func _ready() -> void:
	add_to_group(GROUP)
	# Ambience rides through pauses: the debug menu pauses the tree, and a bed that cuts out
	# every time it opens reads as a bug. A real pause menu should duck the bus instead.
	process_mode = Node.PROCESS_MODE_ALWAYS

## Set (or clear, with null) one layer. Safe to call every frame with the same def.
func set_layer(layer: String, def: AmbientDef) -> void:
	var entries: Array = _layers.get(layer, [])
	var stream: AudioStream = def.stream if def != null else null
	for e in entries:
		var p: AudioStreamPlayer = e["player"]
		if p.stream == stream and e["target"] > SILENT_DB:
			e["target"] = def.volume_db     # same bed, new level — don't restart it
			return
	for e in entries:
		e["target"] = SILENT_DB
		if def != null:
			e["fade"] = def.fade_time
	if stream != null:
		var p := AudioStreamPlayer.new()
		p.stream = stream
		p.bus = def.bus
		p.volume_db = SILENT_DB
		add_child(p)
		p.play()
		entries.append({"player": p, "target": def.volume_db, "fade": def.fade_time})
	_layers[layer] = entries

func stop_all(fade := 1.0) -> void:
	for layer in _layers:
		for e in (_layers[layer] as Array):
			e["target"] = SILENT_DB
			e["fade"] = fade

func _process(delta: float) -> void:
	for layer in _layers:
		var keep: Array = []
		for e in (_layers[layer] as Array):
			var p: AudioStreamPlayer = e["player"]
			var target: float = e["target"]
			p.volume_db = move_toward(p.volume_db, target, SPAN_DB / maxf(e["fade"], 0.05) * delta)
			if target <= SILENT_DB and p.volume_db <= SILENT_DB:
				p.queue_free()       # faded out for good — reclaim the player
			else:
				keep.append(e)
		_layers[layer] = keep
