class_name TutorialOverlay
extends Control

const VIEW_SIZE := Vector2(540.0, 960.0)
const SKIP_BUTTON := Rect2(35.0, 845.0, 170.0, 65.0)
const NEXT_BUTTON := Rect2(275.0, 845.0, 230.0, 65.0)
const PAGE_COUNT := 4

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
	if not released or controller == null:
		return
	AudioManager.play_ui_click()
	if SKIP_BUTTON.has_point(event_position):
		controller.complete_tutorial()
	elif NEXT_BUTTON.has_point(event_position):
		if page_index >= PAGE_COUNT - 1:
			controller.complete_tutorial()
		else:
			page_index += 1
			queue_redraw()


func _draw() -> void:
	DeepUI.draw_cave_background(self, VIEW_SIZE)
	DeepUI.draw_panel(self, Rect2(35.0, 60.0, 470.0, 755.0), Color(DeepUI.PANEL_SOFT, 0.96), DeepUI.BORDER, 22, 2, true)
	_draw_illustration()
	DeepUI.draw_title_plate(
		self,
		tr("TUTORIAL_TITLE_%d" % (page_index + 1)),
		Rect2(62.0, 492.0, 416.0, 64.0),
		27,
		DeepUI.GOLD,
	)
	_draw_wrapped(
		tr("TUTORIAL_BODY_%d" % (page_index + 1)),
		Rect2(55.0, 585.0, 430.0, 125.0),
		18,
		DeepUI.MUTED,
	)
	for dot_index in range(PAGE_COUNT):
		var dot_color := DeepUI.GOLD if dot_index == page_index else DeepUI.BORDER
		draw_circle(Vector2(240.0 + float(dot_index) * 20.0, 775.0), 5.0, dot_color)
	DeepUI.draw_button(self, SKIP_BUTTON, tr("TUTORIAL_SKIP"), &"ghost", 19)
	var next_label := tr("TUTORIAL_START") if page_index == PAGE_COUNT - 1 else tr("TUTORIAL_NEXT")
	DeepUI.draw_button(self, NEXT_BUTTON, next_label, &"primary", 19)


func _draw_illustration() -> void:
	DeepUI.draw_panel(self, Rect2(55.0, 90.0, 430.0, 360.0), DeepUI.PANEL, DeepUI.BORDER_SOFT, 16, 2, false)
	match page_index:
		0:
			var launcher := Vector2(270.0, 385.0)
			draw_circle(launcher, 14.0, DeepUI.TEXT)
			draw_dashed_line(launcher, Vector2(175.0, 180.0), DeepUI.GOLD_LIGHT, 4.0, 12.0)
			draw_circle(Vector2(175.0, 180.0), 9.0, DeepUI.GOLD)
		1:
			draw_line(Vector2(95.0, 390.0), Vector2(95.0, 145.0), DeepUI.BORDER, 8.0)
			draw_line(Vector2(445.0, 390.0), Vector2(445.0, 145.0), DeepUI.BORDER, 8.0)
			draw_rect(Rect2(220.0, 205.0, 100.0, 100.0), Color("35414b"), true)
			draw_line(Vector2(235.0, 220.0), Vector2(305.0, 290.0), DeepUI.TEXT, 7.0)
			draw_line(Vector2(305.0, 220.0), Vector2(235.0, 290.0), DeepUI.TEXT, 7.0)
			draw_dashed_line(Vector2(155.0, 365.0), Vector2(220.0, 255.0), DeepUI.GOLD_LIGHT, 4.0, 11.0)
			draw_dashed_line(Vector2(220.0, 255.0), Vector2(120.0, 170.0), DeepUI.GOLD_LIGHT, 4.0, 11.0)
		2:
			DeepUI.draw_panel(self, Rect2(100.0, 270.0, 105.0, 105.0), DeepUI.BLUE, DeepUI.BLUE_LIGHT, 12, 2, true)
			DeepUI.draw_panel(self, Rect2(218.0, 270.0, 105.0, 105.0), DeepUI.GOLD, DeepUI.GOLD_LIGHT, 12, 2, true)
			DeepUI.draw_glow(self, Vector2(388.0, 322.0), 48.0, DeepUI.CORE)
			draw_circle(Vector2(388.0, 322.0), 51.0, DeepUI.CORE)
			DeepUI.draw_centered(self, "3", Rect2(100.0, 290.0, 105.0, 55.0), 25, DeepUI.TEXT)
			DeepUI.draw_centered(self, "5", Rect2(218.0, 290.0, 105.0, 55.0), 25, DeepUI.BACKGROUND_DEEP)
			DeepUI.draw_centered(self, "6", Rect2(335.0, 290.0, 105.0, 55.0), 25, DeepUI.BACKGROUND_DEEP)
		3:
			DeepUI.draw_panel(self, Rect2(80.0, 155.0, 175.0, 225.0), Color("173550"), DeepUI.BLUE, 15, 2, true)
			DeepUI.draw_panel(self, Rect2(285.0, 155.0, 175.0, 225.0), Color("4a3923"), DeepUI.GOLD, 15, 2, true)
			DeepUI.draw_centered(self, "×1.0", Rect2(90.0, 195.0, 155.0, 50.0), 25, DeepUI.BLUE_LIGHT)
			DeepUI.draw_centered(self, "×1.5", Rect2(295.0, 195.0, 155.0, 50.0), 25, DeepUI.GOLD)
			DeepUI.draw_centered(self, tr("ROUTE_SAFE"), Rect2(90.0, 300.0, 155.0, 45.0), 17, DeepUI.TEXT)
			DeepUI.draw_centered(self, tr("ROUTE_BONUS"), Rect2(295.0, 300.0, 155.0, 45.0), 17, DeepUI.TEXT)


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
