extends RefCounted

const PROFILE_PATH := "user://tests/deep_ricochet_profile_test.json"
const SETTINGS_PATH := "user://tests/deep_ricochet_settings_test.json"


class FailingSaveService:
	extends SaveService

	func clear_all() -> bool:
		last_error = "Test kayıt silme hatası."
		return false


class FailingProfileService:
	extends ProfileService

	func clear_all() -> bool:
		last_error = "Test profil silme hatası."
		return false

	func save_profile(_profile: PlayerProfile) -> bool:
		last_error = "Test profil yazma hatası."
		return false


static func run(controller: RunController) -> void:
	_test_profile_round_trip()
	_test_settings_round_trip()
	_test_audio_manager()
	_test_controller_profile_tutorial_and_locale(controller)


static func _test_profile_round_trip() -> void:
	var service := ProfileService.new(PROFILE_PATH)
	assert(service.clear_all())
	var profile := service.load_profile()
	assert(profile.is_valid())
	assert(profile.best_score == 0)
	assert(profile.record_run("run_profile_1", 450, true, 4))
	assert(not profile.record_run("run_profile_1", 900, true, 4))
	assert(profile.runs_played == 1)
	assert(profile.successful_runs == 1)
	assert(profile.total_cores_broken == 4)
	profile.tutorial_completed = true
	assert(service.save_profile(profile))
	var restored := service.load_profile()
	assert(restored.best_score == 450)
	assert(restored.tutorial_completed)
	assert(restored.last_recorded_run_id == "run_profile_1")
	assert(not profile.record_run("run_profile_2", 300, false, 1))
	assert(service.save_profile(profile))
	_write_text(service.store.primary_path, "{damaged-profile")
	restored = service.load_profile()
	assert(restored.best_score == 450)
	assert(restored.runs_played == 1)
	assert(not service.store.loaded_from_backup)
	assert(FileAccess.file_exists(service.store.primary_path))
	assert(FileAccess.file_exists(service.store.backup_path))
	_write_text(service.store.primary_path, "{damaged-again")
	restored = service.load_profile()
	assert(restored.best_score == 450)
	assert(restored.runs_played == 1)
	assert(not service.store.loaded_from_backup)
	assert(service.clear_all())


static func _test_settings_round_trip() -> void:
	var service := SettingsService.new(SETTINGS_PATH)
	assert(service.clear_all())
	var settings := service.load_settings()
	assert(settings.language == &"tr")
	settings.language = &"en"
	settings.sfx_enabled = false
	settings.sfx_volume = 0.35
	settings.music_enabled = false
	settings.music_volume = 0.2
	settings.shake_enabled = false
	assert(service.save_settings(settings))
	var restored := service.load_settings()
	assert(restored.language == &"en")
	assert(not restored.sfx_enabled)
	assert(is_equal_approx(restored.sfx_volume, 0.35))
	assert(not restored.music_enabled)
	assert(is_equal_approx(restored.music_volume, 0.2))
	assert(not restored.shake_enabled)

	_write_text(SETTINGS_PATH, JSON.stringify({
		"schemaVersion": 1,
		"language": "tr",
		"soundEnabled": true,
		"soundVolume": 0.45,
	}))
	restored = service.load_settings()
	assert(restored.schema_version == AppSettings.SCHEMA_VERSION)
	assert(restored.sfx_enabled)
	assert(is_equal_approx(restored.sfx_volume, 0.45))
	assert(restored.music_enabled)
	assert(restored.shake_enabled)
	assert(service.clear_all())


static func _test_audio_manager() -> void:
	var settings := AppSettings.new()
	settings.sfx_enabled = true
	settings.sfx_volume = 0.5
	settings.music_enabled = true
	settings.music_volume = 0.25
	AudioManager.apply_settings(settings)
	assert(AudioServer.get_bus_index(&"SFX") >= 0)
	assert(AudioServer.get_bus_index(&"UI") >= 0)
	assert(AudioServer.get_bus_index(&"Music") >= 0)
	assert(is_equal_approx(AudioManager.sfx_volume, 0.5))
	assert(is_equal_approx(AudioManager.music_volume, 0.25))
	assert(AudioManager._music_player.stream is AudioStreamWAV)
	AudioManager.begin_volley()
	var event_count := AudioManager.played_event_count
	assert(AudioManager.play_collision(-1, 4.0))
	assert(AudioManager.melody_index == 1)
	assert(AudioManager.played_event_count == event_count + 1)
	assert(not AudioManager.play_collision(-1, 4.0))
	settings.sfx_enabled = false
	AudioManager.apply_settings(settings)
	event_count = AudioManager.played_event_count
	AudioManager.play_ui_click()
	assert(AudioManager.played_event_count == event_count)
	AudioManager.apply_settings(AppSettings.new())


