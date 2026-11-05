class_name SettingsOverlay
extends Control

enum Mode {
	SETTINGS,
	CONFIRM_RESET,
}

const VIEW_SIZE := Vector2(540.0, 960.0)
const TURKISH_BUTTON := Rect2(55.0, 300.0, 200.0, 66.0)
const ENGLISH_BUTTON := Rect2(285.0, 300.0, 200.0, 66.0)
const TUTORIAL_BUTTON := Rect2(80.0, 420.0, 380.0, 70.0)
const RESET_BUTTON := Rect2(80.0, 515.0, 380.0, 70.0)
const BACK_BUTTON := Rect2(80.0, 690.0, 380.0, 70.0)
const CANCEL_BUTTON := Rect2(55.0, 570.0, 200.0, 70.0)
const CONFIRM_BUTTON := Rect2(285.0, 570.0, 200.0, 70.0)

const COLOR_BACKGROUND := Color("0b111a")
const COLOR_PANEL := Color("17283b")
const COLOR_TEXT := Color("f4f0e6")
const COLOR_MUTED := Color("9fb4c8")
const COLOR_PRIMARY := Color("f2b65b")
const COLOR_DANGER := Color("d96c5f")

var controller: RunController
var mode: Mode = Mode.SETTINGS


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind(run_controller: RunController) -> void:
	controller = run_controller


func show_settings() -> void:
	mode = Mode.SETTINGS
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func show_reset_confirmation() -> void:
	mode = Mode.CONFIRM_RESET
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

	if mode == Mode.SETTINGS:
		if TURKISH_BUTTON.has_point(event_position):
			controller.set_language(&"tr")
		elif ENGLISH_BUTTON.has_point(event_position):
			controller.set_language(&"en")
		elif TUTORIAL_BUTTON.has_point(event_position):
			controller.show_tutorial_from_settings()
		elif RESET_BUTTON.has_point(event_position):
			show_reset_confirmation()
		elif BACK_BUTTON.has_point(event_position):
			controller.close_settings()
	else:
		if CANCEL_BUTTON.has_point(event_position):
			show_settings()
		elif CONFIRM_BUTTON.has_point(event_position):
			controller.confirm_reset_progress()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), COLOR_BACKGROUND, true)
	if mode == Mode.SETTINGS:
		_draw_settings()
	else:
		_draw_reset_confirmation()


func _draw_settings() -> void:
	_draw_centered(tr("SETTINGS_TITLE"), Rect2(30.0, 105.0, 480.0, 58.0), 34, COLOR_TEXT)
	_draw_centered(tr("SETTINGS_LANGUAGE"), Rect2(30.0, 220.0, 480.0, 36.0), 19, COLOR_MUTED)
	var selected_language := &"tr"
	if controller != null and controller.app_settings != null:
		selected_language = controller.app_settings.language
	_draw_choice(TURKISH_BUTTON, tr("SETTINGS_TURKISH"), selected_language == &"tr")
	_draw_choice(ENGLISH_BUTTON, tr("SETTINGS_ENGLISH"), selected_language == &"en")
	_draw_button(TUTORIAL_BUTTON, tr("SETTINGS_TUTORIAL"), COLOR_PANEL, COLOR_TEXT)
	_draw_button(RESET_BUTTON, tr("SETTINGS_RESET"), Color("3b2529"), Color("f2a299"))
	_draw_button(BACK_BUTTON, tr("COMMON_BACK"), COLOR_PRIMARY, COLOR_BACKGROUND)


func _draw_reset_confirmation() -> void:
	_draw_centered(tr("CONFIRM_RESET_TITLE"), Rect2(30.0, 260.0, 480.0, 58.0), 30, COLOR_TEXT)
	_draw_centered(tr("CONFIRM_RESET_BODY"), Rect2(45.0, 370.0, 450.0, 50.0), 17, COLOR_MUTED)
	_draw_button(CANCEL_BUTTON, tr("COMMON_CANCEL"), COLOR_PANEL, COLOR_TEXT)
	_draw_button(CONFIRM_BUTTON, tr("CONFIRM_RESET_ACTION"), COLOR_DANGER, COLOR_TEXT)


func _draw_choice(rect: Rect2, label: String, selected: bool) -> void:
	var color := COLOR_PRIMARY if selected else COLOR_PANEL
	var text_color := COLOR_BACKGROUND if selected else COLOR_TEXT
	_draw_button(rect, label, color, text_color)


func _draw_button(rect: Rect2, label: String, color: Color, text_color: Color) -> void:
	draw_rect(rect, color, true)
	draw_rect(rect, Color("40546a"), false, 2.0)
	_draw_centered(label, rect, 19, text_color)


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
