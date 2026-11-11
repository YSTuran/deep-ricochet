class_name RoomCatalog
extends RefCounted

const DEFAULT_MANIFEST_PATH := "res://content/mines/catalog.json"
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


func route_capacity_errors(
	room_count: int,
	mine_id: StringName = &"mine_01",
) -> PackedStringArray:
	var errors := PackedStringArray()
	if room_count <= 0:
		errors.append("Oda sayısı pozitif olmalıdır.")
		return errors
	var start_count := 0
	var wide_count := 0
	var narrow_count := 0
	for template: RoomTemplate in templates:
		if template.mine_id != mine_id:
			continue
		match template.role:
			RoomTemplate.Role.START:
				start_count += 1
			RoomTemplate.Role.WIDE:
				wide_count += 1
			RoomTemplate.Role.NARROW:
				narrow_count += 1
	if start_count < 1:
		errors.append("%s madeni en az bir başlangıç şablonu gerektirir." % mine_id)
	var required_routes := maxi(room_count - 1, 0)
	if wide_count < required_routes:
		errors.append("%d odalık koşu için en az %d geniş geçit gerekir." % [room_count, required_routes])
	if narrow_count < required_routes:
		errors.append("%d odalık koşu için en az %d dar damar gerekir." % [room_count, required_routes])
	return errors


func pick_first_room(
	rng: RandomNumberGenerator,
	mine_id: StringName = &"mine_01",
) -> RoomTemplate:
	return _pick_template(RoomTemplate.Role.START, rng, {}, mine_id)


func create_route_options(
	next_room_number: int,
	rng: RandomNumberGenerator,
	excluded_ids: Dictionary[StringName, bool],
	mine_id: StringName = &"mine_01",
) -> Array[RouteOption]:
	var safe_template := _pick_template(RoomTemplate.Role.WIDE, rng, excluded_ids, mine_id)
	var bonus_template := _pick_template(RoomTemplate.Role.NARROW, rng, excluded_ids, mine_id)
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


func role_counts(mine_id: StringName) -> Dictionary[int, int]:
	var counts: Dictionary[int, int] = {
		RoomTemplate.Role.START: 0,
		RoomTemplate.Role.WIDE: 0,
		RoomTemplate.Role.NARROW: 0,
	}
	for template: RoomTemplate in templates:
		if template.mine_id == mine_id:
			counts[template.role] = counts.get(template.role, 0) + 1
	return counts


func _pick_template(
	role: int,
	rng: RandomNumberGenerator,
	excluded_ids: Dictionary[StringName, bool],
	mine_id: StringName,
) -> RoomTemplate:
	var candidates: Array[RoomTemplate] = []
	for template: RoomTemplate in templates:
		if template.mine_id == mine_id \
			and template.role == role \
			and not excluded_ids.has(template.room_id):
			candidates.append(template)
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]
