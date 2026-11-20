extends RefCounted


func select_route(controller, option_id: StringName) -> bool:
	if controller.run_session == null:
		return false
	var selected_template: RoomTemplate = controller.run_session.route_template(option_id)
	if selected_template == null:
		return false
	var previous_template: RoomTemplate = controller.gameplay_room.current_template
	var previous_room_snapshot: RoomSnapshot = controller.gameplay_room.capture_snapshot()
	if not controller.gameplay_room.load_room(selected_template):
		return false
	if controller.run_session.select_route(option_id) == null:
		if previous_template != null and previous_room_snapshot != null:
			controller.gameplay_room.restore_room(previous_template, previous_room_snapshot)
		return false
	controller._record_test_event(&"route_selected", {
		"optionId": str(option_id),
		"templateId": str(selected_template.room_id),
	})
	controller.gameplay_room.set_run_context(
		controller.run_session.room_number,
		controller.run_session.room_count,
		controller.run_session.banked_score,
	)
	AudioManager.play_route_select()
	controller.flow_view.show_gameplay()
	controller.gameplay_room.set_simulation_enabled(true)
	controller.pause_button.visible = true
	controller.speed_button.visible = true
	controller._refresh_speed_button()
	if controller.tutorial_coach_step == 2:
		controller._finish_interactive_tutorial()
	controller._save_stable()
	return true


func on_room_finished(controller, resolution: RoomResolution) -> void:
	if controller.run_session == null or not controller.run_session.resolve_room(resolution):
		return
	controller._record_test_event(&"room_completed", {
		"templateId": str(controller.run_session.current_template_id),
		"shotsRemaining": resolution.remaining_shots,
		"breakScore": resolution.break_score,
		"reward": resolution.reward,
		"multiplierBps": resolution.multiplier_bps,
		"succeeded": resolution.succeeded,
	}, false)
	controller.gameplay_room.set_simulation_enabled(false)
	if controller.run_session.ended:
		controller._record_test_event(&"run_ended", {
			"succeeded": controller.run_session.succeeded,
			"coresBroken": controller.run_session.cores_broken,
			"routeChoices": controller.run_session.route_choices_made,
			"totalScore": controller.run_session.banked_score,
		})
		if controller.tutorial_overlay.mode == TutorialOverlay.Mode.COACH:
			controller.tutorial_overlay.hide_overlay()
			controller.tutorial_coach_step = -1
		controller._record_run_result_if_needed()
		controller._save_stable()
		controller.pause_button.visible = false
		controller.speed_button.visible = false
		controller.flow_view.show_run_result(
			controller.run_session,
			controller.profile,
			controller.last_result_new_best,
		)
		return

	var options: Array[RouteOption] = controller.catalog.create_route_options(
		controller.run_session.room_number + 1,
		controller.rng,
		controller.run_session.used_template_ids(),
		controller.run_session.mine_id,
	)
	if not controller.run_session.set_route_options(options):
		push_error("Sonraki oda için rota seçenekleri üretilemedi.")
		return
	var option_ids: Array[String] = []
	var template_ids: Array[String] = []
	var multipliers_bps: Array[int] = []
	for option: RouteOption in options:
		option_ids.append(str(option.option_id))
		template_ids.append(str(option.template.room_id))
		multipliers_bps.append(option.template.multiplier_bps)
	controller._record_test_event(&"route_offered", {
		"optionIds": option_ids,
		"templateIds": template_ids,
		"multipliersBps": multipliers_bps,
	})
	controller._save_stable()
	controller.pause_button.visible = true
	controller.speed_button.visible = false
	controller.flow_view.show_route_selection(controller.run_session)
	if controller.tutorial_coach_step == 1 and controller.run_session.room_number == 1:
		controller.tutorial_coach_step = 2
		controller.tutorial_overlay.show_coach(controller.tutorial_coach_step)


func on_shot_will_start(controller) -> void:
	if controller.tutorial_coach_step == 0:
		controller.tutorial_coach_step = 1
		controller.tutorial_overlay.show_coach(controller.tutorial_coach_step)
	if not controller.persistence_enabled or controller.save_service == null:
		return
	var snapshot: RunSnapshot = controller.create_snapshot()
	if controller.save_service.save_pre_shot(snapshot):
		controller._mark_storage_write_succeeded(&"run")
	else:
		controller._report_save_error(controller.save_service.last_error, &"run")


func on_shot_started(controller) -> void:
	controller._record_test_event(&"shot_started", {
		"templateId": str(controller.run_session.current_template_id) \
			if controller.run_session != null else "",
		"shotsRemaining": controller.gameplay_room.room.shots_remaining,
		"ballsLaunched": controller.gameplay_room.volley.launched_count,
	}, false)


func on_shot_resolved(controller, resolution: RoomResolution) -> void:
	controller._record_test_event(&"shot_resolved", {
		"templateId": str(controller.run_session.current_template_id) \
			if controller.run_session != null else "",
		"shotsRemaining": resolution.remaining_shots,
		"ballsLaunched": controller.gameplay_room.volley.launched_count,
		"ballsCollected": controller.gameplay_room.volley.collected_count,
		"ballsForcedCollected": controller.gameplay_room.volley.forced_collection_count,
		"breakScore": resolution.break_score,
		"reward": resolution.reward,
		"multiplierBps": resolution.multiplier_bps,
		"succeeded": resolution.succeeded,
		"roomFinished": resolution.room_finished,
	}, not resolution.room_finished)
	if not resolution.room_finished:
		controller._save_stable()
