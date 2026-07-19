class_name CarAudio
extends Node3D
## Everything a car sounds like, driven from VehicleController state. Add it as a child of the
## car; it finds the controller on its parent.
##
## Four layers, each a looping AudioStreamPlayer3D parented here so they follow the car:
##   engine   3 RPM bands, pitched within their band and equal-power crossfaded (see EngineDef)
##   roll     the tyre loop for whatever surface is under the rear wheels, crossfaded on change
##   skid     faded in by wheel slip; picks the tarmac squeal or the loose-surface slide
##   scrape   faded in while the body is dragging along something
## plus one-shots: engine start/off, and impacts scaled by collision impulse.
##
## Levels live in EngineDef and the exports below, never in the files — see docs/AUDIO.md §1.

const ROLL_DIR := "res://assets/audio/loops/"
const FADE_DB := 60.0            ## dB span a crossfade travels; with fade_time gives the rate
const SILENT_DB := -60.0

@export var engine: EngineDef
@export var roll_volume_db := -6.0
@export var roll_full_speed := 22.0    ## m/s where roll reaches full level
@export var roll_pitch_range := 0.35   ## pitch added from standstill to full speed
@export var skid_volume_db := -8.0
@export var scrape_volume_db := -10.0
@export var fade_time := 0.15          ## s for a layer to fade in/out
@export var surface_fade_time := 0.25  ## s to crossfade between two surfaces

@export_group("Impacts")
@export var impact_light: SfxDef
@export var impact_heavy: SfxDef
@export var debris: SfxDef
@export var heavy_threshold := 4500.0  ## N·s above which a hit is heavy (and throws debris)

var _car: VehicleController
var _bands: Array[AudioStreamPlayer3D] = []
var _band_rpm: PackedFloat32Array = []
var _roll_a: AudioStreamPlayer3D
var _roll_b: AudioStreamPlayer3D
var _roll_surface := ""
var _skid: AudioStreamPlayer3D
var _scrape: AudioStreamPlayer3D
var _rpm := 0.0
var _rolls := {}                       # surface id -> AudioStream, loaded once

func _ready() -> void:
	_car = get_parent() as VehicleController
	if _car == null:
		push_warning("CarAudio expects a VehicleController parent")
		set_physics_process(false)
		return
	_car.impacted.connect(_on_impact)

	if engine != null:
		for pair in [[engine.low, engine.low_rpm], [engine.mid, engine.mid_rpm], [engine.high, engine.high_rpm]]:
			if pair[0] == null:
				continue
			var p := _make_player(pair[0])
			_bands.append(p)
			_band_rpm.append(pair[1])
		_rpm = engine.idle_rpm
		if engine.start_sfx != null:
			Sfx.play_at(engine.start_sfx, global_position)

	_roll_a = _make_player(null)
	_roll_b = _make_player(null)
	_skid = _make_player(null)
	_scrape = _make_player(load(ROLL_DIR + "scrape.wav") as AudioStream)

## Cut the engine — the wind-down cue, and every loop out. Call when a race ends.
func shut_down() -> void:
	if engine != null and engine.off_sfx != null:
		Sfx.play_at(engine.off_sfx, global_position)
	for p in _bands:
		p.stop()
	for p in [_roll_a, _roll_b, _skid, _scrape]:
		if p != null:
			p.stop()
	set_physics_process(false)

func _make_player(stream: AudioStream) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = "SFX"
	p.volume_db = SILENT_DB
	p.max_distance = 60.0
	# Doppler would multiply with the pitch we drive from RPM and fight it (docs/AUDIO.md §4).
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	add_child(p)
	if stream != null:
		p.play()
	return p

func _physics_process(delta: float) -> void:
	if _car == null:
		return
	var speed := absf(_car.get_forward_speed())
	var grounded := _car.wheels_on_ground() > 0
	_update_engine(delta, speed)
	_update_roll(delta, speed, grounded)
	_update_skid(delta, speed, grounded)
	_fade(_scrape, scrape_volume_db if _car.is_scraping() else SILENT_DB, delta, fade_time)

# ---------------------------------------------------------------- engine
func _update_engine(delta: float, speed: float) -> void:
	if engine == null or _bands.is_empty():
		return
	var target := _target_rpm(speed)
	# Revs chase their target rather than snapping, so shifts and throttle blips have weight.
	_rpm = move_toward(_rpm, target, (engine.redline_rpm - engine.idle_rpm) * 2.5 * delta)

	# Equal-power crossfade between adjacent bands: full weight at a band's own centre, handing
	# over to its neighbour by the time it reaches theirs.
	var weights := PackedFloat32Array()
	var total := 0.0
	for i in _bands.size():
		var span := _band_span(i)
		var w: float = clampf(1.0 - absf(_rpm - _band_rpm[i]) / span, 0.0, 1.0)
		weights.append(w)
		total += w * w
	total = sqrt(maxf(total, 0.0001))

	var load_db: float = lerpf(engine.idle_volume_db, engine.volume_db, _car.throttle_amount)
	for i in _bands.size():
		var p := _bands[i]
		var w := weights[i] / total
		p.pitch_scale = clampf(_rpm / _band_rpm[i], engine.pitch_min, engine.pitch_max)
		var db: float = load_db + linear_to_db(maxf(w, 0.0001))
		p.volume_db = move_toward(p.volume_db, db if w > 0.001 else SILENT_DB, FADE_DB / fade_time * delta)

