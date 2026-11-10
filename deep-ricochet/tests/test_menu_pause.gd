extends RefCounted

const VALID_AIM_SCREEN_POSITION := Vector2(270.0, 300.0)


static func run(controller: RunController, parent: Node) -> void:
	assert(controller.main_menu_view.visible)
	assert(not controller.main_menu_view.continue_available)
	assert(controller.run_session == null)
	assert(not controller.gameplay_room.simulation_enabled)
	_assert_blank_release_is_silent(controller.main_menu_view)

	controller.open_settings_from_main_menu()
	assert(controller.settings_overlay.visible)
	_assert_blank_release_is_silent(controller.settings_overlay)
	controller.close_settings()
	assert(controller.main_menu_view.visible)

	controller.tutorial_overlay.show_tutorial()
	_assert_blank_release_is_silent(controller.tutorial_overlay)
	controller.tutorial_overlay.hide_overlay()

	assert(controller.start_new_run(31_415))
	assert(not controller.main_menu_view.visible)
	assert(controller.pause_button.visible)
	assert(controller.gameplay_room.simulation_enabled)

	controller.gameplay_room._begin_aim(VALID_AIM_SCREEN_POSITION)
	assert(controller.gameplay_room.aiming)
	controller.pause_game()
	assert(controller.pause_active)
	assert(parent.get_tree().paused)
	assert(controller.pause_overlay.visible)
	assert(not controller.gameplay_room.aiming)
	assert(not controller.gameplay_room.volley.active)
	_assert_blank_release_is_silent(controller.pause_overlay)
	controller.resume_game()
	assert(not parent.get_tree().paused)
	assert(not controller.pause_overlay.visible)

	controller._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(controller.pause_active)
	assert(parent.get_tree().paused)
	await parent.get_tree().process_frame
	assert(parent.get_tree().paused)
	controller.resume_game()

	controller.gameplay_room.aiming = true
	controller.gameplay_room.aim_valid = true
	controller.gameplay_room.aim_direction = Vector2.UP
	controller.gameplay_room._release_aim()
	assert(controller.gameplay_room.volley.active)
	await parent.get_tree().physics_frame
	controller.pause_game()
	var paused_elapsed := controller.gameplay_room.volley.elapsed_seconds
	await parent.get_tree().process_frame
	await parent.get_tree().process_frame
	assert(is_equal_approx(controller.gameplay_room.volley.elapsed_seconds, paused_elapsed))
	controller.resume_game()
	await parent.get_tree().physics_frame
	await parent.get_tree().physics_frame
	assert(controller.gameplay_room.volley.elapsed_seconds > paused_elapsed)

	var expected_seed := controller.run_session.seed
	var expected_template := controller.run_session.current_template_id
	controller.pause_game()
	controller.return_to_main_menu()
	assert(not parent.get_tree().paused)
	assert(controller.main_menu_view.visible)
	assert(controller.main_menu_view.continue_available)
	assert(not controller.gameplay_room.simulation_enabled)
	assert(controller.continue_saved_run())
	assert(controller.run_session.seed == expected_seed)
	assert(controller.run_session.current_template_id == expected_template)
	assert(controller.gameplay_room.simulation_enabled)

	controller.pause_game()
	controller.return_to_main_menu()
	controller.request_new_game_from_menu()
	assert(controller.pause_overlay.mode == PauseOverlay.Mode.CONFIRM_NEW_GAME)
	controller.cancel_new_game_confirmation()
	assert(controller.main_menu_view.visible)
	assert(not controller.pause_overlay.visible)
	controller.request_new_game_from_menu()
	controller.confirm_new_game()
	assert(not parent.get_tree().paused)
	assert(not controller.main_menu_view.visible)
	assert(controller.run_session != null)


static func _assert_blank_release_is_silent(control: Control) -> void:
	var event_count := AudioManager.played_event_count
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = Vector2(12.0, 12.0)
	release.pressed = false
	control._gui_input(release)
	assert(AudioManager.played_event_count == event_count)

