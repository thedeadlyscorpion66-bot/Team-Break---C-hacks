extends StaticBody2D
class_name ForestTree

# A tree that sways, takes a few axe hits, then falls away from whoever
# chopped it and leaves a permanent stump.
#
# NOTE: class is ForestTree, not Tree - Godot already has a built-in
# Tree node (the editor's own UI list control).

signal tree_lost(tree)

@export var hits_to_fell: int = 4
@export var variant: int = 0
@export var variant_count: int = 3
@export var sway_enabled: bool = true
@export var sway_amount: float = 0.03
@export var leave_stump: bool = true

const ANIM_IDLE  := "idle"
const ANIM_HIT   := "hit"
const ANIM_FALL  := "fall"
const ANIM_STUMP := "stump"

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D

var hits: int = 0
var felled: bool = false

var _side: String = "right"
var _sway_phase: float = 0.0
var _sway_speed: float = 1.0
var _playing_hit: bool = false


func _ready() -> void:
	add_to_group("trees")

	if variant <= 0:
		variant = randi_range(1, max(1, variant_count))

	sprite.offset = Vector2(0, -_sprite_h() * 0.5)

	_sway_phase = randf() * TAU
	_sway_speed = randf_range(0.7, 1.3)

	sprite.animation_finished.connect(_on_animation_finished)

	_play(ANIM_IDLE)


func _process(delta: float) -> void:
	if felled or not sway_enabled:
		return
	_sway_phase += delta * _sway_speed
	sprite.rotation = sin(_sway_phase) * sway_amount


func hit(from_global: Vector2 = Vector2.INF) -> void:
	if felled:
		return

	_side = _side_away_from(from_global)
	hits += 1

	if hits >= hits_to_fell:
		_fell()
		return

	_burst(8, Color(0.38, 0.66, 0.35), 70.0)
	_knock()
	Sfx.play(self, "sfx_tree_chop.wav", -3.0)

	var a := _resolve(ANIM_HIT, _side)
	if a != "":
		_playing_hit = true
		sprite.animation = a
		sprite.frame = 0
		sprite.play()


func is_choppable() -> bool:
	return not felled


func health_fraction() -> float:
	return 1.0 - (float(hits) / float(hits_to_fell))


func _side_away_from(from_global: Vector2) -> String:
	if from_global == Vector2.INF:
		return _side
	# FLIP THIS LINE if your fall animations look backwards.
	return "right" if from_global.x < global_position.x else "left"


func _knock() -> void:
	var push := 3.0 if _side == "right" else -3.0
	var t := create_tween()
	t.tween_property(sprite, "position", Vector2(push, 0), 0.05)
	t.tween_property(sprite, "position", Vector2.ZERO, 0.12)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _fell() -> void:
	felled = true
	_playing_hit = false
	sprite.position = Vector2.ZERO
	shape.set_deferred("disabled", true)

	_burst(18, Color(0.38, 0.66, 0.35), 100.0)
	Sfx.play(self, "sfx_tree_fall.wav")
	tree_lost.emit(self)

	var a := _resolve(ANIM_FALL, _side)
	if a != "":
		sprite.animation = a
		sprite.frame = 0
		sprite.play()
		# Wait a COMPUTED duration rather than the animation_finished
		# signal. A fall animation left on Loop never emits that signal.
		await get_tree().create_timer(_anim_duration(a)).timeout
		if not is_instance_valid(self):
			return
		sprite.stop()
		var n := sprite.sprite_frames.get_frame_count(a)
		sprite.frame = maxi(0, n - 1)
	else:
		var dir := 1.0 if _side == "right" else -1.0
		var t := create_tween()
		t.tween_property(sprite, "rotation", dir * PI * 0.5, 0.6)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		await t.finished

	if not is_instance_valid(self):
		return

	var s := _resolve(ANIM_STUMP, _side)
	if leave_stump and s != "":
		sprite.stop()
		sprite.rotation = 0.0
		sprite.animation = s
		sprite.frame = 0
		return

	var f := create_tween()
	f.tween_property(sprite, "modulate:a", 0.0, 0.4)
	await f.finished
	queue_free()


func _on_animation_finished() -> void:
	if _playing_hit and not felled:
		_playing_hit = false
		_play(ANIM_IDLE)


func _burst(count: int, color: Color, speed: float) -> void:
	var p := GPUParticles2D.new()
	p.amount = count
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.position = Vector2(0, -_sprite_h() * 0.45)

	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)

	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0)
	m.spread = 180.0
	m.gravity = Vector3(0, 120, 0)
	m.initial_velocity_min = speed * 0.4
	m.initial_velocity_max = speed
	m.angular_velocity_min = -240.0
	m.angular_velocity_max = 240.0
	m.scale_min = 0.7
	m.scale_max = 1.6

	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([color, Color(color.r, color.g, color.b, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt

	p.process_material = m
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(func():
		if is_instance_valid(p): p.queue_free())


func _resolve(base: String, side: String = "") -> String:
	if sprite.sprite_frames == null:
		return ""

	var names: Array[String] = []
	if side != "":
		names.append("%s_%s_%d" % [base, side, variant])
		names.append("%s_%s" % [base, side])
	names.append("%s_%d" % [base, variant])
	names.append(base)

	for n in names:
		if sprite.sprite_frames.has_animation(n):
			return n
	return ""


func _anim_duration(a: String) -> float:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(a):
		return 0.6
	var n := sprite.sprite_frames.get_frame_count(a)
	var fps: float = sprite.sprite_frames.get_animation_speed(a)
	if fps <= 0.0:
		fps = 10.0
	return clampf(float(n) / fps, 0.15, 2.5)


func _play(base: String) -> void:
	var a := _resolve(base)
	if a == "":
		return
	sprite.animation = a
	sprite.play()


func _sprite_h() -> float:
	if sprite and sprite.sprite_frames:
		var a: String = sprite.animation
		if sprite.sprite_frames.has_animation(a):
			var tex := sprite.sprite_frames.get_frame_texture(a, 0)
			if tex:
				return float(tex.get_height())
	return 64.0
