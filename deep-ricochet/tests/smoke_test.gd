extends Node

const BOARD_SIZE := Vector2(8.0, 10.0)


func _ready() -> void:
	var config := GameConfig.load_from_file()
	assert(config.config_version == "prototype-1")
	assert(config.ball_count == 8)
	assert(is_equal_approx(config.ball_speed, 18.0))
	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://app/main.tscn")

	var main_scene: PackedScene = load("res://app/main.tscn")
	var main_instance := main_scene.instantiate()
	add_child(main_instance)
	await get_tree().process_frame
	assert(main_instance.has_node("PhysicsTestRoom"))
	var test_room: PhysicsTestRoom = main_instance.get_node("PhysicsTestRoom")
	assert(test_room.config != null)
	assert(test_room.board.blocks.size() == 4)
	assert(test_room.board.core_count() == 1)
	assert(test_room.room.shots_remaining == config.shots_per_room)
	main_instance.queue_free()

	_test_board_contract()
	_test_collision_and_damage(config)
	_test_preview_contract(config)
	_test_volley_lifecycle(config)
	_test_scoring_and_room_resolution(config)

	print("[PASS] Deep Ricochet fizik, yaylım, puan ve oda sonucu testleri geçti.")
	get_tree().quit()


func _test_board_contract() -> void:
	var board := BoardModel.new()
	assert(board.add_block(BlockState.new(1, BlockState.BlockType.ROCK, Vector2i(2, 7), 0)))
	assert(not board.add_block(BlockState.new(2, BlockState.BlockType.NORMAL, Vector2i(2, 8), 2)))
	assert(board.add_block(BlockState.new(3, BlockState.BlockType.CORE, Vector2i(4, 8), 6)))
	assert(not board.add_block(BlockState.new(4, BlockState.BlockType.CORE, Vector2i(6, 8), 6)))
	assert(board.core_count() == 1)
	assert(not board.is_core_destroyed())


func _test_collision_and_damage(config: GameConfig) -> void:
	var simulator := ShotSimulator.new()
	var ball := BallState.new()

	ball.launch(Vector2(7.8, 5.0), Vector2(config.ball_speed, 0.0))
	var collision := simulator.advance_ball(ball, 0.02, BOARD_SIZE, config.ball_radius)
	assert(collision.kind == &"wall")
	assert(ball.velocity_world.x < 0.0)

	ball.launch(Vector2(4.0, 0.01), Vector2(0.0, -config.ball_speed))
	collision = simulator.advance_ball(ball, 0.02, BOARD_SIZE, config.ball_radius)
	assert(collision.kind == &"collector")
	assert(not ball.active)

	var normal_board := BoardModel.new()
	var normal_block := BlockState.new(10, BlockState.BlockType.NORMAL, Vector2i(2, 4), 3)
	assert(normal_board.add_block(normal_block))
	ball.launch(Vector2(1.5, 4.5), Vector2(10.0, 0.0))
	collision = simulator.advance_ball(
		ball,
		0.1,
		BOARD_SIZE,
		config.ball_radius,
		normal_board.blocks,
	)
	assert(collision.kind == &"block")
	assert(collision.block_contacts.size() == 1)
	assert(normal_block.hit_points == 3)
	var damage := normal_board.resolve_contact(collision.block_contacts[0].block_id)
	assert(damage.damage_applied)
	assert(not damage.destroyed)
	assert(normal_block.hit_points == 2)
	assert(ball.velocity_world.x < 0.0)

	var ore_board := BoardModel.new()
	var ore_block := BlockState.new(11, BlockState.BlockType.ORE, Vector2i(2, 2), 2)
	assert(ore_board.add_block(ore_block))
	ball.launch(Vector2(2.5, 1.5), Vector2(0.0, 10.0))
	collision = simulator.advance_ball(ball, 0.1, BOARD_SIZE, config.ball_radius, ore_board.blocks)
	assert(collision.block_contacts.size() == 1)
	damage = ore_board.resolve_contact(collision.block_contacts[0].block_id)
	assert(damage.damage_applied)
	assert(ore_block.hit_points == 1)
	assert(ball.velocity_world.y < 0.0)

	var rock_board := BoardModel.new()
	var rock_block := BlockState.new(12, BlockState.BlockType.ROCK, Vector2i(4, 4), 0)
	assert(rock_board.add_block(rock_block))
	ball.launch(Vector2(3.5, 4.5), Vector2(10.0, 0.0))
	collision = simulator.advance_ball(ball, 0.1, BOARD_SIZE, config.ball_radius, rock_board.blocks)
	assert(collision.block_contacts.size() == 1)
	damage = rock_board.resolve_contact(collision.block_contacts[0].block_id)
	assert(damage.contact_valid)
	assert(not damage.damage_applied)
	assert(ball.velocity_world.x < 0.0)

	var core_board := BoardModel.new()
	var core_block := BlockState.new(13, BlockState.BlockType.CORE, Vector2i(5, 8), 2)
	assert(core_board.add_block(core_block))
	ball.launch(Vector2(4.5, 8.5), Vector2(10.0, 0.0))
	collision = simulator.advance_ball(ball, 0.1, BOARD_SIZE, config.ball_radius, core_board.blocks)
	assert(collision.block_contacts.size() == 1)
	damage = core_board.resolve_contact(collision.block_contacts[0].block_id)
	assert(damage.damage_applied)
	assert(core_block.hit_points == 1)

	var missed_core_board := BoardModel.new()
	var missed_core := BlockState.new(14, BlockState.BlockType.CORE, Vector2i(5, 8), 2)
	assert(missed_core_board.add_block(missed_core))
	ball.launch(Vector2(4.0, 7.94), Vector2(10.0, 0.0))
	collision = simulator.advance_ball(
		ball,
		0.25,
		BOARD_SIZE,
		config.ball_radius,
		missed_core_board.blocks,
	)
	assert(collision.kind == &"none")
	assert(missed_core.hit_points == 2)

	var guarded_board := BoardModel.new()
	var guarded_block := BlockState.new(15, BlockState.BlockType.NORMAL, Vector2i(2, 4), 3)
	assert(guarded_board.add_block(guarded_block))
	ball.launch(Vector2(1.93, 4.5), Vector2(10.0, 0.0))
	ball.active_contacts[guarded_block.id] = true
	collision = simulator.advance_ball(
		ball,
		0.02,
		BOARD_SIZE,
		config.ball_radius,
		guarded_board.blocks,
	)
	assert(collision.kind == &"block")
	assert(collision.block_contacts.is_empty())
	assert(guarded_block.hit_points == 3)


