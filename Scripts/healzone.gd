extends Node2D
class_name HealZone
 
 
signal healing_started
signal healing_stopped
 
@export var radius: float = 72.0
@export var heal_per_second: float = 14.0
@export var show_zone: bool = true           # soft ring so players see it
@export var zone_color: Color = Color(0.35, 0.95, 0.45, 1.0)
 
var _accum: float = 0.0
var _healing: bool = false
var _pulse: float = 0.0
 
 
func _ready() -> void:
	add_to_group("heal_zones")
 
 
func _process(delta: float) -> void:
	_pulse += delta
	if show_zone:
		queue_redraw()
 
	var p := _find_player()
	if p == null:
		_set_healing(false)
		return
 
	if p.has_method("is_alive") and not p.is_alive():
		_set_healing(false)
		return
 
	var inside := global_position.distance_to(p.global_position) <= radius
 
	# Already full? Stand there all you like, nothing happens.
	if inside and "health" in p and "max_health" in p and p.health >= p.max_health:
		_set_healing(false)
		return
 
	_set_healing(inside)
	if not inside:
		_accum = 0.0
		return
 
	
	_accum += heal_per_second * delta
	if _accum >= 1.0:
		var amount := int(_accum)
		_accum -= float(amount)
		if p.has_method("heal"):
			p.heal(amount)
			_spark()
 
 
func _set_healing(on: bool) -> void:
	if on == _healing:
		return
	_healing = on
 
	# Tint the player green for as long as they're topping up.
	var p := _find_player()
	if p and p.has_method("set_healing"):
		p.set_healing(on)
 
	if on:
		healing_started.emit()
	else:
		healing_stopped.emit()
 
 
# ----------------------------------------------------------------- visual
 
func _draw() -> void:
	if not show_zone:
		return
 
	
	var speed := 4.0 if _healing else 1.6
	var breathe := 0.5 + 0.5 * sin(_pulse * speed)
 
	var fill_a := (0.07 + 0.06 * breathe) if not _healing else (0.14 + 0.10 * breathe)
	var ring_a := (0.30 + 0.15 * breathe) if not _healing else (0.65 + 0.35 * breathe)
 
	draw_circle(Vector2.ZERO, radius, Color(zone_color.r, zone_color.g, zone_color.b, fill_a))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48,
		Color(zone_color.r, zone_color.g, zone_color.b, ring_a), 2.0, true)
 
	
	if _healing:
		var inner := radius * (1.0 - fmod(_pulse * 0.6, 1.0))
		draw_arc(Vector2.ZERO, inner, 0.0, TAU, 40,
			Color(zone_color.r, zone_color.g, zone_color.b, 0.45), 1.5, true)
 
 
func _spark() -> void:
	
	var p := GPUParticles2D.new()
	p.amount = 4
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 0.7
 
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
 
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0)
	m.spread = 20.0
	m.gravity = Vector3(0, -40, 0)
	m.initial_velocity_min = 25.0
	m.initial_velocity_max = 55.0
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = radius * 0.6
	m.scale_min = 0.6
	m.scale_max = 1.4
 
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([
		Color(0.55, 1.0, 0.6, 0.9),
		Color(0.35, 0.9, 0.45, 0.0),
	])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
 
	p.process_material = m
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(p): p.queue_free())
 
 
func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]
 
 
func is_healing() -> bool:
	return _healing
 
