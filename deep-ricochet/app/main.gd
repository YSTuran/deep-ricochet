class_name RunController
extends Node

@export var persistence_enabled := true
@export var save_path := SaveService.DEFAULT_SAVE_PATH

@onready var gameplay_room: GameplayRoom = $GameplayRoom
@onready var flow_view: RunFlowView = $Interface/RunFlowView
@onready var main_menu_view: MainMenuView = $Interface/MainMenuView
@onready var pause_button: Button = $Interface/PauseButton
@onready var pause_overlay: PauseOverlay = $Interface/PauseOverlay

var config: GameConfig
var catalog: RoomCatalog
var run_session: RunSession
var rng := RandomNumberGenerator.new()
var save_service: SaveService
var last_save_error: String
var last_recovery_message: String

var pending_continue_snapshot: RunSnapshot
var pending_continue_interrupted := false
var pending_continue_recovered_backup := false
var pending_continue_notice: String
var continue_in_memory := false
var pause_active := false
var pause_origin_screen: int = RunFlowView.Screen.GAMEPLAY
var confirmation_from_main_menu := false


func _ready() -> void:
	config = GameConfig.load_from_file()
	catalog = RoomCatalog.load_default()
	if catalog == null:
		push_error("Oda kataloğu yüklenemedi; oyun başlatılmadı.")
		return
	gameplay_room.room_finished.connect(_on_room_finished)
	gameplay_room.shot_will_start.connect(_on_shot_will_start)
	gameplay_room.shot_resolved.connect(_on_shot_resolved)
	flow_view.bind(self)
	main_menu_view.bind(self)
	pause_overlay.bind(self)
	pause_button.pressed.connect(pause_game)
	gameplay_room.set_simulation_enabled(false)
	pause_button.visible = false
	_boot_from_save()
	print("Deep Ricochet hazır. İçerik: %s" % catalog.content_version)


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == MainLoop.NOTIFICATION_APPLICATION_PAUSED \
		or what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
		pause_game()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if pause_overlay.visible and pause_overlay.mode == PauseOverlay.Mode.CONFIRM_NEW_GAME:
		cancel_new_game_confirmation()
	elif pause_active:
		resume_game()
	elif not main_menu_view.visible and run_session != null and not run_session.ended:
		pause_game()


func _exit_tree() -> void:
	if pause_active and get_tree() != null:
		get_tree().paused = false


func _boot_from_save() -> void:
	if not persistence_enabled:
		_show_main_menu(false)
		return
	save_service = SaveService.new(save_path)
	var load_result := save_service.load_active(catalog, config)
	if load_result.has_valid_save():
		var snapshot := load_result.snapshot_for_restore()
		if snapshot.ended:
			if _restore_snapshot(snapshot):
				if load_result.status == SaveLoadResult.Status.RECOVERED_BACKUP:
					last_recovery_message = load_result.message
					save_service.discard_primary()
				_save_stable()
				return
		else:
			pending_continue_snapshot = snapshot
			pending_continue_interrupted = load_result.interrupted_shot()
			pending_continue_recovered_backup = (
				load_result.status == SaveLoadResult.Status.RECOVERED_BACKUP
			)
			if pending_continue_interrupted:
				pending_continue_notice = "Yarım kalan atış baştan oynanacak."
			elif pending_continue_recovered_backup:
				pending_continue_notice = load_result.message
			_show_main_menu(true, pending_continue_notice)
			return
	if load_result.status == SaveLoadResult.Status.INVALID:
		last_recovery_message = "Kayıt doğrulanamadı; bozuk dosya ayrıldı."
		save_service.quarantine_invalid()
		_show_main_menu(false, last_recovery_message)
		return
	_show_main_menu(false)


func start_new_run(requested_seed: int = 0) -> bool:
	if catalog == null:
		return false
	_leave_pause_state()
	_clear_pending_continue()
	main_menu_view.hide_menu()
	pause_overlay.hide_overlay()
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
		gameplay_room.set_simulation_enabled(true)
		pause_button.visible = true
		_save_stable()
	return loaded


func continue_saved_run() -> bool:
	if continue_in_memory and run_session != null:
		continue_in_memory = false
		main_menu_view.hide_menu()
		_restore_active_screen()
		return true
	if pending_continue_snapshot == null:
		return false

	var snapshot := pending_continue_snapshot
	var recovery_message := pending_continue_notice
	var recovered_backup := pending_continue_recovered_backup
	if not _restore_snapshot(snapshot):
		_show_main_menu(true, "Kayıt şu anda açılamadı.")
		return false
	if recovered_backup and save_service != null:
		save_service.discard_primary()
	_clear_pending_continue()
	last_recovery_message = recovery_message
	if not recovery_message.is_empty():
		gameplay_room.show_status(recovery_message)
	_save_stable()
	return true


func request_new_game_from_menu() -> void:
	if pending_continue_snapshot != null or continue_in_memory:
		request_new_game_confirmation(true)
	else:
		start_new_run()


