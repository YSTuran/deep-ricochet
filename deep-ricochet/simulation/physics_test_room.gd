class_name PhysicsTestRoom
extends Node2D

const BOARD_ORIGIN := Vector2(30.0, 150.0)
const BOARD_SIZE_WORLD := Vector2(8.0, 10.0)
const WORLD_SCALE := 60.0
const LAUNCHER_WORLD := Vector2(4.0, 0.45)
const FORCED_COLLECTION_EFFECT_SECONDS := 0.35

@onready var view: PhysicsTestRoomView = $View

var config: GameConfig
var simulator := ShotSimulator.new()
var aim_preview_builder := AimPreview.new()
var board := BoardModel.new()
var volley := ShotVolley.new()
var room := RoomSession.new()
var aiming := false
var aim_valid := false
var aim_direction := Vector2.UP
var aim_preview := AimPreviewResult.new()
var aim_preview_dirty := false
var active_touch_id := -1
var status_text := "Basılı tut, yönü seç ve bırak."
var forced_collection_positions := PackedVector2Array()
var forced_collection_effect_elapsed: float = 0.0


func _ready() -> void:
	config = GameConfig.load_from_file()
	view.bind(self)
	_reset_test_room()
	set_process_unhandled_input(true)
	_refresh_view()


func _physics_process(delta: float) -> void:
	if not volley.active:
		return

	var step_result := volley.advance(
		delta,
		simulator,
		BOARD_SIZE_WORLD,
		config.ball_radius,
		board,
	)
	for damage_result: BlockDamageResult in step_result.damage_results:
		_handle_damage_result(damage_result)
	for collision: CollisionResult in step_result.collisions:
		if collision.contact_started and collision.block_type == BlockState.BlockType.ROCK:
			status_text = "Sert kaya topu hasar almadan yansıttı."
	if not step_result.forced_collection_positions.is_empty():
		forced_collection_positions = step_result.forced_collection_positions
		forced_collection_effect_elapsed = 0.0

	if volley.consume_finished_event():
		var resolution := room.resolve_shot(board, config)
		_handle_room_resolution(resolution)
	_refresh_view()


