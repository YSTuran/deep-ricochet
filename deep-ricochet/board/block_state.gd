class_name BlockState
extends RefCounted

const CORE_COLLISION_RADIUS := 0.48

enum BlockType {
	NORMAL,
	ORE,
	ROCK,
	CORE,
}

var id: int
var type: BlockType
var cell: Vector2i
var hit_points: int


func _init(
	block_id: int = 0,
	block_type: BlockType = BlockType.NORMAL,
	block_cell: Vector2i = Vector2i.ZERO,
	initial_hit_points: int = 1,
) -> void:
	id = block_id
	type = block_type
	cell = block_cell
	hit_points = initial_hit_points


func is_breakable() -> bool:
	return type != BlockType.ROCK


func apply_damage(amount: int = 1) -> bool:
	if not is_breakable() or amount <= 0:
		return false
	hit_points = maxi(0, hit_points - amount)
	return true


func is_destroyed() -> bool:
	return is_breakable() and hit_points <= 0


func world_rect() -> Rect2:
	return Rect2(Vector2(float(cell.x), float(cell.y)), Vector2.ONE)


func collision_center_world() -> Vector2:
	return world_rect().get_center()


func duplicate_state() -> BlockState:
	return BlockState.new(id, type, cell, hit_points)
