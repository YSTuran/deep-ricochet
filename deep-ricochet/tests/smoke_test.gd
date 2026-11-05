extends Node

const MenuPauseTests := preload("res://tests/test_menu_pause.gd")
const ProfileSettingsTests := preload("res://tests/test_profile_settings.gd")


func _ready() -> void:
	var config := GameConfig.load_from_file()
	assert(config.config_version == "prototype-1")
	assert(config.ball_count == 8)
	assert(is_equal_approx(config.ball_speed, 18.0))
	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://app/main.tscn")

	var main_scene: PackedScene = load("res://app/main.tscn")
	var main_instance: RunController = main_scene.instantiate()
	main_instance.persistence_enabled = false
	main_instance.tutorial_enabled = false
	add_child(main_instance)
	await get_tree().process_frame
	assert(main_instance is RunController)
	assert(main_instance.has_node("GameplayRoom"))
	var run_controller: RunController = main_instance
	var gameplay_room: GameplayRoom = run_controller.gameplay_room
	assert(run_controller.catalog != null)
	assert(run_controller.catalog.templates.size() == 12)
	assert(run_controller.run_session == null)
	assert(run_controller.main_menu_view.visible)
	await MenuPauseTests.run(run_controller, self)
	assert(run_controller.run_session != null)
	assert(run_controller.run_session.room_number == 1)
	assert(gameplay_room.current_template.family == RoomTemplate.Family.SAFE)
	RunFlowTests.run(run_controller, config)
	await SaveRecoveryTests.run(run_controller, config, self)
	ProfileSettingsTests.run(run_controller)
	main_instance.queue_free()

	var gameplay_scene: PackedScene = load("res://gameplay/gameplay_room.tscn")
	var standalone_room: GameplayRoom = gameplay_scene.instantiate()
	add_child(standalone_room)
	await get_tree().process_frame
	gameplay_room = standalone_room
	assert(gameplay_room.config != null)
	assert(gameplay_room.view != null)
	assert(gameplay_room.current_template != null)
	assert(gameplay_room.current_template.room_id == &"safe_01")
	assert(gameplay_room.board.core_count() == 1)
	assert(gameplay_room.room.shots_remaining == config.shots_per_room)
	RoomTemplateTests.run(gameplay_room, config)
	InputFlowTests.run(gameplay_room, config)
	standalone_room.queue_free()

	BoardAndCollisionTests.run(config)
	VolleyAndRoomTests.run(config)

	print("[PASS] Deep Ricochet P0 profil, dil, öğretici, ayarlar, kayıt, UI ve fizik testleri geçti.")
	get_tree().quit()
