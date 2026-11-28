class_name RunFlowTests
extends RefCounted

const DailyRooms := preload("res://content/daily_room_factory.gd")

const BOARD_SIZE := Vector2(BoardGeometry.WORLD_GRID_SIZE)
const LAUNCHER := BoardGeometry.LAUNCHER_WORLD
const CONTROLLER_EVENT_PATH := "user://tests/deep_ricochet_controller_events_test.json"
const MINE_ORDER_PATH := "user://tests/deep_ricochet_mines_order_test.json"


static func run(controller: RunController, config: GameConfig) -> void:
	_test_mine_registry_normalizes_order()
	_test_catalog_and_seeded_selection(controller.catalog, config, controller.mine_registry)
	_test_template_example_angles(controller.catalog, config)
	_test_failed_run(controller.catalog, config)
	_test_controller_four_room_flow(controller, config)


static func _test_mine_registry_normalizes_order() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var source: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://content/mines/mines.json")
	)
	assert(typeof(source) == TYPE_DICTIONARY)
	var data: Dictionary = source
	var reversed_mines: Array = data["mines"].duplicate(true)
	reversed_mines.reverse()
	data["mines"] = reversed_mines
	var file := FileAccess.open(MINE_ORDER_PATH, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var registry := MineRegistry.load_from_file(MINE_ORDER_PATH)
	assert(registry != null)
	for index in range(registry.mines.size()):
		assert(registry.mines[index].order == index + 1)
	var first_mine := registry.get_mine(&"mine_01")
	assert(first_mine != null)
	assert(first_mine.stars_for_score(900, false) == 0)
	assert(first_mine.stars_for_score(549, true) == 1)
	assert(first_mine.stars_for_score(550, true) == 2)
	assert(first_mine.stars_for_score(800, true) == 3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MINE_ORDER_PATH))


