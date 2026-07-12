class_name TrackCheckpoints
extends Node3D
## Ordered checkpoint gates (GDD 5, anti-shortcut): a lap only counts if every gate is passed in
## sequence, so cutting the track is invalid — a wrong/skipped gate is simply ignored until the
## missed one is collected. Progress is tracked PER BODY (player and AI rivals alike).
##
## Policy-free: emits gate_passed / sequence_completed; what a completed sequence means (lap,
## sprint finish) is the race type's business (code-race-types). Gate 0 is the start/finish line:
## a body's first expected gate is 1, and re-crossing gate 0 with all others collected completes
## the sequence — so completion fires exactly at the line, where lap time is measured.

signal gate_passed(body: Node3D, index: int, total: int)
signal sequence_completed(body: Node3D)

var _gates: Array[CheckpointGate] = []
var _next := {}   # body -> next expected gate index

func _ready() -> void:
	add_to_group("track_checkpoints")
	for child in get_children():
		if child is CheckpointGate:
			_gates.append(child)
	_gates.sort_custom(func(a: CheckpointGate, b: CheckpointGate) -> bool: return a.index < b.index)
	for g in _gates:
		g.body_entered.connect(_on_gate_entered.bind(g))

func gate_count() -> int:
	return _gates.size()

## Index of the gate `body` must pass next (0 = the start/finish line is next).
func next_gate(body: Node3D) -> int:
	return _next.get(body, 1)

## Forget a body's progress (race restart).
func reset(body: Node3D) -> void:
	_next.erase(body)

## Gate node by sequence index (null if out of range).
func gate_node(index: int) -> CheckpointGate:
	return _gates[index] if index >= 0 and index < _gates.size() else null

## The gate `body` most recently passed — the start line before any pass (respawn anchor).
func last_gate(body: Node3D) -> CheckpointGate:
	if _gates.is_empty():
		return null
	return _gates[(next_gate(body) - 1 + _gates.size()) % _gates.size()]

func _on_gate_entered(body: Node3D, gate: CheckpointGate) -> void:
	if _gates.size() < 2:
		return
	var expected := next_gate(body)
	if gate.index != expected:
		return
	gate_passed.emit(body, gate.index, _gates.size())
	if expected == 0:
		sequence_completed.emit(body)
	_next[body] = (expected + 1) % _gates.size()
