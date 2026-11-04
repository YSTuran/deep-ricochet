class_name RunController
extends Node

@export var persistence_enabled := true
@export var save_path := SaveService.DEFAULT_SAVE_PATH

@onready var gameplay_room: GameplayRoom = $GameplayRoom
@onready var flow_view: RunFlowView = $Interface/RunFlowView

var config: GameConfig
var catalog: RoomCatalog
var run_session: RunSession
var rng := RandomNumberGenerator.new()
var save_service: SaveService
var last_save_error: String
var last_recovery_message: String


func _ready() -> void:
	config = GameConfig.load_from_file()
	catalog = RoomCatalog.load_default()
	if catalog == null:
		push_error("Oda kataloğu yüklenemedi; koşu başlatılmadı.")
		return
	gameplay_room.room_finished.connect(_on_room_finished)
	gameplay_room.shot_will_start.connect(_on_shot_will_start)
	gameplay_room.shot_resolved.connect(_on_shot_resolved)
	flow_view.bind(self)
	if persistence_enabled:
		save_service = SaveService.new(save_path)
		var load_result := save_service.load_active(catalog, config)
		if load_result.has_valid_save() and _restore_snapshot(load_result.snapshot_for_restore()):
			if load_result.interrupted_shot():
				last_recovery_message = "Kesilen atış yeniden denenecek."
			elif load_result.status == SaveLoadResult.Status.RECOVERED_BACKUP:
				last_recovery_message = load_result.message
				save_service.discard_primary()
			if not last_recovery_message.is_empty():
				gameplay_room.show_status(last_recovery_message)
			_save_stable()
			print("Deep Ricochet kaydı geri yüklendi. İçerik: %s" % catalog.content_version)
			return
		if load_result.status == SaveLoadResult.Status.INVALID:
			last_recovery_message = "Kayıt açılamadı; yeni oyun başlatıldı."
			save_service.quarantine_invalid()
	start_new_run()
	if not last_recovery_message.is_empty():
		gameplay_room.show_status(last_recovery_message)
	print("Deep Ricochet koşusu hazır. İçerik: %s" % catalog.content_version)


func start_new_run(requested_seed: int = 0) -> bool:
	if catalog == null:
		return false
	var run_seed := requested_seed
	if run_seed == 0:
		run_seed = int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_usec()
	rng.seed = run_seed
	var first_template := catalog.pick_first_room(rng)
	if first_template == null:
		push_error("İlk güvenli oda seçilemedi.")
		return false

	var new_session := RunSession.new()
	if not new_session.start_run(run_seed, catalog.content_version, config.room_count, first_template):
		push_error("Koşu oturumu başlatılamadı.")
		return false
	run_session = new_session
	flow_view.show_gameplay()
	var loaded := _load_current_room(first_template)
	if loaded:
		_save_stable()
	return loaded


func select_route(option_id: StringName) -> bool:
	if run_session == null:
		return false
	var selected_template := run_session.select_route(option_id)
	if selected_template == null:
		return false
	flow_view.show_gameplay()
	var loaded := _load_current_room(selected_template)
	if loaded:
		_save_stable()
	return loaded


func _on_room_finished(resolution: RoomResolution) -> void:
	if run_session == null or not run_session.resolve_room(resolution):
		return
	gameplay_room.set_input_enabled(false)
	if run_session.ended:
		_save_stable()
		flow_view.show_run_result(run_session)
		return

	var options := catalog.create_route_options(
		run_session.room_number + 1,
		rng,
		run_session.used_template_ids(),
	)
	if not run_session.set_route_options(options):
		push_error("Sonraki oda için rota seçenekleri üretilemedi.")
		return
	_save_stable()
	flow_view.show_route_selection(run_session)


func create_snapshot() -> RunSnapshot:
	if run_session == null:
		return null
	var room_snapshot := gameplay_room.capture_snapshot()
	return RunSnapshot.capture(run_session, room_snapshot, rng.state)


func restore_snapshot(snapshot: RunSnapshot, recovery_message: String = "") -> bool:
	if not _restore_snapshot(snapshot):
		return false
	last_recovery_message = recovery_message
	if not recovery_message.is_empty():
		gameplay_room.show_status(recovery_message)
	return true


func _on_shot_will_start() -> void:
	if not persistence_enabled or save_service == null:
		return
	var snapshot := create_snapshot()
	if not save_service.save_pre_shot(snapshot):
		_report_save_error()


func _on_shot_resolved(resolution: RoomResolution) -> void:
	if resolution.room_finished:
		return
	_save_stable()


func _load_current_room(template: RoomTemplate) -> bool:
	gameplay_room.set_run_context(
		run_session.room_number,
		run_session.room_count,
		run_session.banked_score,
	)
	return gameplay_room.load_room(template)


func _restore_snapshot(snapshot: RunSnapshot) -> bool:
	if snapshot == null:
		return false
	var errors := snapshot.validation_errors(catalog, config)
	if not errors.is_empty():
		push_error("Koşu snapshot geri yüklenemedi:\n- %s" % "\n- ".join(errors))
		return false
	var restored_session := snapshot.create_session(catalog)
	var template := catalog.get_template(snapshot.current_template_id)
	if restored_session == null or template == null:
		return false
	gameplay_room.set_run_context(
		restored_session.room_number,
		restored_session.room_count,
		restored_session.banked_score,
	)
	if not gameplay_room.restore_room(template, snapshot.active_room):
		return false
	run_session = restored_session
	rng.seed = snapshot.seed
	rng.state = snapshot.rng_state
	match run_session.phase:
		RunSession.Phase.PLAYING:
			flow_view.show_gameplay()
			gameplay_room.set_input_enabled(true)
		RunSession.Phase.ROUTE_SELECTION:
			gameplay_room.set_input_enabled(false)
			flow_view.show_route_selection(run_session)
		RunSession.Phase.RUN_RESULT:
			gameplay_room.set_input_enabled(false)
			flow_view.show_run_result(run_session)
	return true


func _save_stable() -> void:
	if not persistence_enabled or save_service == null:
		return
	var snapshot := create_snapshot()
	if not save_service.save_stable(snapshot):
		_report_save_error()


func _report_save_error() -> void:
	last_save_error = save_service.last_error if save_service != null else "Kayıt servisi hazır değil."
	push_warning("Oyun kaydedilemedi: %s" % last_save_error)
