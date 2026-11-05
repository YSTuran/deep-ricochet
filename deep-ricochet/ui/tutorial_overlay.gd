class_name TutorialOverlay
extends Control

const VIEW_SIZE := Vector2(540.0, 960.0)
const SKIP_BUTTON := Rect2(35.0, 845.0, 170.0, 65.0)
const NEXT_BUTTON := Rect2(275.0, 845.0, 230.0, 65.0)
const PAGE_COUNT := 4

const COLOR_BACKGROUND := Color("0b111a")
const COLOR_PANEL := Color("17283b")
const COLOR_TEXT := Color("f4f0e6")
const COLOR_MUTED := Color("9fb4c8")
const COLOR_PRIMARY := Color("f2b65b")
const COLOR_CORE := Color("69d8bc")

var controller: RunController
var page_index := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind(run_controller: RunController) -> void:
	controller = run_controller


func show_tutorial() -> void:
	page_index = 0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func hide_overlay() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh_locale() -> void:
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
	if not released or controller == null:
		return
	if SKIP_BUTTON.has_point(event_position):
		controller.complete_tutorial()
	elif NEXT_BUTTON.has_point(event_position):
		if page_index >= PAGE_COUNT - 1:
			controller.complete_tutorial()
		else:
			page_index += 1
			queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), COLOR_BACKGROUND, true)
	_draw_illustration()
	_draw_centered(
		tr("TUTORIAL_TITLE_%d" % (page_index + 1)),
		Rect2(35.0, 505.0, 470.0, 55.0),
		30,
		COLOR_TEXT,
	)
	_draw_wrapped(
		tr("TUTORIAL_BODY_%d" % (page_index + 1)),
		Rect2(55.0, 585.0, 430.0, 125.0),
		18,
		COLOR_MUTED,
	)
	for dot_index in range(PAGE_COUNT):
		var dot_color := COLOR_PRIMARY if dot_index == page_index else Color("40546a")
		draw_circle(Vector2(240.0 + float(dot_index) * 20.0, 775.0), 5.0, dot_color)
	_draw_button(SKIP_BUTTON, tr("TUTORIAL_SKIP"), COLOR_PANEL, COLOR_TEXT)
	var next_label := tr("TUTORIAL_START") if page_index == PAGE_COUNT - 1 else tr("TUTORIAL_NEXT")
	_draw_button(NEXT_BUTTON, next_label, COLOR_PRIMARY, COLOR_BACKGROUND)


func _draw_illustration() -> void:
	draw_rect(Rect2(55.0, 90.0, 430.0, 360.0), COLOR_PANEL, true)
	match page_index:
		0:
			var launcher := Vector2(270.0, 385.0)
			draw_circle(launcher, 14.0, COLOR_TEXT)
			draw_dashed_line(launcher, Vector2(175.0, 180.0), Color("ffe7a8"), 4.0, 12.0)
			draw_circle(Vector2(175.0, 180.0), 9.0, COLOR_PRIMARY)
		1:
			draw_line(Vector2(95.0, 390.0), Vector2(95.0, 145.0), Color("40546a"), 8.0)
			draw_line(Vector2(445.0, 390.0), Vector2(445.0, 145.0), Color("40546a"), 8.0)
			draw_rect(Rect2(220.0, 205.0, 100.0, 100.0), Color("35414b"), true)
			draw_line(Vector2(235.0, 220.0), Vector2(305.0, 290.0), COLOR_TEXT, 7.0)
			draw_line(Vector2(305.0, 220.0), Vector2(235.0, 290.0), COLOR_TEXT, 7.0)
			draw_dashed_line(Vector2(155.0, 365.0), Vector2(220.0, 255.0), Color("ffe7a8"), 4.0, 11.0)
			draw_dashed_line(Vector2(220.0, 255.0), Vector2(120.0, 170.0), Color("ffe7a8"), 4.0, 11.0)
		2:
			draw_rect(Rect2(100.0, 270.0, 105.0, 105.0), Color("4f8fc7"), true)
			draw_rect(Rect2(218.0, 270.0, 105.0, 105.0), COLOR_PRIMARY, true)
			draw_circle(Vector2(388.0, 322.0), 55.0, COLOR_CORE)
			_draw_centered("3", Rect2(100.0, 290.0, 105.0, 55.0), 25, COLOR_TEXT)
			_draw_centered("5", Rect2(218.0, 290.0, 105.0, 55.0), 25, COLOR_TEXT)
			_draw_centered("6", Rect2(335.0, 290.0, 105.0, 55.0), 25, Color("111c2a"))
		3:
			draw_rect(Rect2(80.0, 155.0, 175.0, 225.0), Color("203c55"), true)
			draw_rect(Rect2(285.0, 155.0, 175.0, 225.0), Color("4a3923"), true)
			_draw_centered("×1.0", Rect2(90.0, 195.0, 155.0, 50.0), 25, Color("74b7eb"))
			_draw_centered("×1.5", Rect2(295.0, 195.0, 155.0, 50.0), 25, COLOR_PRIMARY)
			_draw_centered(tr("ROUTE_SAFE"), Rect2(90.0, 300.0, 155.0, 45.0), 17, COLOR_TEXT)
			_draw_centered(tr("ROUTE_BONUS"), Rect2(295.0, 300.0, 155.0, 45.0), 17, COLOR_TEXT)


func _draw_button(rect: Rect2, label: String, color: Color, text_color: Color) -> void:
	draw_rect(rect, color, true)
	_draw_centered(label, rect, 19, text_color)


func _draw_wrapped(text: String, rect: Rect2, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var lines: Array[String] = []
	var current := ""
	for word: String in text.split(" "):
		var candidate := word if current.is_empty() else "%s %s" % [current, word]
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x > rect.size.x:
			lines.append(current)
			current = word
		else:
			current = candidate
	if not current.is_empty():
		lines.append(current)
	var line_height := float(size) * 1.45
	var start_y := rect.position.y + (rect.size.y - line_height * float(lines.size())) * 0.5
	for line_index in range(lines.size()):
		draw_string(
			font,
			Vector2(rect.position.x, start_y + line_height * float(line_index + 1)),
			lines[line_index],
			HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x,
			size,
			color,
		)


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
