class_name BlockContactEvent
extends RefCounted

var block_id: int
var block_type: int
var position_world: Vector2
var normal: Vector2


func _init(
	contact_block_id: int,
	contact_block_type: int,
	contact_position_world: Vector2,
	contact_normal: Vector2,
) -> void:
	block_id = contact_block_id
	block_type = contact_block_type
	position_world = contact_position_world
	normal = contact_normal
