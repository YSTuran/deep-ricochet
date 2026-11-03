class_name PhysicsTestRoom
extends Node2D

const VIEW_SIZE := Vector2(540.0, 960.0)
const BOARD_ORIGIN := Vector2(30.0, 150.0)
const BOARD_SIZE_WORLD := Vector2(8.0, 10.0)
const WORLD_SCALE := 60.0
const LAUNCHER_WORLD := Vector2(4.0, 0.45)

const COLOR_BACKGROUND := Color("111c2a")
const COLOR_PANEL := Color("17283b")
const COLOR_GRID := Color("23384c")
const COLOR_TEXT := Color("f4f0e6")
const COLOR_AIM := Color("ffe7a8")
const COLOR_ROCK := Color("35414b")
const COLOR_ROCK_LIGHT := Color("52606b")
const COLOR_ROCK_DARK := Color("202a33")

const NORMAL_TEXTURE: Texture2D = preload("res://art/source/blok_normal.png")
const ORE_TEXTURE: Texture2D = preload("res://art/source/blok_cevher.png")
const CORE_TEXTURE: Texture2D = preload("res://art/source/cekirdek.png")

var config: GameConfig
var simulator := ShotSimulator.new()
var board := BoardModel.new()
var ball := BallState.new()
var aiming := false
var aim_valid := false
var aim_direction := Vector2.UP
var aim_preview := PackedVector2Array()
var active_touch_id := -1
var status_text := "Basılı tut, yönü seç ve bırak."


func _ready() -> void:
	config = GameConfig.load_from_file()
	_build_test_board()
	set_process_unhandled_input(true)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not ball.active:
		return

	var collision := simulator.advance_ball(
		ball,
		delta,
		BOARD_SIZE_WORLD,
		config.ball_radius,
		board.blocks,
	)
	if collision.kind == &"collector":
		status_text = "Top toplandı. Yeni atış yapabilirsin."
	elif collision.damage_applied:
		var hit_block := board.get_block_by_id(collision.block_id)
		if hit_block != null:
			if hit_block.is_destroyed():
				status_text = "%s kırıldı." % _block_name(hit_block)
			else:
				status_text = "%s hasar aldı. Kalan can: %d" % [
					_block_name(hit_block),
					hit_block.hit_points,
				]
	elif collision.contact_started and collision.block_type == BlockState.BlockType.ROCK:
		status_text = "Sert kaya topu hasar almadan yansıttı."
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch_id == -1:
			active_touch_id = event.index
			_begin_aim(event.position)
		elif not event.pressed and event.index == active_touch_id:
			active_touch_id = -1
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
	if ball.active:
		status_text = "Top hareket ederken yeni atış yapılamaz."
		queue_redraw()
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
		aim_preview.clear()
		status_text = "Nişan için fırlatıcıdan biraz uzaklaş."
		queue_redraw()
		return

	var raw_angle := rad_to_deg(atan2(raw_direction.y, raw_direction.x))
	var clamped_angle := clampf(raw_angle, config.aim_min_degrees, config.aim_max_degrees)
	aim_direction = Vector2.from_angle(deg_to_rad(clamped_angle)).normalized()
	aim_valid = raw_direction.y > 0.0
	status_text = "Açı: %.1f°" % clamped_angle if aim_valid else "Yalnızca yukarı doğru nişan alınabilir."
	if aim_valid:
		_rebuild_aim_preview()
	else:
		aim_preview.clear()
	queue_redraw()


func _release_aim() -> void:
	if not aiming:
		return
	aiming = false
	if aim_valid and not ball.active:
		ball.launch(LAUNCHER_WORLD, aim_direction * config.ball_speed)
		status_text = "Tek top fizik testi çalışıyor."
	aim_valid = false
	aim_preview.clear()
	queue_redraw()


