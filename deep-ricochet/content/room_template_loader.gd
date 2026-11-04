class_name RoomTemplateLoader
extends RefCounted


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
	template.family = _family_from_name(str(data.get("family", "")))
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


static func _block_from_dictionary(data: Dictionary) -> RoomBlockDefinition:
	var raw_cell: Variant = data.get("cell", [])
	var cell := Vector2i(-1, -1)
	if typeof(raw_cell) == TYPE_ARRAY and raw_cell.size() == 2:
		cell = Vector2i(int(raw_cell[0]), int(raw_cell[1]))
	return RoomBlockDefinition.new(
		int(data.get("id", 0)),
		_block_type_from_name(str(data.get("type", ""))),
		cell,
		int(data.get("hitPoints", -1)),
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
	return -1


static func _family_from_name(family_name: String) -> int:
	match family_name.to_lower():
		"safe":
			return RoomTemplate.Family.SAFE
		"bonus":
			return RoomTemplate.Family.BONUS
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
