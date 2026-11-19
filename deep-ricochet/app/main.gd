class_name RunController
extends Node

const RunFactory := preload("res://app/run_session_factory.gd")
const EventReporter := preload("res://app/run_event_reporter.gd")
const RunSettingsController := preload("res://app/run_settings_controller.gd")
const TutorialController := preload("res://app/tutorial_controller.gd")
const UserDataController := preload("res://app/user_data_controller.gd")
const StorageCoordinator := preload("res://app/storage_coordinator.gd")
const RunPersistenceController := preload("res://app/run_persistence_controller.gd")
const RunNavigationController := preload("res://app/run_navigation_controller.gd")
const UiLayoutScript := preload("res://ui/ui_layout.gd")

@export var persistence_enabled := true
@export var save_path := SaveService.DEFAULT_SAVE_PATH
@export var profile_path := ProfileService.DEFAULT_PATH
@export var settings_path := SettingsService.DEFAULT_PATH
@export var test_event_path := TestEventService.DEFAULT_PATH
@export var tutorial_enabled := true

@onready var gameplay_room: GameplayRoom = $GameplayRoom
@onready var interface_layer: CanvasLayer = $Interface
@onready var flow_view: RunFlowView = $Interface/RunFlowView
@onready var main_menu_view: MainMenuView = $Interface/MainMenuView
@onready var mine_select_view: MineSelectView = $Interface/MineSelectView
@onready var pause_button: Button = $Interface/PauseButton
@onready var speed_button: Button = $Interface/SpeedButton
@onready var pause_overlay: PauseOverlay = $Interface/PauseOverlay
@onready var settings_overlay: SettingsOverlay = $Interface/SettingsOverlay
@onready var tutorial_overlay: TutorialOverlay = $Interface/TutorialOverlay
@onready var storage_notice: Control = $Interface/StorageNotice

enum SettingsContext {
	MAIN_MENU,
	PAUSE,
}

const HAPTIC_COOLDOWN_MSEC := 90

var config: GameConfig
var mine_registry: MineRegistry
var catalog: RoomCatalog
var run_session: RunSession
var rng := RandomNumberGenerator.new()
var save_service: SaveService
var profile_service: ProfileService
var settings_service: SettingsService
var test_event_service: TestEventService
var profile: PlayerProfile
var app_settings: AppSettings
var session_factory = RunFactory.new()
var event_reporter = EventReporter.new()
var settings_controller = RunSettingsController.new()
var tutorial_controller = TutorialController.new()
var user_data_controller = UserDataController.new()
var storage_coordinator = StorageCoordinator.new()
var persistence_controller = RunPersistenceController.new()
var navigation_controller = RunNavigationController.new()
var last_save_error: String
var last_recovery_message: String
var last_result_new_best := false
var failed_storage_channels: Dictionary[StringName, bool] = {}

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
var last_haptic_tick_msec := -HAPTIC_COOLDOWN_MSEC
var pending_new_mine_id: StringName = &"mine_01"
var pending_new_run_kind: int = RunSession.RunKind.NORMAL
var pending_new_seed := 0
var pending_new_daily_key: String


func _ready() -> void:
	_apply_safe_layout()
	get_viewport().size_changed.connect(_apply_safe_layout)
	config = GameConfig.load_from_file()
	_initialize_user_data()
	mine_registry = MineRegistry.load_default()
	catalog = mine_registry.catalog if mine_registry != null else null
	if mine_registry == null or catalog == null:
		push_error("Maden ve oda kataloğu yüklenemedi; oyun başlatılmadı.")
		return
	for mine: MineDefinition in mine_registry.mines:
		var route_capacity_errors := catalog.route_capacity_errors(config.room_count, mine.mine_id)
		if not route_capacity_errors.is_empty():
			push_error("%s koşu ayarını karşılamıyor:\n- %s" % [mine.mine_id, "\n- ".join(route_capacity_errors)])
			catalog = null
			return
	session_factory.configure(config, catalog, mine_registry)
	gameplay_room.room_finished.connect(_on_room_finished)
	gameplay_room.shot_will_start.connect(_on_shot_will_start)
	gameplay_room.shot_started.connect(_on_shot_started)
	gameplay_room.shot_resolved.connect(_on_shot_resolved)
	gameplay_room.block_destroyed.connect(_on_block_destroyed)
	flow_view.bind(self)
	main_menu_view.bind(self)
	mine_select_view.bind(self)
	pause_overlay.bind(self)
	settings_overlay.bind(self)
	tutorial_overlay.bind(self)
	pause_button.pressed.connect(pause_game)
	speed_button.pressed.connect(toggle_simulation_speed)
	gameplay_room.set_simulation_enabled(false)
	pause_button.visible = false
	speed_button.visible = false
	_boot_from_save()
	print("Deep Ricochet hazır. Madenler: %d, içerik: %s" % [mine_registry.mines.size(), catalog.content_version])


