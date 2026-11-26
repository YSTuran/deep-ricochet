class_name BoardModel
extends RefCounted

const ROOM_GRID_SIZE := BoardGeometry.BLOCK_GRID_SIZE
const CORE_TARGET_ROW := BoardGeometry.CORE_ROW
const CORE_MIN_TARGET_ROW := BoardGeometry.CORE_MIN_ROW
const EXPLOSION_RADIUS_CELLS := 2
const ACID_RADIUS_CELLS := 3

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
	return _resolve_damage(block, damage, contact_normal)


func resolve_echo(source_block_id: int, damage: int = 1) -> Array[BlockDamageResult]:
	var results: Array[BlockDamageResult] = []
	var source := get_block_by_id(source_block_id)
	if source == null or source.type != BlockState.BlockType.ECHO or damage <= 0:
		return results
	for target: BlockState in blocks:
		if target.id == source_block_id or target.type != BlockState.BlockType.ECHO \
			or target.is_destroyed():
			continue
		var result := _resolve_damage(
			target,
			damage,
			Vector2.ZERO,
			false,
			true,
		)
		if result.damage_applied:
			results.append(result)
	return results


func resolve_piercing(source_block_id: int, damage: int = 2) -> Array[BlockDamageResult]:
	var results: Array[BlockDamageResult] = []
	var source := get_block_by_id(source_block_id)
	if source == null or source.type != BlockState.BlockType.PIERCING \
		or not source.is_destroyed() or damage <= 0:
		return results
	var beam_step := BlockState.beam_vector(source.beam_direction)
	if beam_step == Vector2i.ZERO:
		return results
	var cell := source.cell + beam_step
	while _is_inside_world(cell):
		var target := get_block_at(cell)
		if target != null and not target.is_destroyed() \
			and target.type != BlockState.BlockType.ROCK:
			var result := _resolve_damage(
				target,
				damage,
				Vector2.ZERO,
				false,
				false,
				true,
				source.cell,
				source.beam_direction,
			)
			if result.damage_applied:
				results.append(result)
		cell += beam_step
	return results


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
			if absi(offset.x) > EXPLOSION_RADIUS_CELLS \
				or absi(offset.y) > EXPLOSION_RADIUS_CELLS:
				continue
			var result := _resolve_damage(target, damage, Vector2.ZERO, true)
			if result.damage_applied:
				results.append(result)
			if result.destroyed and target.type == BlockState.BlockType.EXPLOSIVE \
				and not queued_ids.has(target.id):
				queued_ids[target.id] = true
				pending_ids.append(target.id)
	return results


func resolve_acid_burst(source_block_id: int) -> Array[BlockDamageResult]:
	var results: Array[BlockDamageResult] = []
	var source := get_block_by_id(source_block_id)
	if source == null or source.type != BlockState.BlockType.ACID_BARREL \
		or not source.is_destroyed():
		return results
	for target: BlockState in blocks:
		if target.id == source_block_id or target.is_destroyed() \
			or target.type == BlockState.BlockType.ROCK:
			continue
		var offset := target.cell - source.cell
		var radius := maxi(absi(offset.x), absi(offset.y))
		if radius > ACID_RADIUS_CELLS:
			continue
		var damage := 7 if radius <= 1 else (3 if radius == 2 else 1)
		# Asit zırhı aşındırır, fakat tek seferde parçalamaz.
		if target.type == BlockState.BlockType.ARMORED:
			damage = 1
		var result := _resolve_damage(
			target,
			damage,
			Vector2.ZERO,
			false,
			false,
			false,
			Vector2i(-1, -1),
			BlockState.BeamDirection.NONE,
			true,
		)
		if result.damage_applied:
			results.append(result)
	return results


func _resolve_damage(
	block: BlockState,
	damage: int,
	contact_normal: Vector2,
	is_explosion: bool = false,
	is_echo: bool = false,
	is_piercing: bool = false,
	piercing_origin_cell: Vector2i = Vector2i(-1, -1),
	piercing_direction: int = BlockState.BeamDirection.NONE,
	is_acid: bool = false,
) -> BlockDamageResult:
	var result := BlockDamageResult.new()

	result.block_id = block.id
	result.block_type = int(block.type)
	result.contact_valid = true
	result.remaining_hit_points = block.hit_points
	result.damage_amount = maxi(0, damage)
	result.is_explosion = is_explosion
	result.is_echo = is_echo
	result.is_piercing = is_piercing
	result.is_acid = is_acid
	result.piercing_origin_cell = piercing_origin_cell
	result.piercing_direction = piercing_direction
	if block.type == BlockState.BlockType.ARMORED and not is_explosion and not is_piercing \
		and not is_acid \
		and not block.accepts_contact(contact_normal):
		result.blocked_by_armor = true
		return result
	if block.apply_damage(damage):
		result.damage_applied = true
		result.destroyed = block.is_destroyed()
		result.remaining_hit_points = block.hit_points
	return result


func _is_inside_world(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BoardGeometry.WORLD_GRID_SIZE.x \
		and cell.y >= 0 and cell.y < BoardGeometry.WORLD_GRID_SIZE.y


func _is_valid_cell_for_type(cell: Vector2i, block_type: BlockState.BlockType) -> bool:
	if cell.x < 0 or cell.x >= ROOM_GRID_SIZE.x:
		return false
	if block_type == BlockState.BlockType.CORE:
		return BoardGeometry.is_core_row(cell.y)
	return cell.y >= 0 and cell.y < ROOM_GRID_SIZE.y
