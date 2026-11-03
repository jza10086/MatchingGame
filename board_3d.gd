extends Node3D
## Presentation only: the host's 2D cell indices remain the gameplay contract.
## Camera framing and ray picking share the same fixed-aspect UI surface.
const COLORS: Array[Color] = [Color("#ed5466"), Color("#b8d85f"), Color("#ff9e38"), Color("#f8dc54"), Color("#a67be5"), Color("#f15b91"), Color("#b82d51"), Color("#5dc49a"), Color("#ffb395"), Color("#638be0")]
var tiles: Array[Node3D] = []
var bases: Array[MeshInstance3D] = []
var fruits: Array[Node3D] = []
var values: Array[int] = []
var motions: Dictionary[int, Tween] = {}
var materials: Dictionary[String, StandardMaterial3D] = {}
var path_nodes: Node3D
var path_time: float = 0.0
@onready var camera: Camera3D = %Camera
@onready var models: Node3D = %Models
@onready var world: WorldEnvironment = %World
@onready var sun: DirectionalLight3D = %Sun

func _ready() -> void:
	_box(models, Vector3(0, -0.38, 0), Vector3(12.8, 0.5, 10.7), _material(Color("#163c49")))
	_box(models, Vector3(0, -0.10, 0), Vector3(12.55, 0.13, 10.45), _material(Color("#329989")))
	_box(models, Vector3(0, -0.01, 0), Vector3(12.35, 0.12, 10.25), _material(Color("#244b55")))
	for index: int in 80:
		var tile: Node3D = Node3D.new()
		tile.name = "Tile%02d" % index
		tile.position = cell_position(Vector2i(index % 10, index / 10))
		models.add_child(tile)
		tiles.append(tile)
		bases.append(_box(tile, Vector3(0, 0.16, 0), Vector3(0.88, 0.28, 0.88), _material(Color("#edf0d9"))))
		var fruit: Node3D = Node3D.new()
		tile.add_child(fruit)
		fruits.append(fruit)
		tile.hide()
		values.append(0)
	path_nodes = Node3D.new()
	path_nodes.name = "Connection"
	models.add_child(path_nodes)

func cell_position(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) - 4.5, 0, float(cell.y) - 3.5)

## Fit the complete outer route ring into the UI surface, at any window aspect.
func frame_surface(surface: Rect2) -> void:
	if surface.size.y <= 0:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var units_per_pixel: float = 10.2 / surface.size.y
	camera.size = viewport_size.y * units_per_pixel
	camera.h_offset = (viewport_size.x * 0.5 - surface.get_center().x) * units_per_pixel
	camera.v_offset = (surface.get_center().y - viewport_size.y * 0.5) * units_per_pixel

## Ray-box picking uses the whole piece, including its fruit, and rejects gaps/empty cells.
func pick(screen_position: Vector2) -> int:
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.project_ray_normal(screen_position)
	var closest: float = INF
	var result: int = -1
	for index: int in tiles.size():
		if values[index] == 0:
			continue
		var bounds: AABB = AABB(tiles[index].global_position + Vector3(-0.44, 0.02, -0.44), Vector3(0.88, 0.96, 0.88))
		var hit: Variant = bounds.intersects_ray(origin, direction)
		if hit != null:
			var distance: float = origin.distance_squared_to(hit)
			if distance < closest:
				closest = distance
				result = index
	return result