func _build_test_board() -> void:
	board.add_block(BlockState.new(1, BlockState.BlockType.NORMAL, Vector2i(1, 7), 4))
	board.add_block(BlockState.new(2, BlockState.BlockType.ORE, Vector2i(3, 7), 4))
	board.add_block(BlockState.new(3, BlockState.BlockType.ROCK, Vector2i(5, 7), 0))
	board.add_block(BlockState.new(4, BlockState.BlockType.CORE, Vector2i(6, 8), 6))


func _rebuild_aim_preview() -> void:
	aim_preview = simulator.build_preview_path(
		LAUNCHER_WORLD,
		aim_direction * config.ball_speed,
		BOARD_SIZE_WORLD,
		config.ball_radius,
		board.blocks,
		config.preview_max_solid_bounces,
	)


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


func _world_to_screen(world_position: Vector2) -> Vector2:
	return BOARD_ORIGIN + Vector2(
		world_position.x * WORLD_SCALE,
		(BOARD_SIZE_WORLD.y - world_position.y) * WORLD_SCALE,
	)


func _screen_to_world(screen_position: Vector2) -> Vector2:
	var local := (screen_position - BOARD_ORIGIN) / WORLD_SCALE
	return Vector2(local.x, BOARD_SIZE_WORLD.y - local.y)


func _world_rect_to_screen(world_rect: Rect2, margin: float = 4.0) -> Rect2:
	var top_left := _world_to_screen(world_rect.position + Vector2(0.0, world_rect.size.y))
	var size := world_rect.size * WORLD_SCALE
	return Rect2(top_left + Vector2.ONE * margin, size - Vector2.ONE * margin * 2.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), COLOR_BACKGROUND)
	draw_rect(Rect2(Vector2(18.0, 18.0), Vector2(504.0, 104.0)), COLOR_PANEL, true)
	_draw_text(Vector2(30.0, 52.0), "DEEP RICOCHET", 28, COLOR_TEXT)
	_draw_text(Vector2(30.0, 84.0), "Aşama A • Fizik test odası", 18, Color("9fb4c8"))
	_draw_text(Vector2(30.0, 112.0), status_text, 16, COLOR_TEXT)

	var board_rect := Rect2(BOARD_ORIGIN, BOARD_SIZE_WORLD * WORLD_SCALE)
	draw_rect(board_rect, Color("0b1724"), true)
	draw_rect(board_rect, Color("40546a"), false, 4.0)
	for x in range(1, 8):
		var screen_x := BOARD_ORIGIN.x + float(x) * WORLD_SCALE
		draw_line(Vector2(screen_x, BOARD_ORIGIN.y), Vector2(screen_x, BOARD_ORIGIN.y + board_rect.size.y), COLOR_GRID, 1.0)
	for y in range(1, 10):
		var screen_y := BOARD_ORIGIN.y + float(y) * WORLD_SCALE
		draw_line(Vector2(BOARD_ORIGIN.x, screen_y), Vector2(BOARD_ORIGIN.x + board_rect.size.x, screen_y), COLOR_GRID, 1.0)

	for block: BlockState in board.blocks:
		if block.is_destroyed():
			continue
		match block.type:
			BlockState.BlockType.NORMAL:
				_draw_texture_block(
					block.world_rect(),
					NORMAL_TEXTURE,
					Rect2(139.0, 159.0, 976.0, 939.0),
					str(block.hit_points),
				)
			BlockState.BlockType.ORE:
				_draw_texture_block(
					block.world_rect(),
					ORE_TEXTURE,
					Rect2(209.0, 220.0, 837.0, 831.0),
					str(block.hit_points),
				)
			BlockState.BlockType.ROCK:
				_draw_hard_rock(block.world_rect())
			BlockState.BlockType.CORE:
				_draw_core(block.collision_center_world(), str(block.hit_points))

	var launcher_screen := _world_to_screen(LAUNCHER_WORLD)
	draw_circle(launcher_screen, 12.0, Color("fff1cf"))
	draw_arc(launcher_screen, 12.0, 0.0, TAU, 32, Color("c9a86a"), 2.0, true)

	if aiming and aim_valid and aim_preview.size() > 1:
		for point_index in range(aim_preview.size() - 1):
			draw_dashed_line(
				_world_to_screen(aim_preview[point_index]),
				_world_to_screen(aim_preview[point_index + 1]),
				COLOR_AIM,
				3.0,
				10.0,
				true,
				true,
			)

	if ball.active:
		var ball_screen := _world_to_screen(ball.position_world)
		draw_circle(ball_screen, maxf(5.0, config.ball_radius * WORLD_SCALE), COLOR_TEXT)
		draw_arc(ball_screen, maxf(5.0, config.ball_radius * WORLD_SCALE), 0.0, TAU, 20, Color("d6bc8c"), 1.5, true)

	_draw_text(Vector2(30.0, 790.0), "Bloklar artık fizik simülasyonunun parçası.", 17, Color("c6d6e4"))
	_draw_text(Vector2(30.0, 820.0), "Kesikli çizgi gerçek atışla aynı simülatörü kullanır.", 15, Color("839bb0"))


