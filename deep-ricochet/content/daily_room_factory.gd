class_name DailyRoomFactory
extends RefCounted

const DAILY_MINE_ID := &"daily"
const SOURCE_MINE_ID := &"mine_28"
const CONTENT_VERSION := "daily-10"
const CRACKED_HIT_POINTS := 8
const TARGET_BLOCK_COUNT := 24
const SOURCE_ROOM_IDS: Array[StringName] = [
	&"m28_start",
	&"m28_wide_01",
	&"m28_wide_02",
	&"m28_wide_03",
	&"m28_narrow_01",
	&"m28_narrow_02",
	&"m28_narrow_03",
]
const VERIFIED_EXAMPLE_ANGLES := {
	"daily_m28_start_a": 35.0,
	"daily_m28_start_b": 165.0,
	"daily_m28_wide_01_a": 27.5,
	"daily_m28_wide_01_b": 152.5,
	"daily_m28_wide_02_a": 103.0,
	"daily_m28_wide_02_b": 76.0,
	"daily_m28_wide_03_a": 110.5,
	"daily_m28_wide_03_b": 69.5,
	"daily_m28_narrow_01_a": 15.0,
	"daily_m28_narrow_01_b": 165.0,
	"daily_m28_narrow_02_a": 84.5,
	"daily_m28_narrow_02_b": 95.5,
	"daily_m28_narrow_03_a": 85.5,
	"daily_m28_narrow_03_b": 94.5,
}
const DENSITY_TYPES: Array[int] = [
	BlockState.BlockType.NORMAL,
	BlockState.BlockType.ORE,
	BlockState.BlockType.ROCK,
	BlockState.BlockType.EXPLOSIVE,
	BlockState.BlockType.CRACKED,
	BlockState.BlockType.ARMORED,
	BlockState.BlockType.ECHO,
	BlockState.BlockType.BALL_CACHE,
	BlockState.BlockType.PIERCING,
]


static func append_daily_templates(
	templates: Array[RoomTemplate],
	content_version: String,
) -> bool:
	var sources_by_id: Dictionary[StringName, RoomTemplate] = {}
	for template: RoomTemplate in templates:
		if template.mine_id == SOURCE_MINE_ID:
			sources_by_id[template.room_id] = template
	if sources_by_id.size() != SOURCE_ROOM_IDS.size():
		push_error("Günlük oda üretimi tam 7 adet seviye 28 şablonu gerektirir.")
		return false

	for source_index in range(SOURCE_ROOM_IDS.size()):
		var source: RoomTemplate = sources_by_id.get(SOURCE_ROOM_IDS[source_index])
		if source == null:
			push_error("Günlük oda kaynağı eksik: %s" % SOURCE_ROOM_IDS[source_index])
			return false
		for mirrored in [false, true]:
			var variant_index := source_index * 2 + (1 if mirrored else 0)
			var daily_template := _create_daily_template(
				source,
				variant_index,
				content_version,
				mirrored,
			)
			if daily_template == null:
				return false
			templates.append(daily_template)
	return true


