class_name RunController
extends Node

@export var persistence_enabled := true
@export var save_path := SaveService.DEFAULT_SAVE_PATH
@export var profile_path := ProfileService.DEFAULT_PATH
@export var settings_path := SettingsService.DEFAULT_PATH
@export var tutorial_enabled := true

@onready var gameplay_room: GameplayRoom = $GameplayRoom
@onready var flow_view: RunFlowView = $Interface/RunFlowView
@onready var main_menu_view: MainMenuView = $Interface/MainMenuView
@onready var pause_button: Button = $Interface/PauseButton
@onready var pause_overlay: PauseOverlay = $Interface/PauseOverlay
@onready var settings_overlay: SettingsOverlay = $Interface/SettingsOverlay
@onready var tutorial_overlay: TutorialOverlay = $Interface/TutorialOverlay

enum SettingsContext {
	MAIN_MENU,
	PAUSE,
}

var config: GameConfig
var catalog: RoomCatalog
var run_session: RunSession
var rng := RandomNumberGenerator.new()
var save_service: SaveService
var profile_service: ProfileService
var settings_service: SettingsService
var profile: PlayerProfile
var app_settings: AppSettings
var last_save_error: String
var last_recovery_message: String
var last_result_new_best := false

var pending_continue_snapshot: RunSnapshot
var pending_continue_interrupted := false
var pending_continue_recovered_backup := false
var pending_continue_notice: String
var continue_in_memory := false
var pause_active := false
var pause_origin_screen: int = RunFlowView.Screen.GAMEPLAY
var confirmation_from_main_menu := false
var settings_context: SettingsContext = SettingsContext.MAIN_MENU
var tutorial_return_to_settings := false
var tutorial_coach_step := -1


func _ready() -> void:
	config = GameConfig.load_from_file()
	_initialize_user_data()
	catalog = RoomCatalog.load_default()
	if catalog == null:
		push_error("Oda kataloğu yüklenemedi; oyun başlatılmadı.")
		return
	var route_capacity_errors := catalog.route_capacity_errors(config.room_count)
	if not route_capacity_errors.is_empty():
		push_error("Oda kataloğu koşu ayarını karşılamıyor:\n- %s" % "\n- ".join(route_capacity_errors))
		catalog = null
		return
	gameplay_room.room_finished.connect(_on_room_finished)
	gameplay_room.shot_will_start.connect(_on_shot_will_start)
	gameplay_room.shot_resolved.connect(_on_shot_resolved)
	gameplay_room.block_destroyed.connect(_on_block_destroyed)
	flow_view.bind(self)
	main_menu_view.bind(self)
	pause_overlay.bind(self)
	settings_overlay.bind(self)
	tutorial_overlay.bind(self)
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
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_request()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if tutorial_overlay.is_modal():
		complete_tutorial()
	elif settings_overlay.visible:
		if settings_overlay.mode == SettingsOverlay.Mode.CONFIRM_DELETE_ALL:
			settings_overlay.show_settings()
		else:
			close_settings()
	elif pause_overlay.visible and pause_overlay.mode == PauseOverlay.Mode.CONFIRM_NEW_GAME:
		cancel_new_game_confirmation()
	elif pause_active:
		resume_game()
	elif not main_menu_view.visible and run_session != null and not run_session.ended:
		pause_game()


func _exit_tree() -> void:
	if pause_active and get_tree() != null:
		get_tree().paused = false


func _initialize_user_data() -> void:
	profile = PlayerProfile.new()
	app_settings = AppSettings.new()
	if persistence_enabled:
		profile_service = ProfileService.new(profile_path)
		settings_service = SettingsService.new(settings_path)
		profile = profile_service.load_profile()
		app_settings = settings_service.load_settings()
	TranslationServer.set_locale(str(app_settings.language))
	AudioManager.apply_settings(app_settings)


