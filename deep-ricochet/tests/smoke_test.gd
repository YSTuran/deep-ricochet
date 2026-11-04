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
	assert(main_instance.has_node("GameplayRoom"))
	var gameplay_room: GameplayRoom = main_instance.get_node("GameplayRoom")
	assert(gameplay_room.config != null)
	assert(gameplay_room.view != null)
	assert(gameplay_room.current_template != null)
	assert(gameplay_room.current_template.room_id == &"prototype_room")
	assert(gameplay_room.board.blocks.size() == 4)
	assert(gameplay_room.board.core_count() == 1)
	assert(gameplay_room.room.shots_remaining == config.shots_per_room)
	RoomTemplateTests.run(gameplay_room, config)
	InputFlowTests.run(gameplay_room, config)
	main_instance.queue_free()

	BoardAndCollisionTests.run(config)
	VolleyAndRoomTests.run(config)

	print("[PASS] Deep Ricochet şablon, oynanış odası, fizik, girdi, yaylım ve puan testleri geçti.")
	get_tree().quit()
