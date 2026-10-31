
extends Control
class_name TitleScreen
 
# The start screen. Builds itself in code, same as the HUD - one Control
# node with this script on it and nothing else to wire up.
#
# Draws its own animated backdrop: a dusk gradient, three layers of
# swaying tree silhouettes, and drifting leaves. All polygons and
# circles, so there is no art to import and nothing to go blurry.
 
@export var pixel_font: Font
 
# Many pixel fonts ship a zero-width space glyph, so words run together.
# FontVariation widens just the space without touching anything else.
@export var space_width: int = 4
@export var game_scene: String = "res://Scenes/main.tscn"
@export var title_text: String = "FOREST GUARDIAN"
 
# Drop these if the text overflows on a smaller window.
@export var title_font_size: int = 44
@export var ui_scale: float = 1.0
 
const SAVE_PATH := "user://forest_guardian.cfg"
 
# Dusk-over-forest palette
const SKY_TOP := Color(0.09, 0.14, 0.17)
const SKY_BOT := Color(0.16, 0.28, 0.24)
const HILL_FAR := Color(0.11, 0.21, 0.18)
const HILL_MID := Color(0.08, 0.17, 0.14)
const HILL_NEAR := Color(0.05, 0.11, 0.10)
 
const GOLD := Color(0.84, 0.69, 0.35)
const LEAF := Color(0.42, 0.72, 0.40)
 
var _t: float = 0.0
var _leaves: Array = []       # [pos, speed, drift, size, phase]
var _best_time: float = 0.0
var _best_kills: int = 0
 
var _font_res: Font = null
 
 
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_prepare_font()
	_load_best()
	_seed_leaves()
	_build_ui()
 
 
func _process(delta: float) -> void:
	_t += delta
	_drift_leaves(delta)
	queue_redraw()
 
 
# -------------------------------------------------------------- save data
 
func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	_best_time = float(cfg.get_value("score", "best_time", 0.0))
	_best_kills = int(cfg.get_value("score", "best_kills", 0))
 
 
func _fmt(seconds: float) -> String:
	var m := int(floor(seconds / 60.0))
	var s := int(floor(seconds)) % 60
	return "%d:%02d" % [m, s]
 
 
# ------------------------------------------------------------------- UI
 
func _prepare_font() -> void:
	# Wrap the font so the space glyph can be widened.
	if pixel_font == null:
		_font_res = null
		return
	var fv := FontVariation.new()
	fv.base_font = pixel_font
	fv.spacing_space = space_width
	_font_res = fv
 
 
func _font(node: Control, px: int, col: Color) -> void:
	if _font_res:
		node.add_theme_font_override("font", _font_res)
	node.add_theme_font_size_override("font_size", px)
	node.add_theme_color_override("font_color", col)
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	node.add_theme_constant_override("shadow_offset_x", 3)
	node.add_theme_constant_override("shadow_offset_y", 3)
 
 
func _label(text: String, px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font(l, px, col)
	return l
 
 
func _build_ui() -> void:
	# FULL_RECT rather than a fixed-size box. A hard-coded 640x400 gets
	# clipped the moment the content is taller than it, and on a smaller
	# window the whole thing runs off the edge. Anchored to the screen it
	# always centres and always fits.
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", int(8 * ui_scale))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
 
	var f := func(n: int) -> int: return maxi(8, int(n * ui_scale))
 
	# --- title ---
	box.add_child(_label(title_text, f.call(title_font_size),
		Color(0.93, 0.96, 0.90)))
	box.add_child(_label("- - - - - - - - - - -", f.call(18), GOLD))
	box.add_child(_label("defend what is left", f.call(16),
		Color(0.62, 0.72, 0.64)))
 
	box.add_child(_spacer(int(20 * ui_scale)))
 
	# --- buttons ---
	box.add_child(_button("START GAME", _on_start))
	box.add_child(_button("QUIT", _on_quit))
 
	box.add_child(_spacer(int(18 * ui_scale)))
 
	# --- best run ---
	if _best_time > 0.0:
		box.add_child(_label("BEST RUN", f.call(14), Color(0.56, 0.64, 0.58)))
		box.add_child(_label(
			"%s   -   %d loggers stopped" % [_fmt(_best_time), _best_kills],
			f.call(20), GOLD))
	else:
		box.add_child(_label("no run recorded yet", f.call(14),
			Color(0.48, 0.55, 0.50)))
 
	box.add_child(_spacer(int(8 * ui_scale)))
	box.add_child(_label("ENTER to start", f.call(13),
		Color(0.45, 0.52, 0.47)))
 
 
func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
 
 
func _button(text: String, cb: Callable) -> Control:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(230 * ui_scale, 46 * ui_scale)
	_font(b, maxi(10, int(21 * ui_scale)), Color(0.95, 0.97, 0.93))
	b.pressed.connect(func():
		Sfx.play(self, "sfx_click.wav", -6.0)
		cb.call())
 
	# Flat dark panel with a gold edge - matches the icon, and keeps the
	# default theme's rounded gradient from fighting the pixel look.
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.07, 0.13, 0.11, 0.92)
	normal.border_color = GOLD
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(0)
	b.add_theme_stylebox_override("normal", normal)
 
	var hover := normal.duplicate()
	hover.bg_color = Color(0.13, 0.24, 0.18, 0.96)
	hover.border_color = Color(0.96, 0.82, 0.46)
	b.add_theme_stylebox_override("hover", hover)
 
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.05, 0.09, 0.08, 0.98)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", hover)
 
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 50 * ui_scale)
	holder.add_child(b)
	return holder
 
 
