class_name RaceDirector
extends Node3D
## Runs one race end to end (code-race-director). Builds the track + car + camera + HUD from a
## RaceDef (the same setup track_demo uses to drive-verify), then drives the lifecycle:
##   GRID (car parked) → COUNTDOWN 3·2·1·GO → RACING (timing live) → FINISH (parked) → hand off.
##
## Finish detection lives here because RaceTiming only measures: a circuit finishes when the lap
## count reaches RaceDef.laps; a point-to-point finishes on stage_completed. The RaceDef arrives from
## the pre-race screen via `pending`; a scene-embedded `fallback_race` lets race.tscn run standalone
## (F6). On finish it stores `last_result` and returns to the hub — code-ui-results will slot the
## results screen into that handoff (reading last_result).

static var pending: RaceDef = null      ## handoff from the pre-race screen
static var last_result: RaceResult = null   ## finish outcome for the results screen
static var autodrive := false           ## test/attract: a RivalDriver drives the player car to the finish

@export var fallback_race: RaceDef      ## used when launched directly (no pending)
@export var car_scene: PackedScene = preload("res://scenes/vehicle/car.tscn")
## Dev/test: spawn this many AI rivals that drive the AiLine, lined up ahead of you (so you can catch +
## ram one). Drawn from the race's assembled field (real driver cars). The full auto-field with
## finish-time placings is a later integration; this is the minimal opponent.
@export var rivals := 0

const SLICE_RACE := "res://assets/races/test_timetrial.tres"
const COUNT_FROM := 3
# Contact penalty (code-race-contact): an OFFICIALS race adds a flat time penalty for every contact
# with another car (any side). Wilds ignore it entirely. Placeholder — balance owns the number.
const CONTACT_PENALTY := 3.0   # seconds per car-to-car contact

var _race: RaceDef
var _car: VehicleController
var _timing: RaceTiming
var _cps: TrackCheckpoints
var _finished := false
var _built := false
var _banner: Label
var _penalty := 0.0            ## accrued Officials contact penalty (s), folded into the finish time
var _penalty_label: Label
var _rivals: Array[VehicleController] = []   ## AI opponents (dev/test), parked until GO

func _ready() -> void:
	_race = pending if pending != null else (fallback_race if fallback_race != null else load(SLICE_RACE) as RaceDef)
	pending = null
	_boot()

## The baked track is the heavy load — pull it through Flow's async loader (loading screen) so it
## streams in behind the transition's black instead of hitching the main thread.
func _boot() -> void:
	var track_ps := await Flow.load_async(_race.track_scene)
	if track_ps == null:
		push_error("RaceDirector: no baked track at %s" % _race.track_scene)
		return
	_build(track_ps)
	_built = true
	Flow.pausable(true)     # the pause action works throughout the race (the pause menu reacts)
	_run()

## Flow holds the transition reveal until the track has finished loading and the scene is built.
func ready_to_reveal() -> void:
	while not _built:
		await get_tree().process_frame

