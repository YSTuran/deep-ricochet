class_name BoardModel
extends RefCounted

const GRID_SIZE := Vector2i(8, 10)

var blocks: Array[BlockState] = []


func add_block(block: BlockState) -> bool:
	if block.cell.x < 0 or block.cell.y < 0:
		return false
	if block.cell.x >= GRID_SIZE.x or block.cell.y >= GRID_SIZE.y:
		return false
	if get_block_at(block.cell) != null:
		return false
	if get_block_by_id(block.id) != null:
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
