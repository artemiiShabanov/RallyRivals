extends Node
## Save system (autoloaded as "Save"). Three career slots on disk (user://saves/slot_N.json), one
## active SaveProfile in memory. Screens read/write through here: the title enables "Continue" via
## has_any(); the slot-select screen lists summaries and runs new_game/load/delete; the career hub
## and results write() after changes. Settings are NOT here — those live in a separate config
## (code-core-settings-apply); this owns career progress only.

const SLOTS := 3
const DIR := "user://saves"
const STARTER_CAR := "kerb"        ## battered D-class Apex — the free starter (GDD §8)

var active: SaveProfile            ## the loaded slot, or null on the menus

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))

func _path(slot: int) -> String:
	return "%s/slot_%d.json" % [DIR, slot]

func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(_path(slot))

func has_any() -> bool:
	return not occupied_slots().is_empty()

## Slot indices that hold a save, in order.
func occupied_slots() -> Array:
	var out: Array = []
	for i in SLOTS:
		if slot_exists(i):
			out.append(i)
	return out

## Start a fresh career in the slot (overwrites any existing), grant the starter car, persist, and
## make it active. Returns the new profile.
func new_game(slot: int) -> SaveProfile:
	var now := int(Time.get_unix_time_from_system())
	var p := SaveProfile.new()
	p.slot = slot
	p.money = 0
	p.cp = 0
	p.owned_cars = PackedStringArray([STARTER_CAR])
	p.current_car = STARTER_CAR
	p.created_unix = now
	p.played_unix = now
	active = p
	write()
	return p

## Load a slot into `active`. Returns false if the file is missing or corrupt.
func load_slot(slot: int) -> bool:
	if not slot_exists(slot):
		return false
	var f := FileAccess.open(_path(slot), FileAccess.READ)
	if f == null:
		push_error("Save.load_slot: cannot open %s" % _path(slot))
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Save.load_slot: slot %d is not valid JSON" % slot)
		return false
	active = SaveProfile.from_dict(parsed)
	active.slot = slot          # trust the filename over stored slot
	return true

## Persist the active profile to its slot. Returns success.
func write() -> bool:
	if active == null:
		push_error("Save.write: no active profile")
		return false
	active.played_unix = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(_path(active.slot), FileAccess.WRITE)
	if f == null:
		push_error("Save.write: cannot write %s" % _path(active.slot))
		return false
	f.store_string(JSON.stringify(active.to_dict(), "\t"))
	f.close()
	return true

func delete_slot(slot: int) -> void:
	if slot_exists(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(slot)))
	if active != null and active.slot == slot:
		active = null

## Lightweight per-slot info for the slot-select screen (no full load). Always returns SLOTS entries.
func summaries() -> Array:
	var out: Array = []
	for i in SLOTS:
		out.append(_summary(i))
	return out

func _summary(slot: int) -> Dictionary:
	if not slot_exists(slot):
		return {"slot": slot, "exists": false}
	var f := FileAccess.open(_path(slot), FileAccess.READ)
	var parsed: Variant = f.get_as_text() if f != null else ""
	if f != null:
		parsed = JSON.parse_string(parsed)
		f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"slot": slot, "exists": true, "corrupt": true}
	var d: Dictionary = parsed
	return {
		"slot": slot,
		"exists": true,
		"money": int(d.get("money", 0)),
		"cp": int(d.get("cp", 0)),
		"cars": Array(d.get("owned_cars", [])).size(),
		"current_car": String(d.get("current_car", "")),
		"played_unix": int(d.get("played_unix", 0)),
	}