func _handle_back_request() -> void:
	if tutorial_overlay.is_modal():
		complete_tutorial()
	elif settings_overlay.visible:
		if settings_overlay.mode == SettingsOverlay.Mode.CONFIRM_DELETE_ALL:
			settings_overlay.show_settings()
		else:
			close_settings()
	elif pause_overlay.visible and pause_overlay.mode == PauseOverlay.Mode.CONFIRM_NEW_GAME:
		cancel_new_game_confirmation()
	elif pause_active:
		resume_game()
	elif main_menu_view.visible:
		get_tree().quit()
	elif run_session != null and run_session.ended:
		show_main_menu_from_result()
	else:
		pause_game()


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
				pending_continue_notice = tr("NOTICE_INTERRUPTED")
			elif pending_continue_recovered_backup:
				pending_continue_notice = tr("NOTICE_BACKUP")
			_show_main_menu(true, pending_continue_notice)
			return
	if load_result.status == SaveLoadResult.Status.INVALID:
		last_recovery_message = tr("NOTICE_SAVE_INVALID")
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
	last_result_new_best = false
	flow_view.show_gameplay()
	var loaded := _load_current_room(first_template)
	if loaded:
		gameplay_room.set_simulation_enabled(true)
		pause_button.visible = true
		_save_stable()
		_maybe_show_first_tutorial()
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
		_show_main_menu(true, tr("NOTICE_LOAD_FAILED"))
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


func open_settings_from_main_menu() -> void:
	settings_context = SettingsContext.MAIN_MENU
	settings_overlay.show_settings()


func open_settings_from_pause() -> void:
	if not pause_active:
		return
	settings_context = SettingsContext.PAUSE
	pause_overlay.hide_overlay()
	settings_overlay.show_settings()


func close_settings() -> void:
	settings_overlay.hide_overlay()
	if settings_context == SettingsContext.PAUSE and pause_active:
		pause_overlay.show_pause()


func set_language(language: StringName) -> bool:
	if app_settings == null or not AppSettings.SUPPORTED_LANGUAGES.has(language):
		return false
	app_settings.language = language
	TranslationServer.set_locale(str(language))
	_save_app_settings()
	_refresh_localized_views()
	return true


func toggle_sfx() -> void:
	if app_settings == null:
		return
	app_settings.sfx_enabled = not app_settings.sfx_enabled
	AudioManager.apply_settings(app_settings)
	_save_app_settings()
	settings_overlay.queue_redraw()
	if app_settings.sfx_enabled:
		AudioManager.play_ui_confirm()


func set_sfx_volume(volume: float) -> void:
	if app_settings == null:
		return
	app_settings.sfx_volume = clampf(volume, 0.0, 1.0)
	AudioManager.apply_settings(app_settings)
	_save_app_settings()
	settings_overlay.queue_redraw()


func toggle_music() -> void:
	if app_settings == null:
		return
	app_settings.music_enabled = not app_settings.music_enabled
	AudioManager.apply_settings(app_settings)
	_save_app_settings()
	settings_overlay.queue_redraw()


func set_music_volume(volume: float) -> void:
	if app_settings == null:
		return
	app_settings.music_volume = clampf(volume, 0.0, 1.0)
	AudioManager.apply_settings(app_settings)
	_save_app_settings()
	settings_overlay.queue_redraw()


func toggle_screen_shake() -> void:
	if app_settings == null:
		return
	app_settings.shake_enabled = not app_settings.shake_enabled
	_save_app_settings()
	settings_overlay.queue_redraw()


func show_tutorial_from_settings() -> void:
	tutorial_return_to_settings = true
	settings_overlay.hide_overlay()
	_show_tutorial()


func complete_tutorial() -> void:
	if not tutorial_overlay.is_modal():
		return
	tutorial_overlay.hide_overlay()
	tutorial_coach_step = -1
	if profile != null:
		profile.tutorial_completed = true
		_save_profile()
	if tutorial_return_to_settings:
		tutorial_return_to_settings = false
		settings_overlay.show_settings()
	elif run_session != null:
		_restore_active_screen()


func confirm_reset_progress() -> bool:
	var replacement_profile := PlayerProfile.new()
	var errors := PackedStringArray()
	if save_service != null and not save_service.clear_all():
		errors.append(save_service.last_error)
	if profile_service != null:
		if not profile_service.clear_all():
			errors.append(profile_service.last_error)
		elif not profile_service.save_profile(replacement_profile):
			errors.append(profile_service.last_error)

	if not errors.is_empty():
		last_save_error = "; ".join(errors)
		push_warning("İlerleme sıfırlanamadı: %s" % last_save_error)
		_save_profile()
		if run_session != null:
			_save_stable()
		settings_overlay.show_settings(tr("NOTICE_STORAGE_FAILED"))
		return false

	profile = replacement_profile
	run_session = null
	last_result_new_best = false
	tutorial_coach_step = -1
	_clear_pending_continue()
	settings_overlay.hide_overlay()
	tutorial_overlay.hide_overlay()
	pause_overlay.hide_overlay()
	_leave_pause_state()
	_show_main_menu(false, tr("NOTICE_PROGRESS_RESET"))
	return true