static func _create_daily_template(
	source: RoomTemplate,
	source_index: int,
	content_version: String,
	mirrored: bool,
) -> RoomTemplate:
	var template := RoomTemplate.new()
	var suffix := "b" if mirrored else "a"
	template.room_id = StringName("daily_%s_%s" % [source.room_id, suffix])
	template.display_name = "Günlük %s" % source.display_name
	template.display_name_key = source.display_name_key
	template.mine_id = DAILY_MINE_ID
	template.role = source.role
	template.family = source.family
	template.content_version = content_version
	template.width = source.width
	template.height = source.height
	template.multiplier_bps = source.multiplier_bps
	template.passage_columns = _mirrored_columns(source.passage_columns) \
		if mirrored else source.passage_columns.duplicate()
	var verified_angle := float(VERIFIED_EXAMPLE_ANGLES.get(str(template.room_id), -1.0))
	if verified_angle < 0.0:
		push_error("Günlük oda için doğrulanmış örnek açı bulunamadı: %s" % template.room_id)
		return null
	template.example_angles = PackedFloat32Array([
		verified_angle,
		verified_angle,
		verified_angle,
	])

	var occupied: Dictionary[Vector2i, bool] = {}
	var present_types: Dictionary[int, bool] = {}
	var next_id := 900_000 + source_index * 100
	for definition: RoomBlockDefinition in source.blocks:
		next_id += 1
		var cell := definition.cell
		var vulnerable_sides := definition.vulnerable_sides
		var beam_direction := definition.beam_direction
		if mirrored:
			cell = Vector2i(template.width - 1 - cell.x, cell.y)
			vulnerable_sides = _mirrored_vulnerable_sides(vulnerable_sides)
			beam_direction = _mirrored_beam_direction(beam_direction)
		template.blocks.append(RoomBlockDefinition.new(
			next_id,
			definition.block_type,
			cell,
			definition.hit_points,
			vulnerable_sides,
			beam_direction,
		))
		occupied[cell] = true
		present_types[definition.block_type] = true

	var candidates := _candidate_cells(template, occupied, source_index)
	_reserve_existing_armor_access(template, candidates)
	var type_counts := _type_counts(template)
	for block_type: int in DENSITY_TYPES:
		if present_types.has(block_type):
			continue
		if template.blocks.size() < TARGET_BLOCK_COUNT:
			if not _append_block(template, candidates, block_type, next_id + 1, source_index):
				return null
			next_id += 1
		else:
			if not _replace_redundant_block(
				template,
				candidates,
				type_counts,
				block_type,
				source_index,
			):
				return null
		type_counts[block_type] = type_counts.get(block_type, 0) + 1
		present_types[block_type] = true
	if template.blocks.size() < TARGET_BLOCK_COUNT:
		if not _append_block(template, candidates, BlockState.BlockType.ACID_BARREL, next_id + 1, source_index):
			return null
		next_id += 1
	elif not _replace_redundant_block(
		template, candidates, type_counts, BlockState.BlockType.ACID_BARREL, source_index,
	):
		return null
	type_counts[BlockState.BlockType.ACID_BARREL] = 1

	var density_index := source_index
	while template.blocks.size() < TARGET_BLOCK_COUNT:
		var block_type: int = DENSITY_TYPES[density_index % DENSITY_TYPES.size()]
		if not _append_block(template, candidates, block_type, next_id + 1, density_index):
			return null
		next_id += 1
		density_index += 1

	var errors := template.validation_errors()
	if not errors.is_empty():
		push_error("Günlük oda üretilemedi (%s):\n- %s" % [
			template.room_id,
			"\n- ".join(errors),
		])
		return null
	return template


static func _candidate_cells(
	template: RoomTemplate,
	occupied: Dictionary[Vector2i, bool],
	variant: int,
) -> Array[Vector2i]:
	var central_candidates: Array[Vector2i] = []
	var top_candidates: Array[Vector2i] = []
	var solution_cells := _solution_cells(template)
	for offset in range(BoardGeometry.BLOCK_GRID_SIZE.x * BoardGeometry.BLOCK_GRID_SIZE.y):
		var x := (offset % BoardGeometry.BLOCK_GRID_SIZE.x + variant * 3) \
			% BoardGeometry.BLOCK_GRID_SIZE.x
		var y := (floori(float(offset) / float(BoardGeometry.BLOCK_GRID_SIZE.x)) + variant) \
			% BoardGeometry.BLOCK_GRID_SIZE.y
		var cell := Vector2i(x, y)
		if y < RoomTemplate.MIN_BLOCK_ROW \
			or (template.passage_columns.has(x) and y <= RoomTemplate.PASSAGE_CLEAR_MAX_ROW) \
			or solution_cells.has(cell) \
			or occupied.has(cell):
			continue
		if y >= BoardGeometry.BLOCK_GRID_SIZE.y - 2:
			top_candidates.append(cell)
		else:
			central_candidates.append(cell)
	central_candidates.append_array(top_candidates)
	return central_candidates


static func _mirrored_columns(columns: PackedInt32Array) -> PackedInt32Array:
	var mirrored := PackedInt32Array()
	for column: int in columns:
		mirrored.append(BoardGeometry.BLOCK_GRID_SIZE.x - 1 - column)
	mirrored.sort()
	return mirrored


static func _solution_cells(template: RoomTemplate) -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	var core_cell := Vector2i(-1, -1)
	for definition: RoomBlockDefinition in template.blocks:
		if definition.block_type == BlockState.BlockType.CORE:
			core_cell = definition.cell
			break
	if core_cell.x < 0:
		return cells
	var launcher := BoardGeometry.LAUNCHER_WORLD
	var core_center := Vector2(core_cell) + Vector2.ONE * 0.5
	for y in range(RoomTemplate.MIN_BLOCK_ROW, core_cell.y):
		var sample_y := float(y) + 0.5
		var progress := (sample_y - launcher.y) / (core_center.y - launcher.y)
		var sample_x := launcher.x + (core_center.x - launcher.x) * progress
		cells[Vector2i(clampi(floori(sample_x), 0, 7), y)] = true
	return cells


static func _mirrored_vulnerable_sides(sides: int) -> int:
	var mirrored := sides & ~(BlockState.VulnerableSide.LEFT | BlockState.VulnerableSide.RIGHT)
	if (sides & BlockState.VulnerableSide.LEFT) != 0:
		mirrored |= BlockState.VulnerableSide.RIGHT
	if (sides & BlockState.VulnerableSide.RIGHT) != 0:
		mirrored |= BlockState.VulnerableSide.LEFT
	return mirrored


