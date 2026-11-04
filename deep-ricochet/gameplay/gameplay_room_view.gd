class_name GameplayRoomView
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

var room: GameplayRoom


func bind(gameplay_room: GameplayRoom) -> void:
	room = gameplay_room
	queue_redraw()


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if room == null or room.config == null or room.current_template == null:
		return

	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), COLOR_BACKGROUND)
	draw_rect(Rect2(Vector2(18.0, 18.0), Vector2(504.0, 104.0)), COLOR_PANEL, true)
	_draw_text(Vector2(30.0, 52.0), "DEEP RICOCHET • %s" % room.current_template.display_name, 24, COLOR_TEXT)
	_draw_text(
		Vector2(30.0, 84.0),
		"Oda %d/%d • Toplam %d • Oda %d • Atış %d/%d • ×%.1f" % [
			room.run_room_number,
			room.run_room_count,
			room.banked_score,
			room.room.break_score,
			room.room.shots_remaining,
			room.config.shots_per_room,
			float(room.room.multiplier_bps) / 10_000.0,
		],
		14,
		Color("9fb4c8"),
	)
	_draw_text(Vector2(30.0, 112.0), room.status_text, 16, COLOR_TEXT)

	var board_rect := Rect2(BOARD_ORIGIN, BOARD_SIZE_WORLD * WORLD_SCALE)
	draw_rect(board_rect, Color("0b1724"), true)
	draw_rect(board_rect, Color("40546a"), false, 4.0)
	for x in range(1, 8):
		var screen_x := BOARD_ORIGIN.x + float(x) * WORLD_SCALE
		draw_line(
			Vector2(screen_x, BOARD_ORIGIN.y),
			Vector2(screen_x, BOARD_ORIGIN.y + board_rect.size.y),
			COLOR_GRID,
			1.0,
		)
	for y in range(1, 10):
		var screen_y := BOARD_ORIGIN.y + float(y) * WORLD_SCALE
		draw_line(
			Vector2(BOARD_ORIGIN.x, screen_y),
			Vector2(BOARD_ORIGIN.x + board_rect.size.x, screen_y),
			COLOR_GRID,
			1.0,
		)

	for block: BlockState in room.board.blocks:
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

	if room.aiming and room.aim_valid and room.aim_preview.points.size() > 1:
		for point_index in range(room.aim_preview.points.size() - 1):
			draw_dashed_line(
				_world_to_screen(room.aim_preview.points[point_index]),
				_world_to_screen(room.aim_preview.points[point_index + 1]),
				COLOR_AIM,
				3.0,
				10.0,
				true,
				true,
			)
		if room.aim_preview.has_terminal_contact:
			var contact_screen := _world_to_screen(room.aim_preview.contact_position_world)
			draw_circle(contact_screen, 7.0, Color("ffcf66"))
			draw_arc(contact_screen, 10.0, 0.0, TAU, 20, COLOR_TEXT, 2.0, true)

	for volley_ball: BallState in room.volley.balls:
		if not volley_ball.active:
			continue
		var ball_screen := _world_to_screen(volley_ball.position_world)
		draw_circle(ball_screen, maxf(5.0, room.config.ball_radius * WORLD_SCALE), COLOR_TEXT)
		draw_arc(
			ball_screen,
			maxf(5.0, room.config.ball_radius * WORLD_SCALE),
			0.0,
			TAU,
			20,
			Color("d6bc8c"),
			1.5,
			true,
		)

	_draw_forced_collection_effect()
	_draw_text(Vector2(30.0, 790.0), "Her geçerli atışta 8 top, 0,08 sn arayla çıkar.", 17, Color("c6d6e4"))
	_draw_text(Vector2(30.0, 820.0), "Sarı işaret ilk kırılabilir temas noktasını gösterir.", 15, Color("839bb0"))


func _draw_forced_collection_effect() -> void:
	if room.forced_collection_positions.is_empty():
		return
	var progress := clampf(
		room.forced_collection_effect_elapsed / room.FORCED_COLLECTION_EFFECT_SECONDS,
		0.0,
		1.0,
	)
	var eased_progress := ease(progress, 2.0)
	for start_world: Vector2 in room.forced_collection_positions:
		var effect_world := start_world.lerp(LAUNCHER_WORLD, eased_progress)
		var effect_color := Color(COLOR_TEXT, 1.0 - progress * 0.65)
		draw_circle(_world_to_screen(effect_world), 5.0, effect_color)


func _world_to_screen(world_position: Vector2) -> Vector2:
	return BOARD_ORIGIN + Vector2(
		world_position.x * WORLD_SCALE,
		(BOARD_SIZE_WORLD.y - world_position.y) * WORLD_SCALE,
	)


func _world_rect_to_screen(world_rect: Rect2, margin: float = 4.0) -> Rect2:
	var top_left := _world_to_screen(world_rect.position + Vector2(0.0, world_rect.size.y))
	var size := world_rect.size * WORLD_SCALE
	return Rect2(top_left + Vector2.ONE * margin, size - Vector2.ONE * margin * 2.0)


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
