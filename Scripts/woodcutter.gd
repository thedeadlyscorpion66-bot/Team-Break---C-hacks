extends CharacterBody2D
class_name Woodcutter
 
# An illegal logger. Walks to a tree and chops it down. If the ranger
# gets close he turns and swings at him instead, then goes back to work.
#
# No attack or death frames in the sprite pack, so the axe swing, the
# hurt reaction and the death are all done in code.
#
# NOTE: class is Woodcutter, not Logger - "Logger" collides with common
# engine and addon names.
 
signal died(woodcutter)
signal tree_felled(woodcutter)
 
enum State { SEEK_TREE, CHOP, CHASE, STRIKE, DEAD }
 
@export var speed: float = 55.0
@export var max_health: int = 3
 
@export var tree_reach: float = 36.0      # how close to chop a tree
@export var player_reach: float = 30.0    # how close to hit the ranger
@export var aggro_range: float = 95.0     # when he turns on you
 
@export var swing_interval: float = 1.1   # seconds between swings
@export var hit_delay: float = 0.18       # damage lands this far into a swing
@export var damage_to_player: int = 10
 
# --- feel ---------------------------------------------------------------
@export var knockback_force: float = 120.0
@export var hitstop_duration: float = 0.07
 
# --- axe ----------------------------------------------------------------
# ONE number controls the whole swing now. If it looks backwards,
# flip the sign here in the Inspector. No per-direction logic to fight.
@export var swing_arc_degrees: float = 105.0
 
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var axe: Sprite2D = $Axe
 
var health: int
var state: int = State.SEEK_TREE
var facing: String = "down"
 
var _target: Node2D = null
var _swing_cd: float = 0.0
var _swinging: bool = false
var _knockback: Vector2 = Vector2.ZERO
 
 
func _ready() -> void:
	add_to_group("woodcutters")
	health = max_health
 
	# Pivot the axe at the bottom of its handle so it swings from the
	# grip. Guarded so a missing texture can't take the game down.
	if axe and axe.texture:
		axe.offset = Vector2(0, -axe.texture.get_height() * 0.5)
 
	_place_axe()
 
 
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
 
	_swing_cd = maxf(0.0, _swing_cd - delta)
	_knockback = _knockback.move_toward(Vector2.ZERO, 600.0 * delta)
 
	var player := _find_player()
 
	# The ranger takes priority. Nobody keeps chopping with someone
	# swinging a sword at their back.
	if player and player.has_method("is_alive") and player.is_alive() \
			and global_position.distance_to(player.global_position) <= aggro_range:
		_handle_player(player)
		return
 
	_handle_tree()
 
 
# ------------------------------------------------------------ the ranger
 
func _handle_player(player: Node2D) -> void:
	var to_player: Vector2 = player.global_position - global_position
 
	if to_player.length() > player_reach:
		state = State.CHASE
		_move_toward(to_player)
		return
 
	state = State.STRIKE
	velocity = _knockback
	move_and_slide()
	_face(to_player)
	_idle_anim()
 
	if _swing_cd > 0.0:
		return
 
	_swing_cd = swing_interval
	_swing_axe()
 
	# Damage lands partway through the swing, not the instant it starts.
	# That window is what lets the player dodge.
	await get_tree().create_timer(hit_delay).timeout
	if state == State.DEAD or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= player_reach * 1.3:
		if player.has_method("take_damage"):
			# Passing our position lets him be knocked away from us.
			player.take_damage(damage_to_player, global_position)
			GameFeel.hitstop(self, hitstop_duration)
 
 
# ------------------------------------------------------------- the trees
 
func _handle_tree() -> void:
	# Only look for a new tree when we genuinely don't have a usable one.
	# Re-picking on a timer made him spread hits across many trees and
	# never actually fell any of them.
	if _target == null or not is_instance_valid(_target) \
			or not _target.is_choppable():
		_pick_tree()
 
	if _target == null or not is_instance_valid(_target):
		state = State.SEEK_TREE
		velocity = _knockback
		move_and_slide()
		_idle_anim()
		return
 
	var to_tree: Vector2 = _target.global_position - global_position
 
	if to_tree.length() > tree_reach:
		state = State.SEEK_TREE
		_move_toward(to_tree)
		return
 
	state = State.CHOP
	velocity = _knockback
	move_and_slide()
	_face(to_tree)
	_idle_anim()
 
	if _swing_cd > 0.0:
		return
 
	_swing_cd = swing_interval
	_swing_axe()
 
	# Hold our own reference across the await - _target could change
	# while we're waiting.
	var tree: Node2D = _target
 
	await get_tree().create_timer(hit_delay).timeout
	if state == State.DEAD:
		return
	if not is_instance_valid(tree) or not tree.is_choppable():
		return
 
	# Passing our position lets the tree fall away from us.
	tree.hit(global_position)
 
	if not tree.is_choppable():
		tree_felled.emit(self)
		if _target == tree:
			_target = null
 
 
