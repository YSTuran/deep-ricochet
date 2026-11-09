class_name RunFlowView
extends Control

enum Screen {
	GAMEPLAY,
	ROUTE_SELECTION,
	RUN_RESULT,
}

const VIEW_SIZE := Vector2(540.0, 960.0)
const SAFE_CARD := Rect2(24.0, 150.0, 492.0, 290.0)
const BONUS_CARD := Rect2(24.0, 465.0, 492.0, 290.0)
const RESTART_BUTTON := Rect2(90.0, 665.0, 360.0, 70.0)
const RESULT_MENU_BUTTON := Rect2(90.0, 755.0, 360.0, 70.0)
const CORE_TEXTURE: Texture2D = preload("res://art/source/cekirdek.png")
const PREVIEW_COLUMNS := 8
const PREVIEW_ROWS := 10
const PREVIEW_CELL_SIZE := 15.5

var controller: RunController
var run_session: RunSession
var profile: PlayerProfile
var new_best := false
var screen: Screen = Screen.GAMEPLAY


func bind(run_controller: RunController) -> void:
	controller = run_controller


func show_gameplay() -> void:
	screen = Screen.GAMEPLAY
	run_session = null
	profile = null
	new_best = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_route_selection(session: RunSession) -> void:
	screen = Screen.ROUTE_SELECTION
	run_session = session
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func show_run_result(
	session: RunSession,
	current_profile: PlayerProfile = null,
	is_new_best: bool = false,
) -> void:
	screen = Screen.RUN_RESULT
	run_session = session
	profile = current_profile
	new_best = is_new_best
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if DeepUI.is_emulated_mouse_event(event):
		return
	var released := false
	var event_position := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		released = not event.pressed
		event_position = event.position
	elif event is InputEventScreenTouch:
		accept_event()
		released = not event.pressed and not event.canceled
		event_position = event.position
	if not released or controller == null or run_session == null:
		return

	if screen == Screen.ROUTE_SELECTION:
		var card_rects := [SAFE_CARD, BONUS_CARD]
		for option_index in range(mini(card_rects.size(), run_session.pending_routes.size())):
			if card_rects[option_index].has_point(event_position):
				controller.select_route(run_session.pending_routes[option_index].option_id)
				return
	elif screen == Screen.RUN_RESULT:
		if RESTART_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			controller.start_new_run()
		elif RESULT_MENU_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			controller.show_main_menu_from_result()


func _draw() -> void:
	if screen == Screen.GAMEPLAY or run_session == null:
		return
	DeepUI.draw_cave_background(self, VIEW_SIZE)
	if screen == Screen.ROUTE_SELECTION:
		_draw_route_selection()
	else:
		_draw_run_result()


func _draw_route_selection() -> void:
	DeepUI.draw_title_plate(self, tr("ROUTE_SELECT"), Rect2(78.0, 26.0, 384.0, 62.0), 30, DeepUI.GOLD)
	_draw_centered(
		tr("ROUTE_SUMMARY") % [
			run_session.room_number,
			run_session.last_room_reward,
			run_session.banked_score,
			run_session.room_number + 1,
			run_session.room_count,
		],
		Rect2(20.0, 82.0, 500.0, 32.0),
		16,
		DeepUI.MUTED,
	)
	var card_rects := [SAFE_CARD, BONUS_CARD]
	for option_index in range(mini(card_rects.size(), run_session.pending_routes.size())):
		_draw_route_card(
			card_rects[option_index],
			run_session.pending_routes[option_index],
		)
	_draw_centered(
		tr("ROUTE_HINT"),
		Rect2(20.0, 805.0, 500.0, 34.0),
		15,
		DeepUI.MUTED,
	)


func _draw_route_card(rect: Rect2, option: RouteOption) -> void:
	var is_safe := option.template.family == RoomTemplate.Family.SAFE
	var accent := DeepUI.BLUE if is_safe else DeepUI.GOLD
	var fill := Color("102a40") if is_safe else Color("382c1d")
	DeepUI.draw_panel(self, rect, fill, accent, 18, 3, true)
	_draw_text(option.title(), rect.position + Vector2(18.0, 34.0), 23, DeepUI.TEXT)
	DeepUI.draw_chip(
		self,
		Rect2(rect.end.x - 92.0, rect.position.y + 14.0, 72.0, 34.0),
		"×%.1f" % (float(option.template.multiplier_bps) / 10_000.0),
		accent,
		17,
	)
	_draw_centered(
		option.template.localized_display_name(),
		Rect2(rect.position + Vector2(150.0, 42.0), Vector2(192.0, 26.0)),
		14,
		DeepUI.MUTED,
	)
	var preview_size := Vector2(PREVIEW_COLUMNS, PREVIEW_ROWS) * PREVIEW_CELL_SIZE
	var preview_origin := rect.position + Vector2(
		(rect.size.x - preview_size.x) * 0.5,
		76.0,
	)
	_draw_template_preview(option.template, preview_origin, PREVIEW_CELL_SIZE)
	DeepUI.draw_button(
		self,
		Rect2(rect.position + Vector2(120.0, 244.0), Vector2(252.0, 34.0)),
		tr("ROUTE_TAP"),
		&"safe" if is_safe else &"primary",
		15,
	)


