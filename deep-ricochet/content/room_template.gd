class_name RoomTemplate
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 1

var schema_version: int = SUPPORTED_SCHEMA_VERSION
var room_id: StringName
var display_name: String
var multiplier_bps: int = 10_000
var blocks: Array[RoomBlockDefinition] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != SUPPORTED_SCHEMA_VERSION:
		errors.append(
			"Desteklenmeyen oda şablonu sürümü: %d (beklenen: %d)." % [
				schema_version,
				SUPPORTED_SCHEMA_VERSION,
			]
		)
	if room_id.is_empty():
		errors.append("Oda kimliği boş olamaz.")
	if display_name.strip_edges().is_empty():
		errors.append("Oda adı boş olamaz.")
	if multiplier_bps <= 0:
		errors.append("Oda çarpanı sıfırdan büyük olmalıdır.")

	var known_ids: Dictionary[int, bool] = {}
	var known_cells: Dictionary[Vector2i, bool] = {}
	var core_count := 0
	for block_index in range(blocks.size()):
		var definition := blocks[block_index]
		if definition == null:
			errors.append("%d. blok tanımı boş." % (block_index + 1))
			continue

		var label := "%d. blok" % (block_index + 1)
		if definition.id <= 0:
			errors.append("%s için kimlik sıfırdan büyük olmalıdır." % label)
		elif known_ids.has(definition.id):
			errors.append("%s yinelenen blok kimliğine sahip: %d." % [label, definition.id])
		else:
			known_ids[definition.id] = true

		if known_cells.has(definition.cell):
			errors.append("%s başka bir blokla aynı hücreyi kullanıyor: %s." % [label, definition.cell])
		else:
			known_cells[definition.cell] = true

		if not _is_known_block_type(definition.block_type):
			errors.append("%s bilinmeyen blok türüne sahip." % label)
			continue

		if definition.block_type == BlockState.BlockType.CORE:
			core_count += 1
			if definition.cell.y != BoardModel.CORE_TARGET_ROW:
				errors.append("%s çekirdek satırında olmalıdır." % label)
		elif definition.cell.y < 0 or definition.cell.y >= BoardModel.ROOM_GRID_SIZE.y:
			errors.append("%s 8x8 oda alanının dışında." % label)

		if definition.cell.x < 0 or definition.cell.x >= BoardModel.ROOM_GRID_SIZE.x:
			errors.append("%s yatay oda sınırlarının dışında." % label)

		if definition.block_type == BlockState.BlockType.ROCK:
			if definition.hit_points != 0:
				errors.append("%s sert kaya olduğu için canı 0 olmalıdır." % label)
		elif definition.hit_points <= 0:
			errors.append("%s kırılabilir olduğu için pozitif cana sahip olmalıdır." % label)

	if core_count != 1:
		errors.append("Bir oda tam olarak bir çekirdek içermelidir; bulunan: %d." % core_count)
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()


func create_board() -> BoardModel:
	if not is_valid():
		return null

	var board := BoardModel.new()
	for definition: RoomBlockDefinition in blocks:
		if not board.add_block(definition.create_block()):
			return null
	return board


func _is_known_block_type(block_type: int) -> bool:
	return block_type == BlockState.BlockType.NORMAL \
		or block_type == BlockState.BlockType.ORE \
		or block_type == BlockState.BlockType.ROCK \
		or block_type == BlockState.BlockType.CORE
