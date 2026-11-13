class_name RunFlowTests
extends RefCounted

const BOARD_SIZE := Vector2(BoardGeometry.WORLD_GRID_SIZE)
const LAUNCHER := BoardGeometry.LAUNCHER_WORLD


static func run(controller: RunController, config: GameConfig) -> void:
	_test_catalog_and_seeded_selection(controller.catalog, config)
	_test_template_example_angles(controller.catalog, config)
	_test_failed_run(controller.catalog, config)
	_test_controller_four_room_flow(controller)


static func _test_catalog_and_seeded_selection(catalog: RoomCatalog, config: GameConfig) -> void:
	assert(catalog != null)
	assert(catalog.templates.size() == 98)
	var mine_counts: Dictionary[StringName, int] = {}
	var block_type_counts: Dictionary[int, int] = {}
	var mine_block_type_counts: Dictionary[StringName, Dictionary] = {}
	var mine_classic_hp_totals: Dictionary[StringName, int] = {}
	var mine_classic_block_counts: Dictionary[StringName, int] = {}
	var role_counts: Dictionary[StringName, Dictionary] = {}
	var layout_signatures: Dictionary[StringName, Dictionary] = {}
	for template: RoomTemplate in catalog.templates:
		assert(template.is_valid())
		assert(template.create_board().core_count() == 1)
		var mine_order := str(template.mine_id).trim_prefix("mine_").to_int()
		assert(mine_order >= 1 and mine_order <= 7)
		if not layout_signatures.has(template.mine_id):
			layout_signatures[template.mine_id] = {}
		var mine_layouts: Dictionary = layout_signatures[template.mine_id]
		var layout_signature := _layout_signature(template)
		assert(
			not mine_layouts.has(layout_signature),
			"Yinelenen oda düzeni bulundu: %s" % template.room_id,
		)
		mine_layouts[layout_signature] = true
		mine_counts[template.mine_id] = mine_counts.get(template.mine_id, 0) + 1
		if not mine_block_type_counts.has(template.mine_id):
			mine_block_type_counts[template.mine_id] = {}
		var mine_types: Dictionary = mine_block_type_counts[template.mine_id]
		for definition: RoomBlockDefinition in template.blocks:
			block_type_counts[definition.block_type] = block_type_counts.get(definition.block_type, 0) + 1
			mine_types[definition.block_type] = mine_types.get(definition.block_type, 0) + 1
			if definition.block_type in [BlockState.BlockType.NORMAL, BlockState.BlockType.ORE]:
				mine_classic_hp_totals[template.mine_id] = mine_classic_hp_totals.get(template.mine_id, 0) \
					+ definition.hit_points
				mine_classic_block_counts[template.mine_id] = mine_classic_block_counts.get(template.mine_id, 0) + 1
			elif definition.block_type == BlockState.BlockType.CORE:
				assert(definition.hit_points == 6 + floori(float(mine_order - 1) / 3.0))
		if not role_counts.has(template.mine_id):
			role_counts[template.mine_id] = {}
		var mine_roles: Dictionary = role_counts[template.mine_id]
		mine_roles[template.role] = mine_roles.get(template.role, 0) + 1
		if template.family == RoomTemplate.Family.SAFE:
			assert(template.multiplier_bps == config.safe_multiplier_bps)
			assert(template.passage_columns.size() == 2)
		else:
			assert(template.multiplier_bps == config.bonus_multiplier_bps)
			assert(template.passage_columns.size() == 1)
	var previous_classic_average := 0.0
	for mine_order in range(1, 8):
		var mine_id := StringName("mine_%02d" % mine_order)
		assert(mine_counts.get(mine_id, 0) == 14)
		var counts: Dictionary = role_counts[mine_id]
		assert(counts.get(RoomTemplate.Role.START, 0) == 2)
		assert(counts.get(RoomTemplate.Role.WIDE, 0) == 6)
		assert(counts.get(RoomTemplate.Role.NARROW, 0) == 6)
		var classic_average := float(mine_classic_hp_totals[mine_id]) \
			/ float(mine_classic_block_counts[mine_id])
		assert(classic_average > previous_classic_average)
		previous_classic_average = classic_average
		var mine_types: Dictionary = mine_block_type_counts[mine_id]
		if mine_order <= 3:
			assert(mine_types.get(BlockState.BlockType.EXPLOSIVE, 0) == 0)
			assert(mine_types.get(BlockState.BlockType.CRACKED, 0) == 0)
			assert(mine_types.get(BlockState.BlockType.ARMORED, 0) == 0)
		elif mine_order <= 5:
			assert(mine_types.get(BlockState.BlockType.EXPLOSIVE, 0) > 0)
			assert(mine_types.get(BlockState.BlockType.CRACKED, 0) > 0)
			assert(mine_types.get(BlockState.BlockType.ARMORED, 0) == 0)
		else:
			assert(mine_types.get(BlockState.BlockType.EXPLOSIVE, 0) > 0)
			assert(mine_types.get(BlockState.BlockType.CRACKED, 0) > 0)
			assert(mine_types.get(BlockState.BlockType.ARMORED, 0) > 0)

	assert(block_type_counts.get(BlockState.BlockType.EXPLOSIVE, 0) > 0)
	assert(block_type_counts.get(BlockState.BlockType.CRACKED, 0) > 0)
	assert(block_type_counts.get(BlockState.BlockType.ARMORED, 0) > 0)

	for mine_order in range(1, 8):
		var mine_id := StringName("mine_%02d" % mine_order)
		for sample_index in range(100):
			var rng := RandomNumberGenerator.new()
			rng.seed = sample_index + 1000
			var first_room := catalog.pick_first_room(rng, mine_id)
			assert(first_room.role == RoomTemplate.Role.START)
			var session := RunSession.new()
			assert(session.start_run(rng.seed, catalog.content_version, config.room_count, first_room, "", mine_id))
			for room_index in range(3):
				assert(session.resolve_room(_finished_resolution(true, 100 + room_index)))
				var options := catalog.create_route_options(
					session.room_number + 1,
					rng,
					session.used_template_ids(),
					mine_id,
				)
				assert(options.size() == 2)
				assert(options[0].template.role == RoomTemplate.Role.WIDE)
				assert(options[1].template.role == RoomTemplate.Role.NARROW)
				assert(session.set_route_options(options))
				var selected_index := (sample_index + room_index) % 2
				var room_number_before_selection := session.room_number
				var selected_count_before_selection := session.selected_template_ids.size()
				assert(session.route_template(options[selected_index].option_id) == options[selected_index].template)
				assert(session.room_number == room_number_before_selection)
				assert(session.selected_template_ids.size() == selected_count_before_selection)
				assert(session.select_route(options[selected_index].option_id) != null)
			assert(session.resolve_room(_finished_resolution(true, 100)))
			assert(session.ended)
			assert(session.succeeded)
			assert(session.cores_broken == 4)
			assert(session.route_choices_made == 3)
			assert(session.selected_template_ids.size() == 4)
			assert(session.offered_template_ids.size() == 6)
			assert(session.used_template_ids().size() == 7)

	var first_rng := RandomNumberGenerator.new()
	first_rng.seed = 4444
	var second_rng := RandomNumberGenerator.new()
	second_rng.seed = 4444
	assert(catalog.pick_first_room(first_rng, &"mine_07").room_id == catalog.pick_first_room(second_rng, &"mine_07").room_id)


