class_name RunSnapshot
extends RefCounted

const SCHEMA_VERSION := 1

var schema_version: int = SCHEMA_VERSION
var run_id: String
var seed: int
var rng_state: int
var content_version: String
var room_count: int
var room_number: int
var phase: int
var banked_score: int
var cores_broken: int
var route_choices_made: int
var ended: bool
var succeeded: bool
var current_template_id: StringName
var selected_template_ids: Array[StringName] = []
var offered_template_ids: Array[StringName] = []
var pending_routes: Array[Dictionary] = []
var last_room_reward: int
var last_room_break_score: int
var last_room_remaining_shots: int
var last_room_succeeded: bool
var active_room: RoomSnapshot


static func capture(
	session: RunSession,
	room_snapshot: RoomSnapshot,
	current_rng_state: int,
) -> RunSnapshot:
	if session == null or room_snapshot == null:
		return null
	var snapshot := RunSnapshot.new()
	snapshot.run_id = session.run_id
	snapshot.seed = session.seed
	snapshot.rng_state = current_rng_state
	snapshot.content_version = session.content_version
	snapshot.room_count = session.room_count
	snapshot.room_number = session.room_number
	snapshot.phase = int(session.phase)
	snapshot.banked_score = session.banked_score
	snapshot.cores_broken = session.cores_broken
	snapshot.route_choices_made = session.route_choices_made
	snapshot.ended = session.ended
	snapshot.succeeded = session.succeeded
	snapshot.current_template_id = session.current_template_id
	snapshot.selected_template_ids = session.selected_template_ids.duplicate()
	snapshot.offered_template_ids = session.offered_template_ids.duplicate()
	for option: RouteOption in session.pending_routes:
		snapshot.pending_routes.append({
			"optionId": str(option.option_id),
			"templateId": str(option.template.room_id),
		})
	snapshot.last_room_reward = session.last_room_reward
	snapshot.last_room_break_score = session.last_room_break_score
	snapshot.last_room_remaining_shots = session.last_room_remaining_shots
	snapshot.last_room_succeeded = session.last_room_succeeded
	snapshot.active_room = room_snapshot
	return snapshot


static func from_dictionary(data: Dictionary) -> RunSnapshot:
	var snapshot := RunSnapshot.new()
	snapshot.schema_version = int(data.get("schemaVersion", 0))
	snapshot.run_id = str(data.get("runId", ""))
	snapshot.seed = int(data.get("seed", 0))
	snapshot.rng_state = int(data.get("rngState", 0))
	snapshot.content_version = str(data.get("contentVersion", ""))
	snapshot.room_count = int(data.get("roomCount", 0))
	snapshot.room_number = int(data.get("roomNumber", 0))
	snapshot.phase = int(data.get("phase", -1))
	snapshot.banked_score = int(data.get("bankedScore", -1))
	snapshot.cores_broken = int(data.get("coresBroken", -1))
	snapshot.route_choices_made = int(data.get("routeChoicesMade", -1))
	snapshot.ended = bool(data.get("ended", false))
	snapshot.succeeded = bool(data.get("succeeded", false))
	snapshot.current_template_id = StringName(str(data.get("currentTemplateId", "")))
	snapshot.selected_template_ids = _string_name_array(data.get("selectedTemplateIds", []))
	snapshot.offered_template_ids = _string_name_array(data.get("offeredTemplateIds", []))
	var raw_routes: Variant = data.get("pendingRoutes", [])
	if typeof(raw_routes) == TYPE_ARRAY:
		for raw_route: Variant in raw_routes:
			if typeof(raw_route) == TYPE_DICTIONARY:
				snapshot.pending_routes.append(raw_route)
			else:
				snapshot.pending_routes.append({})
	snapshot.last_room_reward = int(data.get("lastRoomReward", -1))
	snapshot.last_room_break_score = int(data.get("lastRoomBreakScore", -1))
	snapshot.last_room_remaining_shots = int(data.get("lastRoomRemainingShots", -1))
	snapshot.last_room_succeeded = bool(data.get("lastRoomSucceeded", false))
	var raw_room: Variant = data.get("activeRoom", {})
	if typeof(raw_room) == TYPE_DICTIONARY:
		snapshot.active_room = RoomSnapshot.from_dictionary(raw_room)
	return snapshot