func confirm_delete_all_data() -> bool:
	var errors := PackedStringArray()
	if save_service != null and not save_service.clear_all():
		errors.append(save_service.last_error)
	if profile_service != null and not profile_service.clear_all():
		errors.append(profile_service.last_error)
	if settings_service != null and not settings_service.clear_all():
		errors.append(settings_service.last_error)
	if not errors.is_empty():
		last_save_error = "; ".join(errors)
		push_warning("Tüm veriler silinemedi: %s" % last_save_error)
		_save_profile()
		_save_app_settings()
		if run_session != null:
			_save_stable()
		settings_overlay.show_settings(tr("NOTICE_STORAGE_FAILED"))
		return false

	profile = PlayerProfile.new()
	app_settings = AppSettings.new()
	run_session = null
	last_result_new_best = false
	tutorial_coach_step = -1
	_clear_pending_continue()
	TranslationServer.set_locale(str(app_settings.language))
	AudioManager.apply_settings(app_settings)
	settings_overlay.hide_overlay()
	tutorial_overlay.hide_overlay()
	pause_overlay.hide_overlay()
	_leave_pause_state()
	_refresh_localized_views()
	_show_main_menu(false, tr("NOTICE_ALL_DATA_DELETED"))
	return true


func _maybe_show_first_tutorial() -> void:
	if tutorial_enabled and profile != null and not profile.tutorial_completed:
		tutorial_return_to_settings = false
		tutorial_coach_step = 0
		tutorial_overlay.show_coach(tutorial_coach_step)


func _show_tutorial() -> void:
	tutorial_coach_step = -1
	gameplay_room.set_simulation_enabled(false)
	pause_button.visible = false
	tutorial_overlay.show_tutorial()


func _finish_interactive_tutorial() -> void:
	if tutorial_coach_step < 0:
		return
	tutorial_coach_step = -1
	tutorial_overlay.hide_overlay()
	if profile != null and not profile.tutorial_completed:
		profile.tutorial_completed = true
		_save_profile()


func _refresh_localized_views() -> void:
	gameplay_room.refresh_locale()
	main_menu_view.queue_redraw()
	pause_overlay.queue_redraw()
	settings_overlay.refresh_locale()
	tutorial_overlay.refresh_locale()
	flow_view.queue_redraw()


func pause_game() -> void:
	if pause_active or main_menu_view.visible or run_session == null or run_session.ended:
		return
	if flow_view.screen != RunFlowView.Screen.GAMEPLAY \
		and flow_view.screen != RunFlowView.Screen.ROUTE_SELECTION:
		return
	gameplay_room.cancel_aim_for_pause()
	if tutorial_overlay.mode == TutorialOverlay.Mode.COACH:
		tutorial_overlay.hide_overlay()
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
	var notice := tr("NOTICE_RUN_SAVED")
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
				notice = tr("NOTICE_SHOT_RETRY")
			else:
				continue_in_memory = true
				notice = tr("NOTICE_MEMORY_ONLY")
		else:
			continue_in_memory = true
			notice = tr("NOTICE_MEMORY_ONLY")
	else:
		pending_continue_snapshot = create_snapshot()
		_save_stable()

	pending_continue_notice = notice
	gameplay_room.set_simulation_enabled(false)
	_leave_pause_state()
	_show_main_menu(pending_continue_snapshot != null or continue_in_memory, notice)


func show_main_menu_from_result() -> bool:
	if save_service != null and not save_service.clear_all():
		last_save_error = save_service.last_error
		push_warning("Tamamlanan koşu kaydı kaldırılamadı: %s" % last_save_error)
		_clear_pending_continue()
		continue_in_memory = true
		_show_main_menu(true, tr("NOTICE_STORAGE_FAILED"))
		return false
	run_session = null
	_clear_pending_continue()
	_show_main_menu(false)
	return true


func select_route(option_id: StringName) -> bool:
	if run_session == null:
		return false
	var selected_template := run_session.select_route(option_id)
	if selected_template == null:
		return false
	AudioManager.play_route_select()
	flow_view.show_gameplay()
	var loaded := _load_current_room(selected_template)
	if loaded:
		gameplay_room.set_simulation_enabled(true)
		pause_button.visible = true
		if tutorial_coach_step == 2:
			_finish_interactive_tutorial()
		_save_stable()
	return loaded


