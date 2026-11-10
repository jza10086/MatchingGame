extends Node3D
## Presentation only: the host's 2D cell indices remain the gameplay contract.
## Perspective framing keeps the complete playable area and outside route ring in view.
const Piece: Script = preload("res://games/minigame/gp_matching/matching_piece.gd")
const ICONS: Array[String] = ["01_apple", "02_pear", "03_orange", "04_lemon", "05_grape", "06_berry", "07_cherry", "08_melon", "09_peach", "10_blueberry"]
var tiles: Array[Node3D] = []
var textures: Array[Texture2D] = []
var values: Array[int] = []
var motions: Dictionary[int, Tween] = {}
var materials: Dictionary[String, StandardMaterial3D] = {}
@onready var path_nodes: Node3D = %Connection
var path_time: float = 0.0
@onready var camera: Camera3D = %Camera
@onready var models: Node3D = %Models
@onready var world: WorldEnvironment = %World
@onready var sun: DirectionalLight3D = %Sun

func _ready() -> void:
	for icon: String in ICONS:
		textures.append(load("res://games/minigame/gp_matching/assets/icons/" + icon + ".svg"))
	tiles.assign(%Tiles.get_children())
	values.resize(tiles.size())
	for tile: Node3D in tiles:
		tile.hide()

func cell_position(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x) - 4.5, 0, float(cell.y) - 3.5)

## Use memory jigsaw's perspective framing without yaw; preserve the pointer surface across aspects.
## Account for the near board edge's larger projection as well as viewport aspect.
func frame_surface(surface: Rect2) -> void:
	if surface.size.y <= 0.0:
		return
	var pitch: float = deg_to_rad(68.0)
	var aspect: float = surface.size.x / surface.size.y
	var tangent: float = tan(deg_to_rad(25.0))
	camera.fov = rad_to_deg(2.0 * atan(tangent * get_viewport().get_visible_rect().size.y / surface.size.y))
	var half_width: float = 6.9
	var half_depth: float = 6.0
	var distance: float = maxf(half_width / (tangent * aspect), half_depth * sin(pitch) / tangent) + half_depth * cos(pitch)
	camera.position = Vector3(0, sin(pitch), cos(pitch)) * distance
	camera.look_at(Vector3.ZERO)

## Hit only the thin piece volume; removed cells and the gaps remain unselectable.
func pick(screen_position: Vector2) -> int:
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.project_ray_normal(screen_position)
	var closest: float = INF
	var result: int = -1
	for index: int in tiles.size():
		if values[index] == 0:
			continue
		var bounds: AABB = AABB(tiles[index].global_position - Piece.SIZE * 0.5, Piece.SIZE)
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
				tiles[index].set_artwork(textures[value - 1])
				tiles[index].scale = Vector3.ONE
				tiles[index].show()
			values[index] = value
		var hinted: bool = Vector2i(index % 10, index / 10) in hints
		tiles[index].set_lifted(index == selected, hinted)

func show_path(cells: Array, color: Color) -> void:
	for child: Node in path_nodes.get_children():
		child.free()
	path_time = 0.65
	path_nodes.show()
	var material: StandardMaterial3D = _material(color, true)
	for index: int in cells.size():
		var point: Vector3 = cell_position(cells[index]) + Vector3(0, 0.20, 0)
		_sphere(path_nodes, point, Vector3.ONE * 0.13, material)
		if index > 0:
			var previous: Vector3 = cell_position(cells[index - 1]) + Vector3(0, 0.20, 0)
			_rod(path_nodes, previous, point, 0.045, material)

func advance(delta: float) -> void:
	for tile: Node3D in tiles:
		tile.advance(delta)
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
