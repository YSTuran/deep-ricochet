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


func resolve_contact(
	block_id: int,
	damage: int = 1,
	contact_normal: Vector2 = Vector2.ZERO,
) -> BlockDamageResult:
	var result := BlockDamageResult.new()
	var block := get_block_by_id(block_id)
	if block == null or block.is_destroyed():
		return result
	return _resolve_damage(block, damage, contact_normal, false)


func resolve_explosion(source_block_id: int, damage: int = 3) -> Array[BlockDamageResult]:
	var results: Array[BlockDamageResult] = []
	var source := get_block_by_id(source_block_id)
	if source == null or source.type != BlockState.BlockType.EXPLOSIVE \
		or not source.is_destroyed() or damage <= 0:
		return results

	var pending_ids: Array[int] = [source_block_id]
	var queued_ids: Dictionary[int, bool] = {source_block_id: true}
	var exploded_ids: Dictionary[int, bool] = {}
	while not pending_ids.is_empty():
		var explosive_id: int = pending_ids.pop_front()
		if exploded_ids.has(explosive_id):
			continue
		exploded_ids[explosive_id] = true
		var explosive := get_block_by_id(explosive_id)
		if explosive == null:
			continue
		for target: BlockState in blocks:
			if target.is_destroyed() or target.id == explosive_id:
				continue
			var offset := target.cell - explosive.cell
			if absi(offset.x) > 1 or absi(offset.y) > 1:
				continue
			var result := _resolve_damage(target, damage, Vector2.ZERO, true)
			if result.damage_applied:
				results.append(result)
			if result.destroyed and target.type == BlockState.BlockType.EXPLOSIVE \
				and not queued_ids.has(target.id):
				queued_ids[target.id] = true
				pending_ids.append(target.id)
	return results


func _resolve_damage(
	block: BlockState,
	damage: int,
	contact_normal: Vector2,
	is_explosion: bool,
) -> BlockDamageResult:
	var result := BlockDamageResult.new()

	result.block_id = block.id
	result.block_type = int(block.type)
	result.contact_valid = true
	result.remaining_hit_points = block.hit_points
	result.damage_amount = maxi(0, damage)
	result.is_explosion = is_explosion
	if block.type == BlockState.BlockType.ARMORED and not is_explosion \
		and not block.accepts_contact(contact_normal):
		result.blocked_by_armor = true
		return result
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
