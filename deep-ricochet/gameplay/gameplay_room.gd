class_name GameplayRoom
extends Node2D

signal shot_resolved(resolution: RoomResolution)
signal room_finished(resolution: RoomResolution)
signal shot_will_start
signal block_destroyed(block_type: int)

const BOARD_SIZE_WORLD := Vector2(BoardGeometry.WORLD_GRID_SIZE)
const BOARD_SCREEN_RECT := BoardGeometry.SCREEN_RECT
const LAUNCHER_WORLD := BoardGeometry.LAUNCHER_WORLD
const FORCED_COLLECTION_EFFECT_SECONDS := 0.35
const MAX_IMPACT_EFFECTS := 16

@export_file("*.json") var initial_room_template_path := "res://content/rooms/safe_01.json"

@onready var view: GameplayRoomView = $View

var config: GameConfig
var current_template: RoomTemplate
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
var status_text: String
var forced_collection_positions := PackedVector2Array()
var forced_collection_effect_elapsed: float = 0.0
var impact_effects: Array[Dictionary] = []
var run_room_number: int = 1
var run_room_count: int = 1
var banked_score: int = 0
var simulation_enabled := true
var simulation_speed := 1


func _ready() -> void:
	config = GameConfig.load_from_file()
	view.bind(self)
	status_text = tr("STATUS_AIM")
	if current_template == null:
		current_template = RoomTemplateLoader.load_from_file(initial_room_template_path)
		if current_template == null:
			current_template = RoomTemplateLoader.create_verified_fallback_for_path(
				initial_room_template_path
			)
			if current_template != null:
				push_warning("Başlangıç odası yerine doğrulanmış yedek oda kullanılıyor.")
	if current_template == null or not _start_loaded_room():
		status_text = tr("STATUS_TEMPLATE_FAILED")
		set_process_unhandled_input(false)
	_refresh_view()


func load_room(template: RoomTemplate) -> bool:
	if template == null:
		push_error("Boş oda şablonu yüklenemez.")
		return false
	var errors := template.validation_errors()
	if not errors.is_empty():
		if not RoomTemplateLoader.repair_from_verified_fallback(template):
			push_error("Geçersiz oda şablonu kurtarılamadı:\n- %s" % "\n- ".join(errors))
			return false
		push_warning(
			"Geçersiz oda şablonu doğrulanmış yedek düzenle onarıldı (%s):\n- %s" % [
				template.room_id,
				"\n- ".join(errors),
			]
		)

	if not is_node_ready():
		current_template = template
		return true
	var loaded_board := template.create_board()
	if loaded_board == null:
		push_error("Oda şablonundan oyun tahtası oluşturulamadı: %s" % template.room_id)
		return false
	return _commit_loaded_room(template, loaded_board)


func restart_current_room() -> bool:
	if current_template == null:
		return false
	return _start_loaded_room()


func capture_snapshot() -> RoomSnapshot:
	return RoomSnapshot.capture(current_template, board, room)


func restore_room(template: RoomTemplate, snapshot: RoomSnapshot) -> bool:
	if template == null or snapshot == null or config == null:
		return false
	var errors := snapshot.validation_errors(template, config)
	if not errors.is_empty():
		push_error("Oda snapshot geri yüklenemedi:\n- %s" % "\n- ".join(errors))
		return false
	var restored_board := template.create_board()
	if restored_board == null:
		return false
	for block: BlockState in restored_board.blocks:
		block.hit_points = snapshot.hit_points_for(block.id)
	var restored_room := RoomSession.new()
	if not restored_room.restore_stable_state(
		snapshot.shots_remaining,
		snapshot.break_score,
		snapshot.multiplier_bps,
		snapshot.room_finished,
		snapshot.room_succeeded,
		snapshot.final_reward,
		snapshot.scored_block_ids,
	):
		return false

	current_template = template
	board = restored_board
	room = restored_room
	volley = ShotVolley.new()
	_reset_transient_state()
	status_text = tr("STATUS_RESTORED")
	set_process_unhandled_input(simulation_enabled and not room.room_finished)
	_refresh_view()
	return true


func set_run_context(room_number: int, room_count: int, confirmed_score: int) -> void:
	run_room_number = room_number
	run_room_count = room_count
	banked_score = confirmed_score
	_refresh_view()


func show_status(message: String) -> void:
	status_text = message
	_refresh_view()


