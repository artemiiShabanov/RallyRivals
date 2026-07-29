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
const PENALTY_COLOR := Color(1.0, 0.42, 0.32)   # red alert on the HUD strip

var _race: RaceDef
var _car: VehicleController
var _timing: RaceTiming
var _cps: TrackCheckpoints
var _finished := false
var _built := false
var _banner: Label
var _penalty := 0.0            ## accrued Officials contact penalty (s), folded into the finish time
var _hud: RaceHud             ## the race HUD; its bottom strip doubles as the penalty alert line
var _rivals: Array[VehicleController] = []   ## AI opponents (dev/test), parked until GO
var _gp: GrandPrix = null      ## the active grand-prix meeting when this scene is a GP session (else null)
var _qual := false             ## this scene is a GP QUALIFYING session (solo hot-laps, ends to the GP hub)
var _laps_total := 0           ## laps this session runs: QUAL_LAPS in qualifying, else RaceDef.laps
var _qual_hint: Label          ## persistent "[ENTER] to finish" prompt, shown once you've set a lap
var _gates_passed := 0         ## player checkpoints crossed this race — monotonic, drives the race-board projection

# Physical starting grid (code-race-grandprix): a staggered two-column grid built back from the line.
const GRID_ROW := 6.0          # metres between grid rows
const GRID_STAGGER := 1.6      # the right column sits this far further back than the left
const GRID_LAT := 2.2          # lateral offset of each column from the lane centre

func _ready() -> void:
	_race = pending if pending != null else (fallback_race if fallback_race != null else load(SLICE_RACE) as RaceDef)
	pending = null
	# A grand-prix scene entry carries a live meeting whose RaceDef IS this race (the GP hub set both).
	# `phase` says whether we're running qualifying (solo hot-laps) or the graded race off the grid.
	if GrandPrix.session != null and GrandPrix.session.race == _race:
		_gp = GrandPrix.session
		_qual = _gp.phase == GrandPrix.PHASE_QUAL
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
	# Qualifying runs its own lap count (QUAL_LAPS); everything else counts the RaceDef's laps.
	_laps_total = GrandPrix.QUAL_LAPS if _qual else _race.laps

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
		# Live running order refreshes every checkpoint (not just each lap) while there's a field to rank.
		if _gp != null and not _qual:
			_timing.gate_crossed.connect(_on_gate_board)

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
	# A grand-prix RACE starts you from your qualified grid slot; qualifying + open races use the line.
	var car_pos := spawn
	if _gp != null and not _qual:
		car_pos = _grid_pos(spawn, fwd, right, _gp.player_grid - 1)
	_car.transform = Transform3D(Basis(right, Vector3.UP, fwd), car_pos)
	_car.input_enabled = false          # parked until GO
	var picked := Cars.by_id(Save.active.current_car) if Save.active != null else null
	if picked != null:                  # race the car chosen in the garage/pre-race (else scene default)
		_car.car = picked
	add_child(_car)
	if autodrive and ai_line != null:   # test/attract: hand the wheel to a RivalDriver
		_car.driver = RivalDriver.new(ai_line, _cps.loop if _cps != null else true)
	if _race.culture == "officials":    # clean racing: rams cost time. Wilds never connects this.
		_car.rammed.connect(_on_ram)
	# Opponents: qualifying is solo; a GP race lines up the physical grid; a dev scene may add `rivals`.
	if _qual:
		pass
	elif _gp != null and ai_line != null:
		_spawn_grid(spawn, fwd, right, ai_line)
	elif rivals > 0 and ai_line != null:
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
		_hud = RaceHud.new()
		_hud.name = "RaceHud"
		add_child(_hud)
		_hud.bind(_car, _timing, _cps, _laps_total, _race.race_type, _race.tt_targets())
		# Grand-prix order panel: rivals' provisional times while you qualify; the grid at the race start.
		if _qual and _gp != null:
			_gp.set_reference(_reference_lap(ai_line))
			_hud.set_standings(_gp.qual_standings(INF))
		elif _gp != null:
			_hud.set_standings(_gp.grid())

	Music.play(_race.race_type)   # race-type track (no-op/quiet until its .ogg exists)
	_banner = _make_banner()
	if _qual:
		_qual_hint = _make_qual_hint()

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

# Line up the grand-prix field on a PHYSICAL grid in qualifying order, each rival driving the AiLine,
# parked until GO. Your slot is left empty (the player car sits there); rivals fill the rest in grid
# order. Their finish PLACING is the simulated race time (GrandPrix), but they really drive — so you can
# dice with them and ramming still costs you (contact penalty), which is the point of a real grid.
func _spawn_grid(base: Vector3, fwd: Vector3, right: Vector3, ai_line: Path3D) -> void:
	var loop: bool = _cps.loop if _cps != null else true
	var order := _gp.grid_rivals()
	var oi := 0
	for slot in GrandPrix.GRID_SIZE:
		if slot == _gp.player_grid - 1:
			continue                                        # your slot — the player car is already here
		if oi >= order.size():
			break
		var entry: Dictionary = order[oi]
		oi += 1
		var car := car_scene.instantiate() as VehicleController
		car.name = "Rival%d" % slot
		car.car = entry["car"]
		car.transform = Transform3D(Basis(right, Vector3.UP, fwd), _grid_pos(base, fwd, right, slot))
		car.input_enabled = false
		car.driver = RivalDriver.new(ai_line, loop)
		add_child(car)
		_rivals.append(car)

