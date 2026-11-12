class_name RoomTemplateLoader
extends RefCounted

const SAFE_FALLBACK_PATHS := [
	"res://content/rooms/safe_01.json",
	"res://content/rooms/safe_02.json",
]
const BONUS_FALLBACK_PATHS := [
	"res://content/rooms/bonus_01.json",
	"res://content/rooms/bonus_02.json",
]


static func load_from_file(path: String) -> RoomTemplate:
	if not FileAccess.file_exists(path):
		push_error("Oda şablonu bulunamadı: %s" % path)
		return null

	var json := JSON.new()
	var parse_error := json.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK:
		push_error(
			"Oda şablonu JSON olarak okunamadı (%s:%d): %s" % [
				path,
				json.get_error_line(),
				json.get_error_message(),
			]
		)
		return null
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("Oda şablonunun kökü bir JSON nesnesi olmalıdır: %s" % path)
		return null

	var template := from_dictionary(json.data)
	var errors := template.validation_errors()
	if not errors.is_empty():
		push_error("Geçersiz oda şablonu %s:\n- %s" % [path, "\n- ".join(errors)])
		return null
	return template


static func from_dictionary(data: Dictionary) -> RoomTemplate:
	var template := RoomTemplate.new()
	template.schema_version = int(data.get("schemaVersion", 0))
	template.room_id = StringName(str(data.get("id", "")))
	template.display_name = str(data.get("displayName", ""))
	template.display_name_key = StringName(str(data.get("displayNameKey", "")))
	template.mine_id = StringName(str(data.get("mineId", "mine_01")))
	template.family = _family_from_name(str(data.get("family", "")))
	template.role = _role_from_name(str(data.get(
		"role",
		"narrow" if template.family == RoomTemplate.Family.BONUS else "wide",
	)))
	template.content_version = str(data.get("contentVersion", ""))
	template.width = int(data.get("width", 0))
	template.height = int(data.get("height", 0))
	template.multiplier_bps = int(data.get("multiplierBps", 0))
	template.passage_columns = _int_array(data.get("passageColumns", []))
	template.example_angles = _float_array(data.get("exampleAngles", []))

	var raw_blocks: Variant = data.get("blocks", [])
	if typeof(raw_blocks) != TYPE_ARRAY:
		return template
	for raw_block: Variant in raw_blocks:
		if typeof(raw_block) != TYPE_DICTIONARY:
			template.blocks.append(null)
			continue
		template.blocks.append(_block_from_dictionary(raw_block))
	return template


static func create_verified_fallback_for_path(
	failed_path: String,
	content_version: String = "",
) -> RoomTemplate:
	var room_id := StringName(failed_path.get_file().get_basename())
	var family := RoomTemplate.Family.BONUS \
		if str(room_id).begins_with("bonus_") else RoomTemplate.Family.SAFE
	return create_verified_fallback(
		family,
		room_id,
		str(room_id).replace("_", " ").capitalize(),
		content_version,
		failed_path,
	)


static func repair_from_verified_fallback(template: RoomTemplate) -> bool:
	if template == null:
		return false
	var repaired := create_verified_fallback(
		template.family,
		template.room_id,
		template.display_name,
		template.content_version,
	)
	if repaired == null:
		return false
	_copy_template(repaired, template)
	return template.is_valid()


static func create_verified_fallback(
	family: int,
	room_id: StringName,
	display_name: String,
	content_version: String,
	excluded_path: String = "",
) -> RoomTemplate:
	var normalized_family := RoomTemplate.Family.BONUS \
		if family == RoomTemplate.Family.BONUS else RoomTemplate.Family.SAFE
	var fallback_paths: Array = BONUS_FALLBACK_PATHS \
		if normalized_family == RoomTemplate.Family.BONUS else SAFE_FALLBACK_PATHS
	for fallback_path: String in fallback_paths:
		if fallback_path == excluded_path:
			continue
		var source := load_from_file(fallback_path)
		if source == null:
			continue
		var repaired := RoomTemplate.new()
		_copy_template(source, repaired)
		repaired.room_id = room_id if not room_id.is_empty() else source.room_id
		repaired.display_name = display_name if not display_name.strip_edges().is_empty() \
			else source.display_name
		repaired.content_version = content_version if not content_version.strip_edges().is_empty() \
			else source.content_version
		return repaired if repaired.is_valid() else null
	return null


