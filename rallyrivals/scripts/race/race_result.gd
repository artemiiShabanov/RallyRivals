class_name RaceResult
extends RefCounted
## The outcome of one race for the player (code-race-result): finishing place in the field, the time,
## and whether it was a win (1st). Placing is by finish order — a lower total time places ahead. In
## the skeleton the field is just the player (1 / 1); AI rivals join once code-ai-rival lands and
## their finish times feed compute(). Placing is lenient by design — every place pays (GDD §5); this
## only records where you came, not whether you're allowed to progress.

var race_id := ""
var place := 1
var field_size := 1
var total_time := 0.0
var laps: Array = []
var best_lap := INF
var finished := true

func is_win() -> bool:
	return place == 1

## Build the player's result from their finish and the rivals' finish times (seconds; INF = DNF,
## which sorts last). A rival strictly faster than the player pushes the player's place back one.
static func compute(rid: String, player_time: float, lap_times: Array, best: float, rival_times: Array = []) -> RaceResult:
	var r := RaceResult.new()
	r.race_id = rid
	r.total_time = player_time
	r.laps = lap_times
	r.best_lap = best
	r.field_size = 1 + rival_times.size()
	var place := 1
	for t in rival_times:
		if float(t) < player_time:
			place += 1
	r.place = place
	return r
