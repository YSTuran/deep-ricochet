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
	_test_outside_board_does_not_start_aim(gameplay_room, config)
	_test_emulated_mouse_is_ignored(gameplay_room, config)
	_test_cancelled_touch(gameplay_room, config)
	_test_typed_impact_effect(gameplay_room)
	_test_finished_room_does_not_restart(gameplay_room, config)
	_test_room_finished_signal(gameplay_room)


static func _test_outside_board_does_not_start_aim(
	gameplay_room: GameplayRoom,
	config: GameConfig,
) -> void:
	assert(gameplay_room.restart_current_room())
	var press := InputEventScreenTouch.new()
	press.index = 7
	press.position = Vector2(270.0, 80.0)
	press.pressed = true
	gameplay_room._unhandled_input(press)
	assert(not gameplay_room.aiming)
	assert(not gameplay_room.volley.active)

	var release := InputEventScreenTouch.new()
	release.index = 7
	release.position = press.position
	release.pressed = false
	gameplay_room._unhandled_input(release)
	assert(not gameplay_room.volley.active)
	assert(gameplay_room.room.shots_remaining == config.shots_per_room)


static func _test_emulated_mouse_is_ignored(
	gameplay_room: GameplayRoom,
	config: GameConfig,
) -> void:
	assert(gameplay_room.restart_current_room())
	var press := InputEventMouseButton.new()
	press.device = InputEvent.DEVICE_ID_EMULATION
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = VALID_AIM_SCREEN_POSITION
	press.pressed = true
	gameplay_room._unhandled_input(press)
	assert(not gameplay_room.aiming)
	assert(not gameplay_room.volley.active)
	assert(gameplay_room.room.shots_remaining == config.shots_per_room)


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


static func _test_typed_impact_effect(gameplay_room: GameplayRoom) -> void:
	assert(gameplay_room.restart_current_room())
	var target: BlockState = null
	for block: BlockState in gameplay_room.board.blocks:
		if block.type == BlockState.BlockType.NORMAL:
			target = block
			break
	assert(target != null)
	assert(gameplay_room.room.commit_shot())
	var damage := gameplay_room.board.resolve_contact(target.id)
	assert(gameplay_room._handle_damage_result(damage))
	assert(not gameplay_room.impact_effects.is_empty())
	var effect: Dictionary = gameplay_room.impact_effects.back()
	assert(int(effect["block_type"]) == BlockState.BlockType.NORMAL)
	assert(effect.has("points"))


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