static func _copy_template(source: RoomTemplate, target: RoomTemplate) -> void:
	target.schema_version = source.schema_version
	target.room_id = source.room_id
	target.display_name = source.display_name
	target.display_name_key = source.display_name_key
	target.mine_id = source.mine_id
	target.role = source.role
	target.family = source.family
	target.content_version = source.content_version
	target.width = source.width
	target.height = source.height
	target.multiplier_bps = source.multiplier_bps
	target.passage_columns = source.passage_columns.duplicate()
	target.example_angles = source.example_angles.duplicate()
	target.blocks.clear()
	for definition: RoomBlockDefinition in source.blocks:
		target.blocks.append(RoomBlockDefinition.new(
			definition.id,
			definition.block_type,
			definition.cell,
			definition.hit_points,
			definition.vulnerable_sides,
		))


static func _block_from_dictionary(data: Dictionary) -> RoomBlockDefinition:
	var raw_cell: Variant = data.get("cell", [])
	var cell := Vector2i(-1, -1)
	if typeof(raw_cell) == TYPE_ARRAY and raw_cell.size() == 2:
		cell = Vector2i(int(raw_cell[0]), int(raw_cell[1]))
	var block_type := _block_type_from_name(str(data.get("type", "")))
	return RoomBlockDefinition.new(
		int(data.get("id", 0)),
		block_type,
		cell,
		int(data.get("hitPoints", -1)),
		_vulnerable_sides_from_value(
			data.get("vulnerableSides", []),
			block_type == BlockState.BlockType.ARMORED,
		),
	)


static func _block_type_from_name(type_name: String) -> int:
	match type_name.to_lower():
		"normal":
			return BlockState.BlockType.NORMAL
		"ore":
			return BlockState.BlockType.ORE
		"rock":
			return BlockState.BlockType.ROCK
		"core":
			return BlockState.BlockType.CORE
		"explosive":
			return BlockState.BlockType.EXPLOSIVE
		"cracked":
			return BlockState.BlockType.CRACKED
		"armored":
			return BlockState.BlockType.ARMORED
	return -1


static func _vulnerable_sides_from_value(value: Variant, required: bool) -> int:
	if not required:
		return BlockState.ALL_VULNERABLE_SIDES
	if typeof(value) != TYPE_ARRAY:
		return 0
	var mask := 0
	for raw_side: Variant in value:
		match str(raw_side).to_lower():
			"left":
				mask |= BlockState.VulnerableSide.LEFT
			"right":
				mask |= BlockState.VulnerableSide.RIGHT
			"top":
				mask |= BlockState.VulnerableSide.TOP
			"bottom":
				mask |= BlockState.VulnerableSide.BOTTOM
	return mask


static func _family_from_name(family_name: String) -> int:
	match family_name.to_lower():
		"safe":
			return RoomTemplate.Family.SAFE
		"bonus":
			return RoomTemplate.Family.BONUS
	return -1


static func _role_from_name(role_name: String) -> int:
	match role_name.to_lower():
		"start":
			return RoomTemplate.Role.START
		"wide":
			return RoomTemplate.Role.WIDE
		"narrow":
			return RoomTemplate.Role.NARROW
	return -1


static func _int_array(value: Variant) -> PackedInt32Array:
	var result := PackedInt32Array()
	if typeof(value) != TYPE_ARRAY:
		return result
	for item: Variant in value:
		result.append(int(item))
	return result


static func _float_array(value: Variant) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	if typeof(value) != TYPE_ARRAY:
		return result
	for item: Variant in value:
		result.append(float(item))
	return result
