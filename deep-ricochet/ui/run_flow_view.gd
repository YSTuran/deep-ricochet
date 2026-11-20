class_name RunFlowView
extends Control

const TouchControlsScript := preload("res://ui/touch_controls.gd")

enum Screen {
	GAMEPLAY,
	ROUTE_SELECTION,
	RUN_RESULT,
}

const VIEW_SIZE := Vector2(540.0, 960.0)
const SAFE_CARD := Rect2(24.0, 150.0, 492.0, 290.0)
const BONUS_CARD := Rect2(24.0, 465.0, 492.0, 290.0)
const SAME_SEED_BUTTON := Rect2(70.0, 650.0, 400.0, 60.0)
const RESTART_BUTTON := Rect2(70.0, 725.0, 400.0, 60.0)
const RESULT_MENU_BUTTON := Rect2(70.0, 800.0, 400.0, 60.0)
const CORE_TEXTURE: Texture2D = preload("res://assets/images/blocks/cekirdek.png")
const CRACKED_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_catlak.png")
const EXPLOSIVE_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_patlayici.png")
const ARMORED_BOTTOM_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_zirhli_alt.png")
const ARMORED_LEFT_BOTTOM_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_zirhli_sol_alt.png")
const ARMORED_RIGHT_BOTTOM_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_zirhli_sag_alt.png")
const CRACKED_SOURCE := Rect2(32.0, 36.0, 447.0, 454.0)
const EXPLOSIVE_SOURCE := Rect2(54.0, 65.0, 404.0, 407.0)
const ARMORED_BOTTOM_SOURCE := Rect2(5.0, 6.0, 502.0, 502.0)
const ARMORED_LEFT_BOTTOM_SOURCE := Rect2(5.0, 5.0, 503.0, 503.0)
const ARMORED_RIGHT_BOTTOM_SOURCE := Rect2(4.0, 5.0, 503.0, 503.0)
const PREVIEW_CELL_SIZE := 15.5
const ACTION_ROUTE_PREFIX := "route_"
const ACTION_PRIMARY := &"primary"
const ACTION_RESTART := &"restart"
const ACTION_MENU := &"menu"

var controller: RunController
var run_session: RunSession
var profile: PlayerProfile
var new_best := false
var screen: Screen = Screen.GAMEPLAY
var touch_controls = TouchControlsScript.new()


func bind(run_controller: RunController) -> void:
	controller = run_controller


func show_gameplay() -> void:
	touch_controls.reset()
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
	if not TouchControlsScript.handles(event) or DeepUI.is_emulated_mouse_event(event):
		return
	accept_event()
	var action: StringName = touch_controls.process(event, _touch_targets())
	if touch_controls.changed:
		queue_redraw()
	if action.is_empty() or controller == null or run_session == null:
		return

	if screen == Screen.ROUTE_SELECTION:
		var option_index := String(action).trim_prefix(ACTION_ROUTE_PREFIX).to_int()
		if option_index >= 0 and option_index < run_session.pending_routes.size():
			controller.select_route(run_session.pending_routes[option_index].option_id)
	elif screen == Screen.RUN_RESULT:
		AudioManager.play_ui_click()
		if action == ACTION_PRIMARY:
			if _shows_mine_progression_actions():
				controller.start_next_mine_from_result()
			else:
				controller.restart_same_seed()
		elif action == ACTION_RESTART:
			if _shows_mine_progression_actions():
				controller.restart_same_seed()
			elif run_session.run_kind == RunSession.RunKind.NORMAL:
				controller.restart_current_mine()
			else:
				controller.start_new_run()
		elif action == ACTION_MENU:
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
			option_index,
		)
	_draw_centered(
		tr("ROUTE_HINT"),
		Rect2(20.0, 805.0, 500.0, 34.0),
		15,
		DeepUI.MUTED,
	)


func _draw_route_card(rect: Rect2, option: RouteOption, option_index: int) -> void:
	var is_safe := option.template.family == RoomTemplate.Family.SAFE
	var accent := DeepUI.BLUE if is_safe else DeepUI.GOLD
	var fill := Color("102a40") if is_safe else Color("382c1d")
	var action := StringName("%s%d" % [ACTION_ROUTE_PREFIX, option_index])
	var pressed: bool = touch_controls.is_pressed(action)
	var card_rect := Rect2(rect.position + (Vector2(0.0, 3.0) if pressed else Vector2.ZERO), rect.size)
	DeepUI.draw_panel(self, card_rect, fill.darkened(0.1) if pressed else fill, accent, 18, 3, not pressed)
	rect = card_rect
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
	var preview_size := Vector2(BoardGeometry.WORLD_GRID_SIZE) * PREVIEW_CELL_SIZE
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
		true,
		pressed,
	)