static func _layout_signature(template: RoomTemplate) -> String:
	var parts := PackedStringArray()
	for block: RoomBlockDefinition in template.blocks:
		parts.append("%d:%d:%d:%d:%d" % [
			block.block_type,
			block.cell.x,
			block.cell.y,
			block.hit_points,
			block.vulnerable_sides,
		])
	parts.sort()
	return "|".join(parts)


static func _test_template_example_angles(catalog: RoomCatalog, config: GameConfig) -> void:
	var started_usec := Time.get_ticks_usec()
	var simulator := ShotSimulator.new()
	for template: RoomTemplate in catalog.templates:
		var board := template.create_board()
		for angle: float in template.example_angles:
			var volley := ShotVolley.new()
			assert(volley.start(
				LAUNCHER,
				Vector2.from_angle(deg_to_rad(angle)) * config.ball_speed,
				config.ball_count,
				config.launch_interval_seconds,
				config.volley_limit_seconds,
			))
			for tick in range(1300):
				if not volley.active:
					break
				volley.advance(
					1.0 / 120.0,
					simulator,
					BOARD_SIZE,
					config.ball_radius,
					board,
				)
			assert(not volley.active)
			if board.is_core_destroyed():
				break
		assert(board.is_core_destroyed(), "Örnek açı dizisi çekirdeği kıramadı: %s" % template.room_id)
	var elapsed_msec := float(Time.get_ticks_usec() - started_usec) / 1000.0
	print("[PERF] %d oda örnek açı simülasyonu: %.1f ms" % [
		catalog.templates.size(),
		elapsed_msec,
	])


