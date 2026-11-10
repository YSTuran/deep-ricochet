class_name VolleyAndRoomTests
extends RefCounted

const BOARD_SIZE := Vector2(BoardGeometry.WORLD_GRID_SIZE)


static func run(config: GameConfig) -> void:
	_test_volley_lifecycle(config)
	_test_full_timeout(config)
	_test_scoring_and_room_resolution(config)


static func _test_volley_lifecycle(config: GameConfig) -> void:
	var simulator := ShotSimulator.new()
	var board := BoardModel.new()
	var volley := ShotVolley.new()
	assert(volley.start(
		Vector2(4.0, 0.45),
		Vector2.UP * config.ball_speed,
		config.ball_count,
		config.launch_interval_seconds,
		config.volley_limit_seconds,
	))
	assert(volley.launched_count == 1)
	assert(not volley.start(Vector2.ZERO, Vector2.UP, 1, 0.0, 1.0))
	volley.advance(0.079, simulator, BOARD_SIZE, config.ball_radius, board)
	assert(volley.launched_count == 1)
	volley.advance(0.001, simulator, BOARD_SIZE, config.ball_radius, board)
	assert(volley.launched_count == 2)

	for tick in range(400):
		if not volley.active:
			break
		volley.advance(1.0 / 120.0, simulator, BOARD_SIZE, config.ball_radius, board)
	assert(not volley.active)
	assert(volley.launched_count == config.ball_count)
	assert(volley.collected_count == config.ball_count)
	assert(volley.consume_finished_event())
	assert(not volley.consume_finished_event())


static func _test_full_timeout(config: GameConfig) -> void:
	var simulator := ShotSimulator.new()
	var volley := ShotVolley.new()
	assert(volley.start(
		Vector2(4.0, 5.0),
		Vector2.RIGHT * config.ball_speed,
		config.ball_count,
		config.launch_interval_seconds,
		config.volley_limit_seconds,
	))
	var forced_positions := PackedVector2Array()
	for tick in range(1300):
		var step_result := volley.advance(
			1.0 / 120.0,
			simulator,
			BOARD_SIZE,
			config.ball_radius,
			BoardModel.new(),
		)
		if not step_result.forced_collection_positions.is_empty():
			forced_positions = step_result.forced_collection_positions
		if not volley.active:
			break
	assert(not volley.active)
	assert(is_equal_approx(volley.elapsed_seconds, config.volley_limit_seconds))
	assert(volley.forced_collection_count == config.ball_count)
	assert(forced_positions.size() == config.ball_count)
	assert(volley.consume_finished_event())


static func _test_scoring_and_room_resolution(config: GameConfig) -> void:
	assert(ScoreCalculator.room_reward(25, 0, 15_000, false, config) == 37)

	var guard_board := BoardModel.new()
	var guard_block := BlockState.new(29, BlockState.BlockType.NORMAL, Vector2i(7, 0), 1)
	assert(guard_board.add_block(guard_block))
	var guard_room := RoomSession.new()
	guard_room.start(1, config.safe_multiplier_bps)
	var outside_shot_damage := guard_board.resolve_contact(guard_block.id)
	assert(guard_room.record_damage_result(outside_shot_damage, config) == 0)
	assert(guard_room.break_score == 0)

	var board := BoardModel.new()
	assert(board.add_block(BlockState.new(30, BlockState.BlockType.NORMAL, Vector2i(0, 0), 1)))
	assert(board.add_block(BlockState.new(31, BlockState.BlockType.NORMAL, Vector2i(1, 0), 1)))
	assert(board.add_block(BlockState.new(32, BlockState.BlockType.NORMAL, Vector2i(2, 0), 1)))
	assert(board.add_block(BlockState.new(33, BlockState.BlockType.ORE, Vector2i(3, 0), 1)))
	assert(board.add_block(BlockState.new(34, BlockState.BlockType.ORE, Vector2i(4, 0), 1)))
	assert(board.add_block(BlockState.new(35, BlockState.BlockType.CORE, Vector2i(6, 8), 1)))

	var room := RoomSession.new()
	room.start(config.shots_per_room, config.bonus_multiplier_bps)
	assert(room.commit_shot())
	var resolution := room.resolve_shot(board, config)
	assert(resolution.processed)
	assert(not resolution.room_finished)
	assert(room.shots_remaining == 2)
	assert(room.commit_shot())

	var first_damage: BlockDamageResult = null
	for block: BlockState in board.blocks:
		var damage := board.resolve_contact(block.id)
		if first_damage == null:
			first_damage = damage
		room.record_damage_result(damage, config)
	assert(first_damage != null)
	assert(room.record_damage_result(first_damage, config) == 0)
	assert(room.break_score == 180)
	resolution = room.resolve_shot(board, config)
	assert(resolution.processed)
	assert(resolution.room_finished)
	assert(resolution.succeeded)
	assert(resolution.remaining_shots == 1)
	assert(resolution.reward == 300)
	var duplicate_resolution := room.resolve_shot(board, config)
	assert(not duplicate_resolution.processed)
	assert(duplicate_resolution.room_finished)
	assert(duplicate_resolution.succeeded)
	assert(room.final_reward == 300)

	var late_result := BlockDamageResult.new()
	late_result.block_id = 999
	late_result.block_type = BlockState.BlockType.NORMAL
	late_result.damage_applied = true
	late_result.destroyed = true
	assert(room.record_damage_result(late_result, config) == 0)
	assert(room.final_reward == 300)

	var last_shot_board := BoardModel.new()
	var last_core := BlockState.new(40, BlockState.BlockType.CORE, Vector2i(4, 8), 1)
	assert(last_shot_board.add_block(last_core))
	var last_shot_room := RoomSession.new()
	last_shot_room.start(1, config.safe_multiplier_bps)
	assert(last_shot_room.commit_shot())
	last_shot_room.record_damage_result(last_shot_board.resolve_contact(last_core.id), config)
	resolution = last_shot_room.resolve_shot(last_shot_board, config)
	assert(resolution.succeeded)
	assert(resolution.reward == config.core_break_points)

	var failed_board := BoardModel.new()
	var failed_normal := BlockState.new(49, BlockState.BlockType.NORMAL, Vector2i(0, 0), 1)
	assert(failed_board.add_block(failed_normal))
	assert(failed_board.add_block(BlockState.new(50, BlockState.BlockType.CORE, Vector2i(4, 8), 2)))
	var failed_room := RoomSession.new()
	failed_room.start(1, config.safe_multiplier_bps)
	assert(failed_room.commit_shot())
	failed_room.record_damage_result(failed_board.resolve_contact(failed_normal.id), config)
	resolution = failed_room.resolve_shot(failed_board, config)
	assert(resolution.room_finished)
	assert(not resolution.succeeded)
	assert(resolution.reward == config.normal_break_points)