func to_dictionary() -> Dictionary:
	return {
		"schemaVersion": schema_version,
		"runId": run_id,
		"seed": seed,
		"rngState": rng_state,
		"contentVersion": content_version,
		"roomCount": room_count,
		"roomNumber": room_number,
		"phase": phase,
		"bankedScore": banked_score,
		"coresBroken": cores_broken,
		"routeChoicesMade": route_choices_made,
		"ended": ended,
		"succeeded": succeeded,
		"currentTemplateId": str(current_template_id),
		"selectedTemplateIds": _string_array(selected_template_ids),
		"offeredTemplateIds": _string_array(offered_template_ids),
		"pendingRoutes": pending_routes.duplicate(true),
		"lastRoomReward": last_room_reward,
		"lastRoomBreakScore": last_room_break_score,
		"lastRoomRemainingShots": last_room_remaining_shots,
		"lastRoomSucceeded": last_room_succeeded,
		"activeRoom": active_room.to_dictionary() if active_room != null else {},
	}


func validation_errors(catalog: RoomCatalog, config: GameConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != SCHEMA_VERSION:
		errors.append("Desteklenmeyen koşu snapshot sürümü.")
	if run_id.strip_edges().is_empty() or seed == 0:
		errors.append("Koşu kimliği veya seed geçersiz.")
	if catalog == null or content_version != catalog.content_version:
		errors.append("Kayıt içerik sürümü mevcut katalogla uyuşmuyor.")
	if room_count != config.room_count or room_number < 1 or room_number > room_count:
		errors.append("Oda ilerlemesi geçersiz.")
	if phase < RunSession.Phase.PLAYING or phase > RunSession.Phase.RUN_RESULT:
		errors.append("Koşu aşaması geçersiz.")
	if ended != (phase == RunSession.Phase.RUN_RESULT):
		errors.append("Koşu bitiş durumu aşamayla uyuşmuyor.")
	if succeeded and not ended:
		errors.append("Başarılı koşu bitmiş olmalıdır.")
	if banked_score < 0 or cores_broken < 0 or cores_broken > room_count:
		errors.append("Koşu puanı veya çekirdek sayısı geçersiz.")
	if route_choices_made != room_number - 1:
		errors.append("Rota tercih sayısı oda ilerlemesiyle uyuşmuyor.")
	if selected_template_ids.size() != room_number or _has_duplicates(selected_template_ids):
		errors.append("Seçilen şablon listesi oda ilerlemesiyle uyuşmuyor.")
	if _has_duplicates(offered_template_ids):
		errors.append("Sunulan şablon listesinde tekrar var.")
	if catalog != null:
		for template_id: StringName in selected_template_ids:
			if catalog.get_template(template_id) == null:
				errors.append("Seçilen şablon katalogda bulunmuyor: %s." % template_id)
		for template_id: StringName in offered_template_ids:
			if catalog.get_template(template_id) == null:
				errors.append("Sunulan şablon katalogda bulunmuyor: %s." % template_id)
	if not selected_template_ids.has(current_template_id):
		errors.append("Etkin şablon seçilmiş şablonlar arasında değil.")

	var current_template := catalog.get_template(current_template_id) if catalog != null else null
	if current_template == null:
		errors.append("Etkin oda şablonu katalogda bulunamadı.")
	if phase == RunSession.Phase.ROUTE_SELECTION:
		_validate_pending_routes(catalog, errors)
	elif not pending_routes.is_empty():
		errors.append("Rota seçimi dışında bekleyen rota bulunamaz.")
	if active_room == null:
		errors.append("Etkin oda snapshot eksik.")
	elif current_template != null:
		errors.append_array(active_room.validation_errors(current_template, config))
		if active_room.template_id != current_template_id:
			errors.append("Etkin oda ile koşu şablon kimliği uyuşmuyor.")
		if phase == RunSession.Phase.PLAYING and active_room.room_finished:
			errors.append("Oynanış aşamasındaki oda bitmiş olamaz.")
		if phase != RunSession.Phase.PLAYING and not active_room.room_finished:
			errors.append("Rota/sonuç aşamasındaki oda bitmiş olmalıdır.")
	if last_room_reward < 0 or last_room_break_score < 0 or last_room_remaining_shots < 0:
		errors.append("Son oda özeti geçersiz.")
	if phase != RunSession.Phase.PLAYING and active_room != null:
		if last_room_reward != active_room.final_reward \
			or last_room_succeeded != active_room.room_succeeded:
			errors.append("Son oda özeti etkin oda sonucuyla uyuşmuyor.")
	return errors


func create_session(catalog: RoomCatalog) -> RunSession:
	var session := RunSession.new()
	session.run_id = run_id
	session.seed = seed
	session.content_version = content_version
	session.room_count = room_count
	session.room_number = room_number
	session.phase = phase
	session.banked_score = banked_score
	session.cores_broken = cores_broken
	session.route_choices_made = route_choices_made
	session.ended = ended
	session.succeeded = succeeded
	session.current_template_id = current_template_id
	session.selected_template_ids = selected_template_ids.duplicate()
	session.offered_template_ids = offered_template_ids.duplicate()
	session.pending_routes.clear()
	for route_data: Dictionary in pending_routes:
		var template := catalog.get_template(StringName(str(route_data.get("templateId", ""))))
		if template == null:
			return null
		session.pending_routes.append(RouteOption.new(
			StringName(str(route_data.get("optionId", ""))),
			template,
		))
	session.last_room_reward = last_room_reward
	session.last_room_break_score = last_room_break_score
	session.last_room_remaining_shots = last_room_remaining_shots
	session.last_room_succeeded = last_room_succeeded
	return session


func _validate_pending_routes(catalog: RoomCatalog, errors: PackedStringArray) -> void:
	if pending_routes.size() != 2:
		errors.append("Rota ekranında tam iki aday bulunmalıdır.")
		return
	var option_ids: Dictionary[StringName, bool] = {}
	var family_count: Dictionary[int, int] = {
		RoomTemplate.Family.SAFE: 0,
		RoomTemplate.Family.BONUS: 0,
	}
	for route_data: Dictionary in pending_routes:
		var option_id := StringName(str(route_data.get("optionId", "")))
		var template_id := StringName(str(route_data.get("templateId", "")))
		var template := catalog.get_template(template_id) if catalog != null else null
		if option_id.is_empty() or option_ids.has(option_id):
			errors.append("Rota adayı kimliği boş veya yineleniyor.")
		else:
			option_ids[option_id] = true
		if template == null or not offered_template_ids.has(template_id):
			errors.append("Rota adayı katalog/sunulan şablon listesiyle uyuşmuyor.")
		else:
			if selected_template_ids.has(template_id):
				errors.append("Bekleyen rota adayı daha önce seçilmiş olamaz.")
			family_count[template.family] = family_count.get(template.family, 0) + 1
	if family_count[RoomTemplate.Family.SAFE] != 1 \
		or family_count[RoomTemplate.Family.BONUS] != 1:
		errors.append("Rota adayları bir güvenli ve bir bonus oda içermelidir.")


static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item: Variant in value:
		result.append(StringName(str(item)))
	return result


static func _string_array(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value: StringName in values:
		result.append(str(value))
	return result


static func _has_duplicates(values: Array[StringName]) -> bool:
	var seen: Dictionary[StringName, bool] = {}
	for value: StringName in values:
		if seen.has(value):
			return true
		seen[value] = true
	return false
