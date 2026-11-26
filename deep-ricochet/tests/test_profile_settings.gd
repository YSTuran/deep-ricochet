extends RefCounted

const PROFILE_PATH := "user://tests/deep_ricochet_profile_test.json"
const SETTINGS_PATH := "user://tests/deep_ricochet_settings_test.json"
const UiLayoutScript := preload("res://ui/ui_layout.gd")
const THEME_TEST_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_normal.png")
const THEME_TEST_SOURCE := Rect2(139.0, 159.0, 976.0, 939.0)
const ECHO_TEST_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_yanki.png")
const BALL_CACHE_TEST_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_top_haznesi.png")
const PIERCING_TEST_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_delici_kristal.png")


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
	_test_safe_area_layout()
	_test_controller_profile_tutorial_and_locale(controller)


static func _test_profile_round_trip() -> void:
	var service := ProfileService.new(PROFILE_PATH)
	assert(service.clear_all())
	var profile := service.load_profile()
	assert(profile.is_valid())
	assert(profile.best_score == 0)
	assert(profile.record_run("run_profile_1", 450, true, 4, &"mine_01", false, "", 3))
	assert(not profile.record_run("run_profile_1", 900, true, 4))
	assert(profile.runs_played == 1)
	assert(profile.successful_runs == 1)
	assert(profile.total_cores_broken == 4)
	assert(profile.highest_unlocked_mine == 2)
	assert(profile.best_for_mine(&"mine_01") == 450)
	assert(profile.stars_for_mine(&"mine_01") == 3)
	assert(profile.completions_for_mine(&"mine_01") == 1)
	profile.tutorial_completed = true
	assert(service.save_profile(profile))
	var restored := service.load_profile()
	assert(restored.best_score == 450)
	assert(restored.tutorial_completed)
	assert(restored.last_recorded_run_id == "run_profile_1")
	assert(restored.highest_unlocked_mine == 2)
	assert(restored.best_for_mine(&"mine_01") == 450)
	assert(restored.stars_for_mine(&"mine_01") == 3)
	assert(not profile.record_run("run_profile_2", 300, false, 1))
	assert(profile.stars_for_mine(&"mine_01") == 3)
	assert(service.save_profile(profile))
	_write_text(service.store.primary_path, "{damaged-profile")
	restored = service.load_profile()
	assert(restored.best_score == 450)
	assert(restored.runs_played == 1)
	assert(not service.store.loaded_from_backup)
	_write_text(service.store.primary_path, JSON.stringify({
		"schemaVersion": PlayerProfile.SCHEMA_VERSION,
		"bestScore": -10,
	}))
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
	var daily := PlayerProfile.new()
	assert(daily.record_run("daily_1", 220, true, 4, &"mine_01", true, "2026-11-11"))
	assert(daily.highest_unlocked_mine == 1)
	assert(daily.daily_best_score == 220)
	assert(daily.daily_attempts == 1)
	assert(daily.best_for_mine(&"mine_01") == 0)
	assert(not daily.is_mine_unlocked(&"mine_unknown"))
	assert(not daily.record_run("daily_2", 180, false, 1, &"mine_01", true, "2026-11-11"))
	assert(daily.daily_best_score == 220)
	assert(daily.daily_attempts == 2)
	for mine_order in range(1, PlayerProfile.MINE_COUNT + 1):
		var mine_id := StringName("mine_%02d" % mine_order)
		assert(daily.record_run(
			"mine_%d_clear" % mine_order,
			240 + mine_order * 60,
			true,
			4,
			mine_id,
		))
		assert(daily.highest_unlocked_mine == mini(mine_order + 1, PlayerProfile.MINE_COUNT))
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
	settings.haptics_enabled = false
	settings.quality_mode = AppSettings.QualityMode.GRAPHICS
	settings.color_theme = AppSettings.ColorTheme.GLACIAL
	assert(service.save_settings(settings))
	var restored := service.load_settings()
	assert(restored.language == &"en")
	assert(not restored.sfx_enabled)
	assert(is_equal_approx(restored.sfx_volume, 0.35))
	assert(not restored.music_enabled)
	assert(is_equal_approx(restored.music_volume, 0.2))
	assert(not restored.shake_enabled)
	assert(not restored.haptics_enabled)
	assert(restored.quality_mode == AppSettings.QualityMode.GRAPHICS)
	assert(restored.color_theme == AppSettings.ColorTheme.GLACIAL)
	assert(service.save_settings(settings))
	settings.sfx_volume = 0.4
	assert(service.save_settings(settings))
	_write_text(SETTINGS_PATH, JSON.stringify({
		"schemaVersion": AppSettings.SCHEMA_VERSION,
		"language": "unsupported",
	}))
	restored = service.load_settings()
	assert(restored.language == &"en")
	assert(is_equal_approx(restored.sfx_volume, 0.35))

	_write_text(SETTINGS_PATH, JSON.stringify({
		"schemaVersion": 2,
		"language": "en",
		"sfxEnabled": true,
		"sfxVolume": 0.6,
		"musicEnabled": true,
		"musicVolume": 0.3,
		"shakeEnabled": false,
	}))
	restored = service.load_settings()
	assert(restored.schema_version == AppSettings.SCHEMA_VERSION)
	assert(restored.haptics_enabled)
	assert(restored.quality_mode == AppSettings.QualityMode.PERFORMANCE)
	assert(restored.color_theme == AppSettings.ColorTheme.DEEP_SAPPHIRE)

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
	assert(restored.haptics_enabled)
	assert(restored.quality_mode == AppSettings.QualityMode.PERFORMANCE)
	assert(restored.color_theme == AppSettings.ColorTheme.DEEP_SAPPHIRE)
	for theme_id in range(CaveTheme.THEME_COUNT):
		assert(CaveTheme.is_supported(theme_id))
		assert(not CaveTheme.name_key(theme_id).is_empty())
		assert(CaveTheme.swatch_colors(theme_id).size() == 5)
		assert(CaveTheme.color_for_theme(theme_id, &"rock") != Color.WHITE)
	assert(not CaveTheme.is_supported(-1))
	assert(not CaveTheme.is_supported(CaveTheme.THEME_COUNT))
	assert(CaveTheme.set_current_theme(CaveTheme.AMETHYST))
	var themed_texture := CaveTheme._themed_texture(
		THEME_TEST_TEXTURE,
		THEME_TEST_SOURCE,
		BlockState.BlockType.NORMAL,
	)
	assert(themed_texture != null)
	assert(themed_texture.get_size() == Vector2.ONE * CaveTheme.GENERATED_TEXTURE_SIZE)
	var normal_source := CaveTheme.block_texture_source_rect(
		THEME_TEST_TEXTURE,
		BlockState.BlockType.NORMAL,
	)
	assert(normal_source == Rect2(Vector2.ZERO, THEME_TEST_TEXTURE.get_size()))
	for sample: Dictionary in [
		{"texture": ECHO_TEST_TEXTURE, "type": BlockState.BlockType.ECHO},
		{"texture": BALL_CACHE_TEST_TEXTURE, "type": BlockState.BlockType.BALL_CACHE},
		{"texture": PIERCING_TEST_TEXTURE, "type": BlockState.BlockType.PIERCING},
	]:
		var texture: Texture2D = sample["texture"]
		var source_rect := CaveTheme.block_texture_source_rect(texture, sample["type"])
		assert(source_rect.size.x < texture.get_size().x)
		assert(source_rect.size.y < texture.get_size().y)
		assert(source_rect.size.x >= texture.get_size().x * 0.65)
		assert(source_rect.size.y >= texture.get_size().y * 0.65)
	var ball_cache_sample := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	ball_cache_sample.fill(CaveTheme.color_for_theme(CaveTheme.DEEP_SAPPHIRE, &"ball_cache"))
	ball_cache_sample.set_pixel(0, 0, Color("f4f1e8"))
	var original_ball_color := ball_cache_sample.get_pixel(0, 0)
	CaveTheme._recolor_image(ball_cache_sample, BlockState.BlockType.BALL_CACHE)
	assert(ball_cache_sample.get_pixel(0, 0).is_equal_approx(original_ball_color))
	assert(CaveTheme.set_current_theme(CaveTheme.VOLCANIC))
	var piercing_sample := Image.create(2, 4, false, Image.FORMAT_RGBA8)
	piercing_sample.fill(CaveTheme.color_for_theme(CaveTheme.DEEP_SAPPHIRE, &"piercing"))
	for x in range(piercing_sample.get_width()):
		piercing_sample.set_pixel(
			x,
			piercing_sample.get_height() - 1,
			CaveTheme.color_for_theme(CaveTheme.DEEP_SAPPHIRE, &"rock"),
		)
	CaveTheme._recolor_image(piercing_sample, BlockState.BlockType.PIERCING)
	var crystal_color := piercing_sample.get_pixel(0, 0)
	var crystal_target := CaveTheme.color_for_theme(CaveTheme.VOLCANIC, &"piercing")
	assert(
		Vector3(crystal_color.r, crystal_color.g, crystal_color.b).distance_to(
			Vector3(crystal_target.r, crystal_target.g, crystal_target.b),
		) < 0.04
	)
	var base_color := piercing_sample.get_pixel(0, piercing_sample.get_height() - 1)
	var base_target := CaveTheme.color_for_theme(CaveTheme.VOLCANIC, &"rock")
	assert(
		Vector3(base_color.r, base_color.g, base_color.b).distance_to(
			Vector3(base_target.r, base_target.g, base_target.b),
		) < 0.04
	)
	assert(CaveTheme.set_current_theme(CaveTheme.DEEP_SAPPHIRE))
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
	var ambient_stream := AudioManager._music_player.stream as AudioStreamWAV
	var ambient_frame_count := AudioManager.AMBIENT_MIX_RATE * AudioManager.AMBIENT_DURATION_SECONDS
	assert(ambient_stream.loop_end == ambient_frame_count)
	assert(ambient_stream.data.size() == (ambient_frame_count + 1) * 4)
	assert(ambient_stream.data.slice(ambient_frame_count * 4) == ambient_stream.data.slice(0, 4))
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