# -------------------------------------------------------------- backdrop
 
func _seed_leaves() -> void:
	for i in 26:
		_leaves.append([
			Vector2(randf() * 1400.0, randf() * 800.0),   # pos
			randf_range(14.0, 34.0),                      # fall speed
			randf_range(10.0, 26.0),                      # sideways drift
			randf_range(1.6, 3.4),                        # size
			randf() * TAU,                                # phase
		])
 
 
func _drift_leaves(delta: float) -> void:
	var vp := get_viewport_rect().size
	for lf in _leaves:
		lf[0].y += lf[1] * delta
		lf[0].x += sin(_t * 0.8 + lf[4]) * lf[2] * delta
		if lf[0].y > vp.y + 10.0:
			lf[0].y = -10.0
			lf[0].x = randf() * vp.x
 
 
func _draw() -> void:
	var vp := get_viewport_rect().size
 
	# Sky gradient, drawn as horizontal bands.
	var bands := 40
	for i in bands:
		var t := float(i) / float(bands - 1)
		var col := SKY_TOP.lerp(SKY_BOT, t)
		draw_rect(Rect2(0, vp.y * t, vp.x, vp.y / bands + 1), col)
 
	# Three layers of treeline, each swaying on its own rhythm so the
	# parallax reads even though nothing actually moves sideways.
	_treeline(vp, vp.y * 0.60, 54.0, 78.0, HILL_FAR, 0.00, 0.55)
	_treeline(vp, vp.y * 0.74, 72.0, 104.0, HILL_MID, 1.30, 0.80)
	_treeline(vp, vp.y * 0.90, 96.0, 142.0, HILL_NEAR, 2.70, 1.10)
 
	# Drifting leaves over the top.
	for lf in _leaves:
		var a := 0.22 + 0.18 * (0.5 + 0.5 * sin(_t * 1.4 + lf[4]))
		draw_circle(lf[0], lf[3], Color(LEAF.r, LEAF.g, LEAF.b, a))
 
	# Soft vignette so the centred text always has contrast behind it.
	draw_rect(Rect2(0, 0, vp.x, 90), Color(0, 0, 0, 0.30))
	draw_rect(Rect2(0, vp.y - 70, vp.x, 70), Color(0, 0, 0, 0.30))
 
 
func _treeline(vp: Vector2, base_y: float, spacing: float, height: float,
		col: Color, phase: float, sway: float) -> void:
	# Ground slab under this layer.
	draw_rect(Rect2(0, base_y, vp.x, vp.y - base_y), col)
 
	var x := -spacing * 0.5
	var i := 0
	while x < vp.x + spacing:
		i += 1
		var h := height * (0.78 + 0.34 * fmod(sin(float(i) * 12.9898 + phase) * 43758.5453, 1.0))
		h = absf(h)
		var w := spacing * 0.46
		var lean := sin(_t * 0.9 + float(i) * 0.7 + phase) * sway
 
		# Simple conifer: three stacked triangles.
		for tier in 3:
			var ty := base_y - h * (0.30 + 0.26 * tier)
			var tw := w * (1.0 - 0.22 * tier)
			var tip := Vector2(x + lean * (1.0 + tier * 0.5), ty - h * 0.30)
			draw_colored_polygon(PackedVector2Array([
				tip,
				Vector2(x - tw, ty + h * 0.10),
				Vector2(x + tw, ty + h * 0.10),
			]), col)
 
		x += spacing
 
 
# ---------------------------------------------------------------- actions
 
func _on_start() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(game_scene)
 
 
func _on_quit() -> void:
	get_tree().quit()
 
 
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER \
				or event.keycode == KEY_SPACE:
			_on_start()
		elif event.keycode == KEY_ESCAPE:
			_on_quit()
 
