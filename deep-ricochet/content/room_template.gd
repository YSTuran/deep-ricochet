class_name RoomTemplate
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 1
const SAFE_MULTIPLIER_BPS := 10_000
const BONUS_MULTIPLIER_BPS := 15_000
const MAX_ROCK_COUNT := 10
const MAX_STANDARD_BLOCK_HP := 8
const MAX_SPECIAL_BLOCK_HP := 8
const ECHO_HIT_POINTS := 6
const BALL_CACHE_HIT_POINTS := 4
const PIERCING_HIT_POINTS := 7
const ACID_BARREL_HIT_POINTS := 9
const MIN_CORE_HP := 6
const MAX_CORE_HP := 8
const MIN_BLOCK_ROW := 2
const PASSAGE_CLEAR_MAX_ROW := 3

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
	var definitions_by_cell: Dictionary[Vector2i, RoomBlockDefinition] = {}
	var core_count := 0
	var rock_count := 0
	var acid_barrel_count := 0
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
			definitions_by_cell[definition.cell] = definition

		if not _is_known_block_type(definition.block_type):
			errors.append("%s bilinmeyen blok türüne sahip." % label)
			continue

		if definition.block_type == BlockState.BlockType.CORE:
			core_count += 1
			if not BoardGeometry.is_core_row(definition.cell.y):
				errors.append(
					"%s çekirdeği üst bölgede %d-%d satırları arasında olmalıdır." % [
						label,
						BoardGeometry.CORE_MIN_ROW,
						BoardGeometry.CORE_ROW,
					]
				)
		elif definition.cell.y < MIN_BLOCK_ROW \
			or definition.cell.y >= BoardGeometry.BLOCK_GRID_SIZE.y:
			errors.append(
				"%s alt iki satır boş kalacak biçimde %d-%d satırları arasında olmalıdır." % [
					label,
					MIN_BLOCK_ROW,
					BoardGeometry.BLOCK_GRID_SIZE.y - 1,
				]
			)

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
			if definition.hit_points != MAX_SPECIAL_BLOCK_HP:
				errors.append(
					"%s çatlak kaya olduğu için %d cana sahip olmalıdır." \
						% [label, MAX_SPECIAL_BLOCK_HP]
				)
		elif definition.block_type == BlockState.BlockType.ARMORED:
			if definition.hit_points < 3 or definition.hit_points > MAX_SPECIAL_BLOCK_HP:
				errors.append("%s zırhlı blok olduğu için 3-%d cana sahip olmalıdır." % [label, MAX_SPECIAL_BLOCK_HP])
			var vulnerable_count := _vulnerable_side_count(definition.vulnerable_sides)
			if vulnerable_count < 1 or vulnerable_count > 2:
				errors.append("%s zırhlı blok olduğu için 1 veya 2 açık kenara sahip olmalıdır." % label)
			var supported_visual_mask := definition.vulnerable_sides \
				== BlockState.VulnerableSide.BOTTOM \
				or definition.vulnerable_sides == (
					BlockState.VulnerableSide.BOTTOM | BlockState.VulnerableSide.LEFT
				) \
				or definition.vulnerable_sides == (
					BlockState.VulnerableSide.BOTTOM | BlockState.VulnerableSide.RIGHT
				)
			if not supported_visual_mask:
				errors.append(
					"%s zırhlı bloğun zayıf kenarları mevcut görsellerle eşleşmiyor." % label
				)
		elif definition.block_type == BlockState.BlockType.ECHO:
			if definition.hit_points != ECHO_HIT_POINTS:
				errors.append("%s yankı bloğu olduğu için %d cana sahip olmalıdır." % [label, ECHO_HIT_POINTS])
		elif definition.block_type == BlockState.BlockType.BALL_CACHE:
			if definition.hit_points != BALL_CACHE_HIT_POINTS:
				errors.append("%s top kutusu olduğu için %d cana sahip olmalıdır." % [label, BALL_CACHE_HIT_POINTS])
		elif definition.block_type == BlockState.BlockType.PIERCING:
			if definition.hit_points != PIERCING_HIT_POINTS:
				errors.append("%s ışık kristali olduğu için %d cana sahip olmalıdır." % [label, PIERCING_HIT_POINTS])
			if not _is_valid_beam_direction(definition.beam_direction):
				errors.append("%s ışık kristalinin ışın yönü geçersizdir." % label)
		elif definition.block_type == BlockState.BlockType.ACID_BARREL:
			acid_barrel_count += 1
			if definition.hit_points != ACID_BARREL_HIT_POINTS:
				errors.append("%s asit varili olduğu için %d cana sahip olmalıdır." % [label, ACID_BARREL_HIT_POINTS])
		elif definition.block_type == BlockState.BlockType.CORE \
			and (definition.hit_points < MIN_CORE_HP or definition.hit_points > MAX_CORE_HP):
			errors.append("%s çekirdek olduğu için %d-%d cana sahip olmalıdır." % [label, MIN_CORE_HP, MAX_CORE_HP])

	if core_count != 1:
		errors.append("Bir oda tam olarak bir çekirdek içermelidir; bulunan: %d." % core_count)
	if acid_barrel_count > 2:
		errors.append("Bir odada en fazla iki asit varili bulunabilir.")
	for definition: RoomBlockDefinition in blocks:
		if definition == null or definition.block_type != BlockState.BlockType.ARMORED:
			continue
		for side: int in [
			BlockState.VulnerableSide.LEFT,
			BlockState.VulnerableSide.RIGHT,
			BlockState.VulnerableSide.TOP,
			BlockState.VulnerableSide.BOTTOM,
		]:
			if (definition.vulnerable_sides & side) == 0:
				continue
			var neighbor := _neighbor_for_side(definition.cell, side)
			if not _is_accessible_neighbor(neighbor, known_cells):
				errors.append(
					"%d kimlikli zırhlı bloğun zayıf kenarı duvar veya blokla kapalıdır." \
						% definition.id
				)
	for definition: RoomBlockDefinition in blocks:
		if definition == null or definition.block_type != BlockState.BlockType.PIERCING \
			or not _is_valid_beam_direction(definition.beam_direction):
			continue
		var beam_step := BlockState.beam_vector(definition.beam_direction)
		var support_cell := definition.cell - beam_step
		if _is_cell_inside_world(support_cell) and not known_cells.has(support_cell):
			errors.append(
				"%d kimlikli ışık kristalinin arkasında blok veya duvar desteği yoktur." \
					% definition.id
			)
		var ray_cell := definition.cell + beam_step
		var has_damageable_target := false
		while _is_cell_inside_world(ray_cell):
			var ray_target: RoomBlockDefinition = definitions_by_cell.get(ray_cell)
			if ray_target != null and ray_target.block_type != BlockState.BlockType.ROCK:
				has_damageable_target = true
				break
			ray_cell += beam_step
		if not has_damageable_target:
			errors.append(
				"%d kimlikli ışık kristalinin ışın yönünde hasar alabilecek blok yoktur." \
					% definition.id
			)
	if rock_count > MAX_ROCK_COUNT:
		errors.append("Sert kaya sayısı %d sınırını aşıyor: %d." % [MAX_ROCK_COUNT, rock_count])
	for definition: RoomBlockDefinition in blocks:
		if definition != null \
			and definition.block_type != BlockState.BlockType.CORE \
			and passage_columns.has(definition.cell.x) \
			and definition.cell.y <= PASSAGE_CLEAR_MAX_ROW:
			errors.append(
				"%d kimlikli blok ana geçidin alt girişini kapatıyor: x=%d, y=%d." % [
					definition.id,
					definition.cell.x,
					definition.cell.y,
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
		or block_type == BlockState.BlockType.ARMORED \
		or block_type == BlockState.BlockType.ECHO \
		or block_type == BlockState.BlockType.BALL_CACHE \
		or block_type == BlockState.BlockType.PIERCING \
		or block_type == BlockState.BlockType.ACID_BARREL


static func _is_valid_beam_direction(direction: int) -> bool:
	return direction >= BlockState.BeamDirection.UP \
		and direction <= BlockState.BeamDirection.LEFT


static func _is_cell_inside_world(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BoardGeometry.WORLD_GRID_SIZE.x \
		and cell.y >= 0 and cell.y < BoardGeometry.WORLD_GRID_SIZE.y


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


static func _neighbor_for_side(cell: Vector2i, side: int) -> Vector2i:
	match side:
		BlockState.VulnerableSide.LEFT:
			return cell + Vector2i.LEFT
		BlockState.VulnerableSide.RIGHT:
			return cell + Vector2i.RIGHT
		BlockState.VulnerableSide.TOP:
			return cell + Vector2i.DOWN
		BlockState.VulnerableSide.BOTTOM:
			return cell + Vector2i.UP
	return cell


static func _is_accessible_neighbor(
	cell: Vector2i,
	occupied_cells: Dictionary[Vector2i, bool],
) -> bool:
	return cell.x >= 0 and cell.x < BoardGeometry.WORLD_GRID_SIZE.x \
		and cell.y >= 0 and cell.y < BoardGeometry.WORLD_GRID_SIZE.y \
		and not occupied_cells.has(cell)


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