static func _test_failed_run(catalog: RoomCatalog, config: GameConfig) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var session := RunSession.new()
	assert(session.start_run(55, catalog.content_version, config.room_count, catalog.pick_first_room(rng)))
	var failure := _finished_resolution(false, 35)
	assert(session.resolve_room(failure))
	assert(session.ended)
	assert(not session.succeeded)
	assert(session.banked_score == 35)
	assert(session.cores_broken == 0)
	assert(session.room_results.size() == 1)
	assert(not session.room_results[0].succeeded)
	assert(not session.resolve_room(failure))


static func _test_controller_four_room_flow(controller: RunController) -> void:
	assert(controller.start_new_run(777))
	var first_template_id := controller.run_session.current_template_id
	assert(controller.run_session.room_number == 1)
	assert(controller.run_session.mine_id == &"mine_01")
	assert(controller.gameplay_room.current_template.family == RoomTemplate.Family.SAFE)
	for completed_room in range(1, 5):
		controller._on_room_finished(_finished_resolution(true, completed_room * 100))
		if completed_room < 4:
			assert(controller.run_session.phase == RunSession.Phase.ROUTE_SELECTION)
			assert(controller.flow_view.screen == RunFlowView.Screen.ROUTE_SELECTION)
			assert(controller.flow_view.visible)
			assert(controller.run_session.pending_routes.size() == 2)
			var selected_option := controller.run_session.pending_routes[completed_room % 2]
			assert(controller.select_route(selected_option.option_id))
			assert(controller.run_session.room_number == completed_room + 1)
			assert(controller.gameplay_room.current_template.room_id == selected_option.template.room_id)
			assert(not controller.flow_view.visible)
		else:
			assert(controller.run_session.phase == RunSession.Phase.RUN_RESULT)
			assert(controller.run_session.succeeded)
			assert(controller.run_session.banked_score == 1000)
			assert(controller.run_session.room_results.size() == 4)
			assert(controller.flow_view.screen == RunFlowView.Screen.RUN_RESULT)
			assert(controller.flow_view.visible)
	var completed_run_id := controller.run_session.run_id
	assert(controller.profile.is_mine_unlocked(&"mine_02"))
	assert(controller.restart_same_seed())
	assert(controller.run_session.seed == 777)
	assert(controller.run_session.current_template_id == first_template_id)
	assert(controller.run_session.run_id != completed_run_id)
	assert(controller.gameplay_room.simulation_speed == 1)
	var daily_key := "2026-11-11"
	var daily_seed := controller.daily_seed_for_key(daily_key)
	assert(controller.start_new_run(daily_seed, &"mine_01", RunSession.RunKind.DAILY, daily_key))
	assert(controller.run_session.run_kind == RunSession.RunKind.DAILY)
	assert(controller.run_session.daily_key == daily_key)
	var daily_snapshot := controller.create_snapshot()
	assert(daily_snapshot.mine_id == &"mine_01")
	assert(daily_snapshot.run_kind == RunSession.RunKind.DAILY)
	assert(daily_snapshot.daily_key == daily_key)
	assert(controller.start_new_run(778))
	assert(controller.run_session.banked_score == 0)
	assert(controller.run_session.room_number == 1)
	assert(controller.start_new_run(779, &"mine_02"))
	assert(controller.run_session.mine_id == &"mine_02")


static func _finished_resolution(success: bool, reward: int) -> RoomResolution:
	var resolution := RoomResolution.new()
	resolution.processed = true
	resolution.room_finished = true
	resolution.succeeded = success
	resolution.reward = reward
	resolution.break_score = reward
	resolution.remaining_shots = 0
	resolution.multiplier_bps = 10_000
	resolution.unused_shot_bonus = 0
	return resolution
