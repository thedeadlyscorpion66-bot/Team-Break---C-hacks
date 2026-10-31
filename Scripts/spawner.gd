extends Node2D
class_name WoodcutterSpawner
 
# Keeps a steady supply of loggers coming. One alive at a time by
# default - kill him and another walks in a few seconds later.
#
# THREE WAYS to choose where they appear, checked in this order:
#
#   1. Spawn Points   - a list of exact coordinates. Most control.
#                       Use this when part of your map is blocked off.
#   2. Spawn Region   - a rectangle; a random point inside it.
#                       Good for "only the right half of the map".
#   3. Ring           - a ring around the player, clamped to the
#                       tilemap bounds. The fallback.
#
# Default is a single spawn point at (280, 100).
 
signal woodcutter_spawned(woodcutter)
signal woodcutter_killed(woodcutter)
 
@export var woodcutter_scene: PackedScene
 
@export var max_alive: int = 1
@export var respawn_delay: float = 11.0
@export var first_spawn_delay: float = 10.0   # grace period at game start
 
# --- 0. MARKERS (easiest) -----------------------------------------------
# Drop Marker2D nodes in your scene, drag them where you want loggers to
# walk in, then add them to this list. No coordinates to work out, and
# it cannot land outside your map because you placed it by eye.
# This beats everything below it when it has entries.
@export var spawn_markers: Array[NodePath] = []
 
# --- 1. exact points ----------------------------------------------------
# Leave this list non-empty and it's the ONLY thing used. Add more
# Vector2s for several entry points and one is picked at random.
@export var use_spawn_points: bool = true
@export var spawn_points: Array[Vector2] = [Vector2(280, 100)]
 
# --- 2. rectangle -------------------------------------------------------
# Used when use_spawn_points is off (or the list is empty) and this has
# a size. Position is the top-left corner, in world pixels.
@export var use_spawn_region: bool = false
@export var spawn_region: Rect2 = Rect2(280, 80, 900, 560)
 
# --- 3. ring around the player ------------------------------------------
@export var spawn_distance_min: float = 260.0
@export var spawn_distance_max: float = 420.0
 
# Bounds, read off your TileMap so ring spawns stay on solid ground.
@export var bounds_from_tilemap: NodePath
@export var bounds_inset_tiles: int = 2
@export var bounds_min: Vector2 = Vector2(32, 32)
@export var bounds_max: Vector2 = Vector2(1248, 688)
 
# --- difficulty ramp ----------------------------------------------------
@export var ramp_enabled: bool = true
@export var speed_gain_per_spawn: float = 2.5
@export var max_speed_gain: float = 30.0
@export var delay_loss_per_spawn: float = 0.25
@export var min_respawn_delay: float = 5.0
 
var spawned_total: int = 0
var alive: int = 0
 
var _timer: float = 0.0
var _last_point: int = -1
 
 
func _ready() -> void:
	add_to_group("spawner")
	_timer = first_spawn_delay
	_read_bounds()
 
 
func _process(delta: float) -> void:
	if woodcutter_scene == null:
		return
	if alive >= max_alive:
		return
 
	_timer -= delta
	if _timer <= 0.0:
		_spawn()
		_timer = _current_delay()
 
 
# ----------------------------------------------------------------- bounds
 
func _read_bounds() -> void:
	# Works for both TileMapLayer (4.3+) and the older TileMap node.
	if bounds_from_tilemap.is_empty():
		return
 
	var tm := get_node_or_null(bounds_from_tilemap)
	if tm == null or not tm.has_method("get_used_rect"):
		return
 
	var r: Rect2i = tm.get_used_rect()
	if r.size.x <= 0 or r.size.y <= 0:
		return
 
	var ts := Vector2(16, 16)
	if tm.tile_set:
		ts = Vector2(tm.tile_set.tile_size)
 
	var inset := ts * float(bounds_inset_tiles)
	bounds_min = tm.global_position + Vector2(r.position) * ts + inset
	bounds_max = tm.global_position + Vector2(r.end) * ts - inset
 
 
