class_name FieldStandings
extends RefCounted
## Shared HUD running-order builder for any simulated field — grand prix (GrandPrix) and open races
## (RaceGrid) both render through here, so the live order reads the same everywhere. Rows are best-first
## and show GAP TO THE LEADER (P1 = "LEADER", the rest "+gap"), which is how you actually read a race:
## you watch the gap grow or shrink, not an absolute clock.

## Best-first rows {name, time, player} for set_standings(). `entries` are field entries carrying a
## DriverDef under "driver" and a finish time under `time_key`; `player_time` is your projected total
## (INF = not on the board yet → shown last as "--:--").
static func gap_rows(entries: Array, player_time: float, time_key: String) -> Array:
	var rows: Array = []
	for e in entries:
		rows.append({"name": (e["driver"] as DriverDef).hud, "t": float(e[time_key]), "player": false})
	rows.append({"name": "YOU", "t": player_time, "player": true})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
	var leader: float = float(rows[0]["t"]) if not rows.is_empty() else 0.0
	var out: Array = []
	for i in rows.size():
		var t: float = float(rows[i]["t"])
		var label := "--:--"
		if t < INF:
			label = "LEADER" if i == 0 else gap(t - leader)
		out.append({"name": rows[i]["name"], "time": label, "player": bool(rows[i]["player"])})
	return out

## A leader gap: "+2.4" under a minute, "+1:03.20" beyond it.
static func gap(delta: float) -> String:
	if delta <= 0.0:
		return "+0.0"
	if delta < 60.0:
		return "+%.1f" % delta
	var m := int(delta) / 60
	return "+%d:%05.2f" % [m, delta - m * 60]