func _on_room_finished(resolution: RoomResolution) -> void:
	if run_session == null or not run_session.resolve_room(resolution):
		return
	gameplay_room.set_simulation_enabled(false)
	if run_session.ended:
		if tutorial_overlay.mode == TutorialOverlay.Mode.COACH:
			tutorial_overlay.hide_overlay()
			tutorial_coach_step = -1
		_record_run_result_if_needed()
		_save_stable()
		pause_button.visible = false
		flow_view.show_run_result(run_session, profile, last_result_new_best)
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
	if tutorial_coach_step == 1 and run_session.room_number == 1:
		tutorial_coach_step = 2
		tutorial_overlay.show_coach(tutorial_coach_step)


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
	if tutorial_coach_step == 0:
		tutorial_coach_step = 1
		tutorial_overlay.show_coach(tutorial_coach_step)
	if not persistence_enabled or save_service == null:
		return
	var snapshot := create_snapshot()
	if not save_service.save_pre_shot(snapshot):
		_report_save_error()


func _on_shot_resolved(resolution: RoomResolution) -> void:
	if resolution.room_finished:
		return
	_save_stable()


func _on_block_destroyed(block_type: int) -> void:
	if app_settings == null or not app_settings.shake_enabled:
		return
	var is_core := block_type == BlockState.BlockType.CORE
	gameplay_room.trigger_screen_shake(
		7.0 if is_core else 3.0,
		0.26 if is_core else 0.14,
	)


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
	if run_session.ended:
		_record_run_result_if_needed()
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
			flow_view.show_run_result(run_session, profile, last_result_new_best)
			pause_button.visible = false
	_restore_tutorial_coach()


func _restore_tutorial_coach() -> void:
	if not tutorial_enabled or profile == null or profile.tutorial_completed or run_session == null:
		tutorial_coach_step = -1
		if tutorial_overlay.mode == TutorialOverlay.Mode.COACH:
			tutorial_overlay.hide_overlay()
		return
	if run_session.phase == RunSession.Phase.ROUTE_SELECTION and run_session.room_number == 1:
		tutorial_coach_step = 2
	elif run_session.phase == RunSession.Phase.PLAYING and run_session.room_number == 1:
		tutorial_coach_step = 0 if gameplay_room.room.break_score == 0 \
			and gameplay_room.room.shots_remaining == config.shots_per_room else 1
	else:
		tutorial_coach_step = -1
	if tutorial_coach_step >= 0:
		tutorial_overlay.show_coach(tutorial_coach_step)
	elif tutorial_overlay.mode == TutorialOverlay.Mode.COACH:
		tutorial_overlay.hide_overlay()


func _show_main_menu(can_continue: bool, notice: String = "") -> void:
	_leave_pause_state()
	pause_overlay.hide_overlay()
	pause_button.visible = false
	flow_view.show_gameplay()
	gameplay_room.set_simulation_enabled(false)
	if tutorial_overlay.mode == TutorialOverlay.Mode.COACH:
		tutorial_overlay.hide_overlay()
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


func _record_run_result_if_needed() -> void:
	if run_session == null or not run_session.ended or profile == null:
		return
	if profile.last_recorded_run_id == run_session.run_id:
		last_result_new_best = false
		return
	last_result_new_best = profile.record_run(
		run_session.run_id,
		run_session.banked_score,
		run_session.succeeded,
		run_session.cores_broken,
	)
	_save_profile()
	if last_result_new_best:
		AudioManager.play_new_best()


func _save_profile() -> void:
	if profile_service != null and not profile_service.save_profile(profile):
		push_warning("Profil kaydedilemedi: %s" % profile_service.last_error)


func _save_app_settings() -> void:
	if settings_service != null and not settings_service.save_settings(app_settings):
		push_warning("Ayarlar kaydedilemedi: %s" % settings_service.last_error)


func _save_stable() -> void:
	if not persistence_enabled or save_service == null:
		return
	var snapshot := create_snapshot()
	if not save_service.save_stable(snapshot):
		_report_save_error()


func _report_save_error() -> void:
	last_save_error = save_service.last_error if save_service != null else "Kayıt servisi hazır değil."
	push_warning("Oyun kaydedilemedi: %s" % last_save_error)
