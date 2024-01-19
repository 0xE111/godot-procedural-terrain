extends StaticBody3D

const shader = preload("./shaders/terrain.gdshader")

var size: float
var num_cells: int
var height_range: Vector2
var height_func: Callable
var draw_collision_shape: bool

var mesh_instance := MeshInstance3D.new()
var debug_mesh_instance: MeshInstance3D
var collision_shape := CollisionShape3D.new()

func _setup() -> void:
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(size, size)
	mesh.subdivide_depth = num_cells - 1
	mesh.subdivide_width = num_cells - 1

	var texture_size := num_cells + 1
	var texture_size_half := num_cells / 2
	var height_map := Image.create(texture_size, texture_size, false, Image.Format.FORMAT_RGBAF)

	var cell_size := size / num_cells
	var height_diff := height_range.y - height_range.x
	for x in texture_size:
		for y in texture_size:
			var x_ := (x-texture_size_half)*cell_size
			var z_ := (y-texture_size_half)*cell_size
			var height := height_func.call(x_, z_)
			#var h_right := height_func.call(x_ + 1.0, z_)
			#var h_forward := height_func.call(x_, z_ + 1.0)
			#var normal := Vector3(height - h_right, 0.1, h_forward - height).normalized()
			var normal := Vector3(0.0, 1.0, 0.0)
			height_map.set_pixel(x, y, Color(
				normal.x,
				normal.y,
				normal.z,
				(height - height_range.x) / height_diff
			))
			#print("TEX(%s,%s) WORLD(%s,%s) = %s" % [x, y, (x-texture_size_half)*ratio, (y-texture_size_half)*ratio, height])

	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("chunk_size", size)
	material.set_shader_parameter("num_cells", num_cells)
	material.set_shader_parameter("height_map", ImageTexture.create_from_image(height_map))
	material.set_shader_parameter("height_range", height_range)
	mesh.material = material

	mesh_instance.mesh = mesh

	var map_data = PackedFloat32Array()
	for y in texture_size:
		for x in texture_size:
			var x_ := (x-texture_size_half)*cell_size
			var z_ := (y-texture_size_half)*cell_size
			var height := height_func.call(x_, z_)
			map_data.append(height)

	var shape = HeightMapShape3D.new()
	shape.map_depth = num_cells + 1
	shape.map_width = num_cells + 1
	shape.map_data = map_data
	collision_shape.shape = shape
	# each cell is 1m, so we need to adjust scale based on size
	collision_shape.scale = Vector3(cell_size, 1.0, cell_size)
	#add_child(collision_shape)

	if draw_collision_shape:
		debug_mesh_instance = MeshInstance3D.new()
		debug_mesh_instance.mesh = shape.get_debug_mesh()
		debug_mesh_instance.scale = Vector3(cell_size, 1.0, cell_size)

func get_height(position: Vector2) -> float:
	#var arrays = mesh_instance.mesh.get_faces()
	#print("ARRAYS", arrays)


	return 0.0

func _ready() -> void:
	add_child(mesh_instance)
	add_child(collision_shape)

	if draw_collision_shape:
		add_child(debug_mesh_instance)

	get_height(Vector2(0.0, 0.0))