static func _test_safe_area_layout() -> void:
	var layout: Transform2D = UiLayoutScript.calculate_content_transform(
		Vector2(540.0, 960.0),
		Vector2(1080.0, 1920.0),
		Rect2(0.0, 100.0, 1080.0, 1820.0),
	)
	assert(layout.x.x < 1.0)
	assert(is_equal_approx(layout.x.x, layout.y.y))
	assert(layout.origin.y >= 50.0)
	var safe_canvas := Rect2(Vector2(0.0, 50.0), Vector2(540.0, 910.0))
	var fitted_canvas := Rect2(layout.origin, Vector2(540.0, 960.0) * layout.x.x)
	assert(safe_canvas.encloses(fitted_canvas))


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
	assert(controller.settings_overlay.page == SettingsOverlay.Page.ROOT)
	var category_touch := InputEventScreenTouch.new()
	category_touch.position = SettingsOverlay.GENERAL_CATEGORY_BUTTON.get_center()
	category_touch.pressed = false
	controller.settings_overlay._gui_input(category_touch)
	assert(controller.settings_overlay.page == SettingsOverlay.Page.GENERAL)
	controller.settings_overlay.show_settings("", SettingsOverlay.Page.AUDIO)
	var slider_press := InputEventScreenTouch.new()
	slider_press.index = 0
	slider_press.position = Vector2(
		SettingsOverlay.SFX_SLIDER.position.x + SettingsOverlay.SFX_SLIDER.size.x * 0.2,
		SettingsOverlay.SFX_SLIDER.get_center().y,
	)
	slider_press.pressed = true
	controller.settings_overlay._gui_input(slider_press)
	var slider_drag := InputEventScreenDrag.new()
	slider_drag.index = 0
	slider_drag.position = Vector2(
		SettingsOverlay.SFX_SLIDER.position.x + SettingsOverlay.SFX_SLIDER.size.x * 0.7,
		SettingsOverlay.SFX_SLIDER.get_center().y,
	)
	controller.settings_overlay._gui_input(slider_drag)
	assert(is_equal_approx(controller.app_settings.sfx_volume, 0.7))
	var slider_release := InputEventScreenTouch.new()
	slider_release.index = 0
	slider_release.position = slider_drag.position
	slider_release.pressed = false
	controller.settings_overlay._gui_input(slider_release)
	assert(controller.settings_overlay.touch_controls.active_action.is_empty())
	controller.settings_overlay.show_settings("", SettingsOverlay.Page.GENERAL)
	assert(controller.set_language(&"en"))
	assert(TranslationServer.translate("MENU_NEW_GAME") == "NEW GAME")
	assert(TranslationServer.translate("MINE_06_NAME") == "ABYSS MINE")
	assert(TranslationServer.translate("MINE_07_NAME") == "POWDER MINE")
	assert(TranslationServer.translate("MINE_14_NAME") == "FINAL DEPTH")
	assert(TranslationServer.translate("MINE_28_NAME") == "CROWN DEPTH")
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
	var previous_haptics := controller.app_settings.haptics_enabled
	controller.toggle_haptics()
	assert(controller.app_settings.haptics_enabled != previous_haptics)
	controller.toggle_haptics()
	assert(controller.app_settings.haptics_enabled == previous_haptics)
	controller.set_quality_mode(AppSettings.QualityMode.GRAPHICS)
	assert(controller.app_settings.quality_mode == AppSettings.QualityMode.GRAPHICS)
	assert(controller.gameplay_room.quality_mode == AppSettings.QualityMode.GRAPHICS)
	assert(DeepUI.high_quality_enabled)
	controller.set_quality_mode(AppSettings.QualityMode.PERFORMANCE)
	assert(controller.gameplay_room.quality_mode == AppSettings.QualityMode.PERFORMANCE)
	assert(not DeepUI.high_quality_enabled)
	controller.settings_overlay.show_settings("", SettingsOverlay.Page.COLOR_THEME)
	assert(controller.settings_overlay._touch_targets().size() == CaveTheme.THEME_COUNT + 1)
	controller.set_color_theme(AppSettings.ColorTheme.AMETHYST)
	assert(controller.app_settings.color_theme == AppSettings.ColorTheme.AMETHYST)
	assert(CaveTheme.current_theme == CaveTheme.AMETHYST)
	assert(CaveTheme.block_color(BlockState.BlockType.ROCK) == Color("3a3445"))
	controller.set_color_theme(AppSettings.ColorTheme.VOLCANIC)
	assert(CaveTheme.current_theme == CaveTheme.VOLCANIC)
	controller.set_color_theme(AppSettings.ColorTheme.MOSSY)
	assert(CaveTheme.current_theme == CaveTheme.MOSSY)
	controller.set_color_theme(AppSettings.ColorTheme.GLACIAL)
	assert(CaveTheme.current_theme == CaveTheme.GLACIAL)
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
	assert(TutorialOverlay.PAGE_COUNT == 9)
	assert(TutorialOverlay.COACH_PAGE_BY_STEP == [0, 1, 8])
	controller.complete_tutorial()
	assert(controller.settings_overlay.visible)
	assert(controller.settings_overlay.page == SettingsOverlay.Page.GENERAL)
	controller.settings_overlay.show_delete_all_confirmation()
	controller.profile_service = FailingProfileService.new()
	assert(not controller.confirm_delete_all_data())
	assert(controller.profile.best_score == 321)
	assert(controller.settings_overlay.visible)
	assert(controller.settings_overlay.page == SettingsOverlay.Page.GENERAL)
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
	assert(controller.app_settings.haptics_enabled)
	assert(controller.app_settings.quality_mode == AppSettings.QualityMode.PERFORMANCE)
	assert(controller.app_settings.color_theme == AppSettings.ColorTheme.DEEP_SAPPHIRE)
	assert(CaveTheme.current_theme == CaveTheme.DEEP_SAPPHIRE)
	assert(controller.failed_storage_channels.is_empty())
	assert(not controller.storage_notice.visible)
	assert(controller.main_menu_view.visible)
	controller.tutorial_enabled = false


static func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(content)
	file.close()