func _apply_safe_layout() -> void:
	UiLayoutScript.refresh()
	gameplay_room.transform = UiLayoutScript.content_transform
	interface_layer.transform = UiLayoutScript.content_transform


func _notification(what: int) -> void:
	if not is_node_ready():
		return
	if what == MainLoop.NOTIFICATION_APPLICATION_PAUSED \
		or what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
		pause_game()
		_flush_test_events()
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
	elif mine_select_view.visible:
		close_mine_selection()
	elif pause_overlay.visible and pause_overlay.mode != PauseOverlay.Mode.PAUSE:
		cancel_new_game_confirmation()
	elif pause_active:
		resume_game()
	elif not main_menu_view.visible and run_session != null and not run_session.ended:
		pause_game()


func _exit_tree() -> void:
	_flush_test_events()
	if pause_active and get_tree() != null:
		get_tree().paused = false


func _initialize_user_data() -> void:
	persistence_controller.initialize_user_data(self)


func _handle_back_request() -> void:
	if tutorial_overlay.is_modal():
		complete_tutorial()
	elif settings_overlay.visible:
		if settings_overlay.mode == SettingsOverlay.Mode.CONFIRM_DELETE_ALL:
			settings_overlay.show_settings()
		else:
			close_settings()
	elif mine_select_view.visible:
		close_mine_selection()
	elif pause_overlay.visible and pause_overlay.mode != PauseOverlay.Mode.PAUSE:
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
	persistence_controller.boot_from_save(self)


func start_new_run(
	requested_seed: int = 0,
	requested_mine_id: StringName = &"mine_01",
	run_kind: int = RunSession.RunKind.NORMAL,
	daily_key: String = "",
) -> bool:
	var prepared: Dictionary = session_factory.create_run(
		requested_seed,
		requested_mine_id,
		run_kind,
		daily_key,
		profile,
	)
	if prepared.is_empty():
		if not session_factory.last_error.is_empty():
			push_error(session_factory.last_error)
		return false
	var new_session: RunSession = prepared["session"]
	var first_template: RoomTemplate = prepared["first_template"]
	var run_seed := int(prepared["seed"])
	var previous_session := run_session
	run_session = new_session
	if not _load_current_room(first_template):
		run_session = previous_session
		return false
	rng.seed = run_seed
	rng.state = int(prepared["rng_state"])
	_leave_pause_state()
	_clear_pending_continue()
	main_menu_view.hide_menu()
	mine_select_view.hide_selector()
	pause_overlay.hide_overlay()
	last_result_new_best = false
	flow_view.show_gameplay()
	gameplay_room.set_simulation_speed(1)
	_refresh_speed_button()
	gameplay_room.set_simulation_enabled(true)
	pause_button.visible = true
	speed_button.visible = true
	_save_stable()
	_record_test_event(&"run_started", {
		"runKind": run_session.run_kind,
		"firstTemplateId": str(first_template.room_id),
	})
	_maybe_show_first_tutorial()
	return true


func continue_saved_run() -> bool:
	return persistence_controller.continue_saved_run(self)


func request_new_game_from_menu() -> void:
	open_mine_selection()


func open_mine_selection() -> void:
	navigation_controller.open_mine_selection(self)


func close_mine_selection() -> void:
	navigation_controller.close_mine_selection(self)


func request_mine_run(mine_id: StringName) -> bool:
	return navigation_controller.request_mine_run(self, mine_id)


func request_daily_run() -> void:
	navigation_controller.request_daily_run(self)


func current_daily_key() -> String:
	return RunFactory.current_daily_key()


func daily_seed_for_key(key: String) -> int:
	return RunFactory.daily_seed_for_key(key)


func _prepare_new_run(mine_id: StringName, kind: int, seed: int, daily_key: String) -> void:
	navigation_controller.prepare_new_run(self, mine_id, kind, seed, daily_key)


