class_name MineRegistry
extends RefCounted

const DEFAULT_PATH := "res://content/mines/mines.json"
const SUPPORTED_SCHEMA_VERSION := 1

var content_version: String
var catalog: RoomCatalog
var mines: Array[MineDefinition] = []


static func load_default() -> MineRegistry:
	return load_from_file(DEFAULT_PATH)


static func load_from_file(path: String) -> MineRegistry:
	if not FileAccess.file_exists(path):
		push_error("Maden tanım dosyası bulunamadı: %s" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("Maden tanım dosyası okunamadı: %s" % path)
		return null
	var data: Dictionary = json.data
	if int(data.get("schemaVersion", 0)) != SUPPORTED_SCHEMA_VERSION:
		push_error("Desteklenmeyen maden şeması: %s" % path)
		return null
	var registry := MineRegistry.new()
	registry.content_version = str(data.get("contentVersion", ""))
	registry.catalog = RoomCatalog.load_from_manifest(str(data.get("roomCatalog", "")))
	var raw_mines: Variant = data.get("mines", [])
	if typeof(raw_mines) != TYPE_ARRAY:
		return null
	for raw_mine: Variant in raw_mines:
		if typeof(raw_mine) != TYPE_DICTIONARY:
			return null
		var definition := MineDefinition.new()
		definition.mine_id = StringName(str(raw_mine.get("id", "")))
		definition.display_name_key = StringName(str(raw_mine.get("displayNameKey", "")))
		definition.order = int(raw_mine.get("order", 0))
		definition.unlock_after = StringName(str(raw_mine.get("unlockAfter", "")))
		registry.mines.append(definition)
	var errors := registry.validation_errors()
	if not errors.is_empty():
		push_error("Geçersiz maden kaydı:\n- %s" % "\n- ".join(errors))
		return null
	return registry


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if content_version.strip_edges().is_empty():
		errors.append("Maden içerik sürümü boş olamaz.")
	if catalog == null:
		errors.append("Maden oda kataloğu yüklenemedi.")
		return errors
	if catalog.content_version != content_version:
		errors.append("Maden ve oda kataloğu içerik sürümleri uyuşmuyor.")
	if mines.size() != 3:
		errors.append("İlk seviye paketi tam üç maden içermelidir.")
	var ids: Dictionary[StringName, bool] = {}
	var orders: Dictionary[int, bool] = {}
	for mine: MineDefinition in mines:
		if mine == null or not mine.is_valid():
			errors.append("Geçersiz maden tanımı bulundu.")
			continue
		if ids.has(mine.mine_id):
			errors.append("Yinelenen maden kimliği: %s." % mine.mine_id)
		ids[mine.mine_id] = true
		if mine.order < 1 or mine.order > mines.size() or orders.has(mine.order):
			errors.append("Maden sırası 1-%d aralığında ve benzersiz olmalıdır: %s." % [mines.size(), mine.mine_id])
		orders[mine.order] = true
		if mine.order > 1 and mine.unlock_after.is_empty():
			errors.append("Kilitli madenin ön koşulu eksik: %s." % mine.mine_id)
		var counts := catalog.role_counts(mine.mine_id)
		if int(counts.get(RoomTemplate.Role.START, 0)) != 2 \
			or int(counts.get(RoomTemplate.Role.WIDE, 0)) != 6 \
			or int(counts.get(RoomTemplate.Role.NARROW, 0)) != 6:
			errors.append("%s madeni 2 başlangıç, 6 geniş ve 6 dar şablon içermelidir." % mine.mine_id)
	for mine: MineDefinition in mines:
		if mine.order > 1 and mine.unlock_after != mine_id_for_order(mine.order - 1):
			errors.append("%s madeninin kilit ön koşulu bir önceki maden olmalıdır." % mine.mine_id)
	for template: RoomTemplate in catalog.templates:
		if not ids.has(template.mine_id):
			errors.append("Oda şablonu bilinmeyen madene bağlı: %s." % template.room_id)
	return errors


func get_mine(mine_id: StringName) -> MineDefinition:
	for mine: MineDefinition in mines:
		if mine.mine_id == mine_id:
			return mine
	return null


func mine_id_for_order(order: int) -> StringName:
	for mine: MineDefinition in mines:
		if mine.order == order:
			return mine.mine_id
	return &""
