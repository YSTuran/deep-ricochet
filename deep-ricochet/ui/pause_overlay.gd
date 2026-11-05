class_name PauseOverlay
extends Control

enum Mode {
	PAUSE,
	CONFIRM_NEW_GAME,
}

const VIEW_SIZE := Vector2(540.0, 960.0)
const CONTINUE_BUTTON := Rect2(80.0, 390.0, 380.0, 70.0)
const NEW_GAME_BUTTON := Rect2(80.0, 485.0, 380.0, 70.0)
const MAIN_MENU_BUTTON := Rect2(80.0, 580.0, 380.0, 70.0)
const SETTINGS_BUTTON := Rect2(80.0, 675.0, 380.0, 70.0)
const CANCEL_BUTTON := Rect2(55.0, 560.0, 200.0, 70.0)
const CONFIRM_BUTTON := Rect2(285.0, 560.0, 200.0, 70.0)

const COLOR_BACKGROUND := Color("0b111a")
const COLOR_PANEL := Color("17283b")
const COLOR_TEXT := Color("f4f0e6")
const COLOR_MUTED := Color("9fb4c8")
const COLOR_PRIMARY := Color("f2b65b")
const COLOR_DANGER := Color("d96c5f")

var controller: RunController
var mode: Mode = Mode.PAUSE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind(run_controller: RunController) -> void:
	controller = run_controller


func show_pause() -> void:
	mode = Mode.PAUSE
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func show_new_game_confirmation() -> void:
	mode = Mode.CONFIRM_NEW_GAME
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func hide_overlay() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	if mode == Mode.PAUSE:
		if CONTINUE_BUTTON.has_point(event_position):
			controller.resume_game()
		elif NEW_GAME_BUTTON.has_point(event_position):
			controller.request_new_game_confirmation(false)
		elif MAIN_MENU_BUTTON.has_point(event_position):
			controller.return_to_main_menu()
		elif SETTINGS_BUTTON.has_point(event_position):
			controller.open_settings_from_pause()
	else:
		if CANCEL_BUTTON.has_point(event_position):
			controller.cancel_new_game_confirmation()
		elif CONFIRM_BUTTON.has_point(event_position):
			controller.confirm_new_game()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(COLOR_BACKGROUND, 0.97), true)
	if mode == Mode.PAUSE:
		_draw_pause()
	else:
		_draw_confirmation()


func _draw_pause() -> void:
	_draw_centered(tr("PAUSE_TITLE"), Rect2(30.0, 180.0, 480.0, 60.0), 32, COLOR_TEXT)
	_draw_centered(tr("PAUSE_SUBTITLE"), Rect2(40.0, 255.0, 460.0, 34.0), 17, COLOR_MUTED)
	draw_rect(CONTINUE_BUTTON, COLOR_PRIMARY, true)
	_draw_centered(tr("PAUSE_CONTINUE"), CONTINUE_BUTTON, 23, COLOR_BACKGROUND)
	draw_rect(NEW_GAME_BUTTON, COLOR_PANEL, true)
	_draw_centered(tr("PAUSE_NEW_GAME"), NEW_GAME_BUTTON, 21, COLOR_TEXT)
	draw_rect(MAIN_MENU_BUTTON, COLOR_PANEL, true)
	_draw_centered(tr("PAUSE_MAIN_MENU"), MAIN_MENU_BUTTON, 21, COLOR_TEXT)
	draw_rect(SETTINGS_BUTTON, COLOR_PANEL, true)
	_draw_centered(tr("PAUSE_SETTINGS"), SETTINGS_BUTTON, 21, COLOR_TEXT)


func _draw_confirmation() -> void:
	_draw_centered(tr("CONFIRM_NEW_TITLE"), Rect2(30.0, 260.0, 480.0, 56.0), 32, COLOR_TEXT)
	_draw_centered(
		tr("CONFIRM_NEW_BODY"),
		Rect2(50.0, 355.0, 440.0, 58.0),
		17,
		COLOR_MUTED,
	)
	draw_rect(CANCEL_BUTTON, COLOR_PANEL, true)
	_draw_centered(tr("COMMON_CANCEL"), CANCEL_BUTTON, 19, COLOR_TEXT)
	draw_rect(CONFIRM_BUTTON, COLOR_DANGER, true)
	_draw_centered(tr("PAUSE_NEW_GAME"), CONFIRM_BUTTON, 19, COLOR_TEXT)


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