func _process(delta: float) -> void:
	var view_changed := false
	if aim_preview_dirty:
		aim_preview_dirty = false
		if aiming and aim_valid:
			_rebuild_aim_preview()
			view_changed = true
	if not forced_collection_positions.is_empty():
		forced_collection_effect_elapsed += delta
		if forced_collection_effect_elapsed >= FORCED_COLLECTION_EFFECT_SECONDS:
			forced_collection_positions.clear()
		view_changed = true
	if view_changed:
		_refresh_view()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch_id == -1:
			active_touch_id = event.index
			_begin_aim(event.position)
		elif not event.pressed and event.index == active_touch_id:
			active_touch_id = -1
			if event.canceled:
				_cancel_aim()
			else:
				_release_aim()
	elif event is InputEventScreenDrag and event.index == active_touch_id:
		_update_aim(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_aim(event.position)
		else:
			_release_aim()
	elif event is InputEventMouseMotion and aiming:
		_update_aim(event.position)


func _begin_aim(screen_position: Vector2) -> void:
	if room.room_finished:
		_reset_test_room()
		status_text = "Oda yenilendi. Nişan almak için tekrar dokun."
		_refresh_view()
		return
	if volley.active or room.shot_in_progress:
		status_text = "Yaylım sürerken yeni atış yapılamaz."
		_refresh_view()
		return
	aiming = true
	_update_aim(screen_position)


func _update_aim(screen_position: Vector2) -> void:
	if not aiming:
		return

	var target_world := _screen_to_world(screen_position)
	var raw_direction := target_world - LAUNCHER_WORLD
	if raw_direction.length() < config.aim_min_distance:
		aim_valid = false
		aim_preview_dirty = false
		aim_preview = AimPreviewResult.new(LAUNCHER_WORLD)
		status_text = "Nişan için fırlatıcıdan biraz uzaklaş."
		_refresh_view()
		return

	var raw_angle := rad_to_deg(atan2(raw_direction.y, raw_direction.x))
	var clamped_angle := clampf(raw_angle, config.aim_min_degrees, config.aim_max_degrees)
	aim_direction = Vector2.from_angle(deg_to_rad(clamped_angle)).normalized()
	aim_valid = raw_direction.y > 0.0
	status_text = "Açı: %.1f°" % clamped_angle if aim_valid else "Yalnızca yukarı doğru nişan alınabilir."
	if aim_valid:
		aim_preview_dirty = true
	else:
		aim_preview_dirty = false
		aim_preview = AimPreviewResult.new(LAUNCHER_WORLD)
	_refresh_view()


func _release_aim() -> void:
	if not aiming:
		return
	aiming = false
	if aim_valid and room.can_commit_shot():
		var volley_started := volley.start(
			LAUNCHER_WORLD,
			aim_direction * config.ball_speed,
			config.ball_count,
			config.launch_interval_seconds,
			config.volley_limit_seconds,
		)
		if volley_started and room.commit_shot():
			status_text = "8 topluk yaylım başladı."
		else:
			status_text = "Atış başlatılamadı; ayarları kontrol et."
	aim_valid = false
	aim_preview_dirty = false
	aim_preview = AimPreviewResult.new(LAUNCHER_WORLD)
	_refresh_view()


func _cancel_aim() -> void:
	aiming = false
	aim_valid = false
	aim_preview_dirty = false
	aim_preview = AimPreviewResult.new(LAUNCHER_WORLD)
	status_text = "Nişan iptal edildi."
	_refresh_view()


func _reset_test_room() -> void:
	board = BoardModel.new()
	volley = ShotVolley.new()
	room = RoomSession.new()
	_build_test_board()
	room.start(config.shots_per_room, config.safe_multiplier_bps)
	aiming = false
	aim_valid = false
	aim_preview_dirty = false
	aim_preview = AimPreviewResult.new(LAUNCHER_WORLD)
	forced_collection_positions.clear()
	forced_collection_effect_elapsed = 0.0
	status_text = "Basılı tut, yönü seç ve bırak."


func _build_test_board() -> void:
	board.add_block(BlockState.new(1, BlockState.BlockType.NORMAL, Vector2i(1, 7), 4))
	board.add_block(BlockState.new(2, BlockState.BlockType.ORE, Vector2i(3, 7), 4))
	board.add_block(BlockState.new(3, BlockState.BlockType.ROCK, Vector2i(5, 7), 0))
	board.add_block(BlockState.new(4, BlockState.BlockType.CORE, Vector2i(6, 8), 6))


func _rebuild_aim_preview() -> void:
	aim_preview = aim_preview_builder.build_path(
		simulator,
		LAUNCHER_WORLD,
		aim_direction * config.ball_speed,
		BOARD_SIZE_WORLD,
		config.ball_radius,
		board.blocks,
		config.preview_max_solid_bounces,
	)


func _handle_damage_result(result: BlockDamageResult) -> void:
	if not result.contact_valid:
		return
	var block := board.get_block_by_id(result.block_id)
	if block == null or not result.damage_applied:
		return

	var awarded_points := room.record_damage_result(result, config)
	if result.destroyed:
		status_text = "%s kırıldı. +%d puan" % [_block_name(block), awarded_points]
	else:
		status_text = "%s hasar aldı. Kalan can: %d" % [
			_block_name(block),
			result.remaining_hit_points,
		]


func _handle_room_resolution(resolution: RoomResolution) -> void:
	if not resolution.processed:
		return
	if not resolution.room_finished:
		status_text = "Yaylım bitti. Kalan atış: %d" % resolution.remaining_shots
		return

	if resolution.succeeded:
		status_text = "Oda tamamlandı! Ödül: %d • Yeniden başlamak için dokun." % resolution.reward
	else:
		status_text = "Atışlar bitti. Ödül: %d • Yeniden başlamak için dokun." % resolution.reward


func _block_name(block: BlockState) -> String:
	match block.type:
		BlockState.BlockType.NORMAL:
			return "Normal blok"
		BlockState.BlockType.ORE:
			return "Cevher bloğu"
		BlockState.BlockType.ROCK:
			return "Sert kaya"
		BlockState.BlockType.CORE:
			return "Çekirdek"
	return "Blok"


func _screen_to_world(screen_position: Vector2) -> Vector2:
	var local := (screen_position - BOARD_ORIGIN) / WORLD_SCALE
	return Vector2(local.x, BOARD_SIZE_WORLD.y - local.y)


func _refresh_view() -> void:
	if is_instance_valid(view):
		view.refresh()
