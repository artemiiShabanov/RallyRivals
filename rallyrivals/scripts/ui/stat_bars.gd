class_name StatBars
extends VBoxContainer
## The five fixed stat bars (GDD §4) for a CarDef — speed / accel / steering / braking / grip as
## 1-10 segmented pips. Read-only; the whole point is instant car comparison, so it's reused by the
## pre-race screen now and the garage/shop later. Call set_car() to (re)populate.

const STATS := [["SPEED", "speed"], ["ACCEL", "accel"], ["STEER", "steering"], ["BRAKE", "braking"], ["GRIP", "grip"]]
const PIPS := 10
const FILLED := Color(0.95, 0.97, 1.0)   # white — same OSD ink as the theme
const EMPTY := Color(0.05, 0.11, 0.60)   # recessed blue

func _init() -> void:
	add_theme_constant_override("separation", 6)

func set_car(def: CarDef) -> void:
	for c in get_children():
		c.queue_free()
	if def == null:
		return
	for pair in STATS:
		add_child(_row(pair[0], int(def.get(pair[1]))))

func _row(label: String, value: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	# Smaller label so a five-row block stays compact (DotGothic is tall at 720p); pips carry the read.
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(110, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	pips.size_flags_vertical = SIZE_SHRINK_CENTER
	for i in PIPS:
		var cell := ColorRect.new()
		cell.custom_minimum_size = Vector2(20, 18)
		cell.color = FILLED if i < value else EMPTY
		pips.add_child(cell)
	row.add_child(pips)
	return row
