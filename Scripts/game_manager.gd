extends Node
class_name GameManager


signal forest_health_changed(current: int, maximum: int)
signal survival_time_changed(seconds: float)
signal kills_changed(kills: int)
signal game_over(survived: float, is_high_score: bool, reason: String)

@export var tree_scene: PackedScene
@export var max_trees: int = 10
@export var health_per_tree: int = 10

@export var respawn_interval: float = 30.0
@export var trees_per_respawn: int = 1

@export var forest_parent_path: NodePath

@export var death_time_scale: float = 0.25
@export var death_freeze_duration: float = 1.1

const SAVE_PATH := "user://forest_guardian.cfg"

var survival_time: float = 0.0
var loggers_killed: int = 0

var high_score: float = 0.0
var best_kills: int = 0

var running: bool = false

var _slots: Array[Vector2] = []
var _respawn_timer: float = 0.0
var _forest_parent: Node = null


func _ready() -> void:
	add_to_group("game_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS

	high_score = _load_high_score()

	await get_tree().process_frame
	_start_run()


func _start_run() -> void:
	_forest_parent = get_node_or_null(forest_parent_path)

	var trees := get_tree().get_nodes_in_group("trees")

	if _forest_parent == null and not trees.is_empty():
		_forest_parent = trees[0].get_parent()
	if _forest_parent == null:
		_forest_parent = get_parent()

	for t in trees:
		_slots.append(t.global_position)
		_watch(t)

	if _slots.size() > max_trees:
		_slots.resize(max_trees)

	_respawn_timer = respawn_interval
	running = true

	_connect_player()
	_connect_spawner()
	_emit_forest_health()
	kills_changed.emit(loggers_killed)


func _connect_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var p = players[0]
	if p.has_signal("died") and not p.died.is_connected(_on_player_died):
		p.died.connect(_on_player_died)


func _connect_spawner() -> void:
	for sp in get_tree().get_nodes_in_group("spawner"):
		if sp.has_signal("woodcutter_killed") \
				and not sp.woodcutter_killed.is_connected(_on_logger_killed):
			sp.woodcutter_killed.connect(_on_logger_killed)


func _on_logger_killed(_w) -> void:
	loggers_killed += 1
	kills_changed.emit(loggers_killed)


func _watch(t: Node) -> void:
	if t.has_signal("tree_lost") and not t.tree_lost.is_connected(_on_tree_lost):
		t.tree_lost.connect(_on_tree_lost)


func _process(delta: float) -> void:
	if not running:
		return

	survival_time += delta
	survival_time_changed.emit(survival_time)

	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		_respawn_timer = respawn_interval
		_respawn_trees()


func living_trees() -> int:
	var n := 0
	for t in get_tree().get_nodes_in_group("trees"):
		if is_instance_valid(t) and t.has_method("is_choppable") and t.is_choppable():
			n += 1
	return n


func forest_health() -> int:
	return living_trees() * health_per_tree


func forest_health_max() -> int:
	return max_trees * health_per_tree


func _emit_forest_health() -> void:
	forest_health_changed.emit(forest_health(), forest_health_max())


func _on_tree_lost(_tree) -> void:
	_emit_forest_health()

	if living_trees() <= 0:
		_end_run("The forest is gone")


func _respawn_trees() -> void:
	if tree_scene == null or not running:
		return

	var grown := 0
	for slot in _slots:
		if grown >= trees_per_respawn:
			break
		if living_trees() >= max_trees:
			break
		if _slot_occupied(slot):
			continue

		var t := tree_scene.instantiate()
		t.global_position = slot
		_forest_parent.add_child(t)
		_watch(t)

		if t.has_node("AnimatedSprite2D"):
			var s: Node2D = t.get_node("AnimatedSprite2D")
			s.scale = Vector2(0.1, 0.1)
			var tw := t.create_tween()
			tw.tween_property(s, "scale", Vector2.ONE, 0.9)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

		grown += 1

	if grown > 0:
		Sfx.play(self, "sfx_tree_grow.wav", -8.0)
		_emit_forest_health()


func _slot_occupied(slot: Vector2) -> bool:
	for t in get_tree().get_nodes_in_group("trees"):
		if not is_instance_valid(t):
			continue
		if t.global_position.distance_to(slot) < 12.0:
			return true
	return false


func _on_player_died() -> void:
	_end_run("You were cut down")


func _end_run(reason: String) -> void:
	if not running:
		return
	running = false

	var is_best := survival_time > high_score
	if is_best:
		high_score = survival_time
		best_kills = loggers_killed
		_save_high_score()

	Engine.time_scale = death_time_scale
	await get_tree().create_timer(death_freeze_duration, true, false, true).timeout
	Engine.time_scale = 1.0

	game_over.emit(survival_time, is_best, reason)


func restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().reload_current_scene()


func _load_high_score() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0.0
	best_kills = int(cfg.get_value("score", "best_kills", 0))
	return float(cfg.get_value("score", "best_time", 0.0))


func _save_high_score() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best_time", high_score)
	cfg.set_value("score", "best_kills", best_kills)
	cfg.save(SAVE_PATH)


static func format_time(seconds: float) -> String:
	var m := int(floor(seconds / 60.0))
	var s := int(floor(seconds)) % 60
	return "%d:%02d" % [m, s]
