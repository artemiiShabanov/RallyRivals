class_name BossDef
extends RefCounted
## The four chapter bosses (code-ai-boss), the data the RivalDef doc (RIVALS.md) always said it would
## feed. A boss is an identity (name / number / brand / pink-slip car at the chapter's top class) plus a
## DRIVING MANNER expressed as knobs BossDriver reads. Bosses appear only in their 1v1 boss duel, never
## in the pack (field-matching spec).
##
## The manner knobs realise RIVALS.md's four authored lines. Two are RivalDriver pace knobs (corner_grip,
## brake_decel); the rest are boss-only: `power` scales throttle/exit drive, `block` is positional-defence
## strength (0 = races its own line, never covers you), `fade` is pace lost across the run, `poise` is
## composure (low = rattled when you bump it). All PLACEHOLDER feel — balance-difficulty-ai owns the final
## curve; this file owns the SHAPE that makes each boss read as itself.

var name := ""            ## full name (boss-intro screen)
var hud := ""             ## surname (leaderboard/HUD)
var number := 0           ## reserved campaign plate (66/23/7/1)
var brand := ""           ## apex | wreck | mayfly
var car_class := ""       ## the chapter's top class
var car_id := ""          ## the pink-slip car the win awards (drives it in the duel)

# --- manner (see class header) ---
var corner_grip := 8.5    ## RivalDriver lateral budget: high = carries corner speed, low = bleeds in bends
var brake_decel := 12.0   ## RivalDriver braking model: high = brakes impossibly deep
var power := 1.0          ## throttle/launch/corner-exit drive (× RivalDriver throttle_gain)
var block := 0.0          ## 0..1 positional defence — shadow the player's line when they're close behind
var fade := 0.0           ## 0..1 pace lost by the end of the run (gaps early, comes back to you)
var poise := 1.0          ## 0..1 composure — low cracks (wobbles + lifts) when you make contact

## The four, chapter order (0-based). Mirrors docs/RIVALS.md — same names, plates, brands, cars.
static func all() -> Array:
	return [
		# Drago — bulls the start, sits mid-road, bleeds in corners. The wall that teaches cornering.
		_make("Marek Drago", "DRAGO", 66, "wreck", "C", "crowbar", {
			corner_grip = 6.2, brake_decel = 10.0, power = 1.25, block = 0.55, fade = 0.0, poise = 0.7}),
		# Mercer — detonates off the line, gaps early, then fades; brittle, rattled by contact.
		_make("Rae Mercer", "MERCER", 23, "mayfly", "B", "strobe", {
			corner_grip = 8.6, brake_decel = 12.0, power = 1.2, block = 0.4, fade = 0.35, poise = 0.3}),
		# Vance — surgical: textbook line, brakes impossibly deep, never errs, never attacks you.
		_make("Ivo Vance", "VANCE", 7, "apex", "A", "verdict", {
			corner_grip = 10.6, brake_decel = 15.5, power = 1.1, block = 0.0, fade = 0.0, poise = 1.0}),
		# Kozak — immovable: parks his mass on the line, dares you through, rockets out on raw power.
		_make("Boris Kozak", "KOZAK", 1, "wreck", "S", "juggernaut", {
			corner_grip = 8.0, brake_decel = 13.0, power = 1.35, block = 0.9, fade = 0.0, poise = 1.0}),
	]

## The boss for `chapter` (0-based, clamped to the four).
static func for_chapter(chapter: int) -> BossDef:
	var list := all()
	return list[clampi(chapter, 0, list.size() - 1)]

static func _make(full: String, surname: String, num: int, brnd: String, cls: String, car: String, m: Dictionary) -> BossDef:
	var d := BossDef.new()
	d.name = full; d.hud = surname; d.number = num; d.brand = brnd; d.car_class = cls; d.car_id = car
	d.corner_grip = m["corner_grip"]; d.brake_decel = m["brake_decel"]; d.power = m["power"]
	d.block = m["block"]; d.fade = m["fade"]; d.poise = m["poise"]
	return d