func set_input_enabled(enabled: bool) -> void:
	set_process_unhandled_input(enabled and simulation_enabled)
	if enabled:
		return
	cancel_aim_for_pause()


func set_simulation_enabled(enabled: bool) -> void:
	simulation_enabled = enabled
	set_physics_process(enabled)
	set_process(enabled)
	set_process_unhandled_input(enabled and not room.room_finished)
	if not enabled:
		cancel_aim_for_pause()


func trigger_screen_shake(strength: float, duration: float) -> void:
	if is_instance_valid(view):
		view.start_screen_shake(strength, duration)


func set_simulation_speed(speed: int) -> void:
	simulation_speed = 2 if speed >= 2 else 1


func cancel_aim_for_pause() -> void:
	if not aiming and not aim_valid and active_touch_id == -1:
		return
	aiming = false
	aim_valid = false
	aim_preview_dirty = false
	aim_preview = AimPreviewResult.new(LAUNCHER_WORLD)
	active_touch_id = -1
	status_text = tr("STATUS_AIM_CANCELLED")
	_refresh_view()


func _physics_process(delta: float) -> void:
	if not volley.active:
		return

	var static_view_changed := false
	for _step_index in range(simulation_speed):
		if not volley.active:
			break
		static_view_changed = _advance_volley(delta) or static_view_changed
	if static_view_changed:
		_refresh_static_view()
	_refresh_dynamic_view()


func _advance_volley(delta: float) -> bool:
	var step_result := volley.advance(
		delta,
		simulator,
		BOARD_SIZE_WORLD,
		config.ball_radius,
		board,
	)
	var static_view_changed := false
	for damage_result: BlockDamageResult in step_result.damage_results:
		static_view_changed = _handle_damage_result(damage_result) or static_view_changed
	for collision: CollisionResult in step_result.collisions:
		if collision.kind == &"wall" or collision.contact_started:
			AudioManager.play_collision(
				collision.block_type if collision.contact_started else -1,
				collision.position_world.x,
			)
		if collision.contact_started and collision.block_type == BlockState.BlockType.ROCK:
			status_text = tr("STATUS_ROCK_RICOCHET")
			static_view_changed = true
	if not step_result.forced_collection_positions.is_empty():
		forced_collection_positions = step_result.forced_collection_positions
		forced_collection_effect_elapsed = 0.0

	if volley.consume_finished_event():
		var resolution := room.resolve_shot(board, config)
		_handle_room_resolution(resolution)
		static_view_changed = true
	return static_view_changed


func _process(delta: float) -> void:
	var view_changed := false
	if aim_preview_dirty:
		aim_preview_dirty = false
		if aiming and aim_valid:
			_rebuild_aim_preview()
			view_changed = true
	if not forced_collection_positions.is_empty():
		forced_collection_effect_elapsed += delta
		view_changed = true
		if forced_collection_effect_elapsed >= FORCED_COLLECTION_EFFECT_SECONDS:
			forced_collection_positions.clear()
	if not impact_effects.is_empty():
		view_changed = true
	for effect_index in range(impact_effects.size() - 1, -1, -1):
		impact_effects[effect_index]["elapsed"] = float(impact_effects[effect_index]["elapsed"]) + delta
		if float(impact_effects[effect_index]["elapsed"]) >= 0.32:
			impact_effects.remove_at(effect_index)
	if view_changed:
		_refresh_dynamic_view()


func _unhandled_input(event: InputEvent) -> void:
	if DeepUI.is_emulated_mouse_event(event):
		return
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
	if not BOARD_SCREEN_RECT.has_point(screen_position):
		return
	if room.room_finished:
		status_text = tr("STATUS_ROOM_ENDED")
		_refresh_view()
		return
	if volley.active or room.shot_in_progress:
		status_text = tr("STATUS_VOLLEY_ACTIVE")
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
		status_text = tr("STATUS_AIM_FAR")
		_refresh_view()
		return

	var raw_angle := rad_to_deg(atan2(raw_direction.y, raw_direction.x))
	var clamped_angle := clampf(raw_angle, config.aim_min_degrees, config.aim_max_degrees)
	aim_direction = Vector2.from_angle(deg_to_rad(clamped_angle)).normalized()
	aim_valid = raw_direction.y > 0.0
	status_text = tr("STATUS_ANGLE") % clamped_angle if aim_valid else tr("STATUS_UP_ONLY")
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
		if volley_started:
			shot_will_start.emit()
		if volley_started and room.commit_shot():
			AudioManager.begin_volley()
			AudioManager.play_launch()
			status_text = tr("STATUS_VOLLEY_STARTED")
		else:
			volley.reset()
			status_text = tr("STATUS_SHOT_FAILED")
	aim_valid = false
	aim_preview_dirty = false
	aim_preview = AimPreviewResult.new(LAUNCHER_WORLD)
	_refresh_view()