static func _test_catalog_and_seeded_selection(
	catalog: RoomCatalog,
	config: GameConfig,
	registry: MineRegistry,
) -> void:
	assert(catalog != null)
	assert(catalog.templates.size() == 259)
	var mine_counts: Dictionary[StringName, int] = {}
	var block_type_counts: Dictionary[int, int] = {}
	var mine_block_type_counts: Dictionary[StringName, Dictionary] = {}
	var mine_classic_hp_totals: Dictionary[StringName, int] = {}
	var mine_classic_block_counts: Dictionary[StringName, int] = {}
	var mine_role_difficulty_totals: Dictionary[StringName, Dictionary] = {}
	var mine_role_room_counts: Dictionary[StringName, Dictionary] = {}
	var role_counts: Dictionary[StringName, Dictionary] = {}
	var layout_signatures: Dictionary[StringName, Dictionary] = {}
	var core_positions: Dictionary[StringName, Dictionary] = {}
	var normal_templates: Array[RoomTemplate] = []
	for template: RoomTemplate in catalog.templates:
		assert(template.is_valid())
		assert(template.create_board().core_count() == 1)
		var is_daily := template.mine_id == DailyRooms.DAILY_MINE_ID
		var mine_order := PlayerProfile.MINE_COUNT if is_daily \
			else str(template.mine_id).trim_prefix("mine_").to_int()
		assert(is_daily or (mine_order >= 1 and mine_order <= PlayerProfile.MINE_COUNT))
		if not is_daily:
			normal_templates.append(template)
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
		var room_durability := 0
		var room_rock_count := 0
		var edge_rock_count := 0
		var room_cache_count := 0
		var room_acid_count := 0
		var room_acid_cells: Array[Vector2i] = []
		var core_cell := Vector2i(-1, -1)
		for definition: RoomBlockDefinition in template.blocks:
			if definition.block_type != BlockState.BlockType.CORE:
				assert(
					definition.cell.y >= RoomTemplate.MIN_BLOCK_ROW,
					"Alt iki satırda blok bulundu: %s / %s" % [
						template.room_id,
						definition.cell,
					],
				)
			block_type_counts[definition.block_type] = block_type_counts.get(definition.block_type, 0) + 1
			mine_types[definition.block_type] = mine_types.get(definition.block_type, 0) + 1
			if definition.block_type != BlockState.BlockType.ROCK:
				room_durability += definition.hit_points
			else:
				room_rock_count += 1
				if definition.cell.x <= 1 or definition.cell.x >= 6:
					edge_rock_count += 1
			if definition.block_type in [BlockState.BlockType.NORMAL, BlockState.BlockType.ORE]:
				mine_classic_hp_totals[template.mine_id] = mine_classic_hp_totals.get(template.mine_id, 0) \
					+ definition.hit_points
				mine_classic_block_counts[template.mine_id] = mine_classic_block_counts.get(template.mine_id, 0) + 1
			elif definition.block_type == BlockState.BlockType.CRACKED:
				assert(definition.hit_points == 8)
			elif definition.block_type == BlockState.BlockType.ARMORED:
				assert(
					(definition.vulnerable_sides & BlockState.VulnerableSide.BOTTOM) != 0,
					"Zırhlı blok görselindeki alt zayıf nokta hasar maskesinde yok: %s / %d" % [
						template.room_id,
						definition.id,
					],
				)
			elif definition.block_type == BlockState.BlockType.ECHO:
				assert(definition.hit_points == RoomTemplate.ECHO_HIT_POINTS)
			elif definition.block_type == BlockState.BlockType.BALL_CACHE:
				room_cache_count += 1
				assert(definition.hit_points == RoomTemplate.BALL_CACHE_HIT_POINTS)
				assert(definition.cell.y >= 3)
			elif definition.block_type == BlockState.BlockType.PIERCING:
				assert(definition.hit_points == RoomTemplate.PIERCING_HIT_POINTS)
				assert(definition.beam_direction != BlockState.BeamDirection.NONE)
			elif definition.block_type == BlockState.BlockType.ACID_BARREL:
				room_acid_count += 1
				room_acid_cells.append(definition.cell)
				assert(definition.hit_points == RoomTemplate.ACID_BARREL_HIT_POINTS)
			elif definition.block_type == BlockState.BlockType.CORE:
				core_cell = definition.cell
				assert(BoardGeometry.is_core_row(definition.cell.y))
				assert(definition.cell.x >= 1 and definition.cell.x <= 6)
				if not is_daily:
					if not core_positions.has(template.mine_id):
						core_positions[template.mine_id] = {}
					var mine_core_positions: Dictionary = core_positions[template.mine_id]
					mine_core_positions["%d:%d" % [definition.cell.x, definition.cell.y]] = true
				var expected_core_hp := mini(8, 6 + floori(float(mine_order - 1) / 5.0))
				if template.role == RoomTemplate.Role.NARROW:
					expected_core_hp = mini(8, expected_core_hp + 1)
				assert(definition.hit_points == expected_core_hp)
		if not is_daily and mine_order >= 20:
			var has_side_guard := false
			for definition: RoomBlockDefinition in template.blocks:
				if definition.block_type in [BlockState.BlockType.NORMAL, BlockState.BlockType.ORE] \
					and definition.cell.y == core_cell.y - 1 \
					and absi(definition.cell.x - core_cell.x) == 1:
					has_side_guard = true
					break
			assert(has_side_guard, "Çekirdek yan koruması eksik: %s" % template.room_id)
		for acid_cell: Vector2i in room_acid_cells:
			if not is_daily:
				assert(maxi(
					absi(acid_cell.x - core_cell.x),
					absi(acid_cell.y - core_cell.y),
				) >= 3, "Asit varili çekirdeğe fazla yakın: %s" % template.room_id)
		if not role_counts.has(template.mine_id):
			role_counts[template.mine_id] = {}
		var mine_roles: Dictionary = role_counts[template.mine_id]
		mine_roles[template.role] = mine_roles.get(template.role, 0) + 1
		if not is_daily:
			if mine_order <= 14:
				assert(room_cache_count == 0)
			else:
				assert(room_cache_count >= 1 and room_cache_count <= 2)
			if mine_order >= 29:
				assert(room_acid_count >= 1 and room_acid_count <= 2)
			else:
				assert(room_acid_count == 0)
			var density_tier := floori(float(mine_order - 1) / 3.0)
			var base_density := mini(22, 14 + density_tier * 2)
			var late_density_bonus := 1 if mine_order >= 23 else 0
			var minimum_density := base_density + late_density_bonus
			var maximum_density := mini(23, base_density + late_density_bonus + 1)
			if template.role == RoomTemplate.Role.NARROW:
				minimum_density = mini(24, base_density + 2)
				maximum_density = mini(24, base_density + 3)
				assert(room_rock_count >= 5 and room_rock_count <= 9)
				assert(edge_rock_count == room_rock_count)
			assert(
				template.blocks.size() >= minimum_density \
					and template.blocks.size() <= maximum_density,
				"Oda yoğunluğu hedef dışında: %s (%d, beklenen %d-%d)" % [
					template.room_id,
					template.blocks.size(),
					minimum_density,
					maximum_density,
				],
			)
		if not is_daily and template.role != RoomTemplate.Role.START:
			if not mine_role_difficulty_totals.has(template.mine_id):
				mine_role_difficulty_totals[template.mine_id] = {}
				mine_role_room_counts[template.mine_id] = {}
			var role_difficulty: Dictionary = mine_role_difficulty_totals[template.mine_id]
			var role_room_counts: Dictionary = mine_role_room_counts[template.mine_id]
			role_difficulty[template.role] = role_difficulty.get(template.role, 0) \
				+ room_durability + room_rock_count * 5 \
				+ (10 if template.role == RoomTemplate.Role.NARROW else 0)
			role_room_counts[template.role] = role_room_counts.get(template.role, 0) + 1
		if template.family == RoomTemplate.Family.SAFE:
			assert(template.multiplier_bps == config.safe_multiplier_bps)
			assert(template.passage_columns.size() == 2)
		else:
			assert(template.multiplier_bps == config.bonus_multiplier_bps)
			assert(template.passage_columns.size() == 1)
		if is_daily:
			assert(room_acid_count == 1)
			assert(
				template.blocks.size() == DailyRooms.TARGET_BLOCK_COUNT,
				"Günlük oda yoğunluğu uyuşmuyor: %s (%d/%d)" % [
					template.room_id,
					template.blocks.size(),
					DailyRooms.TARGET_BLOCK_COUNT,
				],
			)
			var daily_types: Dictionary[int, bool] = {}
			for definition: RoomBlockDefinition in template.blocks:
				daily_types[definition.block_type] = true
			for required_type: int in [
				BlockState.BlockType.NORMAL,
				BlockState.BlockType.ORE,
				BlockState.BlockType.ROCK,
				BlockState.BlockType.CORE,
				BlockState.BlockType.EXPLOSIVE,
				BlockState.BlockType.CRACKED,
				BlockState.BlockType.ARMORED,
				BlockState.BlockType.ECHO,
				BlockState.BlockType.BALL_CACHE,
				BlockState.BlockType.PIERCING,
				BlockState.BlockType.ACID_BARREL,
			]:
				assert(daily_types.has(required_type))
	_assert_normal_layout_uniqueness(normal_templates)
	var previous_classic_average := 0.0
	for mine_order in range(1, PlayerProfile.MINE_COUNT + 1):
		var mine_id := StringName("mine_%02d" % mine_order)
		assert(mine_counts.get(mine_id, 0) == 7)
		var counts: Dictionary = role_counts[mine_id]
		assert(counts.get(RoomTemplate.Role.START, 0) == 1)
		assert(counts.get(RoomTemplate.Role.WIDE, 0) == 3)
		assert(counts.get(RoomTemplate.Role.NARROW, 0) == 3)
		assert((core_positions[mine_id] as Dictionary).size() >= 6)
		var difficulty_totals: Dictionary = mine_role_difficulty_totals[mine_id]
		var durability_counts: Dictionary = mine_role_room_counts[mine_id]
		var wide_difficulty := float(difficulty_totals[RoomTemplate.Role.WIDE]) \
			/ float(durability_counts[RoomTemplate.Role.WIDE])
		var narrow_difficulty := float(difficulty_totals[RoomTemplate.Role.NARROW]) \
			/ float(durability_counts[RoomTemplate.Role.NARROW])
		assert(
			narrow_difficulty > wide_difficulty,
			"Dar damar geniş geçitten daha zor değil: %s (%.1f <= %.1f)" % [
				mine_id,
				narrow_difficulty,
				wide_difficulty,
			],
		)
		var classic_average := float(mine_classic_hp_totals[mine_id]) \
			/ float(mine_classic_block_counts[mine_id])
		assert(
			classic_average + 0.10 >= previous_classic_average,
			"Klasik blok can ortalaması beklenenden fazla geriledi: %s (%.2f < %.2f)" % [
				mine_id,
				classic_average,
				previous_classic_average,
			],
		)
		previous_classic_average = classic_average
		var mine_types: Dictionary = mine_block_type_counts[mine_id]
		if mine_order <= 6:
			assert(mine_types.get(BlockState.BlockType.EXPLOSIVE, 0) == 0)
			assert(mine_types.get(BlockState.BlockType.CRACKED, 0) == 0)
			assert(mine_types.get(BlockState.BlockType.ARMORED, 0) == 0)
			assert(mine_types.get(BlockState.BlockType.ECHO, 0) == 0)
			assert(mine_types.get(BlockState.BlockType.PIERCING, 0) == 0)
		elif mine_order <= 10:
			assert(mine_types.get(BlockState.BlockType.EXPLOSIVE, 0) > 0)
			assert(mine_types.get(BlockState.BlockType.CRACKED, 0) > 0)
			assert(mine_types.get(BlockState.BlockType.ARMORED, 0) == 0)
			assert(mine_types.get(BlockState.BlockType.ECHO, 0) == 0)
			assert(mine_types.get(BlockState.BlockType.PIERCING, 0) == 0)
		else:
			assert(mine_types.get(BlockState.BlockType.EXPLOSIVE, 0) > 0)
			assert(mine_types.get(BlockState.BlockType.CRACKED, 0) > 0)
			assert(mine_types.get(BlockState.BlockType.ARMORED, 0) > 0)
			if mine_order <= 14:
				assert(mine_types.get(BlockState.BlockType.ECHO, 0) == 0)
			else:
				assert(mine_types.get(BlockState.BlockType.ECHO, 0) > 0)
			if mine_order <= 22:
				assert(mine_types.get(BlockState.BlockType.PIERCING, 0) == 0)
			else:
				assert(mine_types.get(BlockState.BlockType.PIERCING, 0) > 0)
		var mine_acid_count: int = mine_types.get(BlockState.BlockType.ACID_BARREL, 0)
		if mine_order >= 29:
			assert(mine_acid_count >= 7 and mine_acid_count <= 14)
		else:
			assert(mine_acid_count == 0)
		var mine_cache_count: int = mine_types.get(BlockState.BlockType.BALL_CACHE, 0)
		if mine_order <= 14:
			assert(mine_cache_count == 0)
		else:
			assert(mine_cache_count >= 7 and mine_cache_count <= 14)
	assert(mine_counts.get(DailyRooms.DAILY_MINE_ID, 0) == 14)
	var daily_roles: Dictionary = role_counts[DailyRooms.DAILY_MINE_ID]
	assert(daily_roles.get(RoomTemplate.Role.START, 0) == 2)
	assert(daily_roles.get(RoomTemplate.Role.WIDE, 0) == 6)
	assert(daily_roles.get(RoomTemplate.Role.NARROW, 0) == 6)

	assert(block_type_counts.get(BlockState.BlockType.EXPLOSIVE, 0) > 0)
	assert(block_type_counts.get(BlockState.BlockType.CRACKED, 0) > 0)
	assert(block_type_counts.get(BlockState.BlockType.ARMORED, 0) > 0)
	assert(block_type_counts.get(BlockState.BlockType.ECHO, 0) > 0)
	assert(block_type_counts.get(BlockState.BlockType.BALL_CACHE, 0) > 0)
	assert(block_type_counts.get(BlockState.BlockType.PIERCING, 0) > 0)
	assert(block_type_counts.get(BlockState.BlockType.ACID_BARREL, 0) > 0)
	for mine_order in range(1, PlayerProfile.MINE_COUNT + 1):
		var mine_id := StringName("mine_%02d" % mine_order)
		var mine := registry.get_mine(mine_id)
		assert(mine != null)
		var first_room_maximum := 0
		var route_maximums: Array[int] = []
		for template: RoomTemplate in normal_templates:
			if template.mine_id != mine_id:
				continue
			var all_block_points := 0
			for block: RoomBlockDefinition in template.blocks:
				all_block_points += ScoreCalculator.break_points(block.block_type, config)
			var room_maximum := ScoreCalculator.room_reward(
				all_block_points,
				config.shots_per_room - 1,
				template.multiplier_bps,
				true,
				config,
			)
			if template.role == RoomTemplate.Role.START:
				first_room_maximum = room_maximum
			else:
				route_maximums.append(room_maximum)
		route_maximums.sort_custom(func(left: int, right: int) -> bool: return left > right)
		var run_maximum := first_room_maximum
		for route_index in range(config.room_count - 1):
			run_maximum += route_maximums[route_index]
		assert(
			mine.three_star_score <= run_maximum,
			"Üç yıldız eşiği erişilebilir puanı aşıyor: %s (%d > %d)" % [
				mine_id, mine.three_star_score, run_maximum,
			],
		)

	for mine_order in range(1, PlayerProfile.MINE_COUNT + 1):
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
	assert(catalog.pick_first_room(first_rng, &"mine_28").room_id == catalog.pick_first_room(second_rng, &"mine_28").room_id)
	for mine_id: StringName in [
		&"mine_01",
		&"mine_07",
		&"mine_10",
		&"mine_11",
		&"mine_14",
		&"mine_21",
		&"mine_28",
		DailyRooms.DAILY_MINE_ID,
	]:
		for seed in [1, 4444, 98_765]:
			var first_signature := _seeded_route_signature(catalog, config, seed, mine_id)
			var second_signature := _seeded_route_signature(catalog, config, seed, mine_id)
			assert(
				first_signature == second_signature,
				"Aynı seed tüm rota tekliflerinde farklı sonuç üretti: %s / %d" % [
					mine_id,
					seed,
				],
			)


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


