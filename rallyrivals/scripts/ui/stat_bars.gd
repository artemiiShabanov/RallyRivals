class_name StatBars
extends VBoxContainer
## The five fixed stat bars (GDD §4) for a CarDef — speed / accel / steering / braking / grip as
## 1-10 segmented pips. Read-only; the whole point is instant car comparison, so it's reused by the
## pre-race screen now and the garage/shop later. Call set_car() to (re)populate.

const STATS := [["SPEED", "speed"], ["ACCEL", "accel"], ["STEER", "steering"], ["BRAKE", "braking"], ["GRIP", "grip"]]
const PIPS := 10
const FILLED := Color(0.95, 0.97, 1.0)   # white — same OSD ink as the theme
const EMPTY := Color(0.05, 0.11, 0.60)   # recessed blue

var _cells: Dictionary = {}   # stat field -> Array[ColorRect]

func _init() -> void:
	add_theme_constant_override("separation", 6)

## Update the bars for a car. The row structure is built once (labels are the constant stat names),
## then only the pip COLOURS change — so switching cars never rebuilds children, which would
## invalidate layout and reset a surrounding scroll list.
func set_car(def: CarDef) -> void:
	if _cells.is_empty():
		_build_rows()
	for pair in STATS:
		var value := int(def.get(pair[1])) if def != null else 0
		var cells: Array = _cells[pair[1]]
		for i in cells.size():
			cells[i].color = FILLED if i < value else EMPTY

func _build_rows() -> void:
	for pair in STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := Label.new()
		l.text = pair[0]
		l.custom_minimum_size = Vector2(110, 0)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 3)
		pips.size_flags_vertical = SIZE_SHRINK_CENTER
		var cells: Array = []
		for i in PIPS:
			var cell := ColorRect.new()
			cell.custom_minimum_size = Vector2(20, 18)
			cell.color = EMPTY
			pips.add_child(cell)
			cells.append(cell)
		row.add_child(pips)
		add_child(row)
		_cells[pair[1]] = cells