# ------------------------------------------------------------------ spawn
 
func _spawn() -> void:
	var w := woodcutter_scene.instantiate()
	var point := _spawn_point()
 
	if ramp_enabled and "speed" in w:
		w.speed += minf(spawned_total * speed_gain_per_spawn, max_speed_gain)
 
	# Count him down again when he dies. The signal fires the instant
	# he's killed, not when the corpse finishes fading.
	if w.has_signal("died"):
		w.died.connect(_on_woodcutter_died)
 
	# ORDER MATTERS. global_position on a node that isn't in the tree
	# yet just writes to position, which then gets treated as LOCAL to
	# whatever we parent him to - so he'd land at
	# spawner_position + point instead of at point.
	#
	# Add first, position second.
	add_child(w)
	w.global_position = point
 
	alive += 1
	spawned_total += 1
	print("spawned logger at ", w.global_position)
	woodcutter_spawned.emit(w)
 
 
func _on_woodcutter_died(w) -> void:
	alive = maxi(0, alive - 1)
	_timer = _current_delay()
	woodcutter_killed.emit(w)
 
 
func _current_delay() -> float:
	if not ramp_enabled:
		return respawn_delay
	return maxf(min_respawn_delay, respawn_delay - spawned_total * delay_loss_per_spawn)
 
 
# ----------------------------------------------------------- spawn point
 
func _spawn_point() -> Vector2:
	# 0. Markers you placed in the editor. Most reliable, because the
	#    position comes from the scene rather than a number you typed.
	if not spawn_markers.is_empty():
		var pts: Array[Vector2] = []
		for np in spawn_markers:
			var n := get_node_or_null(np)
			if n is Node2D:
				pts.append((n as Node2D).global_position)
		if not pts.is_empty():
			return pts[randi() % pts.size()]
 
	# 1. Exact coordinates. Nothing clamps or second-guesses them, so a
	#    point you typed is the point he appears at.
	if use_spawn_points and not spawn_points.is_empty():
		return _next_point()
 
	# 2. Somewhere inside a rectangle.
	if use_spawn_region and spawn_region.size.x > 0 and spawn_region.size.y > 0:
		return Vector2(
			randf_range(spawn_region.position.x, spawn_region.end.x),
			randf_range(spawn_region.position.y, spawn_region.end.y)
		)
 
	# 3. Ring around the player, kept inside the map.
	return _ring_point()
 
 
func _next_point() -> Vector2:
	if spawn_points.size() == 1:
		return spawn_points[0]
 
	# Avoid using the same entry twice in a row - two loggers walking
	# in from the identical spot reads as a bug even when it isn't.
	var i := randi() % spawn_points.size()
	if i == _last_point:
		i = (i + 1) % spawn_points.size()
	_last_point = i
	return spawn_points[i]
 
 
func _ring_point() -> Vector2:
	var player := _find_player()
	var centre := (bounds_min + bounds_max) * 0.5
	if player:
		centre = player.global_position
 
	for _attempt in 40:
		var ang := randf() * TAU
		var dist := randf_range(spawn_distance_min, spawn_distance_max)
		var p := centre + Vector2(cos(ang), sin(ang)) * dist
		if _inside(p):
			return p
 
	return _furthest_corner(centre)
 
 
func _inside(p: Vector2) -> bool:
	return p.x >= bounds_min.x and p.x <= bounds_max.x \
		and p.y >= bounds_min.y and p.y <= bounds_max.y
 
 
func _furthest_corner(from: Vector2) -> Vector2:
	var corners := [
		bounds_min,
		Vector2(bounds_max.x, bounds_min.y),
		Vector2(bounds_min.x, bounds_max.y),
		bounds_max,
	]
	var best: Vector2 = corners[0]
	var best_d := -1.0
	for c in corners:
		var d: float = c.distance_squared_to(from)
		if d > best_d:
			best_d = d
			best = c
	return best
 
 
func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0]
 
