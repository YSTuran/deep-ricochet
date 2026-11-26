class_name BoardAndCollisionTests
extends RefCounted

const BOARD_SIZE := Vector2(BoardGeometry.WORLD_GRID_SIZE)


static func run(config: GameConfig) -> void:
	_test_shared_geometry()
	_test_board_contract()
	_test_collision_and_damage(config)
	_test_repeated_contact(config)
	_test_corner_collision(config)
	_test_preview_contract(config)
	_test_special_blocks()
	_test_acid_barrel()


static func _test_shared_geometry() -> void:
	assert(BoardModel.ROOM_GRID_SIZE == BoardGeometry.BLOCK_GRID_SIZE)
	assert(BoardModel.CORE_TARGET_ROW == BoardGeometry.CORE_ROW)
	assert(BoardModel.CORE_MIN_TARGET_ROW == BoardGeometry.CORE_MIN_ROW)
	assert(BoardGeometry.WORLD_GRID_SIZE.x == BoardGeometry.BLOCK_GRID_SIZE.x)
	assert(BoardGeometry.WORLD_GRID_SIZE.y == BoardGeometry.BLOCK_GRID_SIZE.y + 2)
	assert(BoardGeometry.CORE_ROW == BoardGeometry.BLOCK_GRID_SIZE.y)
	assert(BoardGeometry.CORE_MIN_ROW == BoardGeometry.BLOCK_GRID_SIZE.y - 2)
	assert(BoardGeometry.preview_row_for_cell(0) == BoardGeometry.WORLD_GRID_SIZE.y - 1)
	assert(BoardGeometry.preview_row_for_cell(BoardGeometry.CORE_ROW) == 1)
	var sample_world := Vector2(3.25, 7.5)
	assert(
		BoardGeometry.screen_to_world(BoardGeometry.world_to_screen(sample_world))
		.is_equal_approx(sample_world)
	)


static func _test_board_contract() -> void:
	var board := BoardModel.new()
	assert(board.add_block(BlockState.new(1, BlockState.BlockType.ROCK, Vector2i(2, 7), 0)))
	assert(not board.add_block(BlockState.new(2, BlockState.BlockType.NORMAL, Vector2i(2, 8), 2)))
	assert(board.add_block(BlockState.new(3, BlockState.BlockType.CORE, Vector2i(4, 8), 6)))
	assert(not board.add_block(BlockState.new(4, BlockState.BlockType.CORE, Vector2i(6, 8), 6)))
	var lower_core_board := BoardModel.new()
	assert(lower_core_board.add_block(BlockState.new(5, BlockState.BlockType.CORE, Vector2i(1, 6), 6)))
	assert(not BoardModel.new().add_block(BlockState.new(6, BlockState.BlockType.CORE, Vector2i(1, 5), 6)))
	assert(board.core_count() == 1)
	assert(not board.is_core_destroyed())


static func _test_collision_and_damage(config: GameConfig) -> void:
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
	collision = simulator.advance_ball(ball, 0.1, BOARD_SIZE, config.ball_radius, normal_board.blocks)
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

	var square_core_board := BoardModel.new()
	var square_core := BlockState.new(14, BlockState.BlockType.CORE, Vector2i(5, 8), 2)
	assert(square_core_board.add_block(square_core))
	ball.launch(Vector2(4.0, 7.94), Vector2(10.0, 0.0))
	collision = simulator.advance_ball(ball, 0.25, BOARD_SIZE, config.ball_radius, square_core_board.blocks)
	assert(collision.kind == &"block")
	assert(collision.block_id == square_core.id)
	assert(collision.block_contacts.size() == 1)
	assert(ball.velocity_world.x < 0.0)
	damage = square_core_board.resolve_contact(collision.block_contacts[0].block_id)
	assert(damage.damage_applied)
	assert(square_core.hit_points == 1)

	var guarded_board := BoardModel.new()
	var guarded_block := BlockState.new(15, BlockState.BlockType.NORMAL, Vector2i(2, 4), 3)
	assert(guarded_board.add_block(guarded_block))
	ball.launch(Vector2(1.93, 4.5), Vector2(10.0, 0.0))
	ball.active_contacts[guarded_block.id] = true
	collision = simulator.advance_ball(ball, 0.02, BOARD_SIZE, config.ball_radius, guarded_board.blocks)
	assert(collision.kind == &"block")
	assert(collision.block_contacts.is_empty())
	assert(guarded_block.hit_points == 3)


