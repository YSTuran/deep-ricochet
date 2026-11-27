extends RefCounted


func initialize_user_data(controller) -> void:
	controller.profile = PlayerProfile.new()
	controller.app_settings = AppSettings.new()
	if controller.persistence_enabled:
		controller.profile_service = ProfileService.new(controller.profile_path)
		controller.settings_service = SettingsService.new(controller.settings_path)
		controller.test_event_service = TestEventService.new(controller.test_event_path)
		controller.profile = controller.profile_service.load_profile()
		controller.app_settings = controller.settings_service.load_settings()
	TranslationServer.set_locale(str(controller.app_settings.language))
	AudioManager.apply_settings(controller.app_settings)
	controller._apply_quality_mode()
	controller._apply_color_theme()


func boot_from_save(controller) -> void:
	if not controller.persistence_enabled:
		controller._show_main_menu(false)
		return
	controller.save_service = SaveService.new(controller.save_path)
	var load_result: SaveLoadResult = controller.save_service.load_active(
		controller.catalog,
		controller.config,
	)
	if load_result.has_valid_save():
		var snapshot := load_result.snapshot_for_restore()
		if load_result.status == SaveLoadResult.Status.RECOVERED_BACKUP \
			or load_result.interrupted_shot():
			controller._record_snapshot_test_event(&"save_recovered", snapshot, {
				"source": "startup",
				"recoveredBackup": load_result.status == SaveLoadResult.Status.RECOVERED_BACKUP,
				"interruptedShot": load_result.interrupted_shot(),
			})
		if snapshot.ended:
			if restore_internal(controller, snapshot):
				if load_result.status == SaveLoadResult.Status.RECOVERED_BACKUP:
					controller.last_recovery_message = load_result.message
					controller.save_service.discard_primary()
				controller._save_stable()
				return
		else:
			controller.pending_continue_snapshot = snapshot
			controller.pending_continue_interrupted = load_result.interrupted_shot()
			controller.pending_continue_recovered_backup = (
				load_result.status == SaveLoadResult.Status.RECOVERED_BACKUP
			)
			if controller.pending_continue_interrupted:
				controller.pending_continue_notice = controller.tr("NOTICE_INTERRUPTED")
			elif controller.pending_continue_recovered_backup:
				controller.pending_continue_notice = controller.tr("NOTICE_BACKUP")
			controller._show_main_menu(true, controller.pending_continue_notice)
			return
	if load_result.status == SaveLoadResult.Status.INCOMPATIBLE:
		controller.last_recovery_message = controller.tr("NOTICE_SAVE_INCOMPATIBLE")
		controller._show_main_menu(false, controller.last_recovery_message)
		return
	if load_result.status == SaveLoadResult.Status.INVALID:
		controller.last_recovery_message = controller.tr("NOTICE_SAVE_INVALID")
		if controller.save_service.quarantine_invalid():
			controller._show_main_menu(false, controller.last_recovery_message)
		else:
			controller._report_save_error(controller.save_service.last_error, &"run")
			controller._show_main_menu(false, controller.tr("NOTICE_STORAGE_FAILED"))
		return
	controller._show_main_menu(false)


func continue_saved_run(controller) -> bool:
	if controller.continue_in_memory and controller.run_session != null:
		controller.continue_in_memory = false
		controller.main_menu_view.hide_menu()
		controller._restore_active_screen()
		controller._record_test_event(&"session_resumed", {"source": "memory"})
		return true
	if controller.pending_continue_snapshot == null:
		return false

	var snapshot: RunSnapshot = controller.pending_continue_snapshot
	var recovery_message: String = controller.pending_continue_notice
	var recovered_backup: bool = controller.pending_continue_recovered_backup
	var interrupted_shot: bool = controller.pending_continue_interrupted
	if not restore_internal(controller, snapshot):
		controller._show_main_menu(true, controller.tr("NOTICE_LOAD_FAILED"))
		return false
	if recovered_backup and controller.save_service != null:
		controller.save_service.discard_primary()
	controller._clear_pending_continue()
	controller.last_recovery_message = recovery_message
	if not recovery_message.is_empty():
		controller.gameplay_room.show_status(recovery_message)
	controller._save_stable()
	controller._record_test_event(&"session_resumed", {
		"source": "saved_run",
		"recoveredBackup": recovered_backup,
		"interruptedShot": interrupted_shot,
	})
	return true


func create_snapshot(controller) -> RunSnapshot:
	if controller.run_session == null:
		return null
	var room_snapshot: RoomSnapshot = controller.gameplay_room.capture_snapshot()
	return RunSnapshot.capture(
		controller.run_session,
		room_snapshot,
		controller.rng.state,
		controller.config.config_version,
		controller.catalog.daily_content_version,
		controller.catalog,
	)


func restore_snapshot(
	controller,
	snapshot: RunSnapshot,
	recovery_message: String = "",
) -> bool:
	if not restore_internal(controller, snapshot):
		return false
	controller.last_recovery_message = recovery_message
	if not recovery_message.is_empty():
		controller.gameplay_room.show_status(recovery_message)
	return true


func restore_internal(controller, snapshot: RunSnapshot) -> bool:
	if snapshot == null:
		return false
	var errors := snapshot.validation_errors(controller.catalog, controller.config)
	if not errors.is_empty():
		push_error("Koşu snapshot geri yüklenemedi:\n- %s" % "\n- ".join(errors))
		return false
	var restored_session := snapshot.create_session(controller.catalog)
	var template: RoomTemplate = controller.catalog.get_template(snapshot.current_template_id)
	if restored_session == null or template == null:
		return false
	restored_session.content_version = controller.catalog.content_version
	if not controller.gameplay_room.set_shots_per_room(
		RunSession.shots_per_room_for_kind(controller.config, restored_session.run_kind)
	):
		return false
	if not controller.gameplay_room.restore_room(template, snapshot.active_room):
		return false
	controller.run_session = restored_session
	controller.gameplay_room.set_run_context(
		restored_session.room_number,
		restored_session.room_count,
		restored_session.banked_score,
		PlayerProfile._mine_order(restored_session.mine_id),
		restored_session.run_kind == RunSession.RunKind.DAILY,
	)
	controller.rng.seed = snapshot.seed
	controller.rng.state = snapshot.rng_state_for_restore(controller.catalog)
	if controller.run_session.ended:
		controller._record_run_result_if_needed()
	controller.main_menu_view.hide_menu()
	controller.mine_select_view.hide_selector()
	controller.pause_overlay.hide_overlay()
	controller._leave_pause_state()
	controller._restore_active_screen()
	return true
