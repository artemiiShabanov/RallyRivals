class_name Campaign
extends RefCounted
## The campaign's races, by chapter (feeds code-ui-career-map + code-meta-chapters). PLACEHOLDER content
## until content-tracks-campaign authors the real region sets: each chapter is the SAME race ten times
## (distinct ids, so each banks its own best + CP) plus the chapter's 1v1 boss duel. That's enough to
## populate the map, exercise the CP gate, and play the full loop end to end; the real varied set
## (sprints, TT, endurance, 2 GP, per CAMPAIGN.md) drops in here later without touching the map or gate.
##
## Built once in code (deterministic — no .tres to author/churn) and cached by id. The class band widens
## by chapter per CAMPAIGN.md's mix (Ch1 D–C … Ch4 A–S), so the field difficulty climbs with the region.
## Reward pools are placeholders — balance-economy-tables / balance-difficulty-pacing own real numbers.

const CHAPTERS := 4
const PER_CHAPTER := 10
const TRACK := "res://assets/tracks/test/baked_track.tscn"        ## loop track for the circuit races
const BOSS_TRACK := "res://assets/tracks/track 1/baked_track.tscn"  ## point-to-point for the sprint duel
const CP_POOL := 15           ## per-race CP pool (1st place); chapter total = 10× this feeds the boss gate
const MONEY_POOL := 500       ## per-race money pool (1st place)

# Per chapter: class band (CAMPAIGN.md mix, as low..high) + conditions (the moment) + region (the
# biome — code-track-regions, 1:1 with chapter, applied as a runtime reskin by RegionSkin).
const CH := [
	{low = "D", high = "C", light = "golden", weather = "clear", region = "backwoods"},
	{low = "D", high = "B", light = "day", weather = "clear", region = "dunes"},
	{low = "D", high = "A", light = "night", weather = "clear", region = "quarry"},
	{low = "A", high = "S", light = "golden", weather = "thunder", region = "alpine"},
]

static var _races := {}       # id -> RaceDef (all chapters' races + bosses)
static var _built := false

# --- public ---

## The chapter's ten race tiles (0-based chapter, clamped), in map order.
static func chapter_races(chapter: int) -> Array:
	_ensure()
	var ch := clampi(chapter, 0, CHAPTERS - 1)
	var out: Array = []
	for m in PER_CHAPTER:
		out.append(_races["c%d_r%d" % [ch + 1, m + 1]])
	return out

## The chapter's boss duel RaceDef (a 1v1 sprint; boss_chapter set — code-ai-boss).
static func boss_race(chapter: int) -> RaceDef:
	_ensure()
	return _races["c%d_boss" % (clampi(chapter, 0, CHAPTERS - 1) + 1)]

## A campaign RaceDef by id, or null if the id isn't part of the placeholder campaign (e.g. a test def).
static func by_id(id: String) -> RaceDef:
	_ensure()
	return _races.get(id, null)

## Total CP available in the chapter's races — the denominator the boss gate takes ~70% of.
static func chapter_cp_total(chapter: int) -> int:
	var total := 0
	for r in chapter_races(chapter):
		total += (r as RaceDef).cp_pool
	return total

# --- build (once) ---

static func _ensure() -> void:
	if _built:
		return
	_built = true
	for ch in CHAPTERS:
		var c: Dictionary = CH[ch]
		for m in PER_CHAPTER:
			var r := RaceDef.new()
			r.id = "c%d_r%d" % [ch + 1, m + 1]
			r.display_name = "Chapter %d — Race %d" % [ch + 1, m + 1]
			r.track_scene = TRACK
			r.race_type = "circuit"
			r.laps = 3
			r.class_low = c["low"]
			r.class_high = c["high"]
			r.money_pool = MONEY_POOL
			r.cp_pool = CP_POOL
			_conditions(r, c)
			_races[r.id] = r
		var b := RaceDef.new()
		b.id = "c%d_boss" % (ch + 1)
		b.display_name = "Chapter %d — Boss: %s" % [ch + 1, BossDef.for_chapter(ch).hud]
		b.track_scene = BOSS_TRACK
		b.race_type = "sprint"
		b.culture = "wilds"          # bump the boss freely (rattles the brittle ones); the AI never rams back
		b.boss_chapter = ch + 1
		_conditions(b, c)
		_races[b.id] = b

static func _conditions(r: RaceDef, c: Dictionary) -> void:
	r.lighting = load("res://assets/lighting/%s.tres" % c["light"]) as LightingPreset
	r.weather = load("res://assets/weather/%s.tres" % c["weather"]) as WeatherPreset
	r.region = load("res://assets/regions/%s.tres" % c["region"]) as Resource   # biome reskin (code-track-regions)
