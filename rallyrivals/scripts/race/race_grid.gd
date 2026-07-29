class_name RaceGrid
extends RefCounted
## The live field for an OPEN race — circuit, sprint, endurance (code-race-grid). Takes the assembled
## field (RaceField: N drivers in the race's class band, each a real (brand, class) car) and gives every
## rival a SIMULATED finish time, so a solo drive becomes a graded race: physical cars to dice with, a
## live running order, and a real finishing place.
##
## Per the field-matching spec, a rival's pace is a property of the RACE, resolved BEFORE the lights and
## independent of the player: it comes from the rival's CLASS (a faster class = a faster reference lap)
## plus a FIXED per-driver skill (seeded by racing number). Nothing here reacts to the player's car or
## mid-race position — bringing a stronger car simply makes YOUR real laps quicker than the band's times
## (a walkover you earned); bringing a weaker one means you lose. The field never scales to meet you.
##
## Grand prix is NOT this — it runs its own qualifying-set grid (GrandPrix). Time trial fields nobody.
##
## The physical rivals drive the AiLine at the base RivalDriver pace (uniform for now; per-class driving
## pace is code-ai-difficulty). Their SCORED time is the simulated one, so the placing is clean and
## band-driven regardless of how the live pack shakes out — the cars are there to race, not to be timed.

# Average lap pace by class, m/s — PLACEHOLDER. These set how fast the band's times are; the real,
# per-track-calibrated numbers are balance-difficulty-pacing's. Bump the whole table if rivals feel
# uniformly too fast/slow on a track. ~2 m/s per class so a better car clearly out-runs a lower band.
const CLASS_SPEED := {"D": 21.0, "C": 23.0, "B": 25.0, "A": 27.0, "S": 29.0}
const FALLBACK_SPEED := 22.0
const SKILL_SPREAD := 0.06     ## ±6% per-driver skill, fixed at build (seeded) — spec allows fixed pace variety, never player-reactive
const RACE_INFLATION := 1.03   ## a real lap runs a touch slower than the ideal-line length / speed estimate

var field: Array = []          ## [{driver: DriverDef, car: CarDef, car_class, race_time}], fastest-first

## Build the field's simulated times. `ai_length` is the racing line's baked length (m); `stages` is the
## number of scored passes (laps on a loop, 1 for a point-to-point sprint). Returns null-safe empty grid
## when the race fields nobody.
static func build(race: RaceDef, chapter: int, ai_length: float, stages: int) -> RaceGrid:
	var g := RaceGrid.new()
	if race == null or ai_length <= 1.0:
		return g
	var passes := maxi(stages, 1)
	for e in RaceField.assemble(race, chapter):
		var cls: String = e["car_class"]
		var rng := RandomNumberGenerator.new()
		rng.seed = (e["driver"] as DriverDef).number * 2654435761        # stable skill per driver
		var speed: float = float(CLASS_SPEED.get(cls, FALLBACK_SPEED))
		speed *= 1.0 + rng.randf_range(-SKILL_SPREAD, SKILL_SPREAD)      # fixed skill, set before GO
		var lap := (ai_length / maxf(speed, 1.0)) * RACE_INFLATION
		g.field.append({
			"driver": e["driver"], "car": e["car"], "car_class": cls, "race_time": lap * float(passes),
		})
	g.field.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["race_time"]) < float(b["race_time"]))
	return g

func size() -> int:
	return field.size()

## The rivals in grid order (fastest-first), for lining them up physically ahead of the player.
func entries() -> Array:
	return field

## Rivals' simulated finish times (seconds), for scoring your place (RaceResult.compute).
func rival_race_times() -> Array:
	var out: Array = []
	for e in field:
		out.append(float(e["race_time"]))
	return out

## Live running order for the HUD: rivals at their finish times + you by a projected total, as gaps to
## the leader (shared with grand prix via FieldStandings).
func race_standings(player_proj: float) -> Array:
	return FieldStandings.gap_rows(field, player_proj, "race_time")