func request_new_game_confirmation(from_main_menu: bool) -> void:
	navigation_controller.request_new_game_confirmation(self, from_main_menu)


func cancel_new_game_confirmation() -> void:
	navigation_controller.cancel_new_game_confirmation(self)


func confirm_new_game() -> void:
	navigation_controller.confirm_new_game(self)


func restart_same_seed() -> bool:
	return navigation_controller.restart_same_seed(self)


func restart_current_mine() -> bool:
	return navigation_controller.restart_current_mine(self)


func next_mine_id_from_result() -> StringName:
	return navigation_controller.next_mine_id_from_result(self)


func start_next_mine_from_result() -> bool:
	return navigation_controller.start_next_mine_from_result(self)


func toggle_simulation_speed() -> void:
	navigation_controller.toggle_simulation_speed(self)


func request_main_menu_confirmation() -> void:
	navigation_controller.request_main_menu_confirmation(self)


func confirm_main_menu_return() -> void:
	navigation_controller.confirm_main_menu_return(self)


func open_settings_from_main_menu() -> void:
	settings_controller.open_from_main_menu(self)


func open_settings_from_pause() -> void:
	settings_controller.open_from_pause(self)


func close_settings() -> void:
	settings_controller.close(self)


func set_language(language: StringName) -> bool:
	return settings_controller.set_language(self, language)


func toggle_sfx() -> void:
	settings_controller.toggle_sfx(self)


func set_sfx_volume(volume: float) -> void:
	settings_controller.set_sfx_volume(self, volume)


func toggle_music() -> void:
	settings_controller.toggle_music(self)


func set_music_volume(volume: float) -> void:
	settings_controller.set_music_volume(self, volume)


func toggle_screen_shake() -> void:
	settings_controller.toggle_screen_shake(self)


func toggle_haptics() -> void:
	settings_controller.toggle_haptics(self)


func set_quality_mode(mode: int) -> void:
	settings_controller.set_quality_mode(self, mode)


func show_tutorial_from_settings() -> void:
	settings_controller.show_tutorial(self)


func export_test_events_to_clipboard() -> bool:
	return settings_controller.export_test_events_to_clipboard(self)


func complete_tutorial() -> void:
	tutorial_controller.complete(self)


func confirm_reset_progress() -> bool:
	return user_data_controller.reset_progress(self)


func confirm_delete_all_data() -> bool:
	return user_data_controller.delete_all(self)


func _maybe_show_first_tutorial() -> void:
	tutorial_controller.maybe_show_first(self)


func _show_tutorial() -> void:
	tutorial_controller.show(self)


func _finish_interactive_tutorial() -> void:
	tutorial_controller.finish_interactive(self)


func _refresh_localized_views() -> void:
	gameplay_room.refresh_locale()
	main_menu_view.queue_redraw()
	pause_overlay.queue_redraw()
	settings_overlay.refresh_locale()
	tutorial_overlay.refresh_locale()
	flow_view.queue_redraw()


func pause_game() -> void:
	navigation_controller.pause_game(self)


func resume_game() -> void:
	navigation_controller.resume_game(self)


func return_to_main_menu() -> void:
	navigation_controller.return_to_main_menu(self)


func show_main_menu_from_result() -> bool:
	return navigation_controller.show_main_menu_from_result(self)


func select_route(option_id: StringName) -> bool:
	if run_session == null:
		return false
	var selected_template := run_session.route_template(option_id)
	if selected_template == null:
		return false
	var previous_template := gameplay_room.current_template
	var previous_room_snapshot := gameplay_room.capture_snapshot()
	if not gameplay_room.load_room(selected_template):
		return false
	if run_session.select_route(option_id) == null:
		if previous_template != null and previous_room_snapshot != null:
			gameplay_room.restore_room(previous_template, previous_room_snapshot)
		return false
	_record_test_event(&"route_selected", {
		"optionId": str(option_id),
		"templateId": str(selected_template.room_id),
	})
	gameplay_room.set_run_context(
		run_session.room_number,
		run_session.room_count,
		run_session.banked_score,
	)
	AudioManager.play_route_select()
	flow_view.show_gameplay()
	gameplay_room.set_simulation_enabled(true)
	pause_button.visible = true
	speed_button.visible = true
	_refresh_speed_button()
	if tutorial_coach_step == 2:
		_finish_interactive_tutorial()
	_save_stable()
	return true