func _build(track_ps: PackedScene) -> void:
	var track := track_ps.instantiate()
	add_child(track)

	# Venue ambience + per-race conditions (time-of-day, weather) — same as the drive harness.
	var bed := AmbientBed.find_or_create(get_tree())
	if bed != null and _race.ambience != null:
		bed.set_layer("world", _race.ambience)
	if _race.lighting != null:
		_race.lighting.apply_in(track)
	if _race.weather != null:
		var fx := WeatherFX.new()
		fx.name = "WeatherFX"
		add_child(fx)
		fx.apply(_race.weather)

	# Checkpoints + timing.
	_cps = track.get_node_or_null("Checkpoints") as TrackCheckpoints
	# The type and its baked track must agree (code-race-types): a sprint on a loop never reaches a
	# finish line; a circuit on a point-to-point ends after one pass. Loud, not fatal.
	if _cps != null and not _race.track_ok(_cps.loop):
		push_warning("RaceDirector: '%s' is %s but its track is %s — fix RaceDef.track_scene." % [
			_race.id, _race.race_type, "a loop" if _cps.loop else "point-to-point"])
	_timing = RaceTiming.new()
	_timing.name = "RaceTiming"
	add_child(_timing)
	if _cps != null:
		_timing.setup(_cps)
		var cp_sfx := load("res://assets/audio/sfx/checkpoint.tres") as SfxDef
		_cps.gate_passed.connect(func(body: Node3D, _i: int, _t: int) -> void: Sfx.play_at(cp_sfx, body.global_position))
		_timing.lap_completed.connect(_on_lap)
		_timing.stage_completed.connect(_on_stage)

	# Car parked at the start line, facing along the extracted spline.
	var start := track.get_node_or_null("StartFinish") as Marker3D
	var path := track.get_node_or_null("TrackPath") as Path3D
	var ai_line := track.get_node_or_null("AiLine") as Path3D
	var spawn := (start.global_position if start else Vector3.ZERO) + Vector3.UP * 1.5
	var fwd := Vector3.FORWARD
	if path != null and path.curve != null and path.curve.point_count > 1:
		var f := path.curve.get_point_position(1) - path.curve.get_point_position(0)
		f.y = 0.0
		if f.length() > 0.01:
			fwd = f.normalized()
	var right := Vector3.UP.cross(fwd).normalized()
	_car = car_scene.instantiate() as VehicleController
	_car.name = "Car"
	_car.transform = Transform3D(Basis(right, Vector3.UP, fwd), spawn)
	_car.input_enabled = false          # parked until GO
	var picked := Cars.by_id(Save.active.current_car) if Save.active != null else null
	if picked != null:                  # race the car chosen in the garage/pre-race (else scene default)
		_car.car = picked
	add_child(_car)
	if autodrive and ai_line != null:   # test/attract: hand the wheel to a RivalDriver
		_car.driver = RivalDriver.new(ai_line, _cps.loop if _cps != null else true)
	if _race.culture == "officials":    # clean racing: rams cost time. Wilds never connects this.
		_car.rammed.connect(_on_ram)
	if rivals > 0 and ai_line != null:
		_spawn_rivals(spawn, fwd, right, ai_line)

	var cam := ChaseCamera.new()
	cam.name = "ChaseCamera"
	cam.target_path = NodePath("../Car")
	add_child(cam)
	cam.current = true

	var vhs := VHSFilter.new()          # layer 5: over the world, under the HUD
	vhs.name = "VHSFilter"
	add_child(vhs)

	if _cps != null:
		var hud := RaceHud.new()
		hud.name = "RaceHud"
		add_child(hud)
		hud.bind(_car, _timing, _cps, _race.laps, _race.race_type, _race.tt_targets())

	Music.play(_race.race_type)   # race-type track (no-op/quiet until its .ogg exists)
	_banner = _make_banner()
	if _race.culture == "officials":
		_penalty_label = _make_penalty_label()

# Line up `rivals` AI cars ahead of the player in the same lane, each driving the AiLine, parked until
# GO. Cars come from the race's assembled field (real driver/car); short of the field, they use the
# scene default. Minimal opponent for contact/feel testing — not the finish-time-scored auto-field yet.
func _spawn_rivals(base: Vector3, fwd: Vector3, right: Vector3, ai_line: Path3D) -> void:
	var field := RaceField.assemble(_race, 0)
	var loop: bool = _cps.loop if _cps != null else true
	for i in rivals:
		var car := car_scene.instantiate() as VehicleController
		car.name = "Rival%d" % (i + 1)
		if i < field.size():
			car.car = field[i]["car"]                       # a real (brand, class) car
		car.transform = Transform3D(Basis(right, Vector3.UP, fwd), base + fwd * (6.0 + i * 6.0))
		car.input_enabled = false                           # parked until GO, like the player
		car.driver = RivalDriver.new(ai_line, loop)
		add_child(car)
		_rivals.append(car)

