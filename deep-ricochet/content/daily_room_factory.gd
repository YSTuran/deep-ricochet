class_name DailyRoomFactory
extends RefCounted

const DAILY_MINE_ID := &"daily"
const SOURCE_MINE_ID := &"mine_07"
const TARGET_BLOCK_COUNT := 14
const DENSITY_TYPES: Array[int] = [
	BlockState.BlockType.NORMAL,
	BlockState.BlockType.ORE,
	BlockState.BlockType.ROCK,
	BlockState.BlockType.EXPLOSIVE,
	BlockState.BlockType.CRACKED,
	BlockState.BlockType.ARMORED,
]


static func append_daily_templates(
	templates: Array[RoomTemplate],
	content_version: String,
) -> bool:
	var sources: Array[RoomTemplate] = []
	for template: RoomTemplate in templates:
		if template.mine_id == SOURCE_MINE_ID:
			sources.append(template)
	if sources.size() != 14:
		push_error("Günlük oda üretimi tam 14 adet seviye 7 şablonu gerektirir.")
		return false

	for source_index in range(sources.size()):
		var daily_template := _create_daily_template(
			sources[source_index],
			source_index,
			content_version,
		)
		if daily_template == null:
			return false
		templates.append(daily_template)
	return true


static func _create_daily_template(
	source: RoomTemplate,
	source_index: int,
	content_version: String,
) -> RoomTemplate:
	var template := RoomTemplate.new()
	template.room_id = StringName("daily_%s" % source.room_id)
	template.display_name = "Günlük %s" % source.display_name
	template.display_name_key = source.display_name_key
	template.mine_id = DAILY_MINE_ID
	template.role = source.role
	template.family = source.family
	template.content_version = content_version
	template.width = source.width
	template.height = source.height
	template.multiplier_bps = source.multiplier_bps
	template.passage_columns = source.passage_columns.duplicate()
	template.example_angles = _example_angles_for(template.room_id)

	var occupied: Dictionary[Vector2i, bool] = {}
	var present_types: Dictionary[int, bool] = {}
	var next_id := 900_000 + source_index * 100
	for definition: RoomBlockDefinition in source.blocks:
		next_id += 1
		template.blocks.append(RoomBlockDefinition.new(
			next_id,
			definition.block_type,
			definition.cell,
			definition.hit_points,
			definition.vulnerable_sides,
		))
		occupied[definition.cell] = true
		present_types[definition.block_type] = true

	var candidates := _candidate_cells(template, occupied, source_index)
	for block_type: int in DENSITY_TYPES:
		if present_types.has(block_type):
			continue
		if not _append_block(template, candidates, block_type, next_id + 1, source_index):
			return null
		next_id += 1
		present_types[block_type] = true

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
	var candidates: Array[Vector2i] = []
	for offset in range(BoardGeometry.BLOCK_GRID_SIZE.x * BoardGeometry.BLOCK_GRID_SIZE.y):
		var x := (offset % BoardGeometry.BLOCK_GRID_SIZE.x + variant * 3) \
			% BoardGeometry.BLOCK_GRID_SIZE.x
		var y := (floori(float(offset) / float(BoardGeometry.BLOCK_GRID_SIZE.x)) + variant) \
			% BoardGeometry.BLOCK_GRID_SIZE.y
		var cell := Vector2i(x, y)
		if template.passage_columns.has(x) or occupied.has(cell):
			continue
		candidates.append(cell)
	return candidates


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
	var cell: Vector2i = candidates.pop_front()
	var vulnerable_sides := BlockState.ALL_VULNERABLE_SIDES
	if block_type == BlockState.BlockType.ARMORED:
		vulnerable_sides = BlockState.VulnerableSide.BOTTOM
		if variant % 2 == 1:
			vulnerable_sides |= BlockState.VulnerableSide.LEFT
	template.blocks.append(RoomBlockDefinition.new(
		block_id,
		block_type,
		cell,
		_hit_points_for(block_type),
		vulnerable_sides,
	))
	return true


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
			return 1
		BlockState.BlockType.ARMORED:
			return 6
	return 1


static func _example_angles_for(room_id: StringName) -> PackedFloat32Array:
	match str(room_id):
		"daily_m7_start_a":
			return PackedFloat32Array([15.0, 16.0, 17.0])
		"daily_m7_start_b":
			return PackedFloat32Array([15.0, 15.5, 16.5])
		"daily_m7_wide_01_a":
			return PackedFloat32Array([20.0, 20.5, 21.0])
		"daily_m7_wide_01_b":
			return PackedFloat32Array([15.0, 16.0, 20.0])
		"daily_m7_wide_02_a":
			return PackedFloat32Array([18.0, 18.5, 19.5])
		"daily_m7_wide_02_b":
			return PackedFloat32Array([15.5, 24.0, 24.5])
		"daily_m7_wide_03_a":
			return PackedFloat32Array([15.5, 16.0, 18.5])
		"daily_m7_wide_03_b":
			return PackedFloat32Array([15.0, 15.5, 16.0])
		"daily_m7_narrow_01_a", "daily_m7_narrow_01_b":
			return PackedFloat32Array([15.0, 15.5, 16.0])
		"daily_m7_narrow_02_a":
			return PackedFloat32Array([17.5, 18.0, 19.5])
		"daily_m7_narrow_02_b":
			return PackedFloat32Array([54.5, 55.0, 55.5])
		"daily_m7_narrow_03_a":
			return PackedFloat32Array([15.0, 15.5, 16.0])
		"daily_m7_narrow_03_b":
			return PackedFloat32Array([17.5, 20.0, 25.0])
	return PackedFloat32Array([90.0])
