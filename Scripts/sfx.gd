
class_name Sfx

 
const SEARCH_DIRS := [
	"res://Assets/",
	"res://Assets/fg_audio/",
	"res://Assets/Audio/",
	"res://Assets/audio/",
	"res://Audio/",
	"res://audio/",
	"res://Sounds/",
	"res://fg_audio/",
	"res://",
]
 

static var _cache: Dictionary = {}
 

static var volume_db: float = -4.0
 
 
static func play(from: Node, sound: String, db_offset: float = 0.0,
		pitch_var: float = 0.10) -> void:


	if from == null or not from.is_inside_tree():
		return
 
	var stream := _stream_for(sound)
	if stream == null:
		return
 
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db + db_offset
	p.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
 

	from.get_tree().root.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
 
 
static func play_at(from: Node2D, sound: String, db_offset: float = 0.0,
		pitch_var: float = 0.10) -> void:
	
	if from == null or not from.is_inside_tree():
		return
 
	var stream := _stream_for(sound)
	if stream == null:
		return
 
	var p := AudioStreamPlayer2D.new()
	p.stream = stream
	p.volume_db = volume_db + db_offset
	p.pitch_scale = randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.global_position = from.global_position
 
	from.get_tree().root.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
 
 
static func _stream_for(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
 
	
	if sound.begins_with("res://"):
		if ResourceLoader.exists(sound):
			_cache[sound] = load(sound)
			return _cache[sound]
		push_warning("Sfx: nothing at " + sound)
		_cache[sound] = null
		return null
 
	
	for dir in SEARCH_DIRS:
		var path: String = dir + sound
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			_cache[sound] = stream
			print("Sfx: found ", sound, " at ", path)
			return stream
 
	push_warning("Sfx: could not find '" + sound + "'. Looked in: "
		+ ", ".join(SEARCH_DIRS))
	_cache[sound] = null
	return null
 
