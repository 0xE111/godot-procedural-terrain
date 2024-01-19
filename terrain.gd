@tool
@icon("./icons/terrain.svg")

class_name Terrain extends Node3D

var Chunk = preload("./chunk.gd")

var noise = FastNoiseLite.new()
@export var chunk_size: float = 256.0:
	set(value): chunk_size = value; configuration_changed.emit()
@export var chunk_num_cells: int = 32:
	set(value): chunk_num_cells = max(value, 1); configuration_changed.emit()
@export var chunks_preload: int = 1:
	# preload at least 1 chunk; on 0 the bug with ref count appears, which
	# makes height function null -> forbid it rather than fixing :)
	set(value): chunks_preload = max(value, 1); configuration_changed.emit()
@export var height_range := Vector2(-1024.0, 1024.0):
	set(value): height_range = value; configuration_changed.emit()
@export var height_map: Node:
	set(value): height_map = value; configuration_changed.emit()
#@export var height_func: Callable = func (x: float, z: float) -> float:
	#return noise.get_noise_2d(x, z) * 20  # TODO: enable it when supported by godot
@export var update_interval := 1.0:
	set(value): update_interval = max(0.1, value)
@export var draw_collision_shape: bool = false:
	set(value): draw_collision_shape = value; configuration_changed.emit()

var _loaded_chunks := {}
var _last_chunk := Vector2i(0, 0)
var _last_chunks_preload := chunks_preload
var _load_mutex := Mutex.new()

signal chunk_loaded(chunk)
signal configuration_changed

func load_chunk(position: Vector2i = Vector2i(0, 0)) -> void:
	assert(OS.get_thread_caller_id() != OS.get_main_thread_id(), "Should be run within a thread")
	#print("Loading chunk", position)

	var chunk = Chunk.new()
	chunk.size = chunk_size
	chunk.num_cells = chunk_num_cells
	chunk.height_range = height_range
	chunk.height_func = func(x: float, z: float) -> float:
		# this is a wrapper which translates global coordinates into coordinates
		# local to specific chunk before calling the height function
		var height = self.height_map.get_height(
			chunk_size * position.x + x,
			chunk_size * position.y + z,
		)
		return clampf(height, height_range.x, height_range.y)
	chunk.position = Vector3(position.x, 0.0, position.y) * chunk_size
	chunk.draw_collision_shape = draw_collision_shape
	chunk._setup()
	_load_mutex.lock()
	_loaded_chunks[position] = chunk
	_load_mutex.unlock()
	call_deferred("add_child", chunk)
	call_deferred("emit_signal", "chunk_loaded", chunk)

func unload_chunk(position: Vector2i) -> void:
	var chunk = _loaded_chunks[position]
	if chunk == null: return  # it is loading
	chunk.queue_free()
	_loaded_chunks.erase(position)

func get_chunk(x: float, z: float) -> Vector2i:
	# given specific position, return which chunk it belongs to
	return Vector2i(roundi(x / chunk_size), roundi(z / chunk_size))

func get_current_chunk() -> Vector2i:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return get_chunk(0.0, 0.0)
	return get_chunk(camera.global_position.x, camera.global_position.z)

func schedule_chunks_to_load() -> void:
	var current_chunk = get_current_chunk()
	if not (
		current_chunk != _last_chunk or \
		current_chunk not in _loaded_chunks or \
		chunks_preload != _last_chunks_preload
	):
		return

	if not _load_mutex.try_lock():
		return

	_last_chunk = current_chunk
	_last_chunks_preload = chunks_preload

	var need_to_load_chunks = []
	for d in chunks_preload + 1:
		for x in range(-d, d+1):
			for z in range(-d, d+1):
				if not (x == d or x == -d or z == d or z == -d):
					continue
				need_to_load_chunks.append(Vector2i(current_chunk.x+x, current_chunk.y+z))

	for pos in _loaded_chunks.keys():
		if pos not in need_to_load_chunks:
			unload_chunk(pos)

	for pos in need_to_load_chunks:
		if pos not in _loaded_chunks:
			_loaded_chunks[pos] = null
			var _load_this_chunk = Callable(self, "load_chunk").bind(pos)
			WorkerThreadPool.add_task(_load_this_chunk)

	_load_mutex.unlock()

func reload_chunks() -> void:
	_load_mutex.lock()
	for pos in _loaded_chunks.keys():
		unload_chunk(pos)
	_load_mutex.unlock()
	schedule_chunks_to_load()

func _ready() -> void:
	configuration_changed.connect(reload_chunks)
	#height_map.script_changed.connect(reload_chunks)
	schedule_chunks_to_load()  # initial chunks should be loaded immediately

	var timer = Timer.new()
	timer.connect("timeout", schedule_chunks_to_load)
	timer.wait_time = update_interval
	add_child(timer)
	timer.start()
