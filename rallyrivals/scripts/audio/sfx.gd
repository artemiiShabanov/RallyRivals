extends Node
## SFX playback service (autoloaded as "Sfx"). One-shots: play(def) for flat cues (UI, global),
## play_at(def, pos) for world-positioned cues — players are pooled and recycled (idle first,
## grow to cap, then steal round-robin) so callers never manage nodes. attach_loop() parents a
## looping 3D player to an emitter (engine/tire loops) and returns it for pitch/volume driving.
## Buses (default_bus_layout.tres): Master > Music / SFX / UI; set_bus_volume() is the settings
## hook (linear 0..1, mutes near zero). Sounds are SfxDef resources under assets/audio/sfx/.

const POOL_2D := 6
const POOL_3D := 12
const Pool = preload("res://scripts/core/pool.gd")   # generic node pool (code-core-pooling), by path

# Players are pooled by the shared Pool: reuse an idle (not-`playing`) one, grow to cap, then steal
# round-robin. A busy-predicate pool needs no release — a finished one-shot recycles itself.
var _pool_2d
var _pool_3d

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # UI cues must play while the game is paused
	_pool_2d = Pool.new(func() -> Node: return AudioStreamPlayer.new(), self, POOL_2D,
		func(p: Node) -> bool: return (p as AudioStreamPlayer).playing)
	_pool_3d = Pool.new(func() -> Node: return AudioStreamPlayer3D.new(), self, POOL_3D,
		func(p: Node) -> bool: return (p as AudioStreamPlayer3D).playing)

func play(def: SfxDef) -> void:
	if def == null or def.streams.is_empty():
		return
	var p := _acquire_2d()
	_configure(p, def)
	p.play()

func play_at(def: SfxDef, pos: Vector3) -> void:
	if def == null or def.streams.is_empty():
		return
	var p := _acquire_3d()
	_configure(p, def)
	p.max_distance = def.max_distance
	p.global_position = pos
	p.play()

## For continuous sources (engine, tires): the stream itself must loop (wav import loop mode).
func attach_loop(parent: Node3D, stream: AudioStream, bus := "SFX") -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = bus
	parent.add_child(p)
	return p

func set_bus_volume(bus_name: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear < 0.001)

func get_bus_volume(bus_name: String) -> float:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0 or AudioServer.is_bus_mute(i):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(i))

func _acquire_2d() -> AudioStreamPlayer:
	return _pool_2d.acquire() as AudioStreamPlayer

func _acquire_3d() -> AudioStreamPlayer3D:
	return _pool_3d.acquire() as AudioStreamPlayer3D

func _configure(p, def: SfxDef) -> void:
	p.stream = def.streams.pick_random()
	p.bus = def.bus
	p.volume_db = def.volume_db
	p.pitch_scale = randf_range(def.pitch_min, def.pitch_max)
