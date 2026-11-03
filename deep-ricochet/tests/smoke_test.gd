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
	assert(main_instance.get_node("PhysicsTestRoom").config != null)
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

	print("[PASS] Deep Ricochet temel smoke testleri geçti.")
	get_tree().quit()