## Big centred text over the HUD — the countdown and the finish message share it.
func _make_banner() -> Label:
	var layer := CanvasLayer.new()
	layer.name = "RaceBanner"
	layer.layer = 60                    # above the HUD (50), below the debug menu (100)
	add_child(layer)
	var l := Label.new()
	l.theme_type_variation = "HudValue"
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(l)
	return l

# A small red flash near the top for Officials contact penalties — distinct from the big centre banner.
func _make_penalty_label() -> Label:
	var layer := CanvasLayer.new()
	layer.name = "PenaltyFlash"
	layer.layer = 55                    # above the HUD (50), below the banner (60)
	add_child(layer)
	var l := Label.new()
	l.theme_type_variation = "HudTag"
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.position = Vector2(0, 96)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.add_theme_color_override("font_color", Color(1.0, 0.42, 0.32))
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(l)
	return l

# A car-to-car ram in an Officials race (Wilds never connect this). Accrue an impact-scaled penalty
# into the finish time and flash it. Cooldown/debounce lives in VehicleController, so one ram = one call.
func _on_ram(_impulse: float) -> void:
	if _finished:
		return
	_penalty += CONTACT_PENALTY
	if _penalty_label != null:
		_penalty_label.text = "CONTACT  +%.0fs   (penalty +%.0fs)" % [CONTACT_PENALTY, _penalty]
		_penalty_label.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_property(_penalty_label, "modulate:a", 0.0, 1.4).set_delay(0.5)

func _run() -> void:
	await _countdown()
	if _finished:
		return
	_car.input_enabled = true
	for r in _rivals:                   # release the AI opponents at the same GO
		r.input_enabled = true
	_timing.begin()
	_banner.text = ""
	if autodrive:
		print("[autodrive] GO %s (%s)" % [_race.id, _race.race_type])

func _countdown() -> void:
	var beep := load("res://assets/audio/sfx/countdown_beep.tres") as SfxDef
	var go := load("res://assets/audio/sfx/countdown_go.tres") as SfxDef
	for n in range(COUNT_FROM, 0, -1):
		_banner.text = str(n)
		Sfx.play(beep)
		await get_tree().create_timer(1.0).timeout
	_banner.text = "GO!"
	Sfx.play(go)
	await get_tree().create_timer(0.6).timeout

func _on_lap(body: Node3D, _lap_time: float, lap_number: int, _is_best: bool) -> void:
	if body == _car and autodrive:
		print("[autodrive] lap %d/%d" % [lap_number, _race.laps])
	if body == _car and _cps != null and _cps.loop and lap_number >= _race.laps:
		_finish()

func _on_stage(body: Node3D, _total_time: float) -> void:
	if body == _car:
		_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	_car.input_enabled = false          # coast to a parked stop
	var total := _timing.total_time(_car) + _penalty   # contact penalty folds into the finish time
	var laps := _timing.laps_of(_car).duplicate()
	var best := _timing.best_lap(_car)
	if _race.race_type == "time_trial":
		# No field: your time becomes a place via the medal targets (code-race-timetrial).
		last_result = RaceResult.compute_time_trial(_race.id, total, laps, best, _race.tt_targets())
	else:
		# Solo field in the skeleton — no rival times yet, so this places 1 / 1. code-ai-rival will
		# pass the rivals' finish times to compute().
		last_result = RaceResult.compute(_race.id, total, laps, best)
	last_result.penalty = _penalty
	RaceEconomy.apply(last_result, _race)   # bank the finish + pay out (code-meta-economy)
	if autodrive:
		print("[autodrive] FINISH %s (%s): place %d/%d, %.2fs" % [_race.id, _race.race_type, last_result.place, last_result.field_size, total])
	Sfx.play(load("res://assets/audio/sfx/finish_win.tres") as SfxDef)
	var ca := _car.get_node_or_null("CarAudio")
	if ca != null and ca.has_method("shut_down"):
		ca.shut_down()
	_banner.text = "FINISH"
	await get_tree().create_timer(1.5).timeout
	Flow.goto(Routes.RESULTS)