func _on_room_finished(resolution: RoomResolution) -> void:
	if run_session == null or not run_session.resolve_room(resolution):
		return
	_record_test_event(&"room_completed", {
		"templateId": str(run_session.current_template_id),
		"shotsRemaining": resolution.remaining_shots,
		"breakScore": resolution.break_score,
		"reward": resolution.reward,
		"multiplierBps": resolution.multiplier_bps,
		"succeeded": resolution.succeeded,
	}, false)
	gameplay_room.set_simulation_enabled(false)
	if run_session.ended:
		_record_test_event(&"run_ended", {
			"succeeded": run_session.succeeded,
			"coresBroken": run_session.cores_broken,
			"routeChoices": run_session.route_choices_made,
			"totalScore": run_session.banked_score,
		})
		if tutorial_overlay.mode == TutorialOverlay.Mode.COACH:
			tutorial_overlay.hide_overlay()
			tutorial_coach_step = -1
		_record_run_result_if_needed()
		_save_stable()
		pause_button.visible = false
		speed_button.visible = false
		flow_view.show_run_result(run_session, profile, last_result_new_best)
		return

	var options := catalog.create_route_options(
		run_session.room_number + 1,
		rng,
		run_session.used_template_ids(),
		run_session.mine_id,
	)
	if not run_session.set_route_options(options):
		push_error("Sonraki oda için rota seçenekleri üretilemedi.")
		return
	var option_ids: Array[String] = []
	var template_ids: Array[String] = []
	var multipliers_bps: Array[int] = []
	for option: RouteOption in options:
		option_ids.append(str(option.option_id))
		template_ids.append(str(option.template.room_id))
		multipliers_bps.append(option.template.multiplier_bps)
	_record_test_event(&"route_offered", {
		"optionIds": option_ids,
		"templateIds": template_ids,
		"multipliersBps": multipliers_bps,
	})
	_save_stable()
	pause_button.visible = true
	speed_button.visible = false
	flow_view.show_route_selection(run_session)
	if tutorial_coach_step == 1 and run_session.room_number == 1:
		tutorial_coach_step = 2
		tutorial_overlay.show_coach(tutorial_coach_step)


func create_snapshot() -> RunSnapshot:
	return persistence_controller.create_snapshot(self)


func restore_snapshot(snapshot: RunSnapshot, recovery_message: String = "") -> bool:
	return persistence_controller.restore_snapshot(self, snapshot, recovery_message)


func _on_shot_will_start() -> void:
	if tutorial_coach_step == 0:
		tutorial_coach_step = 1
		tutorial_overlay.show_coach(tutorial_coach_step)
	if not persistence_enabled or save_service == null:
		return
	var snapshot := create_snapshot()
	if save_service.save_pre_shot(snapshot):
		_mark_storage_write_succeeded(&"run")
	else:
		_report_save_error(save_service.last_error, &"run")


func _on_shot_started() -> void:
	_record_test_event(&"shot_started", {
		"templateId": str(run_session.current_template_id) if run_session != null else "",
		"shotsRemaining": gameplay_room.room.shots_remaining,
		"ballsLaunched": gameplay_room.volley.launched_count,
	}, false)


func _on_shot_resolved(resolution: RoomResolution) -> void:
	_record_test_event(&"shot_resolved", {
		"templateId": str(run_session.current_template_id) if run_session != null else "",
		"shotsRemaining": resolution.remaining_shots,
		"ballsLaunched": gameplay_room.volley.launched_count,
		"ballsCollected": gameplay_room.volley.collected_count,
		"ballsForcedCollected": gameplay_room.volley.forced_collection_count,
		"breakScore": resolution.break_score,
		"reward": resolution.reward,
		"multiplierBps": resolution.multiplier_bps,
		"succeeded": resolution.succeeded,
		"roomFinished": resolution.room_finished,
	}, not resolution.room_finished)
	if resolution.room_finished:
		return
	_save_stable()


func _on_block_destroyed(block_type: int) -> void:
	if app_settings == null:
		return
	var is_core := block_type == BlockState.BlockType.CORE
	var is_explosive := block_type == BlockState.BlockType.EXPLOSIVE
	if app_settings.haptics_enabled:
		_try_haptic(70 if is_core else (45 if is_explosive else 20))
	if not app_settings.shake_enabled:
		return
	var quality_scale := 1.0 if app_settings.quality_mode == AppSettings.QualityMode.GRAPHICS else 0.55
	gameplay_room.trigger_screen_shake(
		(7.0 if is_core else (5.0 if is_explosive else 3.0)) * quality_scale,
		(0.26 if is_core else (0.2 if is_explosive else 0.14)) * quality_scale,
	)


