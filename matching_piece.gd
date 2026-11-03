extends Node3D
## Adapted from memory jigsaw's puzzle_piece: thin ivory body and textured upper face.
## Kept inside this package so installing Lianliankan does not require another minigame.
const SIZE: Vector3 = Vector3(0.94, 0.14, 0.94)
const REST_HEIGHT: float = 0.09
const LIFT_HEIGHT: float = 0.23
var side_material: StandardMaterial3D
var face_material: StandardMaterial3D
var lifted: bool = false

func _ready() -> void:
	side_material = StandardMaterial3D.new()
	side_material.albedo_color = Color("eee4cb")
	side_material.roughness = 0.72
	var body: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = SIZE
	body.mesh = box
	body.material_override = side_material
	add_child(body)
	var face: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(0.80, 0.80)
	face.mesh = plane
	face.position.y = SIZE.y * 0.5 + 0.002
	face_material = StandardMaterial3D.new()
	face_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	face_material.roughness = 0.9
	face.material_override = face_material
	add_child(face)

func set_artwork(texture: Texture2D) -> void:
	face_material.albedo_texture = texture

func set_lifted(value: bool, hinted: bool) -> void:
	lifted = value
	side_material.albedo_color = Color("efbd59") if value else (Color("f6dda0") if hinted else Color("eee4cb"))

func advance(delta: float) -> void:
	var height: float = LIFT_HEIGHT if lifted else REST_HEIGHT
	position.y = lerpf(position.y, height, 1.0 - exp(-18.0 * delta))
