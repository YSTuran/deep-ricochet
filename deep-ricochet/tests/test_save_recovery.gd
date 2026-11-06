class_name SaveRecoveryTests
extends RefCounted

const TEST_SAVE_PATH := "user://tests/deep_ricochet_save_test.json"


static func run(controller: RunController, config: GameConfig, parent: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var service := SaveService.new(TEST_SAVE_PATH)
	assert(service.clear_all())
	_test_stable_round_trip(controller, service, config)
	_test_interrupted_shot_uses_pre_shot(controller, service)
	_test_controller_shot_hook(controller, service)
	_test_interrupted_shot_main_menu_continue(controller, service)
	_test_route_and_result_restore(controller, service)
	_test_backup_and_invalid_save(controller, service, config)
	await _test_startup_restore(controller, service, parent)
	assert(service.clear_all())


static func _test_stable_round_trip(
	controller: RunController,
	service: SaveService,
	config: GameConfig,
) -> void:
	assert(controller.start_new_run(42_424))
	var first_template_id := controller.run_session.current_template_id
	var target := _first_block_of_type(controller.gameplay_room.board, BlockState.BlockType.NORMAL)
	assert(target != null)
	assert(controller.gameplay_room.room.commit_shot())
	while not target.is_destroyed():
		var damage := controller.gameplay_room.board.resolve_contact(target.id)
		controller.gameplay_room.room.record_damage_result(damage, config)
	var resolution := controller.gameplay_room.room.resolve_shot(controller.gameplay_room.board, config)
	assert(resolution.processed)
	assert(not resolution.room_finished)

	var snapshot := controller.create_snapshot()
	assert(snapshot != null)
	assert(snapshot.validation_errors(controller.catalog, config).is_empty())
	assert(service.save_stable(snapshot))
	assert(not FileAccess.file_exists(service.temporary_path))
	var loaded := service.load_active(controller.catalog, config)
	assert(loaded.status == SaveLoadResult.Status.LOADED)
	assert(not loaded.interrupted_shot())
	assert(controller.start_new_run(42_425))
	assert(controller.restore_snapshot(loaded.snapshot_for_restore()))
	assert(controller.run_session.current_template_id == first_template_id)
	assert(controller.gameplay_room.room.shots_remaining == config.shots_per_room - 1)
	assert(controller.gameplay_room.room.break_score == config.normal_break_points)
	assert(controller.gameplay_room.board.get_block_by_id(target.id).is_destroyed())


static func _test_interrupted_shot_uses_pre_shot(
	controller: RunController,
	service: SaveService,
) -> void:
	var pre_shot := controller.create_snapshot()
	var expected_shots := controller.gameplay_room.room.shots_remaining
	var target := _first_living_breakable(controller.gameplay_room.board)
	assert(target != null)
	var expected_hp := target.hit_points
	assert(service.save_pre_shot(pre_shot))
	assert(controller.gameplay_room.room.commit_shot())
	controller.gameplay_room.board.resolve_contact(target.id)
	assert(controller.gameplay_room.room.shots_remaining == expected_shots - 1)
	assert(target.hit_points == expected_hp - 1)

	var loaded := service.load_active(controller.catalog, controller.config)
	assert(loaded.status == SaveLoadResult.Status.LOADED)
	assert(loaded.interrupted_shot())
	assert(controller.restore_snapshot(loaded.snapshot_for_restore(), "Kesilen atış yeniden denenecek."))
	assert(not controller.gameplay_room.room.shot_in_progress)
	assert(controller.gameplay_room.room.shots_remaining == expected_shots)
	assert(controller.gameplay_room.board.get_block_by_id(target.id).hit_points == expected_hp)
	assert(controller.last_recovery_message == "Kesilen atış yeniden denenecek.")
	assert(service.save_stable(controller.create_snapshot()))
	loaded = service.load_active(controller.catalog, controller.config)
	assert(not loaded.interrupted_shot())


static func _test_controller_shot_hook(
	controller: RunController,
	service: SaveService,
) -> void:
	assert(service.clear_all())
	controller.persistence_enabled = true
	controller.save_service = service
	assert(controller.start_new_run(80_808))
	var initial_shots := controller.gameplay_room.room.shots_remaining
	controller.gameplay_room.aiming = true
	controller.gameplay_room.aim_valid = true
	controller.gameplay_room.aim_direction = Vector2.UP
	controller.gameplay_room._release_aim()
	assert(controller.gameplay_room.room.shot_in_progress)
	assert(controller.gameplay_room.room.shots_remaining == initial_shots - 1)
	var loaded := service.load_active(controller.catalog, controller.config)
	assert(loaded.status == SaveLoadResult.Status.LOADED)
	assert(loaded.interrupted_shot())
	assert(controller.restore_snapshot(loaded.snapshot_for_restore()))
	assert(not controller.gameplay_room.volley.active)
	assert(not controller.gameplay_room.room.shot_in_progress)
	assert(controller.gameplay_room.room.shots_remaining == initial_shots)
	controller.persistence_enabled = false
	controller.save_service = null


static func _test_interrupted_shot_main_menu_continue(
	controller: RunController,
	service: SaveService,
) -> void:
	assert(service.clear_all())
	controller.persistence_enabled = true
	controller.save_service = service
	assert(controller.start_new_run(81_818))
	var initial_shots := controller.gameplay_room.room.shots_remaining
	controller.gameplay_room.aiming = true
	controller.gameplay_room.aim_valid = true
	controller.gameplay_room.aim_direction = Vector2.UP
	controller.gameplay_room._release_aim()
	assert(controller.gameplay_room.room.shot_in_progress)
	assert(controller.gameplay_room.room.shots_remaining == initial_shots - 1)
	controller.pause_game()
	controller.return_to_main_menu()
	assert(controller.main_menu_view.visible)
	assert(controller.main_menu_view.continue_available)
	assert(controller.pending_continue_snapshot != null)
	assert(controller.continue_saved_run())
	assert(controller.run_session.seed == 81_818)
	assert(not controller.gameplay_room.room.shot_in_progress)
	assert(not controller.gameplay_room.volley.active)
	assert(controller.gameplay_room.room.shots_remaining == initial_shots)
	var loaded := service.load_active(controller.catalog, controller.config)
	assert(loaded.has_valid_save())
	assert(not loaded.interrupted_shot())
	controller.persistence_enabled = false
	controller.save_service = null


static func _test_route_and_result_restore(
	controller: RunController,
	service: SaveService,
) -> void:
	assert(controller.start_new_run(90_001))
	var resolution := _complete_active_room(controller)
	controller._on_room_finished(resolution)
	assert(controller.run_session.phase == RunSession.Phase.ROUTE_SELECTION)
	var safe_option_id := controller.run_session.pending_routes[0].option_id
	var bonus_option_id := controller.run_session.pending_routes[1].option_id
	var route_snapshot := controller.create_snapshot()
	assert(service.save_stable(route_snapshot))

	assert(controller.start_new_run(90_002))
	var loaded := service.load_active(controller.catalog, controller.config)
	assert(controller.restore_snapshot(loaded.snapshot_for_restore()))
	assert(controller.run_session.phase == RunSession.Phase.ROUTE_SELECTION)
	assert(controller.run_session.pending_routes[0].option_id == safe_option_id)
	assert(controller.run_session.pending_routes[1].option_id == bonus_option_id)
	assert(controller.flow_view.screen == RunFlowView.Screen.ROUTE_SELECTION)

	for room_number in range(1, 4):
		var option := controller.run_session.pending_routes[room_number % 2]
		assert(controller.select_route(option.option_id))
		resolution = _complete_active_room(controller)
		controller._on_room_finished(resolution)
	assert(controller.run_session.phase == RunSession.Phase.RUN_RESULT)
	assert(controller.run_session.succeeded)
	assert(controller.run_session.room_results.size() == 4)
	var result_snapshot := controller.create_snapshot()
	assert(service.save_stable(result_snapshot))
	var expected_score := controller.run_session.banked_score
	assert(controller.start_new_run(90_003))
	loaded = service.load_active(controller.catalog, controller.config)
	assert(controller.restore_snapshot(loaded.snapshot_for_restore()))
	assert(controller.flow_view.screen == RunFlowView.Screen.RUN_RESULT)
	assert(controller.run_session.banked_score == expected_score)
	assert(controller.run_session.room_results.size() == 4)
	assert(controller.run_session.room_results[0].reward > 0)
	controller._on_room_finished(resolution)
	assert(controller.run_session.banked_score == expected_score)


static func _test_backup_and_invalid_save(
	controller: RunController,
	service: SaveService,
	config: GameConfig,
) -> void:
	assert(service.clear_all())
	assert(controller.start_new_run(70_001))
	var first_snapshot := controller.create_snapshot()
	assert(service.save_stable(first_snapshot))
	assert(controller.start_new_run(70_002))
	assert(service.save_stable(controller.create_snapshot()))
	_write_text(service.primary_path, "{bozuk-json")
	var loaded := service.load_active(controller.catalog, config)
	assert(loaded.status == SaveLoadResult.Status.RECOVERED_BACKUP)
	assert(loaded.snapshot_for_restore().run_id == first_snapshot.run_id)
	assert(service.discard_primary())
	assert(service.save_stable(loaded.snapshot_for_restore()))
	_write_text(service.primary_path, "{yeniden-bozuk")
	loaded = service.load_active(controller.catalog, config)
	assert(loaded.status == SaveLoadResult.Status.RECOVERED_BACKUP)
	assert(loaded.snapshot_for_restore().run_id == first_snapshot.run_id)

	assert(service.clear_all())
	_write_text(service.primary_path, "{hala-bozuk")
	loaded = service.load_active(controller.catalog, config)
	assert(loaded.status == SaveLoadResult.Status.INVALID)
	assert(not loaded.has_valid_save())

	assert(service.clear_all())
	var stale_envelope := SaveEnvelope.create(controller.create_snapshot()).to_dictionary()
	var stale_state: Dictionary = stale_envelope["state"]
	stale_state["contentVersion"] = "eski-icerik"
	_write_text(service.primary_path, JSON.stringify(stale_envelope))
	loaded = service.load_active(controller.catalog, config)
	assert(loaded.status == SaveLoadResult.Status.INVALID)

	assert(service.clear_all())
	var legacy_envelope := SaveEnvelope.create(controller.create_snapshot()).to_dictionary()
	var legacy_state: Dictionary = legacy_envelope["state"]
	legacy_state["schemaVersion"] = 1
	legacy_state.erase("roomResults")
	_write_text(service.primary_path, JSON.stringify(legacy_envelope))
	loaded = service.load_active(controller.catalog, config)
	assert(loaded.status == SaveLoadResult.Status.INVALID)


static func _test_startup_restore(
	controller: RunController,
	service: SaveService,
	parent: Node,
) -> void:
	assert(service.clear_all())
	assert(controller.start_new_run(61_616))
	var expected_template_id := controller.run_session.current_template_id
	assert(service.save_stable(controller.create_snapshot()))
	var main_scene: PackedScene = load("res://app/main.tscn")
	var restored_controller: RunController = main_scene.instantiate()
	restored_controller.persistence_enabled = true
	restored_controller.save_path = TEST_SAVE_PATH
	restored_controller.profile_path = "user://tests/deep_ricochet_restore_profile_test.json"
	restored_controller.settings_path = "user://tests/deep_ricochet_restore_settings_test.json"
	restored_controller.tutorial_enabled = false
	parent.add_child(restored_controller)
	await parent.get_tree().process_frame
	assert(restored_controller.run_session == null)
	assert(restored_controller.main_menu_view.visible)
	assert(restored_controller.main_menu_view.continue_available)
	assert(restored_controller.continue_saved_run())
	assert(restored_controller.run_session.seed == 61_616)
	assert(restored_controller.run_session.current_template_id == expected_template_id)
	assert(restored_controller.gameplay_room.current_template.room_id == expected_template_id)
	restored_controller.queue_free()
	await parent.get_tree().process_frame


static func _complete_active_room(controller: RunController) -> RoomResolution:
	var gameplay_room := controller.gameplay_room
	assert(gameplay_room.room.commit_shot())
	var core := _first_block_of_type(gameplay_room.board, BlockState.BlockType.CORE)
	assert(core != null)
	while not core.is_destroyed():
		var damage := gameplay_room.board.resolve_contact(core.id)
		gameplay_room.room.record_damage_result(damage, controller.config)
	var resolution := gameplay_room.room.resolve_shot(gameplay_room.board, controller.config)
	assert(resolution.processed)
	assert(resolution.room_finished)
	assert(resolution.succeeded)
	return resolution


static func _first_block_of_type(board: BoardModel, block_type: int) -> BlockState:
	for block: BlockState in board.blocks:
		if block.type == block_type:
			return block
	return null


static func _first_living_breakable(board: BoardModel) -> BlockState:
	for block: BlockState in board.blocks:
		if block.is_breakable() and not block.is_destroyed():
			return block
	return null


static func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(content)
	file.close()