# World position of grid slot `i` (0 = pole), staggered two-column and stepped back from the line.
func _grid_pos(base: Vector3, fwd: Vector3, right: Vector3, i: int) -> Vector3:
	var row := i / 2
	var col := i % 2                                          # 0 = left column, 1 = right column
	var back := row * GRID_ROW + col * GRID_STAGGER
	var side := (1.0 if col == 1 else -1.0) * GRID_LAT
	return base - fwd * back + right * side

# A provisional reference lap for the qualifying board: the racing line's length at a nominal pace.
func _reference_lap(ai_line: Path3D) -> float:
	if ai_line != null and ai_line.curve != null:
		var length := ai_line.curve.get_baked_length()
		if length > 1.0:
			return length / GrandPrix.REF_SPEED
	return 60.0

# The persistent qualifying prompt (bottom-centre, above the HUD strip), hidden until you set a lap.
func _make_qual_hint() -> Label:
	var l := Label.new()
	l.theme_type_variation = "HudTag"
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN
	l.offset_bottom = -70
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text = "◉ QUALIFYING  ·  [ENTER] to finish"
	l.modulate = Color(1, 1, 1, 0.85)
	l.visible = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.get_parent().add_child(l)
	return l

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

# A car-to-car contact in an Officials race (Wilds never connect this). Accrue the flat penalty into
# the finish time and announce it on the HUD's bottom strip (the same line checkpoint splits use).
# Debounce lives in VehicleController, so one contact = one call.
func _on_ram(_impulse: float, rear: bool) -> void:
	# A rear-end (someone hit the BACK of your car) isn't your fault — no penalty (code-race-contact).
	if _finished or rear:
		return
	_penalty += CONTACT_PENALTY
	if _hud != null:
		_hud.show_strip("CONTACT  +%.0fs   ·   PENALTY +%.0fs" % [CONTACT_PENALTY, _penalty], PENALTY_COLOR)

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
	if body != _car:
		return
	if _qual:
		if _qual_hint != null:
			_qual_hint.visible = true                 # a lap is on the board — end-early is now offered
		if _gp != null:
			_gp.reanchor(_timing.best_lap(_car))      # rival board tracks your real lap pace now
			if _hud != null:
				_hud.set_standings(_gp.qual_standings(_timing.best_lap(_car)))
		if lap_number >= _laps_total:
			_finish_qual()
		return
	if autodrive:
		print("[autodrive] lap %d/%d" % [lap_number, _laps_total])
	if _cps != null and _cps.loop and lap_number >= _laps_total:
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
	elif _gp != null:
		# Grand prix: placed against the field's SIMULATED race times (code-race-grandprix). Ramming a
		# rival already folded a penalty into `total`, so contact costs you positions here.
		last_result = RaceResult.compute(_race.id, total, laps, best, _gp.rival_race_times())
		GrandPrix.clear()                   # the meeting is complete
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

# End a grand-prix QUALIFYING session (code-race-grandprix): your best lap sets the grid, then hand
# back to the GP hub — NOT to results. Reached by running QUAL_LAPS or by the ENTER end-early key.
func _finish_qual() -> void:
	if _finished:
		return
	_finished = true
	_car.input_enabled = false
	if _qual_hint != null:
		_qual_hint.visible = false
	var best := _timing.best_lap(_car)
	if _gp != null:
		_gp.record_qual(best)
		_banner.text = "QUALIFIED\n%s / %d" % [_grid_label(_gp.player_grid), GrandPrix.GRID_SIZE]
	else:
		_banner.text = "QUALIFYING DONE"
	var ca := _car.get_node_or_null("CarAudio")
	if ca != null and ca.has_method("shut_down"):
		ca.shut_down()
	await get_tree().create_timer(1.5).timeout
	Flow.goto(Routes.GP_HUB)

# Player crossed a checkpoint — bump the progress counter and refresh the running order (every gate).
func _on_gate_board(body: Node3D, _index: int, _split: float) -> void:
	if body != _car:
		return
	_gates_passed += 1
	_update_race_board()

# Refresh the grand-prix race board: rivals sit at their simulated finish times; you slot in by a
# projected total (elapsed scaled by how far through the race's gates you are — so it works from the
# very first checkpoint, not only whole laps). Approximate by design — the FINAL place is your real time
# vs the rival times (_finish); this is just the live read-out and can differ mid-race.
func _update_race_board() -> void:
	if _gp == null or _hud == null:
		return
	var elapsed := _timing.total_time(_car)
	var total_gates := (_cps.gate_count() if _cps != null else 0) * maxi(_laps_total, 1)
	var proj := INF
	if total_gates > 0 and _gates_passed > 0 and elapsed > 0.0:
		proj = elapsed * float(total_gates) / float(_gates_passed)
	_hud.set_standings(_gp.race_standings(proj))

func _grid_label(place: int) -> String:
	return "P%d" % place

# End-early in qualifying: ENTER finishes the session once you've set at least one lap (the prompt
# appears then). Only active during a GP qualifying session.
func _unhandled_input(event: InputEvent) -> void:
	if not _qual or _finished or _timing == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_ENTER:
		if (_timing.laps_of(_car) as Array).size() > 0:
			get_viewport().set_input_as_handled()
			_finish_qual()
