extends Node


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
	main_instance.queue_free()

	var board := BoardModel.new()
	assert(board.add_block(BlockState.new(1, BlockState.BlockType.ROCK, Vector2i(2, 2), 0)))
	assert(not board.blocks[0].is_breakable())
	assert(not board.blocks[0].apply_damage())
	assert(board.add_block(BlockState.new(2, BlockState.BlockType.CORE, Vector2i(4, 6), 6)))
	assert(board.core_count() == 1)

	var ball := BallState.new()
	ball.launch(Vector2(7.8, 5.0), Vector2(config.ball_speed, 0.0))
	var simulator := ShotSimulator.new()
	var collision := simulator.advance_ball(ball, 0.02, Vector2(8.0, 10.0), config.ball_radius)
	assert(collision.kind == &"wall")
	assert(ball.velocity_world.x < 0.0)

	ball.launch(Vector2(4.0, 0.01), Vector2(0.0, -config.ball_speed))
	collision = simulator.advance_ball(ball, 0.02, Vector2(8.0, 10.0), config.ball_radius)
	assert(collision.kind == &"collector")
	assert(not ball.active)

	var normal_block := BlockState.new(10, BlockState.BlockType.NORMAL, Vector2i(2, 4), 3)
	var normal_blocks: Array[BlockState] = [normal_block]
	ball.launch(Vector2(1.5, 4.5), Vector2(10.0, 0.0))
	collision = simulator.advance_ball(ball, 0.1, Vector2(8.0, 10.0), config.ball_radius, normal_blocks)
	assert(collision.kind == &"block")
	assert(collision.block_id == normal_block.id)
	assert(collision.damage_applied)
	assert(normal_block.hit_points == 2)
	assert(ball.velocity_world.x < 0.0)

	var ore_block := BlockState.new(11, BlockState.BlockType.ORE, Vector2i(2, 2), 2)
	var ore_blocks: Array[BlockState] = [ore_block]
	ball.launch(Vector2(2.5, 1.5), Vector2(0.0, 10.0))
	collision = simulator.advance_ball(ball, 0.1, Vector2(8.0, 10.0), config.ball_radius, ore_blocks)
	assert(collision.kind == &"block")
	assert(collision.damage_applied)
	assert(ore_block.hit_points == 1)
	assert(ball.velocity_world.y < 0.0)

	var rock_block := BlockState.new(12, BlockState.BlockType.ROCK, Vector2i(4, 4), 0)
	var rock_blocks: Array[BlockState] = [rock_block]
	ball.launch(Vector2(3.5, 4.5), Vector2(10.0, 0.0))
	collision = simulator.advance_ball(ball, 0.1, Vector2(8.0, 10.0), config.ball_radius, rock_blocks)
	assert(collision.kind == &"block")
	assert(collision.block_type == BlockState.BlockType.ROCK)
	assert(not collision.damage_applied)
	assert(ball.velocity_world.x < 0.0)

	var core_block := BlockState.new(13, BlockState.BlockType.CORE, Vector2i(5, 6), 2)
	var core_blocks: Array[BlockState] = [core_block]
	ball.launch(Vector2(4.5, 6.5), Vector2(10.0, 0.0))
	collision = simulator.advance_ball(ball, 0.1, Vector2(8.0, 10.0), config.ball_radius, core_blocks)
	assert(collision.kind == &"block")
	assert(collision.block_type == BlockState.BlockType.CORE)
	assert(collision.damage_applied)
	assert(core_block.hit_points == 1)

	var missed_core := BlockState.new(14, BlockState.BlockType.CORE, Vector2i(5, 6), 2)
	var missed_core_blocks: Array[BlockState] = [missed_core]
	ball.launch(Vector2(4.0, 5.94), Vector2(10.0, 0.0))
	collision = simulator.advance_ball(ball, 0.25, Vector2(8.0, 10.0), config.ball_radius, missed_core_blocks)
	assert(collision.kind == &"none")
	assert(missed_core.hit_points == 2)

	var guarded_block := BlockState.new(15, BlockState.BlockType.NORMAL, Vector2i(2, 4), 3)
	var guarded_blocks: Array[BlockState] = [guarded_block]
	ball.launch(Vector2(1.93, 4.5), Vector2(10.0, 0.0))
	ball.active_contacts[guarded_block.id] = true
	collision = simulator.advance_ball(ball, 0.02, Vector2(8.0, 10.0), config.ball_radius, guarded_blocks)
	assert(collision.kind == &"block")
	assert(not collision.damage_applied)
	assert(guarded_block.hit_points == 3)

	var preview_block := BlockState.new(16, BlockState.BlockType.NORMAL, Vector2i(3, 3), 3)
	var preview_blocks: Array[BlockState] = [preview_block]
	var preview_origin := Vector2(2.0, 3.5)
	var preview_velocity := Vector2(10.0, 0.0)
	var preview := simulator.build_preview_path(
		preview_origin,
		preview_velocity,
		Vector2(8.0, 10.0),
		config.ball_radius,
		preview_blocks,
		1,
	)
	assert(preview.size() == 2)
	ball.launch(preview_origin, preview_velocity)
	collision = simulator.advance_ball(ball, 0.2, Vector2(8.0, 10.0), config.ball_radius, preview_blocks)
	assert(collision.kind == &"block")
	assert(preview[1].is_equal_approx(collision.position_world))

	print("[PASS] Deep Ricochet hareket, blok çarpışması ve önizleme testleri geçti.")
	get_tree().quit()
