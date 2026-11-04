class_name GameplayRoom
extends Node2D

signal shot_resolved(resolution: RoomResolution)
signal room_finished(resolution: RoomResolution)

const BOARD_ORIGIN := Vector2(30.0, 150.0)
const BOARD_SIZE_WORLD := Vector2(8.0, 10.0)
const WORLD_SCALE := 60.0
const LAUNCHER_WORLD := Vector2(4.0, 0.45)
const FORCED_COLLECTION_EFFECT_SECONDS := 0.35

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
var status_text := "Basılı tut, yönü seç ve bırak."
var forced_collection_positions := PackedVector2Array()
var forced_collection_effect_elapsed: float = 0.0
var run_room_number: int = 1
var run_room_count: int = 1
var banked_score: int = 0


func _ready() -> void:
	config = GameConfig.load_from_file()
	view.bind(self)
	if current_template == null:
		current_template = RoomTemplateLoader.load_from_file(initial_room_template_path)
	if current_template == null or not _start_loaded_room():
		status_text = "Oda şablonu yüklenemedi."
		set_process_unhandled_input(false)
	_refresh_view()


func load_room(template: RoomTemplate) -> bool:
	if template == null:
		push_error("Boş oda şablonu yüklenemez.")
		return false
	var errors := template.validation_errors()
	if not errors.is_empty():
		push_error("Geçersiz oda şablonu:\n- %s" % "\n- ".join(errors))
		return false

	current_template = template
	if not is_node_ready():
		return true
	return _start_loaded_room()


func restart_current_room() -> bool:
	if current_template == null:
		return false
	return _start_loaded_room()


func set_run_context(room_number: int, room_count: int, confirmed_score: int) -> void:
	run_room_number = room_number
	run_room_count = room_count
	banked_score = confirmed_score
	_refresh_view()


func set_input_enabled(enabled: bool) -> void:
	set_process_unhandled_input(enabled)
	if enabled:
		return
	aiming = false
	aim_valid = false
	aim_preview_dirty = false
	aim_preview = AimPreviewResult.new(LAUNCHER_WORLD)
	active_touch_id = -1
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
		status_text = "Oda sona erdi. Devam etmek için sonuç ekranını kullan."
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


func _start_loaded_room() -> bool:
	var loaded_board := current_template.create_board()
	if loaded_board == null:
		push_error("Oda şablonundan oyun tahtası oluşturulamadı: %s" % current_template.room_id)
		return false

	board = loaded_board
	volley = ShotVolley.new()
	room = RoomSession.new()
	room.start(config.shots_per_room, current_template.multiplier_bps)
	aiming = false
	aim_valid = false
	aim_direction = Vector2.UP
	aim_preview_dirty = false
	aim_preview = AimPreviewResult.new(LAUNCHER_WORLD)
	active_touch_id = -1
	forced_collection_positions.clear()
	forced_collection_effect_elapsed = 0.0
	status_text = "Basılı tut, yönü seç ve bırak."
	set_process_unhandled_input(true)
	_refresh_view()
	return true


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
	shot_resolved.emit(resolution)
	if not resolution.room_finished:
		status_text = "Yaylım bitti. Kalan atış: %d" % resolution.remaining_shots
		return

	if resolution.succeeded:
		status_text = "Oda tamamlandı! Ödül: %d" % resolution.reward
	else:
		status_text = "Atışlar bitti. Ödül: %d" % resolution.reward
	room_finished.emit(resolution)


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