func _draw_template_preview(template: RoomTemplate, origin: Vector2, cell_size: float) -> void:
	var grid_rect := Rect2(
		origin,
		Vector2(PREVIEW_COLUMNS, PREVIEW_ROWS) * cell_size,
	)
	DeepUI.draw_panel(self, grid_rect.grow(6.0), DeepUI.BACKGROUND_DEEP, DeepUI.BORDER_SOFT, 10, 2, false)
	for column in range(1, PREVIEW_COLUMNS):
		var offset_x := float(column) * cell_size
		draw_line(origin + Vector2(offset_x, 0.0), origin + Vector2(offset_x, grid_rect.size.y), DeepUI.BORDER_SOFT)
	for row in range(1, PREVIEW_ROWS):
		var offset_y := float(row) * cell_size
		draw_line(origin + Vector2(0.0, offset_y), origin + Vector2(grid_rect.size.x, offset_y), DeepUI.BORDER_SOFT)
	for definition: RoomBlockDefinition in template.blocks:
		var preview_row := clampi(
			PREVIEW_ROWS - 1 - definition.cell.y,
			0,
			PREVIEW_ROWS - 1,
		)
		var center := origin + Vector2(
			(float(definition.cell.x) + 0.5) * cell_size,
			(float(preview_row) + 0.5) * cell_size,
		)
		if definition.block_type == BlockState.BlockType.CORE:
			DeepUI.draw_glow(self, center, cell_size * 0.32, DeepUI.CORE)
			draw_circle(center, cell_size * 0.36, DeepUI.CORE)
			_draw_mini_value(center, str(definition.hit_points), cell_size, DeepUI.BACKGROUND_DEEP)
			continue
		var color := DeepUI.BLUE
		var value := str(definition.hit_points)
		if definition.block_type == BlockState.BlockType.ORE:
			color = DeepUI.GOLD
		elif definition.block_type == BlockState.BlockType.ROCK:
			color = Color("35414b")
			value = "×"
		var block_rect := Rect2(center - Vector2.ONE * cell_size * 0.4, Vector2.ONE * cell_size * 0.8)
		DeepUI.draw_panel(self, block_rect, color, Color(color).lightened(0.18), 4, 1, false)
		_draw_mini_value(center, value, cell_size, DeepUI.TEXT)


func _draw_run_result() -> void:
	var heading := tr("RESULT_SUCCESS") if run_session.succeeded else tr("RESULT_FAILURE")
	var accent := DeepUI.CORE if run_session.succeeded else DeepUI.GOLD
	DeepUI.draw_glow(self, Vector2(270.0, 108.0), 48.0, accent)
	draw_texture_rect(CORE_TEXTURE, Rect2(216.0, 54.0, 108.0, 108.0), false, Color.WHITE if run_session.succeeded else Color(0.72, 0.72, 0.72, 0.7))
	DeepUI.draw_title_plate(self, heading, Rect2(58.0, 170.0, 424.0, 68.0), 31, accent)
	DeepUI.draw_panel(self, Rect2(45.0, 250.0, 450.0, 385.0), DeepUI.PANEL_SOFT, Color(accent, 0.72), 18, 2, true)
	_draw_centered(
		tr("RESULT_REACHED") % [run_session.room_number, run_session.cores_broken],
		Rect2(65.0, 272.0, 410.0, 36.0),
		21,
		DeepUI.TEXT,
	)
	_draw_centered(
		tr("RESULT_TOTAL_SCORE"),
		Rect2(65.0, 313.0, 410.0, 28.0),
		17,
		DeepUI.MUTED,
	)
	_draw_centered(
		str(run_session.banked_score),
		Rect2(65.0, 344.0, 410.0, 62.0),
		46,
		accent,
	)
	for result_index in range(run_session.room_results.size()):
		var result := run_session.room_results[result_index]
		_draw_centered(
			tr("RESULT_ROOM_BREAKDOWN") % [
				result.room_number,
				result.break_score,
				result.unused_shot_bonus,
				float(result.multiplier_bps) / 10_000.0,
				result.reward,
			],
			Rect2(65.0, 420.0 + float(result_index) * 32.0, 410.0, 28.0),
			14,
			DeepUI.MUTED,
		)
	if profile != null:
		var best_label := tr("RESULT_NEW_BEST") if new_best else tr("RESULT_BEST") % profile.best_score
		DeepUI.draw_chip(self, Rect2(135.0, 580.0, 270.0, 38.0), best_label, accent, 17)
	DeepUI.draw_button(self, RESTART_BUTTON, tr("RESULT_REPLAY"), &"core" if run_session.succeeded else &"primary", 24)
	DeepUI.draw_button(self, RESULT_MENU_BUTTON, tr("RESULT_MAIN_MENU"), &"secondary", 22)


func _draw_text(text: String, position: Vector2, size: int, color: Color) -> void:
	DeepUI.draw_text(self, text, position, size, color)


func _draw_centered(text: String, rect: Rect2, size: int, color: Color) -> void:
	DeepUI.draw_centered(self, text, rect, size, color)


func _draw_mini_value(center: Vector2, value: String, cell_size: float, color: Color) -> void:
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-cell_size * 0.5, cell_size * 0.23),
		value,
		HORIZONTAL_ALIGNMENT_CENTER,
		cell_size,
		12,
		color,
	)