static func _mirrored_beam_direction(direction: int) -> int:
	if direction == BlockState.BeamDirection.LEFT:
		return BlockState.BeamDirection.RIGHT
	if direction == BlockState.BeamDirection.RIGHT:
		return BlockState.BeamDirection.LEFT
	return direction


static func _append_block(
	template: RoomTemplate,
	candidates: Array[Vector2i],
	block_type: int,
	block_id: int,
	variant: int,
) -> bool:
	if candidates.is_empty():
		push_error("Günlük oda yoğunluğu için boş hücre kalmadı: %s" % template.room_id)
		return false
	var candidate_index := 0
	if block_type == BlockState.BlockType.ARMORED:
		candidate_index = _first_armored_candidate_index(template, candidates)
		if candidate_index < 0:
			push_error("Günlük zırh için erişilebilir zayıf kenar bulunamadı: %s" % template.room_id)
			return false
	elif block_type == BlockState.BlockType.PIERCING:
		candidate_index = _first_piercing_candidate_index(template, candidates, variant)
		if candidate_index < 0:
			push_error("Günlük ışık kristali için destekli ışın hattı bulunamadı: %s" % template.room_id)
			return false
	elif block_type == BlockState.BlockType.ACID_BARREL:
		candidate_index = -1
		for index in range(candidates.size()):
			if _acid_cell_valid(template, candidates[index]):
				candidate_index = index
				break
		if candidate_index < 0:
			push_error("Günlük asit varili için uygun hücre bulunamadı: %s" % template.room_id)
			return false
	var cell: Vector2i = candidates.pop_at(candidate_index)
	var vulnerable_sides := BlockState.ALL_VULNERABLE_SIDES
	var beam_direction := BlockState.BeamDirection.NONE
	if block_type == BlockState.BlockType.ARMORED:
		vulnerable_sides = BlockState.VulnerableSide.BOTTOM
		_reserve_candidate(candidates, cell + Vector2i.UP)
		var preferred_side := BlockState.VulnerableSide.LEFT \
			if variant % 2 == 1 else BlockState.VulnerableSide.RIGHT
		var side_neighbor := RoomTemplate._neighbor_for_side(cell, preferred_side)
		if _cell_is_open(template, side_neighbor):
			vulnerable_sides |= preferred_side
			_reserve_candidate(candidates, side_neighbor)
	elif block_type == BlockState.BlockType.PIERCING:
		beam_direction = _piercing_direction_for_cell(template, cell, variant)
	template.blocks.append(RoomBlockDefinition.new(
		block_id,
		block_type,
		cell,
		_hit_points_for(block_type),
		vulnerable_sides,
		beam_direction,
	))
	return true


static func _replace_redundant_block(
	template: RoomTemplate,
	candidates: Array[Vector2i],
	type_counts: Dictionary,
	new_type: int,
	variant: int,
) -> bool:
	for definition: RoomBlockDefinition in template.blocks:
		if definition.block_type in [BlockState.BlockType.CORE, BlockState.BlockType.ROCK] \
			or int(type_counts.get(definition.block_type, 0)) <= 1:
			continue
		if new_type == BlockState.BlockType.ARMORED \
			and not _cell_is_open(template, definition.cell + Vector2i.UP):
			continue
		if new_type == BlockState.BlockType.ACID_BARREL \
			and not _acid_cell_valid(template, definition.cell):
			continue
		var piercing_direction := BlockState.BeamDirection.NONE
		if new_type == BlockState.BlockType.PIERCING:
			piercing_direction = _piercing_direction_for_cell(
				template,
				definition.cell,
				variant,
			)
			if piercing_direction == BlockState.BeamDirection.NONE:
				continue
		var previous_type := definition.block_type
		definition.block_type = new_type
		definition.hit_points = _hit_points_for(new_type)
		definition.vulnerable_sides = BlockState.ALL_VULNERABLE_SIDES
		definition.beam_direction = BlockState.BeamDirection.NONE
		if new_type == BlockState.BlockType.ARMORED:
			definition.vulnerable_sides = BlockState.VulnerableSide.BOTTOM
			_reserve_candidate(candidates, definition.cell + Vector2i.UP)
			var preferred_side := BlockState.VulnerableSide.LEFT \
				if variant % 2 == 1 else BlockState.VulnerableSide.RIGHT
			var side_neighbor := RoomTemplate._neighbor_for_side(definition.cell, preferred_side)
			if _cell_is_open(template, side_neighbor):
				definition.vulnerable_sides |= preferred_side
				_reserve_candidate(candidates, side_neighbor)
		elif new_type == BlockState.BlockType.PIERCING:
			definition.beam_direction = piercing_direction
		type_counts[previous_type] = int(type_counts[previous_type]) - 1
		return true
	push_error("Günlük oda için dönüştürülebilir blok bulunamadı: %s" % template.room_id)
	return false