## Revs from road speed through a fake gearbox: they climb across a gear, then drop on the shift.
## Standing still, throttle revs the engine in neutral.
func _target_rpm(speed: float) -> float:
	var top: float = _car.max_speed if _car.max_speed < INF else 55.0
	var frac := clampf(speed / top, 0.0, 1.0)
	if speed < 0.5:
		return lerpf(engine.idle_rpm, engine.redline_rpm * 0.6, _car.throttle_amount)
	var gears := engine.gear_starts
	var g := gears.size() - 1
	for i in gears.size():
		if frac < gears[i]:
			g = i - 1
			break
	g = maxi(g, 0)
	var lo: float = gears[g]
	var hi: float = gears[g + 1] if g + 1 < gears.size() else 1.0
	var within := clampf((frac - lo) / maxf(hi - lo, 0.001), 0.0, 1.0)
	return lerpf(engine.idle_rpm, engine.redline_rpm, within)

func _band_span(i: int) -> float:
	# Distance to the nearest neighbouring band centre — how far this sample has to carry.
	var span := INF
	for j in _band_rpm.size():
		if j != i:
			span = minf(span, absf(_band_rpm[j] - _band_rpm[i]))
	return span if span < INF else 2000.0

# ---------------------------------------------------------------- tyres
func _update_roll(delta: float, speed: float, grounded: bool) -> void:
	var surf := _car.current_surface()
	var id: String = surf.id if surf != null else ""
	if id != _roll_surface:
		# New surface: the incoming loop starts on the spare player and the outgoing one fades,
		# so dropping a wheel onto gravel blends rather than cuts.
		var stream := _roll_stream(id)
		if stream != null:
			var tmp := _roll_b
			_roll_b = _roll_a
			_roll_a = tmp
			_roll_a.stream = stream
			_roll_a.volume_db = SILENT_DB
			_roll_a.play()
		_roll_surface = id

	var loud := grounded and speed > 1.0 and _roll_a.stream != null
	var t := clampf(speed / roll_full_speed, 0.0, 1.0)
	_roll_a.pitch_scale = 1.0 - roll_pitch_range * 0.5 + roll_pitch_range * t
	_fade(_roll_a, (roll_volume_db + linear_to_db(maxf(t, 0.001))) if loud else SILENT_DB,
		delta, surface_fade_time)
	_fade(_roll_b, SILENT_DB, delta, surface_fade_time)

func _roll_stream(id: String) -> AudioStream:
	if id == "":
		return null
	if not _rolls.has(id):
		var path := ROLL_DIR + "roll_" + id + ".wav"
		_rolls[id] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _rolls[id]

func _update_skid(delta: float, speed: float, grounded: bool) -> void:
	var slip := _car.skid_amount()
	if _car.is_handbraking:
		slip = maxf(slip, 0.6)
	var want := grounded and speed > 3.0 and slip > 0.15
	if want:
		# Hard surfaces squeal, loose ones hiss. Surface grip is the cheapest proxy we have.
		var surf := _car.current_surface()
		var loose := surf != null and surf.id in ["gravel", "dirt", "sand", "snow"]
		var stream := load(ROLL_DIR + ("skid_loose.wav" if loose else "skid_asphalt.wav")) as AudioStream
		if _skid.stream != stream:
			_skid.stream = stream
			_skid.play()
		elif not _skid.playing:
			_skid.play()
	_fade(_skid, (skid_volume_db + linear_to_db(clampf(slip, 0.001, 1.0))) if want else SILENT_DB,
		delta, fade_time)

# ---------------------------------------------------------------- impacts
func _on_impact(strength: float) -> void:
	var heavy := strength >= heavy_threshold
	var def := impact_heavy if heavy else impact_light
	if def != null:
		Sfx.play_at(def, global_position)
	# Debris rides on top of a heavy hit — the cube burst it accompanies (ADR-003).
	if heavy and debris != null:
		Sfx.play_at(debris, global_position)

func _fade(p: AudioStreamPlayer3D, target_db: float, delta: float, seconds: float) -> void:
	if p == null:
		return
	p.volume_db = move_toward(p.volume_db, target_db, FADE_DB / maxf(seconds, 0.01) * delta)
	if p.volume_db <= SILENT_DB and p.playing and target_db <= SILENT_DB:
		p.stop()
	elif target_db > SILENT_DB and not p.playing and p.stream != null:
		p.play()
