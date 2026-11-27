extends RefCounted

const CONTEXT_MAIN_MENU := 0
const CONTEXT_PAUSE := 1


func open_from_main_menu(controller) -> void:
	controller.settings_context = CONTEXT_MAIN_MENU
	controller.settings_overlay.show_settings()


func open_from_pause(controller) -> void:
	if not controller.pause_active:
		return
	controller.settings_context = CONTEXT_PAUSE
	controller.pause_overlay.hide_overlay()
	controller.settings_overlay.show_settings()


func close(controller) -> void:
	controller.settings_overlay.hide_overlay()
	if controller.settings_context == CONTEXT_PAUSE and controller.pause_active:
		controller.pause_overlay.show_pause()


func set_language(controller, language: StringName) -> bool:
	if controller.app_settings == null or not AppSettings.SUPPORTED_LANGUAGES.has(language):
		return false
	controller.app_settings.language = language
	TranslationServer.set_locale(str(language))
	controller._save_app_settings()
	controller._refresh_localized_views()
	return true


func toggle_sfx(controller) -> void:
	if controller.app_settings == null:
		return
	controller.app_settings.sfx_enabled = not controller.app_settings.sfx_enabled
	AudioManager.apply_settings(controller.app_settings)
	controller._save_app_settings()
	controller.settings_overlay.queue_redraw()
	if controller.app_settings.sfx_enabled:
		AudioManager.play_ui_confirm()


func set_sfx_volume(controller, volume: float, save_now: bool = true) -> void:
	if controller.app_settings == null:
		return
	controller.app_settings.sfx_volume = clampf(volume, 0.0, 1.0)
	AudioManager.apply_settings(controller.app_settings)
	if save_now:
		controller._save_app_settings()
	controller.settings_overlay.queue_redraw()


func toggle_music(controller) -> void:
	if controller.app_settings == null:
		return
	controller.app_settings.music_enabled = not controller.app_settings.music_enabled
	AudioManager.apply_settings(controller.app_settings)
	controller._save_app_settings()
	controller.settings_overlay.queue_redraw()


func set_music_volume(controller, volume: float, save_now: bool = true) -> void:
	if controller.app_settings == null:
		return
	controller.app_settings.music_volume = clampf(volume, 0.0, 1.0)
	AudioManager.apply_settings(controller.app_settings)
	if save_now:
		controller._save_app_settings()
	controller.settings_overlay.queue_redraw()


func toggle_screen_shake(controller) -> void:
	if controller.app_settings == null:
		return
	controller.app_settings.shake_enabled = not controller.app_settings.shake_enabled
	controller._save_app_settings()
	controller.settings_overlay.queue_redraw()


func toggle_haptics(controller) -> void:
	if controller.app_settings == null:
		return
	controller.app_settings.haptics_enabled = not controller.app_settings.haptics_enabled
	controller._save_app_settings()
	controller.settings_overlay.queue_redraw()
	if controller.app_settings.haptics_enabled:
		controller._try_haptic(25)


func set_quality_mode(controller, mode: int) -> void:
	if controller.app_settings == null or mode < AppSettings.QualityMode.PERFORMANCE \
		or mode > AppSettings.QualityMode.GRAPHICS:
		return
	controller.app_settings.quality_mode = mode
	controller._apply_quality_mode()
	controller._save_app_settings()
	controller.settings_overlay.queue_redraw()


func set_color_theme(controller, theme_id: int) -> void:
	if controller.app_settings == null or not CaveTheme.is_supported(theme_id):
		return
	controller.app_settings.color_theme = theme_id
	controller._apply_color_theme()
	controller._save_app_settings()
	controller.settings_overlay.queue_redraw()


func show_tutorial(controller) -> void:
	controller.tutorial_return_to_settings = true
	controller.settings_overlay.hide_overlay()
	controller._show_tutorial()


func export_test_events_to_clipboard(controller) -> bool:
	if controller.test_event_service == null or controller.test_event_service.event_count() <= 0:
		controller.settings_overlay.show_settings(
			controller.tr("NOTICE_TEST_EVENTS_EMPTY"),
			SettingsOverlay.Page.GENERAL,
		)
		return false
	var exported_json: String = controller.test_event_service.export_json()
	if exported_json.is_empty():
		controller.settings_overlay.show_settings(
			controller.tr("NOTICE_TEST_EVENTS_FAILED"),
			SettingsOverlay.Page.GENERAL,
		)
		return false
	DisplayServer.clipboard_set(exported_json)
	AudioManager.play_ui_confirm()
	controller.settings_overlay.show_settings(
		controller.tr("NOTICE_TEST_EVENTS_COPIED") % controller.test_event_service.event_count(),
		SettingsOverlay.Page.GENERAL,
	)
	return true