func show_board(board: Array, selected: int, hints: Array) -> void:
	for index: int in tiles.size():
		var value: int = int(board[index])
		if value != values[index]:
			if motions.has(index):
				motions[index].kill()
				motions.erase(index)
			if value == 0:
				var motion: Tween = create_tween()
				motions[index] = motion
				motion.tween_property(tiles[index], "scale", Vector3.ONE * 0.02, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
				motion.tween_callback(tiles[index].hide)
			else:
				for child: Node in fruits[index].get_children():
					child.free()
				_make_fruit(fruits[index], value)
				tiles[index].scale = Vector3.ONE
				tiles[index].show()
			values[index] = value
		var hinted: bool = Vector2i(index % 10, index / 10) in hints
		var color: Color = Color("#67edc1") if index == selected else (Color("#ffe17a") if hinted else Color("#edf0d9"))
		bases[index].material_override = _material(color)
		tiles[index].position.y = 0.13 if index == selected else 0.0

func show_path(cells: Array, color: Color) -> void:
	for child: Node in path_nodes.get_children():
		child.free()
	path_time = 0.65
	path_nodes.show()
	var material: StandardMaterial3D = _material(color, true)
	for index: int in cells.size():
		var point: Vector3 = cell_position(cells[index]) + Vector3(0, 0.4, 0)
		_sphere(path_nodes, point, Vector3.ONE * 0.13, material)
		if index > 0:
			var previous: Vector3 = cell_position(cells[index - 1]) + Vector3(0, 0.4, 0)
			_rod(path_nodes, previous, point, 0.045, material)

func advance(delta: float) -> void:
	path_time = maxf(0.0, path_time - delta)
	path_nodes.visible = path_time > 0.0

func clear_path() -> void:
	path_time = 0.0
	path_nodes.hide()

func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var key: String = color.to_html() + str(glow)
	if not materials.has(key):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.38
		if glow:
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.emission_enabled = true
			material.emission = color
		materials[key] = material
	return materials[key]

func _mesh(parent: Node3D, shape: Mesh, position_value: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = shape
	instance.position = position_value
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _box(parent: Node3D, point: Vector3, dimensions: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var shape: BoxMesh = BoxMesh.new()
	shape.size = dimensions
	return _mesh(parent, shape, point, material)

func _sphere(parent: Node3D, point: Vector3, dimensions: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var shape: SphereMesh = SphereMesh.new()
	shape.radius = 0.5
	shape.height = 1.0
	shape.radial_segments = 16
	shape.rings = 8
	var instance: MeshInstance3D = _mesh(parent, shape, point, material)
	instance.scale = dimensions
	return instance

func _rod(parent: Node3D, start: Vector3, end: Vector3, radius: float, material: StandardMaterial3D) -> void:
	var shape: CylinderMesh = CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = start.distance_to(end)
	shape.radial_segments = 10
	var instance: MeshInstance3D = _mesh(parent, shape, (start + end) * 0.5, material)
	instance.quaternion = Quaternion(Vector3.UP, (end - start).normalized())

## Ten original low-poly fruit silhouettes; no downloaded models or textures.
func _make_fruit(parent: Node3D, value: int) -> void:
	var color: StandardMaterial3D = _material(COLORS[value - 1])
	var green: StandardMaterial3D = _material(Color("#397d52"))
	var stem: StandardMaterial3D = _material(Color("#78503c"))
	match value:
		1, 9: # Apple and peach: paired lobes and a visible central crease.
			_sphere(parent, Vector3(-0.12, 0.55, 0), Vector3(0.43, 0.48, 0.53), color)
			_sphere(parent, Vector3(0.12, 0.55, 0), Vector3(0.43, 0.48, 0.53), color)
		2: # Pear.
			_sphere(parent, Vector3(0, 0.49, 0), Vector3(0.55, 0.39, 0.52), color)
			_sphere(parent, Vector3(0.02, 0.69, 0), Vector3(0.30, 0.39, 0.29), color)
		3: # Orange.
			_sphere(parent, Vector3(0, 0.56, 0), Vector3.ONE * 0.57, color)
		4: # Lemon, horizontal with pointed ends.
			_sphere(parent, Vector3(0, 0.53, 0), Vector3(0.66, 0.41, 0.43), color)
			_sphere(parent, Vector3(-0.30, 0.53, 0), Vector3(0.16, 0.18, 0.19), color)
			_sphere(parent, Vector3(0.30, 0.53, 0), Vector3(0.16, 0.18, 0.19), color)
		5: # Grape bunch.
			for layer: int in 3:
				for grape: int in 3 - layer:
					_sphere(parent, Vector3((grape - (2 - layer) * 0.5) * 0.21, 0.72 - layer * 0.16, layer * 0.09), Vector3.ONE * 0.27, color)
		6: # Strawberry with a leaf crown and pale seeds.
			var berry: PrismMesh = PrismMesh.new()
			berry.size = Vector3(0.51, 0.53, 0.42)
			var body_mesh: MeshInstance3D = _mesh(parent, berry, Vector3(0, 0.56, 0), color)
			body_mesh.rotation.z = PI
			for seed_index: int in 3:
				_sphere(parent, Vector3((seed_index - 1) * 0.13, 0.64, 0.22), Vector3(0.04, 0.07, 0.035), _material(Color("#ffe7a3")))
		7: # Paired cherries and their forked stalks.
			_sphere(parent, Vector3(-0.18, 0.48, 0), Vector3.ONE * 0.35, color)
			_sphere(parent, Vector3(0.18, 0.49, 0.06), Vector3.ONE * 0.35, color)
			_rod(parent, Vector3(-0.18, 0.60, 0), Vector3(0, 0.89, 0), 0.022, green)
			_rod(parent, Vector3(0.18, 0.61, 0.06), Vector3(0, 0.89, 0), 0.022, green)
		8: # Watermelon with contrasting raised rind stripes.
			_sphere(parent, Vector3(0, 0.56, 0), Vector3(0.64, 0.49, 0.54), color)
			for stripe: int in 3:
				var ring: TorusMesh = TorusMesh.new()
				ring.inner_radius = 0.225
				ring.outer_radius = 0.245
				ring.rings = 20
				ring.ring_segments = 6
				var stripe_mesh: MeshInstance3D = _mesh(parent, ring, Vector3((stripe - 1) * 0.14, 0.56, 0), green)
				stripe_mesh.rotation.z = PI * 0.5
				stripe_mesh.scale = Vector3(1, 1, 1.1)
		10: # Blueberry trio, each with a dark calyx.
			for berry_index: int in 3:
				var point: Vector3 = Vector3((berry_index - 1) * 0.20, 0.48 + (0.12 if berry_index == 1 else 0.0), 0)
				_sphere(parent, point, Vector3.ONE * 0.34, color)
				_sphere(parent, point + Vector3(0, 0.16, 0), Vector3(0.13, 0.035, 0.13), _material(Color("#354775")))
	if value != 4 and value != 8 and value != 10:
		_rod(parent, Vector3(0, 0.73, 0), Vector3(0.04, 0.91, 0), 0.026, stem)
		var leaf: MeshInstance3D = _sphere(parent, Vector3(0.14, 0.83, 0), Vector3(0.29, 0.055, 0.13), green)
		leaf.rotation.z = 0.35
