class_name RoomBlockDefinition
extends RefCounted

var id: int
var block_type: int
var cell: Vector2i
var hit_points: int
var vulnerable_sides: int


func _init(
	block_id: int = 0,
	type: int = BlockState.BlockType.NORMAL,
	block_cell: Vector2i = Vector2i.ZERO,
	initial_hit_points: int = 1,
	block_vulnerable_sides: int = BlockState.ALL_VULNERABLE_SIDES,
) -> void:
	id = block_id
	block_type = type
	cell = block_cell
	hit_points = initial_hit_points
	vulnerable_sides = block_vulnerable_sides


func create_block() -> BlockState:
	return BlockState.new(id, block_type, cell, hit_points, vulnerable_sides)