static func _assert_normal_layout_uniqueness(templates: Array[RoomTemplate]) -> void:
	var cell_sets: Array[Dictionary] = []
	var visual_sets: Array[Dictionary] = []
	for template: RoomTemplate in templates:
		cell_sets.append(_layout_set(template, false))
		visual_sets.append(_layout_set(template, true))
	for left_index in range(templates.size()):
		for right_index in range(left_index + 1, templates.size()):
			var layout_similarity := _jaccard_similarity(
				cell_sets[left_index],
				cell_sets[right_index],
			)
			var visual_similarity := _jaccard_similarity(
				visual_sets[left_index],
				visual_sets[right_index],
			)
			assert(
				layout_similarity <= 0.80 and visual_similarity <= 0.70,
				"Odalar aşırı benzer: %s / %s (%.0f%%, %.0f%%)" % [
					templates[left_index].room_id,
					templates[right_index].room_id,
					layout_similarity * 100.0,
					visual_similarity * 100.0,
				],
			)


static func _layout_set(template: RoomTemplate, include_type: bool) -> Dictionary:
	var result: Dictionary = {}
	for block: RoomBlockDefinition in template.blocks:
		var key := "%d:%d" % [block.cell.x, block.cell.y]
		if include_type:
			key = "%d:%s" % [block.block_type, key]
		result[key] = true
	return result