static func _type_counts(template: RoomTemplate) -> Dictionary:
	var counts: Dictionary = {}
	for definition: RoomBlockDefinition in template.blocks:
		counts[definition.block_type] = counts.get(definition.block_type, 0) + 1
	return counts


static func _reserve_existing_armor_access(
	template: RoomTemplate,
	candidates: Array[Vector2i],
) -> void:
	for definition: RoomBlockDefinition in template.blocks:
		if definition.block_type != BlockState.BlockType.ARMORED:
			continue
		for side: int in [
			BlockState.VulnerableSide.LEFT,
			BlockState.VulnerableSide.RIGHT,
			BlockState.VulnerableSide.TOP,
			BlockState.VulnerableSide.BOTTOM,
		]:
			if (definition.vulnerable_sides & side) != 0:
				_reserve_candidate(
					candidates,
					RoomTemplate._neighbor_for_side(definition.cell, side),
				)


static func _first_armored_candidate_index(
	template: RoomTemplate,
	candidates: Array[Vector2i],
) -> int:
	for index in range(candidates.size()):
		var cell := candidates[index]
		if _cell_is_open(template, cell + Vector2i.UP):
			return index
	return -1


static func _first_piercing_candidate_index(
	template: RoomTemplate,
	candidates: Array[Vector2i],
	variant: int,
) -> int:
	for index in range(candidates.size()):
		if _piercing_direction_for_cell(template, candidates[index], variant) \
			!= BlockState.BeamDirection.NONE:
			return index
	return -1


static func _piercing_direction_for_cell(
	template: RoomTemplate,
	cell: Vector2i,
	variant: int,
) -> int:
	var directions := [
		BlockState.BeamDirection.UP,
		BlockState.BeamDirection.RIGHT,
		BlockState.BeamDirection.DOWN,
		BlockState.BeamDirection.LEFT,
	]
	var rotation := posmod(variant + cell.x + cell.y, directions.size())
	for offset in range(directions.size()):
		var direction: int = directions[posmod(rotation + offset, directions.size())]
		var step := BlockState.beam_vector(direction)
		var support_cell := cell - step
		if _cell_is_inside_world(support_cell) and _definition_at(template, support_cell) == null:
			continue
		var ray_cell := cell + step
		while _cell_is_inside_world(ray_cell):
			var target := _definition_at(template, ray_cell)
			if target != null and target.cell != cell \
				and target.block_type != BlockState.BlockType.ROCK:
				return direction
			ray_cell += step
	return BlockState.BeamDirection.NONE


static func _definition_at(template: RoomTemplate, cell: Vector2i) -> RoomBlockDefinition:
	for definition: RoomBlockDefinition in template.blocks:
		if definition.cell == cell:
			return definition
	return null


static func _acid_cell_valid(template: RoomTemplate, cell: Vector2i) -> bool:
	var neighbors := 0
	for definition: RoomBlockDefinition in template.blocks:
		if definition.cell == cell or definition.block_type == BlockState.BlockType.ROCK:
			continue
		var offset := definition.cell - cell
		if maxi(absi(offset.x), absi(offset.y)) <= 2:
			neighbors += 1
	return neighbors >= 2


static func _cell_is_inside_world(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BoardGeometry.WORLD_GRID_SIZE.x \
		and cell.y >= 0 and cell.y < BoardGeometry.WORLD_GRID_SIZE.y


static func _cell_is_open(template: RoomTemplate, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= BoardGeometry.WORLD_GRID_SIZE.x \
		or cell.y < 0 or cell.y >= BoardGeometry.WORLD_GRID_SIZE.y:
		return false
	for definition: RoomBlockDefinition in template.blocks:
		if definition.cell == cell:
			return false
	return true


static func _reserve_candidate(candidates: Array[Vector2i], cell: Vector2i) -> void:
	candidates.erase(cell)


static func _hit_points_for(block_type: int) -> int:
	match block_type:
		BlockState.BlockType.NORMAL:
			return 8
		BlockState.BlockType.ORE:
			return 8
		BlockState.BlockType.ROCK:
			return 0
		BlockState.BlockType.EXPLOSIVE:
			return 5
		BlockState.BlockType.CRACKED:
			return CRACKED_HIT_POINTS
		BlockState.BlockType.ARMORED:
			return 6
		BlockState.BlockType.ECHO:
			return RoomTemplate.ECHO_HIT_POINTS
		BlockState.BlockType.BALL_CACHE:
			return RoomTemplate.BALL_CACHE_HIT_POINTS
		BlockState.BlockType.PIERCING:
			return RoomTemplate.PIERCING_HIT_POINTS
		BlockState.BlockType.ACID_BARREL:
			return RoomTemplate.ACID_BARREL_HIT_POINTS
	return 1
