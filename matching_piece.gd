extends Node3D
## Adapted from memory jigsaw's puzzle_piece: thin ivory body and textured upper face.
## Kept inside this package so installing Lianliankan does not require another minigame.
const SIZE: Vector3 = Vector3(0.94, 0.14, 0.94)
const REST_HEIGHT: float = 0.09
const LIFT_HEIGHT: float = 0.23
@onready var side_material: StandardMaterial3D = $Body.material_override
@onready var face_material: StandardMaterial3D = $Face.material_override
var lifted: bool = false

func set_artwork(texture: Texture2D) -> void:
	face_material.albedo_texture = texture

func set_lifted(value: bool, hinted: bool) -> void:
	lifted = value
	side_material.albedo_color = Color("efbd59") if value else (Color("f6dda0") if hinted else Color("eee4cb"))

func advance(delta: float) -> void:
	var height: float = LIFT_HEIGHT if lifted else REST_HEIGHT
	position.y = lerpf(position.y, height, 1.0 - exp(-18.0 * delta))
