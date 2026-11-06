class_name SettingsOverlay
extends Control

enum Mode {
	SETTINGS,
	CONFIRM_RESET,
}

const VIEW_SIZE := Vector2(540.0, 960.0)
const TURKISH_BUTTON := Rect2(55.0, 300.0, 200.0, 66.0)
const ENGLISH_BUTTON := Rect2(285.0, 300.0, 200.0, 66.0)
const SOUND_BUTTON := Rect2(80.0, 405.0, 380.0, 58.0)
const VOLUME_SLIDER := Rect2(80.0, 510.0, 380.0, 14.0)
const TUTORIAL_BUTTON := Rect2(80.0, 570.0, 380.0, 64.0)
const RESET_BUTTON := Rect2(80.0, 655.0, 380.0, 64.0)
const BACK_BUTTON := Rect2(80.0, 790.0, 380.0, 66.0)
const CANCEL_BUTTON := Rect2(55.0, 570.0, 200.0, 70.0)
const CONFIRM_BUTTON := Rect2(285.0, 570.0, 200.0, 70.0)

var controller: RunController
var mode: Mode = Mode.SETTINGS
var notice: String


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind(run_controller: RunController) -> void:
	controller = run_controller


func show_settings(message: String = "") -> void:
	mode = Mode.SETTINGS
	notice = message
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func show_reset_confirmation() -> void:
	mode = Mode.CONFIRM_RESET
	notice = ""
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

	if mode == Mode.SETTINGS:
		if TURKISH_BUTTON.has_point(event_position):
			controller.set_language(&"tr")
		elif ENGLISH_BUTTON.has_point(event_position):
			controller.set_language(&"en")
		elif SOUND_BUTTON.has_point(event_position):
			controller.toggle_sound()
		elif VOLUME_SLIDER.grow(24.0).has_point(event_position):
			controller.set_sound_volume(
				(event_position.x - VOLUME_SLIDER.position.x) / VOLUME_SLIDER.size.x
			)
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
	DeepUI.draw_cave_background(self, VIEW_SIZE)
	if mode == Mode.SETTINGS:
		_draw_settings()
	else:
		_draw_reset_confirmation()


func _draw_settings() -> void:
	DeepUI.draw_panel(self, Rect2(38.0, 76.0, 464.0, 820.0), Color(DeepUI.PANEL_SOFT, 0.96), DeepUI.BORDER, 22, 2, true)
	DeepUI.draw_title_plate(self, tr("SETTINGS_TITLE"), Rect2(72.0, 105.0, 396.0, 64.0), 32, DeepUI.GOLD)
	DeepUI.draw_centered(self, tr("SETTINGS_LANGUAGE"), Rect2(30.0, 220.0, 480.0, 36.0), 18, DeepUI.MUTED)
	var selected_language := &"tr"
	if controller != null and controller.app_settings != null:
		selected_language = controller.app_settings.language
	_draw_choice(TURKISH_BUTTON, tr("SETTINGS_TURKISH"), selected_language == &"tr")
	_draw_choice(ENGLISH_BUTTON, tr("SETTINGS_ENGLISH"), selected_language == &"en")
	var sound_enabled := true
	var sound_volume := 0.8
	if controller != null and controller.app_settings != null:
		sound_enabled = controller.app_settings.sound_enabled
		sound_volume = controller.app_settings.sound_volume
	var sound_label := tr("SETTINGS_SOUND_ON") if sound_enabled else tr("SETTINGS_SOUND_OFF")
	DeepUI.draw_button(self, SOUND_BUTTON, sound_label, &"core" if sound_enabled else &"ghost", 19)
	DeepUI.draw_centered(
		self,
		tr("SETTINGS_VOLUME") % int(round(sound_volume * 100.0)),
		Rect2(80.0, 470.0, 380.0, 30.0),
		15,
		DeepUI.MUTED,
	)
	DeepUI.draw_panel(self, VOLUME_SLIDER.grow(4.0), DeepUI.PANEL_RAISED, DeepUI.BORDER_SOFT, 9, 1, false)
	if sound_volume > 0.0:
		DeepUI.draw_panel(self, Rect2(VOLUME_SLIDER.position, Vector2(VOLUME_SLIDER.size.x * sound_volume, VOLUME_SLIDER.size.y)), DeepUI.GOLD, DeepUI.GOLD, 7, 0, false)
	draw_circle(Vector2(VOLUME_SLIDER.position.x + VOLUME_SLIDER.size.x * sound_volume, VOLUME_SLIDER.get_center().y), 12.0, DeepUI.GOLD_LIGHT)
	draw_arc(Vector2(VOLUME_SLIDER.position.x + VOLUME_SLIDER.size.x * sound_volume, VOLUME_SLIDER.get_center().y), 12.0, 0.0, TAU, 20, DeepUI.GOLD_DARK, 2.0, true)
	DeepUI.draw_button(self, TUTORIAL_BUTTON, tr("SETTINGS_TUTORIAL"), &"secondary", 19)
	DeepUI.draw_button(self, RESET_BUTTON, tr("SETTINGS_RESET"), &"danger", 19)
	if not notice.is_empty():
		DeepUI.draw_centered(self, notice, Rect2(55.0, 735.0, 430.0, 38.0), 13, DeepUI.DANGER)
	DeepUI.draw_button(self, BACK_BUTTON, tr("COMMON_BACK"), &"primary", 19)


func _draw_reset_confirmation() -> void:
	DeepUI.draw_panel(self, Rect2(38.0, 220.0, 464.0, 455.0), DeepUI.PANEL_SOFT, DeepUI.BORDER, 22, 2, true)
	DeepUI.draw_title_plate(self, tr("CONFIRM_RESET_TITLE"), Rect2(70.0, 260.0, 400.0, 64.0), 28, DeepUI.DANGER)
	DeepUI.draw_centered(self, tr("CONFIRM_RESET_BODY"), Rect2(45.0, 370.0, 450.0, 50.0), 17, DeepUI.MUTED)
	DeepUI.draw_button(self, CANCEL_BUTTON, tr("COMMON_CANCEL"), &"ghost", 19)
	DeepUI.draw_button(self, CONFIRM_BUTTON, tr("CONFIRM_RESET_ACTION"), &"danger", 19)


func _draw_choice(rect: Rect2, label: String, selected: bool) -> void:
	DeepUI.draw_button(self, rect, label, &"primary" if selected else &"ghost", 19)
