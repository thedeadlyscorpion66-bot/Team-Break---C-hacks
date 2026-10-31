
extends CharacterBody2D
 
 
signal health_changed(current, maximum)
signal died
 
@export var speed: float = 120.0
 
# --- health -------------------------------------------------------------
@export var max_health: int = 100
@export var invuln_time: float = 0.7     # mercy window after being hit
@export var knockback_force: float = 140.0
 
# --- attack -------------------------------------------------------------
@export var attack_damage: int = 1
@export var attack_range: float = 64.0
@export var attack_arc_degrees: float = 160.0
@export var attack_hit_delay: float = 0.10   # how far into the swing it lands
@export var attack_active_time: float = 0.20 # how long the blade stays live
 

@export var point_blank_range: float = 30.0
 
# --- feel ---------------------------------------------------------------
@export var hitstop_duration: float = 0.13
 
const ATTACK_MAX_TIME := 0.8   
const MIN_SWING_TIME := 0.18   
 
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
 
var facing: String = "down"
 
var health: int
var dead: bool = false
var invuln: float = 0.0
var knockback: Vector2 = Vector2.ZERO
 
var healing: bool = false
var _heal_pulse: float = 0.0
 
var attacking: bool = false
var attack_timer: float = 0.0
var swing_toggle: int = 1      
 
var attack_active: bool = false   
var _hit_ids: Array[int] = []     
 
 
func _ready() -> void:
	add_to_group("player")
	health = max_health
	health_changed.emit(health, max_health)
	anim.animation_finished.connect(_on_animation_finished)
 
 
func _physics_process(delta: float) -> void:
	if dead:
		return
 
	invuln = maxf(0.0, invuln - delta)
	_update_heal_tint(delta)
 
	
	knockback = knockback.move_toward(Vector2.ZERO, 600.0 * delta)
 
	if attacking:
		attack_timer += delta
 
		
		if attack_active:
			_damage_in_cone()
 
		
		if attack_timer >= ATTACK_MAX_TIME:
			_end_attack()
 
		velocity = knockback
		move_and_slide()
		return
 
	var dir := Vector2.ZERO
 
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir.x += 1
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dir.y += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		dir.y -= 1
 
	
	dir = dir.normalized()
 
	velocity = dir * speed + knockback
	move_and_slide()
 
	_animate(dir)
 
 
# --------------------------------------------------------------- healing
 
func set_healing(on: bool) -> void:
	
	if on == healing:
		return
	healing = on
	if not on:
		anim.modulate = Color.WHITE
		_heal_pulse = 0.0
 
 
func _update_heal_tint(delta: float) -> void:
	if not healing or dead:
		return
 
	
	if invuln > 0.0:
		return
 
	_heal_pulse += delta * 5.0
	var k := 0.5 + 0.5 * sin(_heal_pulse)
	anim.modulate = Color.WHITE.lerp(Color(0.38, 1.0, 0.48), 0.30 + 0.32 * k)
 
 
# ---------------------------------------------------------------- attack
 
func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
 
	var pressed := false
 
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pressed = true
	elif event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_J:
			pressed = true
 
	if not pressed:
		return
 
	
	if attacking and attack_timer < MIN_SWING_TIME:
		return
 
	_start_attack()
 
 
func _start_attack() -> void:
	attacking = true
	attack_timer = 0.0
 
	
	anim.play("attack_%s_%d" % [facing, swing_toggle])
	Sfx.play(self, "sfx_sword_swing.wav")
 
	swing_toggle = 2 if swing_toggle == 1 else 1
 
	
	_hit_ids.clear()
 
	
	await get_tree().create_timer(attack_hit_delay).timeout
	if dead or not attacking:
		return
 
	attack_active = true
	await get_tree().create_timer(attack_active_time).timeout
	attack_active = false
 
 
func _damage_in_cone() -> void:
	var aim := _facing_vector()
	var half_arc := deg_to_rad(attack_arc_degrees * 0.5)
	var connected := false
 
	for w in get_tree().get_nodes_in_group("woodcutters"):
		if not is_instance_valid(w):
			continue
		if w.has_method("is_alive") and not w.is_alive():
			continue
 
		
		var id := w.get_instance_id()
		if id in _hit_ids:
			continue
 
		var to_them: Vector2 = w.global_position - global_position
		var dist := to_them.length()
		if dist > attack_range:
			continue
 
		
		if dist > point_blank_range:
			if absf(aim.angle_to(to_them)) > half_arc:
				continue
 
		if w.has_method("take_damage"):
			# Our position so he gets knocked away from us.
			w.take_damage(attack_damage, global_position)
			_hit_ids.append(id)
			connected = true
 
	
	if connected:
		Sfx.play(self, "sfx_sword_hit.wav")
		GameFeel.hitstop(self, hitstop_duration)
 
 
func _end_attack() -> void:
	attacking = false
	attack_active = false
	attack_timer = 0.0
	_hit_ids.clear()
 
 
func _on_animation_finished() -> void:
	if attacking:
		_end_attack()
 
 
# ---------------------------------------------------------------- damage
 
func take_damage(amount: int = 1, from_global: Vector2 = Vector2.INF) -> void:
	
	if dead or invuln > 0.0:
		return
 
	health = maxi(0, health - amount)
	invuln = invuln_time
	health_changed.emit(health, max_health)
 
	if from_global != Vector2.INF:
		knockback = (global_position - from_global).normalized() * knockback_force
 
	_hurt_flash()
	Sfx.play(self, "sfx_player_hurt.wav")
	GameFeel.hitstop(self, hitstop_duration)
 
	if health <= 0:
		_die()
 
 
func heal(amount: int = 1) -> void:
	if dead:
		return
	var before := health
	health = mini(max_health, health + amount)
	if health != before:
		health_changed.emit(health, max_health)
 
 
func _hurt_flash() -> void:
	
	var t := create_tween()
	t.tween_property(anim, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.02)
	t.tween_interval(0.08)
	t.tween_property(anim, "modulate", Color.WHITE, 0.12)
	t.tween_property(anim, "modulate:a", 0.3, 0.1)
	t.tween_property(anim, "modulate:a", 1.0, 0.1)
	t.tween_property(anim, "modulate:a", 0.3, 0.1)
	t.tween_property(anim, "modulate:a", 1.0, 0.1)
 
 
func _die() -> void:
	if dead:
		return
	dead = true
	attacking = false
	velocity = Vector2.ZERO
	died.emit()
 
	anim.stop()
	anim.modulate = Color.WHITE
 
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(anim, "rotation", PI * 0.5, 0.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(anim, "modulate", Color(0.55, 0.55, 0.6, 1.0), 0.5)
 
 
# ------------------------------------------------------------- animation
 
func _facing_vector() -> Vector2:
	match facing:
		"right": return Vector2.RIGHT
		"left":  return Vector2.LEFT
		"up":    return Vector2.UP
		_:       return Vector2.DOWN
 
 
func _animate(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		anim.play("idle_" + facing)
		return
 
	
	if abs(dir.x) > abs(dir.y):
		facing = "right" if dir.x > 0 else "left"
	else:
		facing = "down" if dir.y > 0 else "up"
 
	anim.play("walk_" + facing)
 
 
func is_alive() -> bool:
	return not dead
 