func _draw_template_preview(template: RoomTemplate, origin: Vector2, cell_size: float) -> void:
	var grid_rect := Rect2(
		origin,
		Vector2(BoardGeometry.WORLD_GRID_SIZE) * cell_size,
	)
	DeepUI.draw_panel(
		self,
		grid_rect.grow(6.0),
		CaveTheme.color(&"board"),
		CaveTheme.color(&"board_border"),
		10,
		2,
		false,
	)
	for column in range(1, BoardGeometry.WORLD_GRID_SIZE.x):
		var offset_x := float(column) * cell_size
		draw_line(
			origin + Vector2(offset_x, 0.0),
			origin + Vector2(offset_x, grid_rect.size.y),
			CaveTheme.color(&"grid"),
		)
	for row in range(1, BoardGeometry.WORLD_GRID_SIZE.y):
		var offset_y := float(row) * cell_size
		draw_line(
			origin + Vector2(0.0, offset_y),
			origin + Vector2(grid_rect.size.x, offset_y),
			CaveTheme.color(&"grid"),
		)
	for definition: RoomBlockDefinition in template.blocks:
		var preview_row := BoardGeometry.preview_row_for_cell(definition.cell.y)
		var center := origin + Vector2(
			(float(definition.cell.x) + 0.5) * cell_size,
			(float(preview_row) + 0.5) * cell_size,
		)
		if definition.block_type == BlockState.BlockType.CORE:
			var core_color := CaveTheme.block_color(BlockState.BlockType.CORE)
			DeepUI.draw_glow(self, center, cell_size * 0.32, core_color)
			draw_circle(center, cell_size * 0.36, core_color)
			_draw_mini_value(center, str(definition.hit_points), cell_size, CaveTheme.color(&"board"))
			continue
		var block_rect := Rect2(center - Vector2.ONE * cell_size * 0.4, Vector2.ONE * cell_size * 0.8)
		var color := CaveTheme.block_color(BlockState.BlockType.NORMAL)
		var value := str(definition.hit_points)
		if definition.block_type == BlockState.BlockType.ORE:
			color = CaveTheme.block_color(BlockState.BlockType.ORE)
		elif definition.block_type == BlockState.BlockType.ROCK:
			color = CaveTheme.block_color(BlockState.BlockType.ROCK)
			value = "×"
		elif definition.block_type == BlockState.BlockType.EXPLOSIVE:
			_draw_preview_illustrated_block(
				block_rect,
				EXPLOSIVE_TEXTURE,
				EXPLOSIVE_SOURCE,
				value,
				BlockState.BlockType.EXPLOSIVE,
			)
			continue
		elif definition.block_type == BlockState.BlockType.CRACKED:
			_draw_preview_illustrated_block(
				block_rect,
				CRACKED_TEXTURE,
				CRACKED_SOURCE,
				value,
				BlockState.BlockType.CRACKED,
			)
			continue
		elif definition.block_type == BlockState.BlockType.ARMORED:
			_draw_preview_armored_block(block_rect, definition.vulnerable_sides, value)
			continue
		DeepUI.draw_panel(self, block_rect, color, Color(color).lightened(0.18), 4, 1, false)
		_draw_mini_value(center, value, cell_size, DeepUI.TEXT)


func _draw_preview_illustrated_block(
	rect: Rect2,
	texture: Texture2D,
	source_rect: Rect2,
	hp_text: String,
	block_type: int,
) -> void:
	CaveTheme.draw_texture_region(self, texture, rect, source_rect, block_type)
	_draw_mini_value(rect.get_center(), hp_text, rect.size.x / 0.8, DeepUI.TEXT)


func _draw_preview_armored_block(rect: Rect2, vulnerable_sides: int, hp_text: String) -> void:
	var texture := ARMORED_BOTTOM_TEXTURE
	var source_rect := ARMORED_BOTTOM_SOURCE
	if (vulnerable_sides & BlockState.VulnerableSide.LEFT) != 0:
		texture = ARMORED_LEFT_BOTTOM_TEXTURE
		source_rect = ARMORED_LEFT_BOTTOM_SOURCE
	elif (vulnerable_sides & BlockState.VulnerableSide.RIGHT) != 0:
		texture = ARMORED_RIGHT_BOTTOM_TEXTURE
		source_rect = ARMORED_RIGHT_BOTTOM_SOURCE
	_draw_preview_illustrated_block(
		rect,
		texture,
		source_rect,
		hp_text,
		BlockState.BlockType.ARMORED,
	)


