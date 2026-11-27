extends RefCounted

const DailyRooms := preload("res://content/daily_room_factory.gd")
const RunFactory := preload("res://app/run_session_factory.gd")


func open_mine_selection(controller) -> void:
	controller.main_menu_view.hide_menu()
	controller.mine_select_view.show_selector()


func close_mine_selection(controller) -> void:
	controller.mine_select_view.hide_selector()
	controller.main_menu_view.show_menu(
		controller.pending_continue_snapshot != null or controller.continue_in_memory,
		controller.pending_continue_notice,
	)


func request_mine_run(controller, mine_id: StringName) -> bool:
	if controller.mine_registry == null or controller.mine_registry.get_mine(mine_id) == null \
		or controller.profile == null or not controller.profile.is_mine_unlocked(mine_id):
		return false
	prepare_new_run(controller, mine_id, RunSession.RunKind.NORMAL, 0, "")
	if controller.pending_continue_snapshot != null or controller.continue_in_memory:
		request_new_game_confirmation(controller, true)
	else:
		controller.start_new_run(0, mine_id)
	return true


func request_daily_run(controller) -> void:
	var key := RunFactory.current_daily_key()
	prepare_new_run(
		controller,
		DailyRooms.DAILY_MINE_ID,
		RunSession.RunKind.DAILY,
		RunFactory.daily_seed_for_key(key),
		key,
	)
	if controller.pending_continue_snapshot != null or controller.continue_in_memory:
		request_new_game_confirmation(controller, true)
	else:
		controller.start_new_run(
			controller.pending_new_seed,
			controller.pending_new_mine_id,
			controller.pending_new_run_kind,
			key,
		)


func prepare_new_run(
	controller,
	mine_id: StringName,
	kind: int,
	seed: int,
	daily_key: String,
) -> void:
	controller.pending_new_mine_id = mine_id
	controller.pending_new_run_kind = kind
	controller.pending_new_seed = seed
	controller.pending_new_daily_key = daily_key


func request_new_game_confirmation(controller, from_main_menu: bool) -> void:
	if not from_main_menu:
		var current_mine: StringName = (
			controller.run_session.mine_id if controller.run_session != null else &"mine_01"
		)
		prepare_new_run(controller, current_mine, RunSession.RunKind.NORMAL, 0, "")
	controller.confirmation_from_main_menu = from_main_menu
	controller.pause_overlay.show_new_game_confirmation()
	if not from_main_menu:
		controller._enter_pause_state()


func cancel_new_game_confirmation(controller) -> void:
	if controller.confirmation_from_main_menu:
		controller.pause_overlay.hide_overlay()
	else:
		controller.pause_overlay.show_pause()


func confirm_new_game(controller) -> void:
	controller.confirmation_from_main_menu = false
	controller._leave_pause_state()
	controller.start_new_run(
		controller.pending_new_seed,
		controller.pending_new_mine_id,
		controller.pending_new_run_kind,
		controller.pending_new_daily_key,
	)


func restart_same_seed(controller) -> bool:
	if controller.run_session == null or not controller.run_session.ended \
		or controller.catalog == null:
		return false
	if controller.run_session.content_version != controller.catalog.content_version:
		return false
	var retry_seed: int = controller.run_session.seed
	var previous_run_id: String = controller.run_session.run_id
	var restarted: bool = controller.start_new_run(
		retry_seed,
		controller.run_session.mine_id,
		controller.run_session.run_kind,
		controller.run_session.daily_key,
	)
	if restarted:
		controller._record_test_event(&"run_restarted", {
			"previousRunId": previous_run_id,
			"sameSeed": true,
		})
	return restarted


func restart_current_mine(controller) -> bool:
	if controller.run_session == null or not controller.run_session.ended:
		return false
	if controller.run_session.run_kind == RunSession.RunKind.DAILY:
		return restart_same_seed(controller)
	var previous_run_id: String = controller.run_session.run_id
	var restarted: bool = controller.start_new_run(
		0,
		controller.run_session.mine_id,
		RunSession.RunKind.NORMAL,
	)
	if restarted:
		controller._record_test_event(&"run_restarted", {
			"previousRunId": previous_run_id,
			"sameSeed": false,
		})
	return restarted


func next_mine_id_from_result(controller) -> StringName:
	if controller.run_session == null or not controller.run_session.ended \
		or not controller.run_session.succeeded \
		or controller.run_session.run_kind != RunSession.RunKind.NORMAL \
		or controller.mine_registry == null:
		return &""
	var current_mine: MineDefinition = controller.mine_registry.get_mine(
		controller.run_session.mine_id,
	)
	if current_mine == null:
		return &""
	return controller.mine_registry.mine_id_for_order(current_mine.order + 1)


