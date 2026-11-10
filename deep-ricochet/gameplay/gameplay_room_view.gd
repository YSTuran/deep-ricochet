class_name GameplayRoomView
extends Node2D

const VIEW_SIZE := Vector2(540.0, 960.0)

const COLOR_GRID := Color("20364a")
const COLOR_ROCK := Color("35414b")
const COLOR_ROCK_LIGHT := Color("52606b")
const COLOR_ROCK_DARK := Color("202a33")

const NORMAL_TEXTURE: Texture2D = preload("res://art/source/blok_normal.png")
const ORE_TEXTURE: Texture2D = preload("res://art/source/blok_cevher.png")
const CORE_TEXTURE: Texture2D = preload("res://art/source/cekirdek.png")

var room: GameplayRoom
@onready var dynamic_layer: GameplayRoomDynamicView = $Dynamic
var shake_remaining := 0.0
var shake_duration := 0.0
var shake_strength := 0.0


func bind(gameplay_room: GameplayRoom) -> void:
	room = gameplay_room
	dynamic_layer.bind(gameplay_room)
	queue_redraw()


func refresh() -> void:
	queue_redraw()
	dynamic_layer.queue_redraw()


func refresh_static() -> void:
	queue_redraw()


func refresh_dynamic() -> void:
	dynamic_layer.queue_redraw()


func start_screen_shake(strength: float, duration: float) -> void:
	shake_strength = maxf(shake_strength, maxf(0.0, strength))
	shake_duration = maxf(shake_duration, maxf(0.01, duration))
	shake_remaining = maxf(shake_remaining, shake_duration)
	set_process(true)


func _process(delta: float) -> void:
	if shake_remaining <= 0.0:
		position = Vector2.ZERO
		set_process(false)
		return
	shake_remaining = maxf(0.0, shake_remaining - delta)
	var progress := 1.0 - shake_remaining / shake_duration
	var amplitude := shake_strength * (1.0 - progress)
	position = Vector2(
		sin(progress * 52.0 * TAU),
		sin(progress * 37.0 * TAU + 0.8),
	) * amplitude
	if shake_remaining <= 0.0:
		position = Vector2.ZERO


func _draw() -> void:
	if room == null or room.config == null or room.current_template == null:
		return

	DeepUI.draw_cave_background(self, VIEW_SIZE)
	DeepUI.draw_panel(self, Rect2(18.0, 18.0, 504.0, 112.0), DeepUI.PANEL_SOFT, DeepUI.BORDER, 15, 2, true)
	_draw_text(
		Vector2(30.0, 48.0),
		tr("HUD_TITLE") % room.current_template.localized_display_name(),
		20,
		DeepUI.TEXT,
	)
	DeepUI.draw_chip(
		self,
		Rect2(30.0, 58.0, 94.0, 28.0),
		tr("HUD_ROOM_CHIP") % [room.run_room_number, room.run_room_count],
		DeepUI.BLUE,
		12,
	)
	DeepUI.draw_chip(
		self,
		Rect2(130.0, 58.0, 116.0, 28.0),
		tr("HUD_SCORE_CHIP") % room.banked_score,
		DeepUI.BORDER,
		12,
	)
	DeepUI.draw_chip(
		self,
		Rect2(252.0, 58.0, 116.0, 28.0),
		tr("HUD_ROOM_SCORE_CHIP") % room.room.break_score,
		DeepUI.BLUE,
		12,
	)
	DeepUI.draw_chip(
		self,
		Rect2(374.0, 58.0, 74.0, 28.0),
		"×%.1f" % (float(room.room.multiplier_bps) / 10_000.0),
		DeepUI.GOLD,
		13,
	)
	DeepUI.draw_chip(
		self,
		Rect2(30.0, 92.0, 116.0, 28.0),
		tr("HUD_SHOTS_CHIP") % [room.room.shots_remaining, room.config.shots_per_room],
		DeepUI.GOLD,
		12,
	)
	DeepUI.draw_panel(self, Rect2(464.0, 24.0, 54.0, 56.0), DeepUI.PANEL_RAISED, DeepUI.BORDER, 11, 2, false)
	DeepUI.draw_centered(self, room.status_text, Rect2(152.0, 92.0, 296.0, 28.0), 12, DeepUI.MUTED)

	var board_rect := BoardGeometry.SCREEN_RECT
	DeepUI.draw_panel(self, board_rect.grow(6.0), DeepUI.BACKGROUND_DEEP, DeepUI.BORDER, 8, 3, true)
	draw_rect(board_rect, Color("0a1724"), true)
	for x in range(1, BoardGeometry.WORLD_GRID_SIZE.x):
		var screen_x := BoardGeometry.SCREEN_ORIGIN.x + float(x) * BoardGeometry.WORLD_SCALE
		draw_line(
			Vector2(screen_x, BoardGeometry.SCREEN_ORIGIN.y),
			Vector2(screen_x, BoardGeometry.SCREEN_ORIGIN.y + board_rect.size.y),
			COLOR_GRID,
			1.0,
		)
	for y in range(1, BoardGeometry.WORLD_GRID_SIZE.y):
		var screen_y := BoardGeometry.SCREEN_ORIGIN.y + float(y) * BoardGeometry.WORLD_SCALE
		draw_line(
			Vector2(BoardGeometry.SCREEN_ORIGIN.x, screen_y),
			Vector2(BoardGeometry.SCREEN_ORIGIN.x + board_rect.size.x, screen_y),
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

	var launcher_screen := BoardGeometry.world_to_screen(BoardGeometry.LAUNCHER_WORLD)
	DeepUI.draw_glow(self, launcher_screen, 12.0, DeepUI.GOLD)
	draw_circle(launcher_screen, 12.0, Color("fff1cf"))
	draw_arc(launcher_screen, 12.0, 0.0, TAU, 32, Color("c9a86a"), 2.0, true)
	DeepUI.draw_panel(self, Rect2(24.0, 778.0, 492.0, 72.0), Color(DeepUI.PANEL_SOFT, 0.94), DeepUI.BORDER_SOFT, 13, 1, false)
	DeepUI.draw_centered(self, tr("HUD_VOLLEY_HINT"), Rect2(34.0, 787.0, 472.0, 26.0), 15, Color("c6d6e4"))
	DeepUI.draw_centered(self, tr("HUD_AIM_HINT"), Rect2(34.0, 817.0, 472.0, 24.0), 13, DeepUI.MUTED_DARK)


func _world_rect_to_screen(world_rect: Rect2, margin: float = 4.0) -> Rect2:
	return BoardGeometry.world_rect_to_screen(world_rect, margin)


func _draw_texture_block(
	world_rect: Rect2,
	texture: Texture2D,
	source_rect: Rect2,
	hp_text: String,
) -> void:
	var destination := _world_rect_to_screen(world_rect, 4.0)
	draw_texture_rect_region(texture, destination, source_rect)
	_draw_centered_text(destination, hp_text, 26, DeepUI.TEXT, 0.66)


func _draw_core(center_world: Vector2, hp_text: String) -> void:
	var center_screen := BoardGeometry.world_to_screen(center_world)
	var destination := Rect2(center_screen - Vector2.ONE * 39.0, Vector2.ONE * 78.0)
	draw_texture_rect(CORE_TEXTURE, destination, false)
	_draw_centered_text(destination, hp_text, 26, DeepUI.TEXT, 0.64)


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
	DeepUI.draw_text(self, text, position, size, color)


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
