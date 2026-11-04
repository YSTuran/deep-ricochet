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
const RESTART_BUTTON := Rect2(90.0, 690.0, 360.0, 76.0)

const COLOR_BACKGROUND := Color("111c2a")
const COLOR_PANEL := Color("17283b")
const COLOR_TEXT := Color("f4f0e6")
const COLOR_MUTED := Color("9fb4c8")
const COLOR_SAFE := Color("4f8fc7")
const COLOR_BONUS := Color("f2b65b")
const COLOR_NORMAL := Color("27394b")
const COLOR_ORE := Color("f2b65b")
const COLOR_ROCK := Color("35414b")
const COLOR_CORE := Color("69d8bc")

var controller: RunController
var run_session: RunSession
var screen: Screen = Screen.GAMEPLAY


func bind(run_controller: RunController) -> void:
	controller = run_controller


func show_gameplay() -> void:
	screen = Screen.GAMEPLAY
	run_session = null
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_route_selection(session: RunSession) -> void:
	screen = Screen.ROUTE_SELECTION
	run_session = session
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func show_run_result(session: RunSession) -> void:
	screen = Screen.RUN_RESULT
	run_session = session
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
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
	elif screen == Screen.RUN_RESULT and RESTART_BUTTON.has_point(event_position):
		controller.start_new_run()


func _draw() -> void:
	if screen == Screen.GAMEPLAY or run_session == null:
		return
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), COLOR_BACKGROUND, true)
	if screen == Screen.ROUTE_SELECTION:
		_draw_route_selection()
	else:
		_draw_run_result()


func _draw_route_selection() -> void:
	_draw_centered("ROTA SEÇ", Rect2(20.0, 30.0, 500.0, 44.0), 30, COLOR_TEXT)
	_draw_centered(
		"Oda %d tamamlandı • +%d • Toplam %d • Sıradaki oda %d/%d" % [
			run_session.room_number,
			run_session.last_room_reward,
			run_session.banked_score,
			run_session.room_number + 1,
			run_session.room_count,
		],
		Rect2(20.0, 82.0, 500.0, 32.0),
		16,
		COLOR_MUTED,
	)
	var card_rects := [SAFE_CARD, BONUS_CARD]
	for option_index in range(mini(card_rects.size(), run_session.pending_routes.size())):
		_draw_route_card(
			card_rects[option_index],
			run_session.pending_routes[option_index],
		)
	_draw_centered(
		"Karttaki küçük tahta, seçildiğinde yüklenecek gerçek odadır.",
		Rect2(20.0, 805.0, 500.0, 34.0),
		15,
		COLOR_MUTED,
	)


func _draw_route_card(rect: Rect2, option: RouteOption) -> void:
	var accent := COLOR_SAFE \
		if option.template.family == RoomTemplate.Family.SAFE else COLOR_BONUS
	draw_rect(rect, COLOR_PANEL, true)
	draw_rect(rect, accent, false, 4.0)
	_draw_text(option.title(), rect.position + Vector2(18.0, 32.0), 24, COLOR_TEXT)
	_draw_text(
		"×%.1f" % (float(option.template.multiplier_bps) / 10_000.0),
		rect.position + Vector2(rect.size.x - 78.0, 32.0),
		22,
		accent,
	)
	_draw_centered(
		option.template.display_name,
		Rect2(rect.position + Vector2(150.0, 42.0), Vector2(192.0, 26.0)),
		14,
		COLOR_MUTED,
	)
	_draw_template_preview(option.template, rect.position + Vector2(158.0, 82.0), 22.0)
	_draw_centered("DOKUN VE SEÇ", Rect2(rect.position + Vector2(120.0, 254.0), Vector2(252.0, 26.0)), 16, accent)


func _draw_template_preview(template: RoomTemplate, origin: Vector2, cell_size: float) -> void:
	var grid_rect := Rect2(origin, Vector2.ONE * cell_size * 8.0)
	draw_rect(grid_rect, Color("0b1724"), true)
	draw_rect(grid_rect, Color("40546a"), false, 2.0)
	for grid_line in range(1, 8):
		var offset := float(grid_line) * cell_size
		draw_line(origin + Vector2(offset, 0.0), origin + Vector2(offset, grid_rect.size.y), Color("23384c"))
		draw_line(origin + Vector2(0.0, offset), origin + Vector2(grid_rect.size.x, offset), Color("23384c"))
	for definition: RoomBlockDefinition in template.blocks:
		var center := origin + Vector2(
			(float(definition.cell.x) + 0.5) * cell_size,
			(float(7 - definition.cell.y) + 0.5) * cell_size,
		)
		if definition.block_type == BlockState.BlockType.CORE:
			center = origin + Vector2((float(definition.cell.x) + 0.5) * cell_size, -cell_size * 0.45)
			draw_circle(center, cell_size * 0.36, COLOR_CORE)
			_draw_mini_value(center, str(definition.hit_points), cell_size, COLOR_BACKGROUND)
			continue
		var color := COLOR_NORMAL
		var value := str(definition.hit_points)
		if definition.block_type == BlockState.BlockType.ORE:
			color = COLOR_ORE
		elif definition.block_type == BlockState.BlockType.ROCK:
			color = COLOR_ROCK
			value = "×"
		draw_rect(Rect2(center - Vector2.ONE * cell_size * 0.4, Vector2.ONE * cell_size * 0.8), color, true)
		_draw_mini_value(center, value, cell_size, COLOR_TEXT)


func _draw_run_result() -> void:
	var heading := "KAZI TAMAMLANDI" if run_session.succeeded else "KAZI SONA ERDİ"
	var accent := COLOR_CORE if run_session.succeeded else COLOR_BONUS
	_draw_centered(heading, Rect2(30.0, 110.0, 480.0, 56.0), 34, accent)
	draw_rect(Rect2(45.0, 220.0, 450.0, 360.0), COLOR_PANEL, true)
	_draw_centered(
		"%d / %d oda" % [run_session.cores_broken, run_session.room_count],
		Rect2(65.0, 270.0, 410.0, 46.0),
		27,
		COLOR_TEXT,
	)
	_draw_centered(
		"Toplam puan",
		Rect2(65.0, 350.0, 410.0, 34.0),
		19,
		COLOR_MUTED,
	)
	_draw_centered(
		str(run_session.banked_score),
		Rect2(65.0, 395.0, 410.0, 74.0),
		52,
		accent,
	)
	_draw_centered(
		"%d rota tercihi • Son oda ödülü %d" % [
			run_session.route_choices_made,
			run_session.last_room_reward,
		],
		Rect2(65.0, 500.0, 410.0, 34.0),
		17,
		COLOR_MUTED,
	)
	draw_rect(RESTART_BUTTON, accent, true)
	_draw_centered("YENİDEN OYNA", RESTART_BUTTON, 24, COLOR_BACKGROUND)


func _draw_text(text: String, position: Vector2, size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _draw_centered(text: String, rect: Rect2, size: int, color: Color) -> void:
	draw_string(
		ThemeDB.fallback_font,
		rect.position + Vector2(0.0, rect.size.y * 0.72),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		size,
		color,
	)


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
