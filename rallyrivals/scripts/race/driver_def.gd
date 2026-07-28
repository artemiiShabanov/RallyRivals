class_name DriverDef
extends RefCounted
## One generated chapter rival (field-matching spec §3, ROSTER.md). An identity, not a character: a
## name, a campaign-unique number, a brand, and a behaviour tag. No dialogue/story (GDD §6). Built by
## Roster (deterministic per save) and persisted as a plain dict inside SaveProfile; the field draw
## (RaceField) turns a driver + an assigned class into a concrete car via (brand, class).
##
## `hud` is the surname — the leaderboard only fits one word (matches the bosses: DRAGO, MERCER…);
## `name` is the full name for anywhere with room. `behaviour` is a tag whose SET is defined by the AI
## work (code-ai-difficulty), not here — carried as an opaque string for now.

var name := ""          ## full name, e.g. "Kai Thorne"
var hud := ""           ## surname (the leaderboard/HUD name), e.g. "Thorne"
var number := 0         ## racing number, campaign-unique (1–100, minus boss + player plates)
var brand := ""         ## apex | wreck | mayfly (matches CarDef.brand)
var behaviour := ""     ## AI behaviour tag (set owned by code-ai-difficulty; "" for now)

static func make(full: String, surname: String, num: int, brnd: String, behav := "") -> DriverDef:
	var d := DriverDef.new()
	d.name = full; d.hud = surname; d.number = num; d.brand = brnd; d.behaviour = behav
	return d

func to_dict() -> Dictionary:
	return {"name": name, "hud": hud, "number": number, "brand": brand, "behaviour": behaviour}

static func from_dict(d: Dictionary) -> DriverDef:
	return make(String(d.get("name", "")), String(d.get("hud", "")), int(d.get("number", 0)),
		String(d.get("brand", "")), String(d.get("behaviour", "")))
