class_name PauseOverlay
extends Control

enum Mode {
	PAUSE,
	CONFIRM_NEW_GAME,
	CONFIRM_MAIN_MENU,
}

const VIEW_SIZE := Vector2(540.0, 960.0)
const CONTINUE_BUTTON := Rect2(80.0, 390.0, 380.0, 70.0)
const NEW_GAME_BUTTON := Rect2(80.0, 485.0, 380.0, 70.0)
const MAIN_MENU_BUTTON := Rect2(80.0, 580.0, 380.0, 70.0)
const SETTINGS_BUTTON := Rect2(80.0, 675.0, 380.0, 70.0)
const CANCEL_BUTTON := Rect2(55.0, 560.0, 200.0, 70.0)
const CONFIRM_BUTTON := Rect2(285.0, 560.0, 200.0, 70.0)

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


func show_main_menu_confirmation() -> void:
	mode = Mode.CONFIRM_MAIN_MENU
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func hide_overlay() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	if mode == Mode.PAUSE:
		if CONTINUE_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			controller.resume_game()
		elif NEW_GAME_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			controller.request_new_game_confirmation(false)
		elif MAIN_MENU_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			controller.request_main_menu_confirmation()
		elif SETTINGS_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			controller.open_settings_from_pause()
	else:
		if CANCEL_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			controller.cancel_new_game_confirmation()
		elif CONFIRM_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			if mode == Mode.CONFIRM_MAIN_MENU:
				controller.confirm_main_menu_return()
			else:
				controller.confirm_new_game()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color(DeepUI.BACKGROUND_DEEP, 0.95), true)
	if mode == Mode.PAUSE:
		_draw_pause()
	else:
		_draw_confirmation()


func _draw_pause() -> void:
	DeepUI.draw_panel(self, Rect2(46.0, 145.0, 448.0, 650.0), DeepUI.PANEL_SOFT, DeepUI.BORDER, 22, 2, true)
	DeepUI.draw_title_plate(self, tr("PAUSE_TITLE"), Rect2(72.0, 180.0, 396.0, 66.0), 30, DeepUI.GOLD)
	DeepUI.draw_centered(self, tr("PAUSE_SUBTITLE"), Rect2(55.0, 265.0, 430.0, 34.0), 16, DeepUI.MUTED)
	DeepUI.draw_button(self, CONTINUE_BUTTON, tr("PAUSE_CONTINUE"), &"primary", 23)
	DeepUI.draw_button(self, NEW_GAME_BUTTON, tr("PAUSE_NEW_GAME"), &"secondary", 21)
	DeepUI.draw_button(self, MAIN_MENU_BUTTON, tr("PAUSE_MAIN_MENU"), &"secondary", 21)
	DeepUI.draw_button(self, SETTINGS_BUTTON, tr("PAUSE_SETTINGS"), &"ghost", 21)


func _draw_confirmation() -> void:
	var is_main_menu := mode == Mode.CONFIRM_MAIN_MENU
	var title := tr("CONFIRM_MENU_TITLE") if is_main_menu else tr("CONFIRM_NEW_TITLE")
	var body := tr("CONFIRM_MENU_BODY") if is_main_menu else tr("CONFIRM_NEW_BODY")
	var action := tr("CONFIRM_MENU_ACTION") if is_main_menu else tr("PAUSE_NEW_GAME")
	DeepUI.draw_panel(self, Rect2(38.0, 220.0, 464.0, 455.0), DeepUI.PANEL_SOFT, DeepUI.BORDER, 22, 2, true)
	DeepUI.draw_title_plate(self, title, Rect2(70.0, 260.0, 400.0, 64.0), 27, DeepUI.DANGER)
	DeepUI.draw_centered(
		self,
		body,
		Rect2(50.0, 355.0, 440.0, 58.0),
		17,
		DeepUI.MUTED,
	)
	DeepUI.draw_button(self, CANCEL_BUTTON, tr("COMMON_CANCEL"), &"ghost", 19)
	DeepUI.draw_button(self, CONFIRM_BUTTON, action, &"danger", 17)
