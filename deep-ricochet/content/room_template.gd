class_name RoomTemplate
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 1
const SAFE_MULTIPLIER_BPS := 10_000
const BONUS_MULTIPLIER_BPS := 15_000
const MAX_ROCK_COUNT := 10

enum Family {
	SAFE,
	BONUS,
}

var schema_version: int = SUPPORTED_SCHEMA_VERSION
var room_id: StringName
var display_name: String
var family: int = Family.SAFE
var content_version: String
var width: int = BoardModel.ROOM_GRID_SIZE.x
var height: int = BoardModel.ROOM_GRID_SIZE.y
var multiplier_bps: int = 10_000
var passage_columns := PackedInt32Array()
var example_angles := PackedFloat32Array()
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
	if content_version.strip_edges().is_empty():
		errors.append("İçerik sürümü boş olamaz.")
	if family != Family.SAFE and family != Family.BONUS:
		errors.append("Oda ailesi safe veya bonus olmalıdır.")
	if width != BoardModel.ROOM_GRID_SIZE.x or height != BoardModel.ROOM_GRID_SIZE.y:
		errors.append("Oda ölçüsü 8x8 olmalıdır.")
	var expected_multiplier := 0
	if family == Family.SAFE:
		expected_multiplier = SAFE_MULTIPLIER_BPS
	elif family == Family.BONUS:
		expected_multiplier = BONUS_MULTIPLIER_BPS
	if expected_multiplier > 0 and multiplier_bps != expected_multiplier:
		errors.append(
			"Oda ailesi ile çarpan uyuşmuyor; beklenen: %d." % expected_multiplier
		)
	_validate_passage(errors)
	if example_angles.is_empty() or example_angles.size() > 3:
		errors.append("Şablon 1-3 örnek atış açısı içermelidir.")
	for angle: float in example_angles:
		if angle < 15.0 or angle > 165.0:
			errors.append("Örnek atış açısı 15-165 derece dışında: %.1f." % angle)

	var known_ids: Dictionary[int, bool] = {}
	var known_cells: Dictionary[Vector2i, bool] = {}
	var core_count := 0
	var rock_count := 0
	var core_cell := Vector2i(-1, -1)
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
			core_cell = definition.cell
			if definition.cell.y != BoardModel.CORE_TARGET_ROW:
				errors.append("%s çekirdek satırında olmalıdır." % label)
		elif definition.cell.y < 0 or definition.cell.y >= BoardModel.ROOM_GRID_SIZE.y:
			errors.append("%s 8x8 oda alanının dışında." % label)

		if definition.cell.x < 0 or definition.cell.x >= BoardModel.ROOM_GRID_SIZE.x:
			errors.append("%s yatay oda sınırlarının dışında." % label)

		if definition.block_type == BlockState.BlockType.ROCK:
			rock_count += 1
			if definition.hit_points != 0:
				errors.append("%s sert kaya olduğu için canı 0 olmalıdır." % label)
		elif definition.block_type == BlockState.BlockType.NORMAL:
			if definition.hit_points < 2 or definition.hit_points > 6:
				errors.append("%s normal blok olduğu için 2-6 cana sahip olmalıdır." % label)
		elif definition.block_type == BlockState.BlockType.ORE:
			if definition.hit_points < 3 or definition.hit_points > 6:
				errors.append("%s cevher bloğu olduğu için 3-6 cana sahip olmalıdır." % label)
		elif definition.block_type == BlockState.BlockType.CORE and definition.hit_points != 6:
			errors.append("%s çekirdek olduğu için 6 cana sahip olmalıdır." % label)

	if core_count != 1:
		errors.append("Bir oda tam olarak bir çekirdek içermelidir; bulunan: %d." % core_count)
	elif not passage_columns.has(core_cell.x):
		errors.append("Çekirdek ana geçit sütunlarından biriyle hizalanmalıdır.")
	if rock_count > MAX_ROCK_COUNT:
		errors.append("Sert kaya sayısı %d sınırını aşıyor: %d." % [MAX_ROCK_COUNT, rock_count])
	for definition: RoomBlockDefinition in blocks:
		if definition != null \
			and definition.block_type != BlockState.BlockType.CORE \
			and passage_columns.has(definition.cell.x):
			errors.append(
				"%d kimlikli blok ana geçit sütununu kapatıyor: x=%d." % [
					definition.id,
					definition.cell.x,
				]
			)
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


func _validate_passage(errors: PackedStringArray) -> void:
	var expected_width := 2 if family == Family.SAFE else 1
	if passage_columns.size() != expected_width:
		errors.append(
			"%s oda ana geçidi %d sütun genişliğinde olmalıdır." % [
				"Güvenli" if family == Family.SAFE else "Bonus",
				expected_width,
			]
		)
	var seen_columns: Dictionary[int, bool] = {}
	for column: int in passage_columns:
		if column < 0 or column >= BoardModel.ROOM_GRID_SIZE.x:
			errors.append("Ana geçit sütunu oda dışında: %d." % column)
		elif seen_columns.has(column):
			errors.append("Ana geçit sütunu yineleniyor: %d." % column)
		else:
			seen_columns[column] = true