func _load_current_room(template: RoomTemplate) -> bool:
	if run_session == null or not gameplay_room.set_shots_per_room(
		RunSession.shots_per_room_for_kind(config, run_session.run_kind)
	):
		return false
	if not gameplay_room.load_room(template):
		return false
	gameplay_room.set_run_context(
		run_session.room_number,
		run_session.room_count,
		run_session.banked_score,
	)
	return true


func _restore_snapshot(snapshot: RunSnapshot) -> bool:
	return persistence_controller.restore_internal(self, snapshot)


func _restore_active_screen() -> void:
	if run_session == null:
		return
	match run_session.phase:
		RunSession.Phase.PLAYING:
			flow_view.show_gameplay()
			gameplay_room.set_simulation_enabled(true)
			pause_button.visible = true
			speed_button.visible = true
			_refresh_speed_button()
		RunSession.Phase.ROUTE_SELECTION:
			gameplay_room.set_simulation_enabled(false)
			flow_view.show_route_selection(run_session)
			pause_button.visible = true
			speed_button.visible = false
		RunSession.Phase.RUN_RESULT:
			gameplay_room.set_simulation_enabled(false)
			flow_view.show_run_result(run_session, profile, last_result_new_best)
			pause_button.visible = false
			speed_button.visible = false
	_restore_tutorial_coach()


func _restore_tutorial_coach() -> void:
	tutorial_controller.restore_coach(self)


func _show_main_menu(can_continue: bool, notice: String = "") -> void:
	_leave_pause_state()
	pause_overlay.hide_overlay()
	pause_button.visible = false
	speed_button.visible = false
	flow_view.show_gameplay()
	gameplay_room.set_simulation_enabled(false)
	mine_select_view.hide_selector()
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
		run_session.mine_id,
		run_session.run_kind == RunSession.RunKind.DAILY,
		run_session.daily_key,
	)
	_save_profile()
	if last_result_new_best:
		AudioManager.play_new_best()


func _save_profile() -> void:
	storage_coordinator.save_profile(self)


func _save_app_settings() -> void:
	storage_coordinator.save_settings(self)


func _save_stable() -> void:
	storage_coordinator.save_stable(self)


func _report_save_error(error_message: String = "", channel: StringName = &"run") -> void:
	storage_coordinator.report_error(self, error_message, channel)


func _mark_storage_write_succeeded(channel: StringName) -> void:
	storage_coordinator.mark_write_succeeded(self, channel)


func _clear_storage_failure_state() -> void:
	storage_coordinator.clear_failure_state(self)


func _refresh_speed_button() -> void:
	if not is_instance_valid(speed_button):
		return
	speed_button.text = "×%d" % gameplay_room.simulation_speed


func _apply_quality_mode() -> void:
	if app_settings == null:
		return
	DeepUI.set_high_quality(app_settings.quality_mode == AppSettings.QualityMode.GRAPHICS)
	if is_instance_valid(gameplay_room):
		gameplay_room.set_quality_mode(app_settings.quality_mode)
	if is_instance_valid(main_menu_view):
		main_menu_view.queue_redraw()
	if is_instance_valid(flow_view):
		flow_view.queue_redraw()


func _record_test_event(
	event_name: StringName,
	data: Dictionary = {},
	persist_immediately := true,
) -> void:
	event_reporter.record(
		test_event_service,
		run_session,
		event_name,
		data,
		persist_immediately,
	)


func _flush_test_events() -> void:
	event_reporter.flush(test_event_service)


func _record_snapshot_test_event(
	event_name: StringName,
	snapshot: RunSnapshot,
	data: Dictionary = {},
) -> void:
	event_reporter.record_snapshot(test_event_service, event_name, snapshot, data)


func _try_haptic(duration_msec: int) -> void:
	if not OS.has_feature("android"):
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec - last_haptic_tick_msec < HAPTIC_COOLDOWN_MSEC:
		return
	last_haptic_tick_msec = now_msec
	Input.vibrate_handheld(duration_msec)
