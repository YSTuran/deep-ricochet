class_name BoardModel
extends RefCounted

const ROOM_GRID_SIZE := BoardGeometry.BLOCK_GRID_SIZE
const CORE_TARGET_ROW := BoardGeometry.CORE_ROW

var blocks: Array[BlockState] = []


func add_block(block: BlockState) -> bool:
	if not _is_valid_cell_for_type(block.cell, block.type):
		return false
	if get_block_at(block.cell) != null:
		return false
	if get_block_by_id(block.id) != null:
		return false
	if block.type == BlockState.BlockType.CORE and core_count() > 0:
		return false
	blocks.append(block)
	return true


func get_block_at(cell: Vector2i) -> BlockState:
	for block: BlockState in blocks:
		if block.cell == cell:
			return block
	return null


func get_block_by_id(block_id: int) -> BlockState:
	for block: BlockState in blocks:
		if block.id == block_id:
			return block
	return null


func core_count() -> int:
	var count := 0
	for block: BlockState in blocks:
		if block.type == BlockState.BlockType.CORE:
			count += 1
	return count


func is_core_destroyed() -> bool:
	for block: BlockState in blocks:
		if block.type == BlockState.BlockType.CORE:
			return block.is_destroyed()
	return false


func resolve_contact(block_id: int, damage: int = 1) -> BlockDamageResult:
	var result := BlockDamageResult.new()
	var block := get_block_by_id(block_id)
	if block == null or block.is_destroyed():
		return result

	result.block_id = block.id
	result.block_type = int(block.type)
	result.contact_valid = true
	result.remaining_hit_points = block.hit_points
	if block.apply_damage(damage):
		result.damage_applied = true
		result.destroyed = block.is_destroyed()
		result.remaining_hit_points = block.hit_points
	return result


func _is_valid_cell_for_type(cell: Vector2i, block_type: BlockState.BlockType) -> bool:
	if cell.x < 0 or cell.x >= ROOM_GRID_SIZE.x:
		return false
	if block_type == BlockState.BlockType.CORE:
		return cell.y == CORE_TARGET_ROW
	return cell.y >= 0 and cell.y < ROOM_GRID_SIZE.y
