extends RefCounted

const PROFILE_PATH := "user://tests/deep_ricochet_profile_test.json"
const SETTINGS_PATH := "user://tests/deep_ricochet_settings_test.json"


static func run(controller: RunController) -> void:
	_test_profile_round_trip()
	_test_settings_round_trip()
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
	assert(service.clear_all())


static func _test_settings_round_trip() -> void:
	var service := SettingsService.new(SETTINGS_PATH)
	assert(service.clear_all())
	var settings := service.load_settings()
	assert(settings.language == &"tr")
	settings.language = &"en"
	assert(service.save_settings(settings))
	assert(service.load_settings().language == &"en")
	assert(service.clear_all())


static func _test_controller_profile_tutorial_and_locale(controller: RunController) -> void:
	controller.profile = PlayerProfile.new()
	controller.tutorial_enabled = true
	assert(controller.start_new_run(92_001))
	assert(controller.tutorial_overlay.visible)
	assert(not controller.gameplay_room.simulation_enabled)
	controller.complete_tutorial()
	assert(controller.profile.tutorial_completed)
	assert(not controller.tutorial_overlay.visible)
	assert(controller.gameplay_room.simulation_enabled)

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

	controller.show_main_menu_from_result()
	controller.open_settings_from_main_menu()
	assert(controller.settings_overlay.visible)
	assert(controller.set_language(&"en"))
	assert(TranslationServer.translate("MENU_NEW_GAME") == "NEW GAME")
	controller.show_tutorial_from_settings()
	assert(controller.tutorial_overlay.visible)
	controller.complete_tutorial()
	assert(controller.settings_overlay.visible)
	controller.settings_overlay.show_reset_confirmation()
	controller.confirm_reset_progress()
	assert(controller.profile.best_score == 0)
	assert(not controller.profile.tutorial_completed)
	assert(controller.main_menu_view.visible)
	assert(controller.set_language(&"tr"))
	controller.tutorial_enabled = false


static func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(content)
	file.close()
