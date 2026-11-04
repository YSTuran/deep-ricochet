class_name RoomTemplateTests
extends RefCounted

const SAFE_ROOM_PATH := "res://content/rooms/safe_01.json"


static func run(gameplay_room: GameplayRoom, config: GameConfig) -> void:
	_test_template_load_and_board_isolation()
	_test_invalid_template_rejected()
	_test_gameplay_room_accepts_external_template(gameplay_room, config)


static func _test_template_load_and_board_isolation() -> void:
	var template := RoomTemplateLoader.load_from_file(SAFE_ROOM_PATH)
	assert(template != null)
	assert(template.is_valid())
	assert(template.room_id == &"safe_01")
	assert(template.family == RoomTemplate.Family.SAFE)
	assert(template.passage_columns.size() == 2)

	var first_board := template.create_board()
	var second_board := template.create_board()
	assert(first_board != null)
	assert(second_board != null)
	assert(first_board != second_board)
	assert(first_board.get_block_by_id(101).hit_points == 2)
	first_board.resolve_contact(101)
	assert(first_board.get_block_by_id(101).hit_points == 1)
	assert(second_board.get_block_by_id(101).hit_points == 2)


static func _test_invalid_template_rejected() -> void:
	var invalid := RoomTemplate.new()
	invalid.room_id = &"invalid_room"
	invalid.display_name = "Geçersiz Oda"
	invalid.content_version = "test"
	invalid.multiplier_bps = 10_000
	invalid.passage_columns = PackedInt32Array([3, 4])
	invalid.example_angles = PackedFloat32Array([90.0])
	invalid.blocks.append(RoomBlockDefinition.new(1, BlockState.BlockType.NORMAL, Vector2i(0, 8), 0))
	invalid.blocks.append(RoomBlockDefinition.new(1, BlockState.BlockType.CORE, Vector2i(0, 7), 3))
	assert(not invalid.is_valid())
	assert(invalid.validation_errors().size() >= 4)
	assert(invalid.create_board() == null)

	var unknown_type := RoomTemplateLoader.from_dictionary({
		"schemaVersion": 1,
		"id": "unknown_type",
		"displayName": "Bilinmeyen Tür",
		"family": "safe",
		"contentVersion": "test",
		"width": 8,
		"height": 8,
		"multiplierBps": 10_000,
		"passageColumns": [3, 4],
		"exampleAngles": [90.0],
		"blocks": [
			{"id": 1, "type": "mystery", "cell": [0, 0], "hitPoints": 2},
			{"id": 2, "type": "core", "cell": [4, 8], "hitPoints": 6},
		],
	})
	assert(not unknown_type.is_valid())


static func _test_gameplay_room_accepts_external_template(
	gameplay_room: GameplayRoom,
	config: GameConfig,
) -> void:
	var bonus_template := RoomTemplateLoader.from_dictionary({
		"schemaVersion": 1,
		"id": "bonus_test_room",
		"displayName": "Bonus Test Odası",
		"family": "bonus",
		"contentVersion": "test",
		"width": 8,
		"height": 8,
		"multiplierBps": config.bonus_multiplier_bps,
		"passageColumns": [4],
		"exampleAngles": [86.5],
		"blocks": [
			{"id": 101, "type": "rock", "cell": [2, 5], "hitPoints": 0},
			{"id": 102, "type": "core", "cell": [4, 8], "hitPoints": 6},
		],
	})
	assert(gameplay_room.load_room(bonus_template))
	assert(gameplay_room.current_template == bonus_template)
	assert(gameplay_room.board.blocks.size() == 2)
	assert(gameplay_room.room.multiplier_bps == config.bonus_multiplier_bps)
	assert(gameplay_room.room.shots_remaining == config.shots_per_room)

	var safe_room := RoomTemplateLoader.load_from_file(SAFE_ROOM_PATH)
	assert(gameplay_room.load_room(safe_room))