func request_new_game_confirmation(from_main_menu: bool) -> void:
	confirmation_from_main_menu = from_main_menu
	pause_overlay.show_new_game_confirmation()
	if not from_main_menu:
		pause_active = true
		get_tree().paused = true


func cancel_new_game_confirmation() -> void:
	if confirmation_from_main_menu:
		pause_overlay.hide_overlay()
	else:
		pause_overlay.show_pause()


func confirm_new_game() -> void:
	confirmation_from_main_menu = false
	_leave_pause_state()
	start_new_run()


func pause_game() -> void:
	if pause_active or main_menu_view.visible or run_session == null or run_session.ended:
		return
	if flow_view.screen != RunFlowView.Screen.GAMEPLAY \
		and flow_view.screen != RunFlowView.Screen.ROUTE_SELECTION:
		return
	gameplay_room.cancel_aim_for_pause()
	if not gameplay_room.room.shot_in_progress:
		_save_stable()
	pause_origin_screen = flow_view.screen
	pause_active = true
	pause_button.visible = false
	pause_overlay.show_pause()
	get_tree().paused = true


func resume_game() -> void:
	if not pause_active:
		return
	_leave_pause_state()
	pause_overlay.hide_overlay()
	_restore_active_screen()


func return_to_main_menu() -> void:
	if run_session == null or run_session.ended:
		return
	var notice := "Koşu kaydedildi."
	continue_in_memory = false
	pending_continue_snapshot = null
	pending_continue_interrupted = false
	pending_continue_recovered_backup = false

	if gameplay_room.room.shot_in_progress:
		if persistence_enabled and save_service != null:
			var load_result := save_service.load_active(catalog, config)
			if load_result.has_valid_save():
				pending_continue_snapshot = load_result.snapshot_for_restore()
				pending_continue_interrupted = true
				pending_continue_recovered_backup = (
					load_result.status == SaveLoadResult.Status.RECOVERED_BACKUP
				)
				notice = "Atış iptal edildi; devamda yeniden deneyebilirsin."
			else:
				continue_in_memory = true
				notice = "Koşu bu oturum için bellekte tutuldu."
		else:
			continue_in_memory = true
			notice = "Koşu bu oturum için bellekte tutuldu."
	else:
		pending_continue_snapshot = create_snapshot()
		_save_stable()

	pending_continue_notice = notice
	gameplay_room.set_simulation_enabled(false)
	_leave_pause_state()
	_show_main_menu(pending_continue_snapshot != null or continue_in_memory, notice)


func show_main_menu_from_result() -> void:
	if save_service != null:
		save_service.clear_all()
	run_session = null
	_clear_pending_continue()
	_show_main_menu(false)


func select_route(option_id: StringName) -> bool:
	if run_session == null:
		return false
	var selected_template := run_session.select_route(option_id)
	if selected_template == null:
		return false
	flow_view.show_gameplay()
	var loaded := _load_current_room(selected_template)
	if loaded:
		gameplay_room.set_simulation_enabled(true)
		pause_button.visible = true
		_save_stable()
	return loaded


func _on_room_finished(resolution: RoomResolution) -> void:
	if run_session == null or not run_session.resolve_room(resolution):
		return
	gameplay_room.set_simulation_enabled(false)
	if run_session.ended:
		_save_stable()
		pause_button.visible = false
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
	pause_button.visible = true
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
	main_menu_view.hide_menu()
	pause_overlay.hide_overlay()
	_leave_pause_state()
	_restore_active_screen()
	return true


func _restore_active_screen() -> void:
	if run_session == null:
		return
	match run_session.phase:
		RunSession.Phase.PLAYING:
			flow_view.show_gameplay()
			gameplay_room.set_simulation_enabled(true)
			pause_button.visible = true
		RunSession.Phase.ROUTE_SELECTION:
			gameplay_room.set_simulation_enabled(false)
			flow_view.show_route_selection(run_session)
			pause_button.visible = true
		RunSession.Phase.RUN_RESULT:
			gameplay_room.set_simulation_enabled(false)
			flow_view.show_run_result(run_session)
			pause_button.visible = false


func _show_main_menu(can_continue: bool, notice: String = "") -> void:
	_leave_pause_state()
	pause_overlay.hide_overlay()
	pause_button.visible = false
	flow_view.show_gameplay()
	gameplay_room.set_simulation_enabled(false)
	main_menu_view.show_menu(can_continue, notice)


func _leave_pause_state() -> void:
	pause_active = false
	if get_tree() != null:
		get_tree().paused = false


func _clear_pending_continue() -> void:
	pending_continue_snapshot = null
	pending_continue_interrupted = false
	pending_continue_recovered_backup = false
	pending_continue_notice = ""
	continue_in_memory = false


func _save_stable() -> void:
	if not persistence_enabled or save_service == null:
		return
	var snapshot := create_snapshot()
	if not save_service.save_stable(snapshot):
		_report_save_error()


func _report_save_error() -> void:
	last_save_error = save_service.last_error if save_service != null else "Kayıt servisi hazır değil."
	push_warning("Oyun kaydedilemedi: %s" % last_save_error)
