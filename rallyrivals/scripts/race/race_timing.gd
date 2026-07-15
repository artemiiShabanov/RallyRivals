class_name RaceTiming
extends Node
## Lap/stage timing on top of TrackCheckpoints. Counts GAME time — accumulated physics delta —
## so it pauses with the tree and stays honest under the debug menu's time scale.
##
## Loop tracks: a lap completes when the sequence does (at the start line, where lap time
## belongs) -> lap_completed with the time and best-lap flag. Point-to-point: the run completes
## at the finish -> stage_completed with the total. gate_crossed provides per-gate splits into
## the current lap/run. Records are PER BODY (player and AI rivals time alike). Win/lose and
## placing live in code-race-result; this node only measures.

signal gate_crossed(body: Node3D, index: int, split: float)   ## seconds into the current lap/run
signal lap_completed(body: Node3D, lap_time: float, lap_number: int, is_best: bool)
signal stage_completed(body: Node3D, total_time: float)

var checkpoints: TrackCheckpoints

var _clock := 0.0
var _running := false
var _recs := {}   # body -> {start, lap_start, laps: Array, best, finished, total}

func setup(cps: TrackCheckpoints) -> void:
	checkpoints = cps
	cps.gate_passed.connect(_on_gate_passed)
	cps.sequence_completed.connect(_on_sequence_completed)

## Start (or restart) the clock. Bodies register lazily at their first gate — call begin() at
## the moment the race actually starts (countdown end / scene ready).
func begin() -> void:
	_clock = 0.0
	_recs.clear()
	_running = true

func _physics_process(delta: float) -> void:
	if _running:
		_clock += delta

# ---------- queries ----------
## Seconds into the body's current lap (loop) or run (point-to-point).
func current_time(body: Node3D) -> float:
	var r := _rec(body)
	return r["total"] if r["finished"] else _clock - r["lap_start"]

## Seconds since the body started racing (frozen at the finish on point-to-point).
func total_time(body: Node3D) -> float:
	var r := _rec(body)
	return r["total"] if r["finished"] else _clock - r["start"]

func laps_of(body: Node3D) -> Array:
	return _rec(body)["laps"]

## Best completed lap (INF until one exists).
func best_lap(body: Node3D) -> float:
	return _rec(body)["best"]

# ---------- checkpoint plumbing ----------
func _rec(body: Node3D) -> Dictionary:
	if not _recs.has(body):
		# Anchor at begin() (clock zero), not at the first event — otherwise lap 1 would miss
		# the start-line-to-first-gate stretch. Everyone races from the moment begin() fires.
		_recs[body] = {"start": 0.0, "lap_start": 0.0, "laps": [], "best": INF, "finished": false, "total": 0.0}
	return _recs[body]

func _on_gate_passed(body: Node3D, index: int, _total: int) -> void:
	var r := _rec(body)
	if not r["finished"]:
		gate_crossed.emit(body, index, _clock - r["lap_start"])

func _on_sequence_completed(body: Node3D) -> void:
	var r := _rec(body)
	if r["finished"]:
		return
	if checkpoints != null and not checkpoints.loop:
		r["finished"] = true
		r["total"] = _clock - r["start"]
		stage_completed.emit(body, r["total"])
		return
	var t: float = _clock - r["lap_start"]
	r["lap_start"] = _clock
	(r["laps"] as Array).append(t)
	var is_best: bool = t < float(r["best"])
	if is_best:
		r["best"] = t
	lap_completed.emit(body, t, (r["laps"] as Array).size(), is_best)
