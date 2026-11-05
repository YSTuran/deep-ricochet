class_name MainMenuView
extends Control

const VIEW_SIZE := Vector2(540.0, 960.0)
const CONTINUE_BUTTON := Rect2(80.0, 510.0, 380.0, 76.0)
const NEW_GAME_BUTTON := Rect2(80.0, 610.0, 380.0, 76.0)
const SETTINGS_BUTTON := Rect2(80.0, 710.0, 380.0, 66.0)

const COLOR_BACKGROUND := Color("111c2a")
const COLOR_PANEL := Color("17283b")
const COLOR_TEXT := Color("f4f0e6")
const COLOR_MUTED := Color("9fb4c8")
const COLOR_PRIMARY := Color("f2b65b")
const COLOR_SECONDARY := Color("27394b")

var controller: RunController
var continue_available := false
var notice: String


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind(run_controller: RunController) -> void:
	controller = run_controller


func show_menu(can_continue: bool, message: String = "") -> void:
	continue_available = can_continue
	notice = message
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func hide_menu() -> void:
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
	if continue_available and CONTINUE_BUTTON.has_point(event_position):
		controller.continue_saved_run()
	elif NEW_GAME_BUTTON.has_point(event_position):
		controller.request_new_game_from_menu()
	elif SETTINGS_BUTTON.has_point(event_position):
		controller.open_settings_from_main_menu()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), COLOR_BACKGROUND, true)
	draw_circle(Vector2(270.0, 220.0), 72.0, Color("69d8bc"))
	draw_circle(Vector2(270.0, 220.0), 52.0, Color("1b756a"))
	_draw_centered("DEEP RICOCHET", Rect2(30.0, 320.0, 480.0, 60.0), 38, COLOR_TEXT)
	_draw_centered(
		tr("MENU_TAGLINE"),
		Rect2(30.0, 390.0, 480.0, 34.0),
		18,
		COLOR_MUTED,
	)
	if controller != null and controller.profile != null:
		_draw_centered(
			tr("PROFILE_BEST") % controller.profile.best_score,
			Rect2(30.0, 440.0, 480.0, 30.0),
			17,
			COLOR_PRIMARY,
		)
		_draw_centered(
			tr("PROFILE_STATS") % [
				controller.profile.runs_played,
				controller.profile.successful_runs,
				controller.profile.total_cores_broken,
			],
			Rect2(30.0, 470.0, 480.0, 26.0),
			14,
			COLOR_MUTED,
		)
	if continue_available:
		draw_rect(CONTINUE_BUTTON, COLOR_PRIMARY, true)
		_draw_centered(tr("MENU_CONTINUE"), CONTINUE_BUTTON, 24, COLOR_BACKGROUND)
	else:
		draw_rect(CONTINUE_BUTTON, COLOR_PANEL, true)
		_draw_centered(tr("MENU_NO_SAVE"), CONTINUE_BUTTON, 17, Color(COLOR_MUTED, 0.6))
	draw_rect(NEW_GAME_BUTTON, COLOR_SECONDARY, true)
	draw_rect(NEW_GAME_BUTTON, Color("40546a"), false, 2.0)
	_draw_centered(tr("MENU_NEW_GAME"), NEW_GAME_BUTTON, 22, COLOR_TEXT)
	draw_rect(SETTINGS_BUTTON, COLOR_PANEL, true)
	draw_rect(SETTINGS_BUTTON, Color("40546a"), false, 2.0)
	_draw_centered(tr("MENU_SETTINGS"), SETTINGS_BUTTON, 19, COLOR_TEXT)
	if not notice.is_empty():
		_draw_centered(notice, Rect2(45.0, 800.0, 450.0, 58.0), 15, COLOR_MUTED)
	_draw_centered(tr("MENU_OFFLINE"), Rect2(30.0, 895.0, 480.0, 30.0), 14, Color(COLOR_MUTED, 0.7))


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
