class_name GrandPrix
extends RefCounted
## A Grand-Prix meeting (code-race-grandprix): the one race type run as TWO sessions with a menu
## between them —
##   QUALIFYING  solo hot-laps from the default start line (up to QUAL_LAPS; end early once you've set a
##               lap). Your best lap is your grid time. Rivals qualify by a SIMULATED pace model (they
##               never share the qual track), shown provisionally on the HUD order panel while you run.
##   RACE        the qualifying order becomes a PHYSICAL starting grid: rivals line up in grid order and
##               drive (RivalDriver), you slot into your qualified position. Placings are scored against
##               the rivals' simulated RACE times (a fast qualifier is a fast racer), so the grid means
##               something without depending on a full live pack finishing clean.
##
## One meeting persists across the qual → GP-hub → race scene changes in the static `session` (like
## RaceDirector.pending). The field is built ONCE at begin() with a deterministic pace per driver
## number, so re-qualifying shows the same rivals. The pace model is ANCHORED to your qual lap at
## record_qual(), so the grid is competitive at any skill level — a hot lap poles, a scrappy one starts
## mid-pack. RaceDirector reads `phase` to branch qual vs race; the GP hub is the menu on both sides.

const PHASE_QUAL := 0
const PHASE_RACE := 1

const GRID_SIZE := 6          ## cars on the grid: you + (GRID_SIZE-1) simulated rivals
const QUAL_LAPS := 3          ## flying laps offered in qualifying (end early once you've set one)
const BAND_WIDTH := 2         ## rivals draw a class in [gate .. gate+BAND_WIDTH], capped at S
const REF_SPEED := 24.0       ## m/s nominal lap pace — turns AiLine length into a PROVISIONAL qual lap (shown before you've set yours); balance owns it
const RACE_INFLATION := 1.03  ## a race lap runs ~3% slower than a qual hot lap (for everyone), so rival race totals stay fair against your real, non-optimal race pace

static var session: GrandPrix = null   ## the active meeting, or null

var race: RaceDef
var phase := PHASE_QUAL
var field: Array = []          ## rivals: {driver, car, car_class, pace, race_mult, qual, race_time}
var player_qual := INF         ## your best qualifying lap (INF = not set / DNF)
var player_grid := 0           ## your grid slot after qualifying (1 = pole)
var _ref_lap := 0.0            ## provisional reference lap, set from the qual track's racing line

## Start a fresh meeting for `race`, drawing a class-gated field from `chapter`. Stored in `session`.
static func begin(the_race: RaceDef, chapter := 0) -> GrandPrix:
	var gp := GrandPrix.new()
	gp.race = the_race
	gp.phase = PHASE_QUAL
	gp._build_field(chapter)
	session = gp
	return gp

## Drop the active meeting (finished, or abandoned back to the hub) so a later non-GP race is clean.
static func clear() -> void:
	session = null

# Draw GRID_SIZE-1 rivals: chapter drivers, each a class in the gate band, resolved to a car, with a
# deterministic pace centred near 1.0 (a small class edge + per-driver skill, seeded by the racing
# number so a meeting is stable across re-qualify). Times are filled later — provisional at
# set_reference(), final at record_qual() — once there's a lap to anchor them to.
func _build_field(chapter: int) -> void:
	field = []
	var gate := race.gate_class()
	var gate_rank := maxi(CarClass.rank(gate), 0)
	var band := _band(gate_rank)
	var pool := Roster.chapter(chapter).duplicate()
	pool.shuffle()                                     # fresh entrants per meeting (global RNG)
	var want := GRID_SIZE - 1
	for i in mini(want, pool.size()):
		var driver: DriverDef = pool[i]
		var rng := RandomNumberGenerator.new()
		rng.seed = driver.number * 2654435761          # stable pace per driver across re-qualify
		var cls: String = band[rng.randi() % band.size()]
		var car := Cars.by_brand_class(driver.brand, cls)
		if car == null:
			continue
		var class_term := 1.0 - 0.015 * float(CarClass.rank(cls) - gate_rank)   # a class up ≈ 1.5% quicker
		var pace: float = clampf(class_term * (1.0 + rng.randf_range(-0.05, 0.06)), 0.90, 1.12)
		var race_mult: float = 1.0 + rng.randf_range(-0.015, 0.015)             # small race-day shuffle
		field.append({
			"driver": driver, "car": car, "car_class": cls,
			"pace": pace, "race_mult": race_mult, "qual": INF, "race_time": INF,
		})