func _draw_texture_block(
	world_rect: Rect2,
	texture: Texture2D,
	source_rect: Rect2,
	hp_text: String,
) -> void:
	var destination := _world_rect_to_screen(world_rect, 4.0)
	draw_texture_rect_region(texture, destination, source_rect)
	_draw_centered_text(destination, hp_text, 26, COLOR_TEXT, 0.66)


func _draw_core(center_world: Vector2, hp_text: String) -> void:
	var center_screen := _world_to_screen(center_world)
	var destination := Rect2(center_screen - Vector2.ONE * 39.0, Vector2.ONE * 78.0)
	draw_texture_rect(CORE_TEXTURE, destination, false)
	_draw_centered_text(destination, hp_text, 26, COLOR_TEXT, 0.64)


func _draw_hard_rock(world_rect: Rect2) -> void:
	var rect := _world_rect_to_screen(world_rect, 5.0)
	var cut := 7.0
	var points := PackedVector2Array([
		rect.position + Vector2(cut, 0.0),
		rect.position + Vector2(rect.size.x - cut, 0.0),
		rect.position + Vector2(rect.size.x, cut),
		rect.end - Vector2(0.0, cut),
		rect.end - Vector2(cut, 0.0),
		rect.position + Vector2(cut, rect.size.y),
		rect.position + Vector2(0.0, rect.size.y - cut),
		rect.position + Vector2(0.0, cut),
	])
	draw_colored_polygon(points, COLOR_ROCK)
	draw_polyline(points + PackedVector2Array([points[0]]), COLOR_ROCK_DARK, 4.0, true)
	draw_colored_polygon(PackedVector2Array([
		points[0], points[1], rect.position + Vector2(rect.size.x * 0.62, rect.size.y * 0.34),
	]), COLOR_ROCK_LIGHT)
	draw_colored_polygon(PackedVector2Array([
		points[4], points[5], rect.position + Vector2(rect.size.x * 0.42, rect.size.y * 0.66),
	]), COLOR_ROCK_DARK)
	var inset := 15.0
	var a := rect.position + Vector2(inset, inset)
	var b := rect.end - Vector2(inset, inset)
	var c := Vector2(rect.end.x - inset, rect.position.y + inset)
	var d := Vector2(rect.position.x + inset, rect.end.y - inset)
	draw_line(a, b, Color("111820"), 10.0, true)
	draw_line(c, d, Color("111820"), 10.0, true)
	draw_line(a, b, Color("c5cbd0"), 5.0, true)
	draw_line(c, d, Color("c5cbd0"), 5.0, true)


func _draw_text(position: Vector2, text: String, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _draw_centered_text(rect: Rect2, text: String, size: int, color: Color, baseline_ratio: float) -> void:
	draw_string(
		ThemeDB.fallback_font,
		Vector2(rect.position.x, rect.position.y + rect.size.y * baseline_ratio),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		size,
		color,
	)
