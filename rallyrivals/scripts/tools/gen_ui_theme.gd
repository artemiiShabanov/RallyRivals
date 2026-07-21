extends SceneTree
## Builds the shared UI theme (art-ui-theme): assets/ui/theme.tres, set as the project default so
## every Control picks it up. Arcade-retro — hard-edged panels, thick palette borders, heavy text
## outlines, bold flat buttons. Colours are the master palette (ADR-003), so UI and world match.
##
## Font: loads the first .ttf/.otf in assets/fonts/ (see that folder's README). Falls back to the
## engine default until one is dropped, so the UI works meanwhile — re-run this after adding a font.
## Run: godot --headless --script res://scripts/tools/gen_ui_theme.gd

const OUT := "res://assets/ui/theme.tres"
const FONTS := "res://assets/fonts/"

# master palette
const INK := Color(0.05, 0.05, 0.07)          # near-black base
const PANEL := Color(0.08, 0.08, 0.11, 0.90)  # panel fill
const CREAM := Color(0.95, 0.92, 0.85)        # primary text
const SULPHUR := Color("f5f5b8")              # identity yellow — headline/values
const CARMINE := Color("a10b2b")              # identity red — danger/accent
const GOLD := Color(0.82, 0.68, 0.38)         # borders, rewards
const SAGE := Color(0.55, 0.80, 0.55)         # positive

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/"))
	var t := Theme.new()

	var font := _find_font()
	if font != null:
		t.default_font = font
	t.default_font_size = 18
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", "Label", 6)

	# --- Panels ---
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, GOLD, 3))
	t.set_stylebox("panel", "Panel", _box(PANEL, GOLD, 3))

	# --- Buttons: bold flat, invert on hover/press (arcade feel) ---
	t.set_stylebox("normal", "Button", _box(Color(0.11, 0.11, 0.15, 0.95), GOLD, 3))
	t.set_stylebox("hover", "Button", _box(GOLD, SULPHUR, 3))
	t.set_stylebox("pressed", "Button", _box(SULPHUR, GOLD, 3))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), SULPHUR, 2))
	t.set_stylebox("disabled", "Button", _box(Color(0.10, 0.10, 0.12, 0.7), Color(0.3, 0.3, 0.3), 2))
	t.set_color("font_color", "Button", SULPHUR)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", "Button", 4)
	t.set_font_size("font_size", "Button", 22)

	# --- ProgressBar (fuel/nitro/health later) ---
	t.set_stylebox("background", "ProgressBar", _box(Color(0.04, 0.04, 0.06, 0.9), GOLD, 2))
	t.set_stylebox("fill", "ProgressBar", _box(SULPHUR, SULPHUR, 0))

	# --- HUD label variations (base type Label) ---
	_variation(t, "HudValue", 68, SULPHUR, 8)     # the big speed number
	_variation(t, "HudUnit", 20, CREAM, 5)        # KM/H
	_variation(t, "HudTimer", 44, CREAM, 7)       # running time
	_variation(t, "HudBest", 18, GOLD, 4)         # best time
	_variation(t, "HudTag", 28, SULPHUR, 6)       # LAP / POS labels
	_variation(t, "HudSplit", 32, CREAM, 7)       # checkpoint split popup
	# Panel variations for tinting the accent border per corner.
	t.set_type_variation("HudPanel", "PanelContainer")
	t.set_stylebox("panel", "HudPanel", _box(PANEL, GOLD, 3))
	t.set_type_variation("HudPanelHot", "PanelContainer")
	t.set_stylebox("panel", "HudPanelHot", _box(PANEL, CARMINE, 3))

	ResourceSaver.save(t, OUT)
	_set_project_default()
	print("theme -> %s   font: %s" % [OUT, font.resource_path if font != null else "(default fallback)"])
	quit()

func _find_font() -> FontFile:
	var da := DirAccess.open(FONTS)
	if da != null:
		for f in da.get_files():
			if f.get_extension().to_lower() in ["ttf", "otf"]:
				var fnt := load(FONTS + f)
				if fnt is FontFile:
					return fnt
	return null

# Hard-edged filled box with a thick border — the chunky arcade panel.
func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(0)           # blocky, no rounding
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _variation(t: Theme, name: String, size: int, color: Color, outline: int) -> void:
	t.set_type_variation(name, "Label")
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)
	t.set_color("font_outline_color", name, Color(0, 0, 0, 0.9))
	t.set_constant("outline_size", name, outline)

func _set_project_default() -> void:
	ProjectSettings.set_setting("gui/theme/custom", OUT)
	ProjectSettings.save()
