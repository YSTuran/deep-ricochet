class_name RoomTemplate
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 1
const SAFE_MULTIPLIER_BPS := 10_000
const BONUS_MULTIPLIER_BPS := 15_000
const MAX_ROCK_COUNT := 10
const MAX_STANDARD_BLOCK_HP := 8
const MAX_SPECIAL_BLOCK_HP := 8
const MIN_CORE_HP := 6
const MAX_CORE_HP := 8

enum Family {
	SAFE,
	BONUS,
}

enum Role {
	START,
	WIDE,
	NARROW,
}

var schema_version: int = SUPPORTED_SCHEMA_VERSION
var room_id: StringName
var display_name: String
var display_name_key: StringName
var mine_id: StringName = &"mine_01"
var role: int = Role.WIDE
var family: int = Family.SAFE
var content_version: String
var width: int = BoardGeometry.BLOCK_GRID_SIZE.x
var height: int = BoardGeometry.BLOCK_GRID_SIZE.y
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
	if mine_id.is_empty():
		errors.append("Oda maden kimliği boş olamaz.")
	if role < Role.START or role > Role.NARROW:
		errors.append("Oda rolü start, wide veya narrow olmalıdır.")
	if content_version.strip_edges().is_empty():
		errors.append("İçerik sürümü boş olamaz.")
	if family != Family.SAFE and family != Family.BONUS:
		errors.append("Oda ailesi safe veya bonus olmalıdır.")
	if width != BoardGeometry.BLOCK_GRID_SIZE.x or height != BoardGeometry.BLOCK_GRID_SIZE.y:
		errors.append(
			"Oda ölçüsü %dx%d olmalıdır." % [
				BoardGeometry.BLOCK_GRID_SIZE.x,
				BoardGeometry.BLOCK_GRID_SIZE.y,
			]
		)
	var expected_multiplier := 0
	if family == Family.SAFE:
		expected_multiplier = SAFE_MULTIPLIER_BPS
	elif family == Family.BONUS:
		expected_multiplier = BONUS_MULTIPLIER_BPS
	if expected_multiplier > 0 and multiplier_bps != expected_multiplier:
		errors.append(
			"Oda ailesi ile çarpan uyuşmuyor; beklenen: %d." % expected_multiplier
		)
	if (role == Role.START or role == Role.WIDE) and family != Family.SAFE:
		errors.append("Başlangıç ve geniş geçit odaları güvenli ailede olmalıdır.")
	elif role == Role.NARROW and family != Family.BONUS:
		errors.append("Dar damar odaları bonus ailede olmalıdır.")
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
			if definition.cell.y != BoardGeometry.CORE_ROW:
				errors.append("%s çekirdek satırında olmalıdır." % label)
		elif definition.cell.y < 0 or definition.cell.y >= BoardGeometry.BLOCK_GRID_SIZE.y:
			errors.append("%s 8x8 oda alanının dışında." % label)

		if definition.cell.x < 0 or definition.cell.x >= BoardGeometry.BLOCK_GRID_SIZE.x:
			errors.append("%s yatay oda sınırlarının dışında." % label)

		if definition.block_type == BlockState.BlockType.ROCK:
			rock_count += 1
			if definition.hit_points != 0:
				errors.append("%s sert kaya olduğu için canı 0 olmalıdır." % label)
		elif definition.block_type == BlockState.BlockType.NORMAL:
			if definition.hit_points < 2 or definition.hit_points > MAX_STANDARD_BLOCK_HP:
				errors.append("%s normal blok olduğu için 2-%d cana sahip olmalıdır." % [label, MAX_STANDARD_BLOCK_HP])
		elif definition.block_type == BlockState.BlockType.ORE:
			if definition.hit_points < 3 or definition.hit_points > MAX_STANDARD_BLOCK_HP:
				errors.append("%s cevher bloğu olduğu için 3-%d cana sahip olmalıdır." % [label, MAX_STANDARD_BLOCK_HP])
		elif definition.block_type == BlockState.BlockType.EXPLOSIVE:
			if definition.hit_points < 1 or definition.hit_points > MAX_SPECIAL_BLOCK_HP:
				errors.append("%s patlayıcı blok olduğu için 1-%d cana sahip olmalıdır." % [label, MAX_SPECIAL_BLOCK_HP])
		elif definition.block_type == BlockState.BlockType.CRACKED:
			if definition.hit_points != 1:
				errors.append("%s çatlak kaya olduğu için 1 cana sahip olmalıdır." % label)
		elif definition.block_type == BlockState.BlockType.ARMORED:
			if definition.hit_points < 3 or definition.hit_points > MAX_SPECIAL_BLOCK_HP:
				errors.append("%s zırhlı blok olduğu için 3-%d cana sahip olmalıdır." % [label, MAX_SPECIAL_BLOCK_HP])
			var vulnerable_count := _vulnerable_side_count(definition.vulnerable_sides)
			if vulnerable_count < 1 or vulnerable_count > 2:
				errors.append("%s zırhlı blok olduğu için 1 veya 2 açık kenara sahip olmalıdır." % label)
		elif definition.block_type == BlockState.BlockType.CORE \
			and (definition.hit_points < MIN_CORE_HP or definition.hit_points > MAX_CORE_HP):
			errors.append("%s çekirdek olduğu için %d-%d cana sahip olmalıdır." % [label, MIN_CORE_HP, MAX_CORE_HP])

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


func localized_display_name() -> String:
	var key := str(display_name_key)
	if key.is_empty():
		key = "ROOM_%s" % str(room_id).to_upper()
	var translated := TranslationServer.translate(key)
	return display_name if translated == key else translated


func _is_known_block_type(block_type: int) -> bool:
	return block_type == BlockState.BlockType.NORMAL \
		or block_type == BlockState.BlockType.ORE \
		or block_type == BlockState.BlockType.ROCK \
		or block_type == BlockState.BlockType.CORE \
		or block_type == BlockState.BlockType.EXPLOSIVE \
		or block_type == BlockState.BlockType.CRACKED \
		or block_type == BlockState.BlockType.ARMORED


func _vulnerable_side_count(mask: int) -> int:
	var count := 0
	for side in [
		BlockState.VulnerableSide.LEFT,
		BlockState.VulnerableSide.RIGHT,
		BlockState.VulnerableSide.TOP,
		BlockState.VulnerableSide.BOTTOM,
	]:
		if (mask & side) != 0:
			count += 1
	return count


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
		if column < 0 or column >= BoardGeometry.BLOCK_GRID_SIZE.x:
			errors.append("Ana geçit sütunu oda dışında: %d." % column)
		elif seen_columns.has(column):
			errors.append("Ana geçit sütunu yineleniyor: %d." % column)
		else:
			seen_columns[column] = true
