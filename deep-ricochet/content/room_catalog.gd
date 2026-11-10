class_name RoomCatalog
extends RefCounted

const DEFAULT_MANIFEST_PATH := "res://content/rooms/catalog.json"
const SUPPORTED_SCHEMA_VERSION := 1

var content_version: String
var templates: Array[RoomTemplate] = []


static func load_default() -> RoomCatalog:
	return load_from_manifest(DEFAULT_MANIFEST_PATH)


static func load_from_manifest(path: String) -> RoomCatalog:
	if not FileAccess.file_exists(path):
		push_error("Oda kataloğu bulunamadı: %s" % path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("Oda kataloğu JSON olarak okunamadı: %s" % path)
		return null
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("Oda kataloğunun kökü bir JSON nesnesi olmalıdır: %s" % path)
		return null

	var data: Dictionary = json.data
	if int(data.get("schemaVersion", 0)) != SUPPORTED_SCHEMA_VERSION:
		push_error("Desteklenmeyen oda kataloğu sürümü: %s" % path)
		return null
	var catalog := RoomCatalog.new()
	catalog.content_version = str(data.get("contentVersion", ""))
	var raw_paths: Variant = data.get("templates", [])
	if typeof(raw_paths) != TYPE_ARRAY:
		push_error("Oda kataloğu templates dizisi içermelidir: %s" % path)
		return null
	for raw_path: Variant in raw_paths:
		var template_path := str(raw_path)
		var template := RoomTemplateLoader.load_from_file(template_path)
		if template == null:
			template = RoomTemplateLoader.create_verified_fallback_for_path(
				template_path,
				catalog.content_version,
			)
			if template == null:
				return null
			push_warning(
				"Oda şablonu doğrulanamadı; doğrulanmış yedek kullanılıyor: %s" % template_path
			)
		catalog.templates.append(template)

	var errors := catalog.validation_errors()
	if not errors.is_empty():
		push_error("Geçersiz oda kataloğu:\n- %s" % "\n- ".join(errors))
		return null
	return catalog


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if content_version.strip_edges().is_empty():
		errors.append("Katalog içerik sürümü boş olamaz.")
	var ids: Dictionary[StringName, bool] = {}
	var safe_count := 0
	var bonus_count := 0
	for template: RoomTemplate in templates:
		if template == null:
			errors.append("Katalog boş şablon içeriyor.")
			continue
		if not template.is_valid():
			errors.append("Geçersiz şablon: %s." % template.room_id)
		if template.content_version != content_version:
			errors.append("Şablon içerik sürümü katalogla uyuşmuyor: %s." % template.room_id)
		if ids.has(template.room_id):
			errors.append("Yinelenen şablon kimliği: %s." % template.room_id)
		else:
			ids[template.room_id] = true
		if template.family == RoomTemplate.Family.SAFE:
			safe_count += 1
		elif template.family == RoomTemplate.Family.BONUS:
			bonus_count += 1
	if safe_count < 6 or bonus_count < 6:
		errors.append("Katalog en az 6 güvenli ve 6 bonus şablon içermelidir.")
	return errors


func route_capacity_errors(room_count: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if room_count <= 0:
		errors.append("Oda sayısı pozitif olmalıdır.")
		return errors
	var safe_count := 0
	var bonus_count := 0
	for template: RoomTemplate in templates:
		if template.family == RoomTemplate.Family.SAFE:
			safe_count += 1
		elif template.family == RoomTemplate.Family.BONUS:
			bonus_count += 1
	if safe_count < room_count:
		errors.append("%d odalık koşu için en az %d güvenli şablon gerekir." % [room_count, room_count])
	var required_bonus := maxi(room_count - 1, 0)
	if bonus_count < required_bonus:
		errors.append("%d odalık koşu için en az %d bonus şablon gerekir." % [room_count, required_bonus])
	return errors


func pick_first_room(rng: RandomNumberGenerator) -> RoomTemplate:
	return _pick_template(RoomTemplate.Family.SAFE, rng, {})


func create_route_options(
	next_room_number: int,
	rng: RandomNumberGenerator,
	excluded_ids: Dictionary[StringName, bool],
) -> Array[RouteOption]:
	var safe_template := _pick_template(RoomTemplate.Family.SAFE, rng, excluded_ids)
	var bonus_template := _pick_template(RoomTemplate.Family.BONUS, rng, excluded_ids)
	if safe_template == null or bonus_template == null:
		return []
	return [
		RouteOption.new(
			StringName("room_%d_safe_%s" % [next_room_number, safe_template.room_id]),
			safe_template,
		),
		RouteOption.new(
			StringName("room_%d_bonus_%s" % [next_room_number, bonus_template.room_id]),
			bonus_template,
		),
	]


func get_template(template_id: StringName) -> RoomTemplate:
	for template: RoomTemplate in templates:
		if template.room_id == template_id:
			return template
	return null


func _pick_template(
	family: int,
	rng: RandomNumberGenerator,
	excluded_ids: Dictionary[StringName, bool],
) -> RoomTemplate:
	var candidates: Array[RoomTemplate] = []
	for template: RoomTemplate in templates:
		if template.family == family and not excluded_ids.has(template.room_id):
			candidates.append(template)
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]
