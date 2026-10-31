extends Control
class_name ThreatArrow
 
# Blinking red warning that points at any logger currently chopping.
#
# Two behaviours depending on where he is:
#   - OFF SCREEN: an arrow pinned to the screen edge, pointing his way.
#   - ON SCREEN:  a bouncing marker above his head.
#
# Everything is drawn with polygons, so there is no icon to import and
# nothing to go blurry.
#
# The HUD creates this automatically. You don't add it yourself.
 
@export var edge_margin: float = 56.0
@export var blink_speed: float = 7.0
@export var arrow_size: float = 19.0
@export var marker_size: float = 13.0
 
const HOT := Color(1.00, 0.22, 0.16)
const COOL := Color(1.00, 0.62, 0.20)
 
var _t: float = 0.0
 
 
func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
 
 
func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
 
 
func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
 
	var vp := get_viewport_rect().size
	var centre := vp * 0.5
 
	# Pulse between a hot red and an amber, alpha swinging with it.
	var wave := 0.5 + 0.5 * sin(_t * blink_speed)
	var col := HOT.lerp(COOL, wave * 0.5)
	col.a = 0.55 + 0.45 * wave
 
	for w in get_tree().get_nodes_in_group("woodcutters"):
		if not is_instance_valid(w):
			continue
		if not w.has_method("is_chopping") or not w.is_chopping():
			continue
 
		var screen := _world_to_screen(w.global_position, cam, centre)
 
		if _on_screen(screen, vp):
			_draw_marker(screen, col, wave)
		else:
			_draw_edge_arrow(screen, centre, vp, col, wave)
 
 
# ----------------------------------------------------------------- helpers
 
func _world_to_screen(world: Vector2, cam: Camera2D, centre: Vector2) -> Vector2:
	# Camera2D.zoom scales up, so multiplying is correct here.
	return (world - cam.get_screen_center_position()) * cam.zoom + centre
 
 
func _on_screen(p: Vector2, vp: Vector2) -> bool:
	return p.x > edge_margin and p.x < vp.x - edge_margin \
		and p.y > edge_margin and p.y < vp.y - edge_margin
 
 
# ------------------------------------------------------------ on screen
 
func _draw_marker(at: Vector2, col: Color, wave: float) -> void:
	# Bob above his head so it doesn't sit flat on the sprite.
	var bob := sin(_t * 5.0) * 4.0
	var tip := at + Vector2(0, -42.0 + bob)
	var s := marker_size
 
	# Downward triangle pointing at him.
	var tri := PackedVector2Array([
		tip + Vector2(0, s),
		tip + Vector2(-s * 0.8, -s * 0.5),
		tip + Vector2(s * 0.8, -s * 0.5),
	])
	draw_colored_polygon(tri, col)
	_outline(tri, col)
 
	# Exclamation mark inside it.
	var bar := Color(1, 1, 1, col.a)
	draw_line(tip + Vector2(0, -s * 0.30), tip + Vector2(0, s * 0.18), bar, 2.5)
	draw_circle(tip + Vector2(0, s * 0.46), 1.4, bar)
 
	# Expanding ring on the beat - draws the eye without being loud.
	var r := 14.0 + wave * 12.0
	draw_arc(at + Vector2(0, -14), r, 0.0, TAU, 24,
		Color(col.r, col.g, col.b, (1.0 - wave) * 0.5), 2.0, true)
 
 
# ----------------------------------------------------------- off screen
 
func _draw_edge_arrow(target: Vector2, centre: Vector2, vp: Vector2,
		col: Color, wave: float) -> void:
	var dir := (target - centre).normalized()
	if dir == Vector2.ZERO:
		return
 
	# Push out from the centre until we hit the margin box, so the arrow
	# sits on the edge nearest the threat rather than in a corner.
	var half := vp * 0.5 - Vector2(edge_margin, edge_margin)
	var scale_x := half.x / absf(dir.x) if absf(dir.x) > 0.0001 else INF
	var scale_y := half.y / absf(dir.y) if absf(dir.y) > 0.0001 else INF
	var pos := centre + dir * minf(scale_x, scale_y)
 
	# Nudge outward on the pulse so it feels urgent.
	pos += dir * wave * 4.0
 
	var s := arrow_size
	var ang := dir.angle()
 
	var pts := PackedVector2Array([
		pos + Vector2(s, 0).rotated(ang),
		pos + Vector2(-s * 0.7, -s * 0.78).rotated(ang),
		pos + Vector2(-s * 0.25, 0).rotated(ang),
		pos + Vector2(-s * 0.7, s * 0.78).rotated(ang),
	])
	draw_colored_polygon(pts, col)
	_outline(pts, col)
 
	# Soft halo behind it so it reads over bright grass too.
	draw_circle(pos, s * 1.45, Color(col.r, col.g, col.b, 0.14 * col.a))
 
 
func _outline(pts: PackedVector2Array, col: Color) -> void:
	# Dark edge keeps the shape legible on any background.
	var dark := Color(0.15, 0.03, 0.03, col.a)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, dark, 1.6, true)
 
