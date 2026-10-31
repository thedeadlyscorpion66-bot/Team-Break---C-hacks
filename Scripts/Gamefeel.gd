class_name GameFeel
 
 
 
static func hitstop(node: Node, duration: float = 0.08, scale: float = 0.04) -> void:
	
	if node == null or not node.is_inside_tree():
		return
 
	# Don't stack freezes - a second hit during a freeze would multiply.
	if Engine.time_scale < 1.0:
		return
 
	Engine.time_scale = scale
	await node.get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
 
 
static func flash(sprite: CanvasItem, color: Color = Color(1, 0.3, 0.3, 1),
		hold: float = 0.06, fade: float = 0.18) -> void:
	
	if sprite == null or not sprite.is_inside_tree():
		return
	var t := sprite.create_tween()
	t.tween_property(sprite, "modulate", color, 0.02)
	t.tween_interval(hold)
	t.tween_property(sprite, "modulate", Color.WHITE, fade)
 
 
static func shake(camera: Camera2D, strength: float = 6.0,
		duration: float = 0.18) -> void:
	
	if camera == null or not camera.is_inside_tree():
		return
	var original := camera.offset
	var steps := 6
	var t := camera.create_tween()
	for i in steps:
		var falloff := 1.0 - (float(i) / float(steps))
		var off := Vector2(
			randf_range(-strength, strength) * falloff,
			randf_range(-strength, strength) * falloff
		)
		t.tween_property(camera, "offset", original + off, duration / steps)
	t.tween_property(camera, "offset", original, duration / steps)
