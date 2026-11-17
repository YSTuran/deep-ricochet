extends RefCounted


func complete(controller) -> void:
	if not controller.tutorial_overlay.is_modal():
		return
	controller.tutorial_overlay.hide_overlay()
	controller.tutorial_coach_step = -1
	if controller.profile != null:
		controller.profile.tutorial_completed = true
		controller._save_profile()
	if controller.tutorial_return_to_settings:
		controller.tutorial_return_to_settings = false
		controller.settings_overlay.show_settings("", SettingsOverlay.Page.GENERAL)
	elif controller.run_session != null:
		controller._restore_active_screen()


func maybe_show_first(controller) -> void:
	if controller.tutorial_enabled and controller.profile != null \
		and not controller.profile.tutorial_completed:
		controller.tutorial_return_to_settings = false
		controller.tutorial_coach_step = 0
		controller.tutorial_overlay.show_coach(controller.tutorial_coach_step)


func show(controller) -> void:
	controller.tutorial_coach_step = -1
	controller.gameplay_room.set_simulation_enabled(false)
	controller.pause_button.visible = false
	controller.speed_button.visible = false
	controller.tutorial_overlay.show_tutorial()


func finish_interactive(controller) -> void:
	if controller.tutorial_coach_step < 0:
		return
	controller.tutorial_coach_step = -1
	controller.tutorial_overlay.hide_overlay()
	if controller.profile != null and not controller.profile.tutorial_completed:
		controller.profile.tutorial_completed = true
		controller._save_profile()


func restore_coach(controller) -> void:
	if not controller.tutorial_enabled or controller.profile == null \
		or controller.profile.tutorial_completed or controller.run_session == null:
		controller.tutorial_coach_step = -1
		if controller.tutorial_overlay.mode == TutorialOverlay.Mode.COACH:
			controller.tutorial_overlay.hide_overlay()
		return
	if controller.run_session.phase == RunSession.Phase.ROUTE_SELECTION \
		and controller.run_session.room_number == 1:
		controller.tutorial_coach_step = 2
	elif controller.run_session.phase == RunSession.Phase.PLAYING \
		and controller.run_session.room_number == 1:
		controller.tutorial_coach_step = 0 if controller.gameplay_room.room.break_score == 0 \
			and controller.gameplay_room.room.shots_remaining == controller.gameplay_room.shots_per_room else 1
	else:
		controller.tutorial_coach_step = -1
	if controller.tutorial_coach_step >= 0:
		controller.tutorial_overlay.show_coach(controller.tutorial_coach_step)
	elif controller.tutorial_overlay.mode == TutorialOverlay.Mode.COACH:
		controller.tutorial_overlay.hide_overlay()