static func _jaccard_similarity(left: Dictionary, right: Dictionary) -> float:
	var intersection := 0
	for key: String in left:
		if right.has(key):
			intersection += 1
	var union_size := left.size() + right.size() - intersection
	return float(intersection) / float(maxi(union_size, 1))


static func _seeded_route_signature(
	catalog: RoomCatalog,
	config: GameConfig,
	seed: int,
	mine_id: StringName,
) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var first_room := catalog.pick_first_room(rng, mine_id)
	assert(first_room != null)
	var session := RunSession.new()
	assert(session.start_run(
		seed,
		catalog.content_version,
		config.room_count,
		first_room,
		"",
		mine_id,
	))
	var parts := PackedStringArray(["start=%s" % first_room.room_id])
	for route_index in range(config.room_count - 1):
		assert(session.resolve_room(_finished_resolution(true, 100 + route_index)))
		var options := catalog.create_route_options(
			session.room_number + 1,
			rng,
			session.used_template_ids(),
			mine_id,
		)
		assert(options.size() == 2)
		parts.append("offer%d=%s,%s" % [
			route_index + 1,
			options[0].template.room_id,
			options[1].template.room_id,
		])
		assert(session.set_route_options(options))
		var selected_index := route_index % 2
		parts.append("select%d=%s" % [
			route_index + 1,
			options[selected_index].template.room_id,
		])
		assert(session.select_route(options[selected_index].option_id) != null)
	assert(session.resolve_room(_finished_resolution(true, 100)))
	assert(session.ended and session.succeeded)
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