func start_next_mine_from_result(controller) -> bool:
	if controller.run_session == null or not controller.run_session.ended \
		or not controller.run_session.succeeded \
		or controller.run_session.run_kind != RunSession.RunKind.NORMAL \
		or controller.mine_registry == null:
		return false
	var next_mine_id := next_mine_id_from_result(controller)
	if not next_mine_id.is_empty():
		return controller.start_new_run(0, next_mine_id, RunSession.RunKind.NORMAL)
	if not controller.show_main_menu_from_result():
		return false
	open_mine_selection(controller)
	return true


func toggle_simulation_speed(controller) -> void:
	if controller.main_menu_view.visible or controller.pause_active \
		or controller.run_session == null or controller.run_session.ended:
		return
	if controller.flow_view.screen != RunFlowView.Screen.GAMEPLAY:
		return
	controller.gameplay_room.set_simulation_speed(
		2 if controller.gameplay_room.simulation_speed == 1 else 1
	)
	AudioManager.play_ui_click()
	controller._refresh_speed_button()


func request_main_menu_confirmation(controller) -> void:
	if not controller.pause_active or controller.run_session == null \
		or controller.run_session.ended:
		return
	controller.confirmation_from_main_menu = false
	controller.pause_overlay.show_main_menu_confirmation()


func confirm_main_menu_return(controller) -> void:
	if not controller.pause_active \
		or controller.pause_overlay.mode != PauseOverlay.Mode.CONFIRM_MAIN_MENU:
		return
	controller.pause_overlay.hide_overlay()
	return_to_main_menu(controller)


func pause_game(controller) -> void:
	if controller.pause_active or controller.main_menu_view.visible \
		or controller.run_session == null or controller.run_session.ended:
		return
	if controller.flow_view.screen != RunFlowView.Screen.GAMEPLAY \
		and controller.flow_view.screen != RunFlowView.Screen.ROUTE_SELECTION:
		return
	controller.gameplay_room.cancel_aim_for_pause()
	if controller.tutorial_overlay.mode == TutorialOverlay.Mode.COACH:
		controller.tutorial_overlay.hide_overlay()
	if not controller.gameplay_room.room.shot_in_progress:
		controller._save_stable()
	controller.pause_origin_screen = controller.flow_view.screen
	controller._enter_pause_state()
	controller.pause_button.visible = false
	controller.speed_button.visible = false
	controller.pause_overlay.show_pause()


func resume_game(controller) -> void:
	if not controller.pause_active:
		return
	controller._leave_pause_state()
	controller.pause_overlay.hide_overlay()
	controller._restore_active_screen()
	controller._record_test_event(&"session_resumed", {"source": "pause"})


func return_to_main_menu(controller) -> void:
	if controller.run_session == null or controller.run_session.ended:
		return
	var notice: String = controller.tr("NOTICE_RUN_SAVED")
	controller.continue_in_memory = false
	controller.pending_continue_snapshot = null
	controller.pending_continue_interrupted = false
	controller.pending_continue_recovered_backup = false

	if controller.gameplay_room.room.shot_in_progress:
		if controller.persistence_enabled and controller.save_service != null:
			var load_result: SaveLoadResult = controller.save_service.load_active(
				controller.catalog,
				controller.config,
			)
			if load_result.has_valid_save():
				controller.pending_continue_snapshot = load_result.snapshot_for_restore()
				controller.pending_continue_interrupted = true
				controller.pending_continue_recovered_backup = (
					load_result.status == SaveLoadResult.Status.RECOVERED_BACKUP
				)
				notice = controller.tr("NOTICE_SHOT_RETRY")
			else:
				controller.continue_in_memory = true
				notice = controller.tr("NOTICE_MEMORY_ONLY")
		else:
			controller.continue_in_memory = true
			notice = controller.tr("NOTICE_MEMORY_ONLY")
	else:
		controller.pending_continue_snapshot = controller.create_snapshot()
		controller._save_stable()

	controller.pending_continue_notice = notice
	controller.gameplay_room.set_simulation_enabled(false)
	controller._leave_pause_state()
	controller._show_main_menu(
		controller.pending_continue_snapshot != null or controller.continue_in_memory,
		notice,
	)


func show_main_menu_from_result(controller) -> bool:
	if controller.save_service != null and not controller.save_service.clear_all():
		controller.last_save_error = controller.save_service.last_error
		push_warning(
			"Tamamlanan koşu kaydı kaldırılamadı: %s" % controller.last_save_error
		)
		controller._clear_pending_continue()
		controller.continue_in_memory = true
		controller._show_main_menu(true, controller.tr("NOTICE_STORAGE_FAILED"))
		return false
	controller._mark_storage_write_succeeded(&"run")
	controller.run_session = null
	controller._clear_pending_continue()
	controller._show_main_menu(false)
	return true
