extends SceneTree
## Builds the shared UI theme (art-ui-theme): assets/ui/theme.tres, set as the project default.
## TWO registers, per the broadcast pivot (GDD §9):
##   - CHROME (menus/meta): white-on-blue VCR-OSD / teletext — hard blue fields, white text, an
##     inverted white-field highlight on the selected item. Panels, buttons, inputs, sliders.
##   - TELEMETRY (the in-race HUD): the Hud* label variations + HudPanel styleboxes stay a CLEAN
##     white-on-dark scorebug, NOT the blue chrome — so the scorebug reads as broadcast graphics
##     over the footage, not a menu. (Restyle proper is code-ui-scorebug.)
## Font: first .ttf/.otf in assets/fonts/ (README there), else the engine default.
## Run: godot --headless --script res://scripts/tools/gen_ui_theme.gd

const OUT := "res://assets/ui/theme.tres"
const FONTS := "res://assets/fonts/"

# --- VCR-OSD chrome palette ---
const BLUE := Color(0.09, 0.12, 0.58)      # the OSD field
const BLUE_DK := Color(0.04, 0.06, 0.34)   # recessed field (inputs, tracks)
const WHITE := Color(0.95, 0.97, 1.0)      # text
const CYAN := Color(0.45, 0.90, 0.98)      # teletext accent (secondary text)
const YELLOW := Color(0.98, 0.92, 0.38)    # teletext accent (headings/values)
const DIM := Color(0.55, 0.62, 0.88)       # disabled / secondary
const SEL_FG := Color(0.05, 0.08, 0.42)    # text on the white highlight
# --- telemetry (scorebug) palette ---
const TELE_DARK := Color(0.02, 0.02, 0.04, 0.68)
const RED := Color("a10b2b")

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/"))
	var t := Theme.new()
	var font := _find_font()
	if font != null:
		t.default_font = font
	t.default_font_size = 20

	# --- base Label (chrome text) ---
	t.set_color("font_color", "Label", WHITE)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.5))
	t.set_constant("outline_size", "Label", 3)   # thin — legibility over the tape grain

	# --- Panels: hard blue field, thin white box outline (the OSD "window") ---
	t.set_stylebox("panel", "PanelContainer", _box(BLUE, WHITE, 2))
	t.set_stylebox("panel", "Panel", _box(BLUE, WHITE, 2))

	# --- Buttons: OSD menu items. Idle = recessed field; hover/focus/press = inverted white bar ---
	var sel := _box(WHITE, WHITE, 2)
	t.set_stylebox("normal", "Button", _box(BLUE_DK, WHITE, 2))
	t.set_stylebox("hover", "Button", sel)
	t.set_stylebox("pressed", "Button", sel)
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), YELLOW, 2))
	t.set_stylebox("disabled", "Button", _box(BLUE_DK.darkened(0.3), DIM, 1))
	t.set_color("font_color", "Button", WHITE)
	t.set_color("font_hover_color", "Button", SEL_FG)
	t.set_color("font_pressed_color", "Button", SEL_FG)
	t.set_color("font_focus_color", "Button", WHITE)
	t.set_color("font_disabled_color", "Button", DIM)
	t.set_font_size("font_size", "Button", 22)

	# OptionButton mirrors Button.
	for s in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(s, "OptionButton", t.get_stylebox(s, "Button"))
	t.set_color("font_color", "OptionButton", WHITE)
	t.set_color("font_hover_color", "OptionButton", SEL_FG)

	# --- LineEdit (settings fields / rename) ---
	t.set_stylebox("normal", "LineEdit", _box(BLUE_DK, WHITE, 2))
	t.set_stylebox("focus", "LineEdit", _box(BLUE_DK, YELLOW, 2))
	t.set_color("font_color", "LineEdit", WHITE)
	t.set_color("font_placeholder_color", "LineEdit", DIM)
	t.set_color("caret_color", "LineEdit", YELLOW)
	t.set_color("selection_color", "LineEdit", CYAN * Color(1, 1, 1, 0.4))

	# --- CheckBox ---
	t.set_color("font_color", "CheckBox", WHITE)
	t.set_color("font_hover_color", "CheckBox", CYAN)
	t.set_color("font_pressed_color", "CheckBox", CYAN)
	t.set_color("font_disabled_color", "CheckBox", DIM)

	# --- HSlider (settings, incl. the VHS-intensity dial) ---
	t.set_stylebox("slider", "HSlider", _bar(BLUE_DK, WHITE))
	t.set_stylebox("grabber_area", "HSlider", _bar(WHITE, WHITE))
	t.set_stylebox("grabber_area_highlight", "HSlider", _bar(YELLOW, YELLOW))

	# --- ProgressBar ---
	t.set_stylebox("background", "ProgressBar", _box(BLUE_DK, WHITE, 2))
	t.set_stylebox("fill", "ProgressBar", _box(WHITE, WHITE, 0))
	t.set_color("font_color", "ProgressBar", WHITE)

	# --- chrome label variations ---
	_var(t, "OsdTitle", 40, YELLOW, 4)
	_var(t, "OsdHead", 26, CYAN, 3)
	_var(t, "OsdDim", 18, DIM, 2)

	# --- telemetry / scorebug register (clean white-on-dark, NOT blue) ---
	_var(t, "HudValue", 68, WHITE, 8)
	_var(t, "HudUnit", 20, WHITE, 5)
	_var(t, "HudTimer", 44, WHITE, 7)
	_var(t, "HudBest", 18, YELLOW, 4)
	_var(t, "HudTag", 28, WHITE, 6)
	_var(t, "HudSplit", 32, WHITE, 7)
	t.set_type_variation("HudPanel", "PanelContainer")
	t.set_stylebox("panel", "HudPanel", _box(TELE_DARK, WHITE, 2))
	t.set_type_variation("HudPanelHot", "PanelContainer")
	t.set_stylebox("panel", "HudPanelHot", _box(TELE_DARK, RED, 2))

	ResourceSaver.save(t, OUT)
	_set_project_default()
	print("VHS-OSD theme -> %s   font: %s" % [OUT, font.resource_path if font != null else "(default fallback)"])
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

# Hard-edged filled box with a thin border — the OSD window / menu item.
func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	return sb

# Slim bar for slider tracks/fills.
func _bar(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(0)
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb

func _var(t: Theme, name: String, size: int, color: Color, outline: int) -> void:
	t.set_type_variation(name, "Label")
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)
	t.set_color("font_outline_color", name, Color(0, 0, 0, 0.6))
	t.set_constant("outline_size", name, outline)

func _set_project_default() -> void:
	ProjectSettings.set_setting("gui/theme/custom", OUT)
	ProjectSettings.save()