# The class letters a rival may draw: the gate class up to gate+BAND_WIDTH, clamped to S.
func _band(gate_rank: int) -> Array:
	var out: Array = []
	var top := mini(gate_rank + BAND_WIDTH, CarClass.ALL.size() - 1)
	for r in range(gate_rank, top + 1):
		out.append(CarClass.ALL[r])
	return out if not out.is_empty() else [CarClass.ALL[clampi(gate_rank, 0, CarClass.ALL.size() - 1)]]

## Provisional rival qual times from the qualifying track's racing-line length (before you've set a
## lap). Only for the HUD board during qualifying — the grid re-anchors to your real lap at record_qual().
func set_reference(ref_lap: float) -> void:
	_ref_lap = maxf(ref_lap, 1.0)
	for e in field:
		e["qual"] = _ref_lap * float(e["pace"])

## Lock in your qualifying lap and build the grid. Rival qual + race times RE-ANCHOR to your lap so the
## field is competitive at any skill; the grid is everyone sorted by qual time. Advances to the race.
func record_qual(best_lap: float) -> void:
	player_qual = best_lap
	var anchor: float = best_lap if best_lap < INF else _ref_lap   # DNF? fall back to the estimate
	var laps := maxi(race.laps, 1)
	for e in field:
		var pace := float(e["pace"])
		e["qual"] = anchor * pace
		e["race_time"] = anchor * pace * float(e["race_mult"]) * RACE_INFLATION * float(laps)
	# Your grid slot = your rank among the qual times (1 = pole). A DNF (INF) sorts you last.
	var faster := 0
	for e in field:
		if float(e["qual"]) < player_qual:
			faster += 1
	player_grid = faster + 1
	phase = PHASE_RACE

## Order-panel rows for the QUALIFYING HUD: rivals' provisional times + your live best, best-first.
func qual_standings(player_live: float) -> Array:
	return _rows_by_time(player_live, "qual")

## Order-panel rows for the RACE HUD: rivals by simulated finish time + you by a projected finish
## (INF before your first lap completes), best-first.
func race_standings(player_proj: float) -> Array:
	return _rows_by_time(player_proj, "race_time")

## The grid, pole-first: each {name, time, place, player}. Used by the GP hub and the race's opening board.
func grid() -> Array:
	var rows := _rows_by_time(player_qual, "qual")
	for i in rows.size():
		rows[i]["place"] = i + 1
	return rows

## Rivals ordered by grid slot (pole-first), for physically lining up the start (player excluded).
func grid_rivals() -> Array:
	var sorted := field.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["qual"]) < float(b["qual"]))
	return sorted

## Rivals' simulated finish times (seconds), for scoring your place (RaceResult.compute).
func rival_race_times() -> Array:
	var out: Array = []
	for e in field:
		out.append(float(e["race_time"]))
	return out

# Build best-first standings rows from the rivals' `key` time plus a YOU row at `player_time`.
func _rows_by_time(player_time: float, key: String) -> Array:
	var rows: Array = []
	for e in field:
		rows.append({"name": _name(e), "t": float(e[key]), "player": false})
	rows.append({"name": "YOU", "t": player_time, "player": true})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	var out: Array = []
	for r in rows:
		out.append({"name": r["name"], "time": _fmt(float(r["t"])), "player": bool(r["player"])})
	return out

func _name(e: Dictionary) -> String:
	return (e["driver"] as DriverDef).hud

func _fmt(t: float) -> String:
	if t >= INF or t <= 0.0:
		return "--:--"
	var m := int(t) / 60
	return "%d:%05.2f" % [m, t - m * 60]
