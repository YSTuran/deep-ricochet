class_name InputFlowTests
extends RefCounted

const VALID_AIM_SCREEN_POSITION := Vector2(270.0, 300.0)


static func run(test_room: PhysicsTestRoom, config: GameConfig) -> void:
	_test_cancelled_touch(test_room, config)
	_test_restart_touch_is_consumed(test_room, config)


static func _test_cancelled_touch(test_room: PhysicsTestRoom, config: GameConfig) -> void:
	test_room._reset_test_room()
	var press := InputEventScreenTouch.new()
	press.index = 1
	press.position = VALID_AIM_SCREEN_POSITION
	press.pressed = true
	test_room._unhandled_input(press)
	assert(test_room.aiming)
	assert(test_room.aim_valid)

	var cancel := InputEventScreenTouch.new()
	cancel.index = 1
	cancel.position = VALID_AIM_SCREEN_POSITION
	cancel.pressed = false
	cancel.canceled = true
	test_room._unhandled_input(cancel)
	assert(not test_room.aiming)
	assert(not test_room.volley.active)
	assert(test_room.room.shots_remaining == config.shots_per_room)


static func _test_restart_touch_is_consumed(test_room: PhysicsTestRoom, config: GameConfig) -> void:
	test_room.room.room_finished = true
	var press := InputEventScreenTouch.new()
	press.index = 2
	press.position = VALID_AIM_SCREEN_POSITION
	press.pressed = true
	test_room._unhandled_input(press)
	assert(not test_room.aiming)
	assert(not test_room.volley.active)
	assert(test_room.room.shots_remaining == config.shots_per_room)

	var release := InputEventScreenTouch.new()
	release.index = 2
	release.position = VALID_AIM_SCREEN_POSITION
	release.pressed = false
	test_room._unhandled_input(release)
	assert(not test_room.volley.active)
	assert(test_room.room.shots_remaining == config.shots_per_room)
