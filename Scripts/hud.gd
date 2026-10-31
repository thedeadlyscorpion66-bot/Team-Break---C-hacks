extends CanvasLayer
class_name HUD


@export var bar_width: float = 260.0
@export var bar_height: float = 22.0
@export var margin: float = 18.0

@export var pixel_font: Font
@export var space_width: int = 4
@export var title_scene: String = "res://Scenes/title.tscn"

var _forest_fill: ColorRect
var _forest_label: Label
var _player_fill: ColorRect
var _player_label: Label
var _timer_label: Label
var _best_label: Label
var _kills_label: Label

var _death_root: Control
var _death_title: Label
var _death_time: Label
var _death_best: Label

var _manager: Node = null
var _player: Node = null

var _font_res: Font = null

const GOOD := Color(0.35, 0.80, 0.38)
const WARN := Color(0.93, 0.78, 0.25)
const BAD  := Color(0.88, 0.26, 0.24)


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_prepare_font()
	_build_bars()
	_build_death_screen()
	_build_threat_arrow()

	await get_tree().process_frame
	_connect_up()


func _make_bar(y_from_bottom: float, label_text: String) -> Array:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	root.position = Vector2(margin, -y_from_bottom)
	root.size = Vector2(bar_width, bar_height)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var back := ColorRect.new()
	back.color = Color(0.06, 0.07, 0.08, 0.78)
	back.size = Vector2(bar_width, bar_height)
	back.position = Vector2(-3, -3)
	back.size += Vector2(6, 6)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)

	var fill := ColorRect.new()
	fill.color = GOOD
	fill.size = Vector2(bar_width, bar_height)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fill)

	var lab := Label.new()
	lab.text = label_text
	lab.size = Vector2(bar_width, bar_height)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_color_override("font_color", Color.WHITE)
	lab.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lab.add_theme_constant_override("shadow_offset_x", 1)
	lab.add_theme_constant_override("shadow_offset_y", 1)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(lab, 15)
	root.add_child(lab)

	return [fill, lab]


func _prepare_font() -> void:
	if pixel_font == null:
		_font_res = null
		return
	var fv := FontVariation.new()
	fv.base_font = pixel_font
	fv.spacing_space = space_width
	_font_res = fv


func _apply_font(node: Control, size: int) -> void:
	if _font_res:
		node.add_theme_font_override("font", _font_res)
	node.add_theme_font_size_override("font_size", size)


func _build_bars() -> void:
	var p := _make_bar(margin + bar_height, "HEALTH")
	_player_fill = p[0]
	_player_label = p[1]

	var f := _make_bar(margin + bar_height * 2.0 + 14.0, "FOREST")
	_forest_fill = f[0]
	_forest_label = f[1]

	_timer_label = Label.new()
	_timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_timer_label.position = Vector2(-170, margin)
	_timer_label.size = Vector2(150, 30)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_font(_timer_label, 26)
	_timer_label.add_theme_color_override("font_color", Color.WHITE)
	_timer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_timer_label.add_theme_constant_override("shadow_offset_x", 2)
	_timer_label.add_theme_constant_override("shadow_offset_y", 2)
	_timer_label.text = "0:00"
	_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_timer_label)

	_best_label = Label.new()
	_best_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_best_label.position = Vector2(-170, margin + 30)
	_best_label.size = Vector2(150, 24)
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_font(_best_label, 15)
	_best_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.85))
	_best_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_best_label.add_theme_constant_override("shadow_offset_x", 1)
	_best_label.add_theme_constant_override("shadow_offset_y", 1)
	_best_label.text = "BEST 0:00"
	_best_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_best_label)

	_kills_label = Label.new()
	_kills_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_kills_label.position = Vector2(-170, margin + 52)
	_kills_label.size = Vector2(150, 24)
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_apply_font(_kills_label, 15)
	_kills_label.add_theme_color_override("font_color", Color(0.95, 0.72, 0.35))
	_kills_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_kills_label.add_theme_constant_override("shadow_offset_x", 1)
	_kills_label.add_theme_constant_override("shadow_offset_y", 1)
	_kills_label.text = "LOGGERS 0"
	_kills_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_kills_label)


func _build_threat_arrow() -> void:
	var arrow := ThreatArrow.new()
	add_child(arrow)