func _cancel_aim() -> void:
	aiming = false
	aim_valid = false
	aim_preview_dirty = false
	aim_preview = AimPreviewResult.new(LAUNCHER_WORLD)
	status_text = tr("STATUS_AIM_CANCELLED")
	_refresh_view()


func _start_loaded_room() -> bool:
	var loaded_board := current_template.create_board()
	if loaded_board == null:
		push_error("Oda şablonundan oyun tahtası oluşturulamadı: %s" % current_template.room_id)
		return false

	return _commit_loaded_room(current_template, loaded_board)


func _commit_loaded_room(template: RoomTemplate, loaded_board: BoardModel) -> bool:
	if template == null or loaded_board == null:
		return false
	current_template = template
	board = loaded_board
	volley = ShotVolley.new()
	room = RoomSession.new()
	room.start(config.shots_per_room, current_template.multiplier_bps)
	_reset_transient_state()
	status_text = tr("STATUS_AIM")
	set_process_unhandled_input(simulation_enabled)
	_refresh_view()
	return true


func _reset_transient_state() -> void:
	aiming = false
	aim_valid = false
	aim_direction = Vector2.UP
	aim_preview_dirty = false
	aim_preview = AimPreviewResult.new(LAUNCHER_WORLD)
	active_touch_id = -1
	forced_collection_positions.clear()
	forced_collection_effect_elapsed = 0.0
	impact_effects.clear()


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


func _handle_damage_result(result: BlockDamageResult) -> bool:
	if not result.contact_valid:
		return false
	var block := board.get_block_by_id(result.block_id)
	if block == null or not result.damage_applied:
		return false

	var awarded_points := room.record_damage_result(result, config)
	if impact_effects.size() >= MAX_IMPACT_EFFECTS:
		impact_effects.pop_front()
	impact_effects.append({
		"position": block.collision_center_world(),
		"block_type": block.type,
		"destroyed": result.destroyed,
		"points": awarded_points,
		"elapsed": 0.0,
	})
	if result.destroyed:
		AudioManager.play_break(block.type)
		block_destroyed.emit(block.type)
		status_text = tr("STATUS_BLOCK_BROKE") % [_block_name(block), awarded_points]
	else:
		status_text = tr("STATUS_BLOCK_DAMAGED") % [
			_block_name(block),
			result.remaining_hit_points,
		]
	return true


func _handle_room_resolution(resolution: RoomResolution) -> void:
	if not resolution.processed:
		return
	shot_resolved.emit(resolution)
	if not resolution.room_finished:
		status_text = tr("STATUS_VOLLEY_ENDED") % resolution.remaining_shots
		return

	if resolution.succeeded:
		status_text = tr("STATUS_ROOM_COMPLETE") % resolution.reward
	else:
		status_text = tr("STATUS_SHOTS_OVER") % resolution.reward
	AudioManager.play_room_result(resolution.succeeded)
	room_finished.emit(resolution)


func _block_name(block: BlockState) -> String:
	match block.type:
		BlockState.BlockType.NORMAL:
			return tr("BLOCK_NORMAL")
		BlockState.BlockType.ORE:
			return tr("BLOCK_ORE")
		BlockState.BlockType.ROCK:
			return tr("BLOCK_ROCK")
		BlockState.BlockType.CORE:
			return tr("BLOCK_CORE")
	return tr("BLOCK_GENERIC")


func refresh_locale() -> void:
	if not volley.active and not room.room_finished:
		status_text = tr("STATUS_AIM")
	_refresh_view()


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return BoardGeometry.screen_to_world(screen_position)


func _refresh_view() -> void:
	if is_instance_valid(view):
		view.refresh()


func _refresh_static_view() -> void:
	if is_instance_valid(view):
		view.refresh_static()


func _refresh_dynamic_view() -> void:
	if is_instance_valid(view):
		view.refresh_dynamic()
