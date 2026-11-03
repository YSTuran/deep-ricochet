class_name AimPreviewResult
extends RefCounted

var points: PackedVector2Array = PackedVector2Array()
var has_terminal_contact: bool = false
var contact_position_world: Vector2 = Vector2.ZERO
var contact_block_id: int = -1


func _init(origin: Vector2 = Vector2.ZERO) -> void:
	points.append(origin)