func _build_death_screen() -> void:
	_death_root = Control.new()
	_death_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_root.visible = false
	_death_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_death_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.04, 0.82)
	_death_root.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_root.add_child(box)

	_death_title = _centered_label("THE FOREST IS LOST", 38, Color(0.90, 0.30, 0.28))
	box.add_child(_death_title)

	_death_time = _centered_label("You survived 0:00", 20, Color(0.92, 0.93, 0.95))
	box.add_child(_death_time)

	_death_best = _centered_label("", 18, Color(0.98, 0.84, 0.35))
	box.add_child(_death_best)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)

	var btn := Button.new()
	btn.text = "PLAY AGAIN"
	btn.custom_minimum_size = Vector2(190, 48)
	_apply_font(btn, 20)
	btn.pressed.connect(_on_restart)
	row.add_child(btn)

	var menu := Button.new()
	menu.text = "MAIN MENU"
	menu.custom_minimum_size = Vector2(190, 48)
	_apply_font(menu, 20)
	menu.pressed.connect(_on_main_menu)
	row.add_child(menu)

	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(0, 52)
	center.add_child(row)
	box.add_child(center)

	var hint := _centered_label("R to retry   -   ESC for menu", 15,
		Color(0.65, 0.67, 0.70))
	box.add_child(hint)


func _centered_label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(l, size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _connect_up() -> void:
	var ms := get_tree().get_nodes_in_group("game_manager")
	if not ms.is_empty():
		_manager = ms[0]
		_manager.forest_health_changed.connect(_on_forest_changed)
		_manager.survival_time_changed.connect(_on_time_changed)
		_manager.kills_changed.connect(_on_kills_changed)
		_manager.game_over.connect(_on_game_over)
		_best_label.text = "BEST %s / %d" % [
			GameManager.format_time(_manager.high_score), _manager.best_kills]
		_on_forest_changed(_manager.forest_health(), _manager.forest_health_max())

	var ps := get_tree().get_nodes_in_group("player")
	if not ps.is_empty():
		_player = ps[0]
		if _player.has_signal("health_changed"):
			_player.health_changed.connect(_on_player_health)
			_on_player_health(_player.health, _player.max_health)


func _grade(fraction: float) -> Color:
	if fraction > 0.5:
		return WARN.lerp(GOOD, (fraction - 0.5) * 2.0)
	return BAD.lerp(WARN, fraction * 2.0)


func _set_bar(fill: ColorRect, label: Label, title: String,
		current: int, maximum: int) -> void:
	var frac := 0.0
	if maximum > 0:
		frac = clampf(float(current) / float(maximum), 0.0, 1.0)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fill, "size:x", bar_width * frac, 0.22)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(fill, "color", _grade(frac), 0.22)

	label.text = "%s  %d / %d" % [title, current, maximum]


func _on_forest_changed(current: int, maximum: int) -> void:
	_set_bar(_forest_fill, _forest_label, "FOREST", current, maximum)


func _on_player_health(current: int, maximum: int) -> void:
	_set_bar(_player_fill, _player_label, "HEALTH", current, maximum)


func _on_time_changed(seconds: float) -> void:
	_timer_label.text = GameManager.format_time(seconds)


func _on_kills_changed(kills: int) -> void:
	_kills_label.text = "LOGGERS %d" % kills
	_kills_label.scale = Vector2(1.35, 1.35)
	_kills_label.pivot_offset = Vector2(150, 12)
	var tw := create_tween()
	tw.tween_property(_kills_label, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_game_over(survived: float, is_high_score: bool, reason: String) -> void:
	Sfx.play(self, "jingle_gameover.wav", -2.0)
	_death_title.text = reason.to_upper()
	var kills: int = _manager.loggers_killed if _manager else 0
	_death_time.text = "Survived %s   -   %d loggers stopped" % [
		GameManager.format_time(survived), kills]

	if is_high_score:
		_death_best.text = "NEW BEST"
	else:
		var bt: float = _manager.high_score if _manager else 0.0
		var bk: int = _manager.best_kills if _manager else 0
		_death_best.text = "Best  %s  /  %d loggers" % [
			GameManager.format_time(bt), bk]

	_death_root.visible = true
	_death_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_death_root, "modulate:a", 1.0, 0.45)


func _on_restart() -> void:
	if _manager:
		_manager.restart()
	else:
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()


func _on_main_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(title_scene)


func _unhandled_input(event: InputEvent) -> void:
	if not _death_root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_on_restart()
		elif event.keycode == KEY_ESCAPE:
			_on_main_menu()