static func _test_controller_four_room_flow(
	controller: RunController,
	config: GameConfig,
) -> void:
	controller.test_event_service = TestEventService.new(CONTROLLER_EVENT_PATH, 200)
	assert(controller.test_event_service.clear_all())
	assert(controller.start_new_run(777))
	controller.pause_game()
	controller.resume_game()
	controller._on_shot_started()
	controller._on_shot_resolved(_finished_resolution(false, 0))
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
	assert(controller.next_mine_id_from_result() == &"mine_02")
	assert(controller.restart_same_seed())
	assert(controller.run_session.seed == 777)
	assert(controller.run_session.current_template_id == first_template_id)
	assert(controller.run_session.run_id != completed_run_id)
	assert(controller.gameplay_room.simulation_speed == 1)
	for completed_room in range(1, 5):
		controller._on_room_finished(_finished_resolution(true, completed_room * 50))
		if completed_room < 4:
			assert(controller.run_session.pending_routes.size() == 2)
			assert(controller.select_route(controller.run_session.pending_routes[0].option_id))
	assert(controller.run_session.ended)
	assert(controller.run_session.succeeded)
	assert(controller.start_next_mine_from_result())
	assert(controller.run_session.mine_id == &"mine_02")
	assert(controller.run_session.room_number == 1)
	assert(controller.gameplay_room.run_mine_number == 2)
	assert(not controller.gameplay_room.run_is_daily)
	assert(not controller.flow_view.visible)
	var daily_key := "2026-11-11"
	var daily_seed := controller.daily_seed_for_key(daily_key)
	assert(daily_seed == controller.daily_seed_for_key(daily_key))
	assert(daily_seed != controller.daily_seed_for_key("2026-11-12"))
	assert(controller.start_new_run(
		daily_seed,
		&"mine_01",
		RunSession.RunKind.DAILY,
		daily_key,
	))
	assert(controller.run_session.run_kind == RunSession.RunKind.DAILY)
	assert(controller.run_session.daily_key == daily_key)
	assert(controller.run_session.mine_id == DailyRooms.DAILY_MINE_ID)
	assert(controller.gameplay_room.run_is_daily)
	assert(controller.gameplay_room.room.shots_remaining == config.daily_shots_per_room)
	assert(controller.gameplay_room.shots_per_room == config.daily_shots_per_room)
	var daily_snapshot := controller.create_snapshot()
	assert(daily_snapshot.mine_id == DailyRooms.DAILY_MINE_ID)
	assert(daily_snapshot.run_kind == RunSession.RunKind.DAILY)
	assert(daily_snapshot.daily_key == daily_key)
	assert(daily_snapshot.validation_errors(controller.catalog, config).is_empty())
	assert(controller.start_new_run(778))
	assert(controller.restore_snapshot(daily_snapshot))
	assert(controller.run_session.mine_id == DailyRooms.DAILY_MINE_ID)
	assert(controller.gameplay_room.run_is_daily)
	assert(controller.gameplay_room.room.shots_remaining == config.daily_shots_per_room)
	assert(controller.start_new_run(778))
	assert(controller.run_session.banked_score == 0)
	assert(controller.run_session.room_number == 1)
	assert(controller.start_new_run(779, &"mine_02"))
	assert(controller.run_session.mine_id == &"mine_02")
	assert(controller.gameplay_room.run_mine_number == 2)
	assert(not controller.gameplay_room.run_is_daily)

	var final_mine_result := RunSession.new()
	final_mine_result.mine_id = &"mine_35"
	final_mine_result.run_kind = RunSession.RunKind.NORMAL
	final_mine_result.ended = true
	final_mine_result.succeeded = true
	final_mine_result.phase = RunSession.Phase.RUN_RESULT
	controller.run_session = final_mine_result
	assert(controller.next_mine_id_from_result().is_empty())
	assert(controller.start_next_mine_from_result())
	assert(controller.run_session == null)
	assert(controller.mine_select_view.visible)
	controller.close_mine_selection()
	var recorded_names := controller.test_event_service.event_names()
	for required_name in [
		"run_started",
		"shot_started",
		"shot_resolved",
		"room_completed",
		"route_offered",
		"route_selected",
		"run_ended",
		"run_restarted",
		"session_resumed",
	]:
		assert(recorded_names.has(required_name), "Denetleyici olayı eksik: %s" % required_name)
	assert(controller.test_event_service.clear_all())
	controller.test_event_service = null


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