func _draw_run_result() -> void:
	var heading := tr("RESULT_SUCCESS") if run_session.succeeded else tr("RESULT_FAILURE")
	var accent := DeepUI.CORE if run_session.succeeded else DeepUI.GOLD
	DeepUI.draw_glow(self, Vector2(270.0, 108.0), 48.0, accent)
	CaveTheme.draw_texture(
		self,
		CORE_TEXTURE,
		Rect2(216.0, 54.0, 108.0, 108.0),
		BlockState.BlockType.CORE,
		Color.WHITE if run_session.succeeded else Color(0.72, 0.72, 0.72, 0.7),
	)
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
	_draw_result_table()
	if profile != null:
		var best_label := tr("RESULT_NEW_BEST") if new_best else tr("RESULT_BEST") % profile.best_score
		DeepUI.draw_chip(self, Rect2(135.0, 580.0, 270.0, 38.0), best_label, accent, 17)
	var primary_label := tr("RESULT_RETRY_SEED")
	var restart_label := tr("RESULT_REPLAY")
	if _shows_mine_progression_actions():
		primary_label = tr("RESULT_NEXT_MINE") \
			if not controller.next_mine_id_from_result().is_empty() \
			else tr("RESULT_CHOOSE_MINE")
		restart_label = tr("RESULT_RESTART")
	DeepUI.draw_button(
		self, SAME_SEED_BUTTON, primary_label,
		&"core" if run_session.succeeded else &"primary", 21, true,
		touch_controls.is_pressed(ACTION_PRIMARY),
	)
	DeepUI.draw_button(
		self, RESTART_BUTTON, restart_label, &"secondary", 21, true,
		touch_controls.is_pressed(ACTION_RESTART),
	)
	DeepUI.draw_button(
		self, RESULT_MENU_BUTTON, tr("RESULT_MAIN_MENU"), &"secondary", 22, true,
		touch_controls.is_pressed(ACTION_MENU),
	)


func _draw_result_table() -> void:
	var table_rect := Rect2(65.0, 414.0, 410.0, 160.0)
	DeepUI.draw_panel(self, table_rect, Color(DeepUI.BACKGROUND_DEEP, 0.55), DeepUI.BORDER_SOFT, 10, 1, false)
	var columns := [
		Rect2(68.0, 420.0, 48.0, 24.0),
		Rect2(116.0, 420.0, 78.0, 24.0),
		Rect2(194.0, 420.0, 78.0, 24.0),
		Rect2(272.0, 420.0, 82.0, 24.0),
		Rect2(354.0, 420.0, 116.0, 24.0),
	]
	var headers := [
		tr("RESULT_TABLE_ROOM"),
		tr("RESULT_TABLE_BREAK"),
		tr("RESULT_TABLE_BONUS"),
		tr("RESULT_TABLE_MULTIPLIER"),
		tr("RESULT_TABLE_TOTAL"),
	]
	for column_index in range(columns.size()):
		_draw_centered(headers[column_index], columns[column_index], 11, DeepUI.GOLD)
	for result_index in range(mini(run_session.room_results.size(), 4)):
		var result := run_session.room_results[result_index]
		var row_y := 447.0 + float(result_index) * 30.0
		if result_index % 2 == 0:
			draw_rect(Rect2(69.0, row_y, 402.0, 28.0), Color(DeepUI.PANEL_RAISED, 0.45), true)
		var values := [
			str(result.room_number),
			str(result.break_score),
			str(result.unused_shot_bonus),
			"×%.1f" % (float(result.multiplier_bps) / 10_000.0),
			str(result.reward),
		]
		for column_index in range(columns.size()):
			var value_rect: Rect2 = columns[column_index]
			value_rect.position.y = row_y
			value_rect.size.y = 28.0
			_draw_centered(values[column_index], value_rect, 12, DeepUI.TEXT)


func _shows_mine_progression_actions() -> bool:
	return run_session != null \
		and run_session.ended \
		and run_session.succeeded \
		and run_session.run_kind == RunSession.RunKind.NORMAL \
		and controller != null


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


func _touch_targets() -> Dictionary:
	if screen == Screen.RUN_RESULT:
		return {
			ACTION_PRIMARY: SAME_SEED_BUTTON,
			ACTION_RESTART: RESTART_BUTTON,
			ACTION_MENU: RESULT_MENU_BUTTON,
		}
	if screen != Screen.ROUTE_SELECTION or run_session == null:
		return {}
	var targets := {}
	var card_rects := [SAFE_CARD, BONUS_CARD]
	for option_index in range(mini(card_rects.size(), run_session.pending_routes.size())):
		targets[StringName("%s%d" % [ACTION_ROUTE_PREFIX, option_index])] = card_rects[option_index]
	return targets
