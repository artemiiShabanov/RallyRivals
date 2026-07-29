class_name BossDriver
extends RivalDriver
## A chapter boss in the 1v1 duel (code-ai-boss). It drives the racing line like any RivalDriver, then
## layers on the MANNER that makes a boss feel like a boss (BossDef knobs, realising RIVALS.md):
##
##   BLOCKING (positional, never contact) — when the player is close BEHIND, the boss slides across to
##   shadow their line and cover the pass; firm-but-fair, so it eases off with distance and, crucially,
##   HOLDS ITS LINE the moment the player draws alongside. That single rule means the boss can never be
##   the car that hits you — "aggression is positional, never contact" (GDD §6). `block` scales it;
##   block = 0 (Vance) races its own line and never covers.
##
##   FADE — pace bled across the run (`fade`): gaps you early, comes back to you late (Mercer).
##
##   POISE — composure (`poise`): a low-poise boss that YOU bump wobbles and lifts for a beat (Mercer
##   "cracks"); high-poise bosses (Vance, Kozak) are unmoved. The boss never initiates the contact.
##
## The boss never rams: it only ever defends a position it already holds and yields when that would mean
## contact. Wired live in RaceDirector (the duel), which feeds it the player car + connects on_contact().

var player                    ## the player's car node, for reading the gap + which side to cover
var block := 0.0              ## 0..1 positional-defence strength
var fade := 0.0              ## 0..1 pace lost by the end of the run
var poise := 1.0             ## 0..1 composure; low cracks on contact
var _base_corner_grip := 8.5
var _base_throttle_gain := 1.0
var _rattle := 0.0           ## seconds of "cracked" wobble remaining after a bump

const ALONGSIDE_GAP := 3.5   # along-track gap (m) within which the player counts as ALONGSIDE → hold line
const BLOCK_RANGE := 20.0    # start covering once the player is within this far behind
const MAX_COVER := 2.6       # max lateral shift (m) toward the player's line — bounded to stay on the road
const BLOCK_STEER := 0.45    # steering authority of the cover nudge
const RATTLE_TIME := 1.3     # seconds a fully brittle (poise 0) boss wobbles after a bump

func _init(ai_path: Path3D, is_loop := true, def: BossDef = null) -> void:
	super._init(ai_path, is_loop)
	if def != null:
		corner_grip = def.corner_grip
		brake_decel = def.brake_decel
		throttle_gain = def.power          # power → throttle/launch/corner-exit drive
		block = def.block
		fade = def.fade
		poise = def.poise
	_base_corner_grip = corner_grip
	_base_throttle_gain = throttle_gain

func poll(car, delta: float) -> Dictionary:
	var curve: Curve3D = path.curve if path != null else null
	if curve == null or curve.point_count < 2:
		return {}
	var length := curve.get_baked_length()
	# FADE: scale pace down as the run progresses (progress from last frame's line offset — close enough).
	var progress := clampf(last_offset / maxf(length, 1.0), 0.0, 1.0)
	var fade_f := 1.0 - fade * progress
	corner_grip = _base_corner_grip * fade_f
	throttle_gain = _base_throttle_gain * fade_f
	if _rattle > 0.0:
		_rattle -= delta

	var out := super.poll(car, delta)      # base racing-line intent (also refreshes last_offset)
	if out.is_empty():
		return out
	out = _apply_block(car, out, curve, length)
	if _rattle > 0.0:                       # cracked: a beat of twitchy steering + a lift
		out.steer = clampf(out.steer + randf_range(-1.0, 1.0) * 0.22 * (1.0 - poise), -1.0, 1.0)
		out.throttle *= 0.7
	return out

# The player bumped the boss — a brittle boss wobbles/lifts briefly; a composed one shrugs it off. The
# boss never causes this itself (it yields before contact); it only reacts to being hit.
func on_contact() -> void:
	if poise < 1.0:
		_rattle = maxf(_rattle, (1.0 - poise) * RATTLE_TIME)

# Firm-but-fair cover: nudge the steer to shadow the player's line when they're close behind, easing to
# nothing at BLOCK_RANGE and OFF entirely once they're alongside (so the boss never closes a door into
# contact). block = 0 → no cover at all (races its own line).
func _apply_block(car, out: Dictionary, curve: Curve3D, length: float) -> Dictionary:
	if block <= 0.0 or player == null:
		return out
	var boss_off := last_offset
	var p_off := curve.get_closest_offset(path.to_local(player.global_position))
	var behind := boss_off - p_off
	if behind <= ALONGSIDE_GAP or behind > BLOCK_RANGE:
		return out                          # alongside/ahead (hold line) or too far back (nothing to do)
	var cover := block * (1.0 - (behind - ALONGSIDE_GAP) / (BLOCK_RANGE - ALONGSIDE_GAP))
	var want := clampf(_lateral(curve, boss_off, length, player.global_position), -MAX_COVER, MAX_COVER) * cover
	var boss_lat := _lateral(curve, boss_off, length, car.global_position)
	var nudge := clampf((want - boss_lat) * BLOCK_STEER, -0.5, 0.5)
	out.steer = clampf(out.steer + steer_sign * nudge, -1.0, 1.0)
	return out

# Signed distance of `world_pos` from the racing line at arc-length `off`, along the line's RIGHT
# (Vector3.UP × tangent, matching the car's local +x) — so + = right of the line, like the steer sign.
func _lateral(curve: Curve3D, off: float, length: float, world_pos: Vector3) -> float:
	var here := _point(curve, off, length)
	var tan := _point(curve, off + PROBE, length) - here
	tan.y = 0.0
	if tan.length() < 0.01:
		return 0.0
	var perp := Vector3.UP.cross(tan.normalized())
	var d := world_pos - here
	d.y = 0.0
	return d.dot(perp)