static func _test_controller_profile_tutorial_and_locale(controller: RunController) -> void:
	controller.profile = PlayerProfile.new()
	controller.tutorial_enabled = true
	assert(controller.start_new_run(92_001))
	assert(controller.tutorial_overlay.visible)
	assert(controller.tutorial_overlay.mode == TutorialOverlay.Mode.COACH)
	assert(controller.tutorial_coach_step == 0)
	assert(controller.gameplay_room.simulation_enabled)
	controller._on_shot_will_start()
	assert(controller.tutorial_coach_step == 1)
	var tutorial_result := RoomResolution.new()
	tutorial_result.processed = true
	tutorial_result.room_finished = true
	tutorial_result.succeeded = true
	tutorial_result.break_score = 100
	tutorial_result.remaining_shots = 2
	tutorial_result.multiplier_bps = controller.gameplay_room.room.multiplier_bps
	tutorial_result.unused_shot_bonus = 40
	tutorial_result.reward = 140
	controller._on_room_finished(tutorial_result)
	assert(controller.tutorial_coach_step == 2)
	assert(controller.run_session.phase == RunSession.Phase.ROUTE_SELECTION)
	assert(controller.select_route(controller.run_session.pending_routes[0].option_id))
	assert(controller.profile.tutorial_completed)
	assert(not controller.tutorial_overlay.visible)
	assert(controller.gameplay_room.simulation_enabled)

	assert(controller.start_new_run(92_002))
	var result := RoomResolution.new()
	result.processed = true
	result.room_finished = true
	result.succeeded = false
	result.reward = 321
	result.break_score = 321
	controller._on_room_finished(result)
	assert(controller.profile.runs_played == 1)
	assert(controller.profile.best_score == 321)
	assert(controller.flow_view.profile == controller.profile)
	assert(controller.flow_view.new_best)

	controller.save_service = FailingSaveService.new()
	assert(not controller.show_main_menu_from_result())
	assert(controller.run_session != null)
	assert(controller.continue_in_memory)
	assert(controller.main_menu_view.continue_available)
	controller.save_service = null
	assert(controller.show_main_menu_from_result())
	controller.open_settings_from_main_menu()
	assert(controller.settings_overlay.visible)
	assert(controller.set_language(&"en"))
	assert(TranslationServer.translate("MENU_NEW_GAME") == "NEW GAME")
	controller.set_sfx_volume(0.42)
	assert(is_equal_approx(controller.app_settings.sfx_volume, 0.42))
	controller.set_music_volume(0.24)
	assert(is_equal_approx(controller.app_settings.music_volume, 0.24))
	controller.toggle_sfx()
	assert(not controller.app_settings.sfx_enabled)
	controller.toggle_sfx()
	assert(controller.app_settings.sfx_enabled)
	controller.toggle_music()
	assert(not controller.app_settings.music_enabled)
	controller.toggle_music()
	assert(controller.app_settings.music_enabled)
	if not controller.app_settings.shake_enabled:
		controller.toggle_screen_shake()
	controller.gameplay_room.view.shake_remaining = 0.0
	controller._on_block_destroyed(BlockState.BlockType.CORE)
	assert(controller.gameplay_room.view.shake_remaining > 0.0)
	controller.toggle_screen_shake()
	controller.gameplay_room.view.shake_remaining = 0.0
	controller._on_block_destroyed(BlockState.BlockType.CORE)
	assert(is_zero_approx(controller.gameplay_room.view.shake_remaining))
	controller.show_tutorial_from_settings()
	assert(controller.tutorial_overlay.visible)
	assert(controller.tutorial_overlay.is_modal())
	assert(TutorialOverlay.PAGE_COUNT == 3)
	controller.complete_tutorial()
	assert(controller.settings_overlay.visible)
	controller.settings_overlay.show_delete_all_confirmation()
	controller.profile_service = FailingProfileService.new()
	assert(not controller.confirm_delete_all_data())
	assert(controller.profile.best_score == 321)
	assert(controller.settings_overlay.visible)
	assert(not controller.settings_overlay.notice.is_empty())
	assert(controller.storage_notice.visible)
	assert(controller.failed_storage_channels.has(&"profile"))
	controller.profile_service = null
	controller.settings_overlay.show_delete_all_confirmation()
	assert(controller.confirm_delete_all_data())
	assert(controller.profile.best_score == 0)
	assert(not controller.profile.tutorial_completed)
	assert(controller.app_settings.language == &"tr")
	assert(is_equal_approx(controller.app_settings.sfx_volume, 0.8))
	assert(is_equal_approx(controller.app_settings.music_volume, 0.28))
	assert(controller.failed_storage_channels.is_empty())
	assert(not controller.storage_notice.visible)
	assert(controller.main_menu_view.visible)
	controller.tutorial_enabled = false


static func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(content)
	file.close()