static func _test_repeated_contact(config: GameConfig) -> void:
	var simulator := ShotSimulator.new()
	var board := BoardModel.new()
	var block := BlockState.new(16, BlockState.BlockType.NORMAL, Vector2i(3, 3), 3)
	assert(board.add_block(block))
	var ball := BallState.new()
	ball.launch(Vector2(2.0, 3.5), Vector2(10.0, 0.0))
	var damage_count := 0
	for tick in range(240):
		var collision := simulator.advance_ball(
			ball,
			1.0 / 120.0,
			BOARD_SIZE,
			config.ball_radius,
			board.blocks,
		)
		for contact: BlockContactEvent in collision.block_contacts:
			if board.resolve_contact(contact.block_id).damage_applied:
				damage_count += 1
		if damage_count >= 2:
			break
	assert(damage_count == 2)
	assert(block.hit_points == 1)


static func _test_corner_collision(config: GameConfig) -> void:
	var simulator := ShotSimulator.new()
	var board := BoardModel.new()
	assert(board.add_block(BlockState.new(17, BlockState.BlockType.ROCK, Vector2i(3, 3), 0)))
	var ball := BallState.new()
	ball.launch(Vector2(2.0, 2.0), Vector2(18.0, 18.0))
	var collision := simulator.advance_ball(ball, 0.1, BOARD_SIZE, config.ball_radius, board.blocks)
	assert(collision.block_contacts.size() == 1)
	assert(ball.velocity_world.x < 0.0)
	assert(ball.velocity_world.y < 0.0)


