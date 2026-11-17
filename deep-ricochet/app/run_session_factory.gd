class_name RunSessionFactory
extends RefCounted

const DailyRooms := preload("res://content/daily_room_factory.gd")

var config: GameConfig
var catalog: RoomCatalog
var mine_registry: MineRegistry
var last_error: String
var run_id_sequence := 0


func configure(
	game_config: GameConfig,
	room_catalog: RoomCatalog,
	registry: MineRegistry,
) -> void:
	config = game_config
	catalog = room_catalog
	mine_registry = registry


func create_run(
	requested_seed: int,
	requested_mine_id: StringName,
	run_kind: int,
	daily_key: String,
	profile: PlayerProfile,
) -> Dictionary:
	last_error = ""
	if config == null or catalog == null or mine_registry == null:
		last_error = "Koşu içerikleri hazır değil."
		return {}
	if run_kind < RunSession.RunKind.NORMAL or run_kind > RunSession.RunKind.DAILY:
		last_error = "Koşu türü geçersiz."
		return {}

	var effective_mine_id := requested_mine_id
	if run_kind == RunSession.RunKind.DAILY:
		if daily_key.is_empty():
			last_error = "Günlük koşu anahtarı eksik."
			return {}
		effective_mine_id = DailyRooms.DAILY_MINE_ID
	else:
		if mine_registry.get_mine(effective_mine_id) == null:
			last_error = "Maden kimliği geçersiz."
			return {}
		if profile != null and not profile.is_mine_unlocked(effective_mine_id):
			last_error = "Maden henüz açık değil."
			return {}

	var run_seed := requested_seed
	if run_kind == RunSession.RunKind.DAILY:
		run_seed = daily_seed_for_key(daily_key)
	elif run_seed == 0:
		run_seed = int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_usec()
	var candidate_rng := RandomNumberGenerator.new()
	candidate_rng.seed = run_seed
	var first_template := catalog.pick_first_room(candidate_rng, effective_mine_id)
	if first_template == null:
		last_error = "İlk güvenli oda seçilemedi."
		return {}

	var session := RunSession.new()
	if not session.start_run(
		run_seed,
		catalog.content_version,
		config.room_count,
		first_template,
		_create_run_id(run_seed),
		effective_mine_id,
		run_kind,
		daily_key,
	):
		last_error = "Koşu oturumu başlatılamadı."
		return {}
	return {
		"session": session,
		"first_template": first_template,
		"seed": run_seed,
		"rng_state": candidate_rng.state,
	}
	return {
		"session": session,
		"firstTemplate": first_template,
		"seed": run_seed,
		"rngState": candidate_rng.state,
	}


static func current_daily_key() -> String:
	var date := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [
		int(date["year"]),
		int(date["month"]),
		int(date["day"]),
	]


static func daily_seed_for_key(key: String) -> int:
	var seed_value := 0x2D28_16FE
	for character: int in key.to_utf8_buffer():
		seed_value = ((seed_value * 16_777_619) ^ character) & 0x7FFF_FFFF
	return maxi(1, seed_value)


func _create_run_id(run_seed: int) -> String:
	run_id_sequence += 1
	return "run_%d_%d_%d" % [
		abs(run_seed),
		int(Time.get_unix_time_from_system() * 1_000_000.0),
		run_id_sequence,
	]