func _test_preview_contract(config: GameConfig) -> void:
	var simulator := ShotSimulator.new()
	var board := BoardModel.new()
	var preview_block := BlockState.new(20, BlockState.BlockType.NORMAL, Vector2i(3, 3), 3)
	assert(board.add_block(preview_block))
	var origin := Vector2(2.0, 3.5)
	var velocity := Vector2(10.0, 0.0)
	var preview := simulator.build_preview_path(
		origin,
		velocity,
		BOARD_SIZE,
		config.ball_radius,
		board.blocks,
		2,
	)
	assert(preview.has_terminal_contact)
	assert(preview.contact_block_id == preview_block.id)
	assert(preview.points.size() == 2)
	assert(preview_block.hit_points == 3)

	var real_ball := BallState.new()
	real_ball.launch(origin, velocity)
	var collision := simulator.advance_ball(
		real_ball,
		0.2,
		BOARD_SIZE,
		config.ball_radius,
		board.blocks,
	)
	assert(collision.block_contacts.size() == 1)
	assert(preview.contact_position_world.distance_to(collision.block_contacts[0].position_world) <= 0.1)

	var rock_board := BoardModel.new()
	assert(rock_board.add_block(BlockState.new(21, BlockState.BlockType.ROCK, Vector2i(3, 3), 0)))
	var rock_preview := simulator.build_preview_path(
		origin,
		velocity,
		BOARD_SIZE,
		config.ball_radius,
		rock_board.blocks,
		2,
	)
	assert(not rock_preview.has_terminal_contact)
	assert(rock_preview.points.size() == 3)


func _test_volley_lifecycle(config: GameConfig) -> void:
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

	var timeout_volley := ShotVolley.new()
	assert(timeout_volley.start(Vector2(4.0, 5.0), Vector2.RIGHT, 2, 0.08, 0.2))
	timeout_volley.advance(0.2, simulator, BOARD_SIZE, config.ball_radius, BoardModel.new())
	assert(not timeout_volley.active)
	assert(timeout_volley.forced_collection_count == 2)
	assert(timeout_volley.consume_finished_event())


func _test_scoring_and_room_resolution(config: GameConfig) -> void:
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
