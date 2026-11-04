class_name RoomBlockDefinition
extends RefCounted

var id: int
var block_type: int
var cell: Vector2i
var hit_points: int


func _init(
	block_id: int = 0,
	type: int = BlockState.BlockType.NORMAL,
	block_cell: Vector2i = Vector2i.ZERO,
	initial_hit_points: int = 1,
) -> void:
	id = block_id
	block_type = type
	cell = block_cell
	hit_points = initial_hit_points


func create_block() -> BlockState:
	return BlockState.new(id, block_type, cell, hit_points)