func _pick_tree() -> void:
	var best: Node2D = null
	var best_d := INF
	for t in get_tree().get_nodes_in_group("trees"):
		if not is_instance_valid(t) or not t.is_choppable():
			continue
		var d: float = global_position.distance_squared_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	_target = best
 
 
# ------------------------------------------------------------- movement
 
func _move_toward(dir: Vector2) -> void:
	var d := dir.normalized()
	velocity = d * speed + _knockback
	move_and_slide()
	_face(d)
	_walk_anim()
 
 
func _face(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	var was := facing
	if abs(dir.x) > abs(dir.y):
		facing = "right" if dir.x > 0 else "left"
	else:
		facing = "down" if dir.y > 0 else "up"
	if facing != was:
		_place_axe()
 
 
func _place_axe() -> void:
	# Put the axe on the correct side of the body, and behind him when
	# he's facing away so it doesn't float over his head.
	if axe == null:
		return
	match facing:
		"right":
			axe.position = Vector2(7, 2)
			axe.z_index = 1
			axe.flip_h = false
		"left":
			axe.position = Vector2(-7, 2)
			axe.z_index = 1
			axe.flip_h = true
		"down":
			axe.position = Vector2(6, 3)
			axe.z_index = 1
			axe.flip_h = false
		"up":
			axe.position = Vector2(-6, 2)
			axe.z_index = -1
			axe.flip_h = true
 
 
# ------------------------------------------------------------ animation
 
func _walk_anim() -> void:
	var n := "walk_" + facing
	if anim.sprite_frames and anim.sprite_frames.has_animation(n):
		anim.play(n)
 
 
func _idle_anim() -> void:
	var n := "idle_" + facing
	if anim.sprite_frames and anim.sprite_frames.has_animation(n):
		anim.play(n)
	else:
		_walk_anim()
 
 
func _swing_axe() -> void:
	if _swinging or axe == null:
		return
	_swinging = true
	Sfx.play(self, "sfx_axe_swing.wav", -6.0)
 
	# Single value, no per-direction flipping. One sign change in the
	# Inspector reverses every swing in the game.
	var arc := deg_to_rad(swing_arc_degrees)
 
	var t := create_tween()
	t.tween_property(axe, "rotation", arc, 0.14)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(axe, "rotation", 0.0, 0.26)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(func(): _swinging = false)
 
 
# ---------------------------------------------------------------- damage
 
func take_damage(amount: int = 1, from_global: Vector2 = Vector2.INF) -> void:
	if state == State.DEAD:
		return
 
	health -= amount
 
	# Red flash - no hurt animation exists, so this is what tells the
	# player the hit landed.
	GameFeel.flash(anim, Color(1.0, 0.25, 0.25, 1.0))
 
	# Shoved away from whoever hit him.
	if from_global != Vector2.INF:
		_knockback = (global_position - from_global).normalized() * knockback_force
 
	_chips(10)
 
	if health <= 0:
		_die()
 
 
func _die() -> void:
	state = State.DEAD
	Sfx.play(self, "sfx_logger_die.wav")
	died.emit(self)
 
	velocity = Vector2.ZERO
	set_physics_process(false)
 
	var shape := get_node_or_null("CollisionShape2D")
	if shape:
		shape.set_deferred("disabled", true)
 
	if axe:
		axe.visible = false
	anim.stop()
	anim.modulate = Color.WHITE
 
	# No death frames, so topple him in code.
	var dir := 1.0 if randf() < 0.5 else -1.0
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(anim, "rotation", dir * PI * 0.5, 0.45)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(anim, "modulate", Color(0.6, 0.6, 0.6, 1.0), 0.45)
	await t.finished
 
	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(self):
		return
 
	var f := create_tween()
	f.tween_property(anim, "modulate:a", 0.0, 0.5)
	await f.finished
	queue_free()
 
 
func _chips(count: int) -> void:
	var p := GPUParticles2D.new()
	p.amount = count
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 1.0
	p.position = Vector2(0, -6)
 
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	p.texture = ImageTexture.create_from_image(img)
 
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, -1, 0)
	m.spread = 180.0
	m.gravity = Vector3(0, 150, 0)
	m.initial_velocity_min = 40.0
	m.initial_velocity_max = 110.0
	m.scale_min = 0.8
	m.scale_max = 1.6
 
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([
		Color(0.85, 0.75, 0.55, 1.0),   # wood chips, not gore
		Color(0.60, 0.48, 0.32, 0.0),
	])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	m.color_ramp = gt
 
	p.process_material = m
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(p): p.queue_free())
 
 
# --------------------------------------------------------------- helpers
 
func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]
 
 
func is_alive() -> bool:
	return state != State.DEAD
 
 
func is_chopping() -> bool:
	# Used by the HUD threat arrow - only warns while he's actually
	# felling a tree, not while he's walking around looking for one.
	return state == State.CHOP
 
