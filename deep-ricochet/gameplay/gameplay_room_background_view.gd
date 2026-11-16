class_name GameplayRoomBackgroundView
extends Node2D

const VIEW_SIZE := Vector2(540.0, 960.0)
const COLOR_GRID := Color("20364a")


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	DeepUI.draw_cave_background(self, VIEW_SIZE)
	DeepUI.draw_panel(
		self,
		Rect2(18.0, 18.0, 504.0, 120.0),
		DeepUI.PANEL_SOFT,
		DeepUI.BORDER,
		15,
		2,
		true,
	)
	DeepUI.draw_panel(
		self,
		Rect2(464.0, 24.0, 54.0, 56.0),
		DeepUI.PANEL_RAISED,
		DeepUI.BORDER,
		11,
		2,
		false,
	)
	DeepUI.draw_panel(
		self,
		Rect2(458.0, 84.0, 60.0, 50.0),
		DeepUI.PANEL_RAISED,
		DeepUI.GOLD_DARK,
		11,
		2,
		false,
	)

	var board_rect := BoardGeometry.SCREEN_RECT
	DeepUI.draw_panel(
		self,
		board_rect.grow(6.0),
		DeepUI.BACKGROUND_DEEP,
		DeepUI.BORDER,
		8,
		3,
		true,
	)
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

	var launcher_screen := BoardGeometry.world_to_screen(BoardGeometry.LAUNCHER_WORLD)
	DeepUI.draw_glow(self, launcher_screen, 12.0, DeepUI.GOLD)
	draw_circle(launcher_screen, 12.0, Color("fff1cf"))
	draw_arc(launcher_screen, 12.0, 0.0, TAU, 32, Color("c9a86a"), 2.0, true)
	DeepUI.draw_panel(
		self,
		Rect2(24.0, 778.0, 492.0, 72.0),
		Color(DeepUI.PANEL_SOFT, 0.94),
		DeepUI.BORDER_SOFT,
		13,
		1,
		false,
	)
	DeepUI.draw_centered(
		self,
		tr("HUD_VOLLEY_HINT"),
		Rect2(34.0, 787.0, 472.0, 26.0),
		15,
		Color("c6d6e4"),
	)
	DeepUI.draw_centered(
		self,
		tr("HUD_AIM_HINT"),
		Rect2(34.0, 817.0, 472.0, 24.0),
		13,
		DeepUI.MUTED_DARK,
	)