static func _test_preview_contract(config: GameConfig) -> void:
	var simulator := ShotSimulator.new()
	var preview_builder := AimPreview.new()
	var board := BoardModel.new()
	var preview_block := BlockState.new(20, BlockState.BlockType.NORMAL, Vector2i(3, 3), 3)
	assert(board.add_block(preview_block))
	var origin := Vector2(2.0, 3.5)
	var velocity := Vector2(10.0, 0.0)
	var preview := preview_builder.build_path(
		simulator,
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
	var collision := simulator.advance_ball(real_ball, 0.2, BOARD_SIZE, config.ball_radius, board.blocks)
	assert(collision.block_contacts.size() == 1)
	assert(preview.contact_position_world.distance_to(collision.block_contacts[0].position_world) <= 0.1)

	var core_preview_board := BoardModel.new()
	var preview_core := BlockState.new(24, BlockState.BlockType.CORE, Vector2i(5, 8), 2)
	assert(core_preview_board.add_block(preview_core))
	var core_preview := preview_builder.build_path(
		simulator,
		Vector2(4.0, 7.94),
		Vector2(10.0, 0.0),
		BOARD_SIZE,
		config.ball_radius,
		core_preview_board.blocks,
		2,
	)
	assert(core_preview.has_terminal_contact)
	assert(core_preview.contact_block_id == preview_core.id)

	var rock_board := BoardModel.new()
	assert(rock_board.add_block(BlockState.new(21, BlockState.BlockType.ROCK, Vector2i(3, 3), 0)))
	var rock_preview := preview_builder.build_path(
		simulator,
		origin,
		velocity,
		BOARD_SIZE,
		config.ball_radius,
		rock_board.blocks,
		2,
	)
	assert(not rock_preview.has_terminal_contact)
	assert(rock_preview.points.size() == 3)

	var closed_armor_board := BoardModel.new()
	assert(closed_armor_board.add_block(BlockState.new(
		22,
		BlockState.BlockType.ARMORED,
		Vector2i(3, 3),
		4,
		BlockState.VulnerableSide.BOTTOM,
	)))
	var closed_armor_preview := preview_builder.build_path(
		simulator,
		origin,
		velocity,
		BOARD_SIZE,
		config.ball_radius,
		closed_armor_board.blocks,
		2,
	)
	assert(not closed_armor_preview.has_terminal_contact)
	assert(closed_armor_preview.points.size() == 3)

	var open_armor_board := BoardModel.new()
	assert(open_armor_board.add_block(BlockState.new(
		23,
		BlockState.BlockType.ARMORED,
		Vector2i(3, 3),
		4,
		BlockState.VulnerableSide.LEFT,
	)))
	var open_armor_preview := preview_builder.build_path(
		simulator,
		origin,
		velocity,
		BOARD_SIZE,
		config.ball_radius,
		open_armor_board.blocks,
		2,
	)
	assert(open_armor_preview.has_terminal_contact)
	assert(open_armor_preview.contact_block_id == 23)


static func _test_special_blocks() -> void:
	var armored := BlockState.new(
		60,
		BlockState.BlockType.ARMORED,
		Vector2i(1, 1),
		4,
		BlockState.VulnerableSide.LEFT | BlockState.VulnerableSide.BOTTOM,
	)
	var armor_board := BoardModel.new()
	assert(armor_board.add_block(armored))
	var blocked := armor_board.resolve_contact(armored.id, 1, Vector2.RIGHT)
	assert(blocked.contact_valid)
	assert(blocked.blocked_by_armor)
	assert(not blocked.damage_applied)
	assert(armored.hit_points == 4)
	var exposed := armor_board.resolve_contact(armored.id, 1, Vector2.LEFT)
	assert(exposed.damage_applied)
	assert(not exposed.blocked_by_armor)
	assert(armored.hit_points == 3)

	var board := BoardModel.new()
	var source := BlockState.new(70, BlockState.BlockType.EXPLOSIVE, Vector2i(3, 3), 1)
	var chain := BlockState.new(71, BlockState.BlockType.EXPLOSIVE, Vector2i(4, 3), 2)
	var cracked := BlockState.new(72, BlockState.BlockType.CRACKED, Vector2i(2, 2), 8)
	var blast_armor := BlockState.new(
		73,
		BlockState.BlockType.ARMORED,
		Vector2i(2, 3),
		5,
		BlockState.VulnerableSide.TOP,
	)
	var overlap_target := BlockState.new(74, BlockState.BlockType.NORMAL, Vector2i(3, 4), 5)
	var chain_only_target := BlockState.new(75, BlockState.BlockType.NORMAL, Vector2i(5, 3), 5)
	var hard_rock := BlockState.new(76, BlockState.BlockType.ROCK, Vector2i(3, 2), 0)
	var radius_two_target := BlockState.new(77, BlockState.BlockType.NORMAL, Vector2i(1, 1), 5)
	var outside_target := BlockState.new(78, BlockState.BlockType.NORMAL, Vector2i(0, 0), 5)
	for block: BlockState in [
		source,
		chain,
		cracked,
		blast_armor,
		overlap_target,
		chain_only_target,
		hard_rock,
		radius_two_target,
		outside_target,
	]:
		assert(board.add_block(block))
	var source_damage := board.resolve_contact(source.id, 1, Vector2.LEFT)
	assert(source_damage.destroyed)
	assert(not source_damage.is_explosion)
	var explosion_results := board.resolve_explosion(source.id)
	assert(not explosion_results.is_empty())
	for result: BlockDamageResult in explosion_results:
		assert(result.is_explosion)
	assert(chain.is_destroyed())
	assert(not cracked.is_destroyed())
	assert(cracked.hit_points == 2)
	assert(blast_armor.is_destroyed())
	assert(overlap_target.is_destroyed())
	assert(chain_only_target.is_destroyed())
	assert(hard_rock.hit_points == 0)
	assert(radius_two_target.hit_points == 2)
	assert(outside_target.hit_points == 5)

	var echo_board := BoardModel.new()
	var echo_source := BlockState.new(80, BlockState.BlockType.ECHO, Vector2i(1, 3), 2)
	var echo_target := BlockState.new(81, BlockState.BlockType.ECHO, Vector2i(5, 4), 2)
	assert(echo_board.add_block(echo_source))
	assert(echo_board.add_block(echo_target))
	var echo_contact := echo_board.resolve_contact(echo_source.id, 1, Vector2.LEFT)
	assert(echo_contact.damage_applied)
	var echo_results := echo_board.resolve_echo(echo_source.id)
	assert(echo_results.size() == 1)
	assert(echo_results[0].is_echo)
	assert(echo_target.hit_points == 1)

	var piercing_board := BoardModel.new()
	var piercing := BlockState.new(
		90,
		BlockState.BlockType.PIERCING,
		Vector2i(0, 3),
		1,
		BlockState.ALL_VULNERABLE_SIDES,
		BlockState.BeamDirection.RIGHT,
	)
	var beam_target := BlockState.new(91, BlockState.BlockType.NORMAL, Vector2i(2, 3), 3)
	var beam_rock := BlockState.new(92, BlockState.BlockType.ROCK, Vector2i(3, 3), 0)
	var beam_armor := BlockState.new(
		93,
		BlockState.BlockType.ARMORED,
		Vector2i(4, 3),
		3,
		BlockState.VulnerableSide.LEFT,
	)
	var outside_beam := BlockState.new(94, BlockState.BlockType.NORMAL, Vector2i(2, 4), 3)
	for block: BlockState in [piercing, beam_target, beam_rock, beam_armor, outside_beam]:
		assert(piercing_board.add_block(block))
	assert(piercing_board.resolve_contact(piercing.id).destroyed)
	var piercing_results := piercing_board.resolve_piercing(piercing.id)
	assert(piercing_results.size() == 2)
	for result: BlockDamageResult in piercing_results:
		assert(result.is_piercing)
		assert(result.piercing_direction == BlockState.BeamDirection.RIGHT)
	assert(beam_target.hit_points == 1)
	assert(beam_rock.hit_points == 0)
	assert(beam_armor.hit_points == 1)
	assert(outside_beam.hit_points == 3)


static func _test_acid_barrel() -> void:
	var board := BoardModel.new()
	var barrel := BlockState.new(100, BlockState.BlockType.ACID_BARREL, Vector2i(3, 4), 1)
	var close := BlockState.new(101, BlockState.BlockType.NORMAL, Vector2i(4, 4), 8)
	var middle := BlockState.new(102, BlockState.BlockType.ORE, Vector2i(5, 4), 5)
	var far := BlockState.new(103, BlockState.BlockType.NORMAL, Vector2i(6, 4), 5)
	var outside := BlockState.new(104, BlockState.BlockType.NORMAL, Vector2i(7, 4), 5)
	var rock := BlockState.new(105, BlockState.BlockType.ROCK, Vector2i(3, 6), 0)
	var armor := BlockState.new(
		106, BlockState.BlockType.ARMORED, Vector2i(2, 4), 5, BlockState.VulnerableSide.TOP,
	)
	for block: BlockState in [barrel, close, middle, far, outside, rock, armor]:
		assert(board.add_block(block))
	assert(board.resolve_acid_burst(barrel.id).is_empty())
	assert(board.resolve_contact(barrel.id, 1, Vector2.LEFT).destroyed)
	var results := board.resolve_acid_burst(barrel.id)
	assert(results.size() == 4)
	for result: BlockDamageResult in results:
		assert(result.is_acid)
	assert(close.hit_points == 3)
	assert(middle.hit_points == 2)
	assert(far.hit_points == 4)
	assert(outside.hit_points == 5)
	assert(rock.hit_points == 0)
	assert(armor.hit_points == 4)

	var chain_board := BoardModel.new()
	var first_barrel := BlockState.new(110, BlockState.BlockType.ACID_BARREL, Vector2i(3, 4), 1)
	var second_barrel := BlockState.new(111, BlockState.BlockType.ACID_BARREL, Vector2i(4, 4), 5)
	var chain_target := BlockState.new(112, BlockState.BlockType.NORMAL, Vector2i(5, 4), 8)
	for block: BlockState in [first_barrel, second_barrel, chain_target]:
		assert(chain_board.add_block(block))
	var first_result := chain_board.resolve_contact(first_barrel.id, 1, Vector2.LEFT)
	assert(first_result.destroyed)
	var step_result := VolleyStepResult.new()
	ShotVolley.new()._append_destroy_effects(chain_board, [first_result], step_result)
	assert(second_barrel.is_destroyed())
	assert(chain_target.is_destroyed())
	assert(step_result.damage_results.size() == 3)
