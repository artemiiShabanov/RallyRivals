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

@export var fallback_race: RaceDef      ## used when launched directly (no pending)
@export var car_scene: PackedScene = preload("res://scenes/vehicle/car.tscn")

const SLICE_RACE := "res://assets/races/test_circuit.tres"
const COUNT_FROM := 3

var _race: RaceDef
var _car: VehicleController
var _timing: RaceTiming
var _cps: TrackCheckpoints
var _finished := false
var _banner: Label

func _ready() -> void:
	_race = pending if pending != null else (fallback_race if fallback_race != null else load(SLICE_RACE) as RaceDef)
	pending = null
	_build()
	Flow.pausable(true)     # the pause action works throughout the race (the pause menu reacts)
	_run()

func _build() -> void:
	var ps := load(_race.track_scene) as PackedScene
	if ps == null:
		push_error("RaceDirector: no baked track at %s" % _race.track_scene)
		return
	var track := ps.instantiate()
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
	add_child(_car)

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
		hud.bind(_car, _timing, _cps, _race.laps)

	_banner = _make_banner()

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

func _run() -> void:
	await _countdown()
	if _finished:
		return
	_car.input_enabled = true
	Sfx.play(load("res://assets/audio/sfx/engine_start.tres") as SfxDef)
	_timing.begin()
	_banner.text = ""

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
	# Solo field in the skeleton — no rival times yet, so this places 1 / 1. code-ai-rival will pass
	# the rivals' finish times to compute().
	last_result = RaceResult.compute(_race.id, _timing.total_time(_car),
		_timing.laps_of(_car).duplicate(), _timing.best_lap(_car))
	Sfx.play(load("res://assets/audio/sfx/finish_win.tres") as SfxDef)
	var ca := _car.get_node_or_null("CarAudio")
	if ca != null and ca.has_method("shut_down"):
		ca.shut_down()
	_banner.text = "FINISH"
	await get_tree().create_timer(1.5).timeout
	Flow.goto(Routes.RESULTS)
