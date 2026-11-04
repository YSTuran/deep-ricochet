class_name InputFlowTests
extends RefCounted

const VALID_AIM_SCREEN_POSITION := Vector2(270.0, 300.0)


class RoomSignalProbe:
	extends RefCounted

	var emission_count := 0
	var last_resolution: RoomResolution

	func capture(resolution: RoomResolution) -> void:
		emission_count += 1
		last_resolution = resolution


static func run(gameplay_room: GameplayRoom, config: GameConfig) -> void:
	_test_cancelled_touch(gameplay_room, config)
	_test_finished_room_does_not_restart(gameplay_room, config)
	_test_room_finished_signal(gameplay_room)


static func _test_cancelled_touch(gameplay_room: GameplayRoom, config: GameConfig) -> void:
	assert(gameplay_room.restart_current_room())
	var press := InputEventScreenTouch.new()
	press.index = 1
	press.position = VALID_AIM_SCREEN_POSITION
	press.pressed = true
	gameplay_room._unhandled_input(press)
	assert(gameplay_room.aiming)
	assert(gameplay_room.aim_valid)

	var cancel := InputEventScreenTouch.new()
	cancel.index = 1
	cancel.position = VALID_AIM_SCREEN_POSITION
	cancel.pressed = false
	cancel.canceled = true
	gameplay_room._unhandled_input(cancel)
	assert(not gameplay_room.aiming)
	assert(not gameplay_room.volley.active)
	assert(gameplay_room.room.shots_remaining == config.shots_per_room)


static func _test_finished_room_does_not_restart(gameplay_room: GameplayRoom, config: GameConfig) -> void:
	assert(gameplay_room.restart_current_room())
	var finished_board := gameplay_room.board
	gameplay_room.room.room_finished = true
	var press := InputEventScreenTouch.new()
	press.index = 2
	press.position = VALID_AIM_SCREEN_POSITION
	press.pressed = true
	gameplay_room._unhandled_input(press)
	assert(not gameplay_room.aiming)
	assert(not gameplay_room.volley.active)
	assert(gameplay_room.board == finished_board)
	assert(gameplay_room.room.room_finished)
	assert(gameplay_room.room.shots_remaining == config.shots_per_room)

	var release := InputEventScreenTouch.new()
	release.index = 2
	release.position = VALID_AIM_SCREEN_POSITION
	release.pressed = false
	gameplay_room._unhandled_input(release)
	assert(not gameplay_room.volley.active)
	assert(gameplay_room.board == finished_board)
	assert(gameplay_room.room.room_finished)


static func _test_room_finished_signal(gameplay_room: GameplayRoom) -> void:
	var probe := RoomSignalProbe.new()
	gameplay_room.room_finished.connect(probe.capture)
	var resolution := RoomResolution.new()
	resolution.processed = true
	resolution.room_finished = true
	resolution.succeeded = true
	resolution.reward = 125
	gameplay_room._handle_room_resolution(resolution)
	assert(probe.emission_count == 1)
	assert(probe.last_resolution == resolution)
	gameplay_room.room_finished.disconnect(probe.capture)
