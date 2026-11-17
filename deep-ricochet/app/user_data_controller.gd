extends RefCounted


func reset_progress(controller) -> bool:
	var replacement_profile := PlayerProfile.new()
	var errors := PackedStringArray()
	if controller.save_service != null and not controller.save_service.clear_all():
		errors.append(controller.save_service.last_error)
	if controller.profile_service != null:
		if not controller.profile_service.clear_all():
			errors.append(controller.profile_service.last_error)
		elif not controller.profile_service.save_profile(replacement_profile):
			errors.append(controller.profile_service.last_error)

	if not errors.is_empty():
		controller.last_save_error = "; ".join(errors)
		push_warning("İlerleme sıfırlanamadı: %s" % controller.last_save_error)
		controller._save_profile()
		if controller.run_session != null:
			controller._save_stable()
		controller.settings_overlay.show_settings(
			controller.tr("NOTICE_STORAGE_FAILED"),
			SettingsOverlay.Page.GENERAL,
		)
		return false

	controller.profile = replacement_profile
	controller.run_session = null
	controller.last_result_new_best = false
	controller.tutorial_coach_step = -1
	controller._clear_storage_failure_state()
	controller._clear_pending_continue()
	controller.settings_overlay.hide_overlay()
	controller.tutorial_overlay.hide_overlay()
	controller.pause_overlay.hide_overlay()
	controller._leave_pause_state()
	controller._show_main_menu(false, controller.tr("NOTICE_PROGRESS_RESET"))
	return true


func delete_all(controller) -> bool:
	var errors := PackedStringArray()
	if controller.save_service != null and not controller.save_service.clear_all():
		errors.append(controller.save_service.last_error)
	if controller.profile_service != null and not controller.profile_service.clear_all():
		errors.append(controller.profile_service.last_error)
	if controller.settings_service != null and not controller.settings_service.clear_all():
		errors.append(controller.settings_service.last_error)
	if controller.test_event_service != null and not controller.test_event_service.clear_all():
		errors.append(controller.test_event_service.last_error)
	if not errors.is_empty():
		controller.last_save_error = "; ".join(errors)
		push_warning("Tüm veriler silinemedi: %s" % controller.last_save_error)
		controller._save_profile()
		controller._save_app_settings()
		if controller.run_session != null:
			controller._save_stable()
		controller.settings_overlay.show_settings(
			controller.tr("NOTICE_STORAGE_FAILED"),
			SettingsOverlay.Page.GENERAL,
		)
		return false

	controller.profile = PlayerProfile.new()
	controller.app_settings = AppSettings.new()
	controller.run_session = null
	controller.last_result_new_best = false
	controller.tutorial_coach_step = -1
	controller._clear_storage_failure_state()
	controller._clear_pending_continue()
	TranslationServer.set_locale(str(controller.app_settings.language))
	AudioManager.apply_settings(controller.app_settings)
	controller._apply_quality_mode()
	controller.settings_overlay.hide_overlay()
	controller.tutorial_overlay.hide_overlay()
	controller.pause_overlay.hide_overlay()
	controller._leave_pause_state()
	controller._refresh_localized_views()
	controller._show_main_menu(false, controller.tr("NOTICE_ALL_DATA_DELETED"))
	return true
