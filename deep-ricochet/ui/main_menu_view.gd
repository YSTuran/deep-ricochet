class_name MainMenuView
extends Control

const VIEW_SIZE := Vector2(540.0, 960.0)
const CONTINUE_BUTTON := Rect2(80.0, 510.0, 380.0, 76.0)
const NEW_GAME_BUTTON := Rect2(80.0, 610.0, 380.0, 76.0)
const SETTINGS_BUTTON := Rect2(80.0, 710.0, 380.0, 66.0)
const CORE_TEXTURE: Texture2D = preload("res://art/source/cekirdek.png")

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
	if continue_available and CONTINUE_BUTTON.has_point(event_position):
		AudioManager.play_ui_click()
		controller.continue_saved_run()
	elif _new_game_button_rect().has_point(event_position):
		AudioManager.play_ui_click()
		controller.request_new_game_from_menu()
	elif _settings_button_rect().has_point(event_position):
		AudioManager.play_ui_click()
		controller.open_settings_from_main_menu()


func _draw() -> void:
	DeepUI.draw_cave_background(self, VIEW_SIZE)
	DeepUI.draw_glow(self, Vector2(270.0, 208.0), 70.0, DeepUI.CORE)
	draw_texture_rect(CORE_TEXTURE, Rect2(190.0, 128.0, 160.0, 160.0), false)
	DeepUI.draw_title_plate(
		self,
		"DEEP RICOCHET",
		Rect2(70.0, 310.0, 400.0, 68.0),
		36,
		DeepUI.CORE,
	)
	DeepUI.draw_centered(
		self,
		tr("MENU_TAGLINE"),
		Rect2(30.0, 390.0, 480.0, 32.0),
		18,
		DeepUI.MUTED,
	)
	if controller != null and controller.profile != null:
		DeepUI.draw_panel(
			self,
			Rect2(80.0, 434.0, 380.0, 58.0),
			Color(DeepUI.PANEL_SOFT, 0.92),
			DeepUI.BORDER_SOFT,
			12,
			1,
			false,
		)
		DeepUI.draw_centered(
			self,
			tr("PROFILE_BEST") % controller.profile.best_score,
			Rect2(90.0, 439.0, 170.0, 44.0),
			16,
			DeepUI.GOLD,
		)
		DeepUI.draw_centered(
			self,
			tr("PROFILE_STATS") % [
				controller.profile.runs_played,
				controller.profile.successful_runs,
				controller.profile.total_cores_broken,
			],
			Rect2(250.0, 439.0, 200.0, 44.0),
			13,
			DeepUI.MUTED,
		)
	if continue_available:
		DeepUI.draw_button(self, CONTINUE_BUTTON, tr("MENU_CONTINUE"), &"primary", 24)
	DeepUI.draw_button(
		self,
		_new_game_button_rect(),
		tr("MENU_NEW_GAME"),
		&"secondary" if continue_available else &"primary",
		22,
	)
	DeepUI.draw_button(self, _settings_button_rect(), tr("MENU_SETTINGS"), &"ghost", 19)
	if not notice.is_empty():
		DeepUI.draw_centered(self, notice, Rect2(45.0, 800.0, 450.0, 58.0), 15, DeepUI.MUTED)
	DeepUI.draw_centered(
		self,
		tr("MENU_OFFLINE"),
		Rect2(30.0, 895.0, 480.0, 30.0),
		14,
		Color(DeepUI.MUTED, 0.7),
	)


func _new_game_button_rect() -> Rect2:
	return NEW_GAME_BUTTON if continue_available else CONTINUE_BUTTON


func _settings_button_rect() -> Rect2:
	return SETTINGS_BUTTON if continue_available else NEW_GAME_BUTTON
