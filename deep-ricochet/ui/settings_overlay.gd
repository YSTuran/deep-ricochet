class_name SettingsOverlay
extends Control

enum Mode {
	SETTINGS,
	CONFIRM_DELETE_ALL,
}

const VIEW_SIZE := Vector2(540.0, 960.0)
const TURKISH_BUTTON := Rect2(55.0, 215.0, 200.0, 58.0)
const ENGLISH_BUTTON := Rect2(285.0, 215.0, 200.0, 58.0)
const SFX_BUTTON := Rect2(80.0, 305.0, 380.0, 52.0)
const SFX_SLIDER := Rect2(80.0, 403.0, 380.0, 14.0)
const MUSIC_BUTTON := Rect2(80.0, 447.0, 380.0, 52.0)
const MUSIC_SLIDER := Rect2(80.0, 545.0, 380.0, 14.0)
const SHAKE_BUTTON := Rect2(55.0, 585.0, 210.0, 52.0)
const HAPTICS_BUTTON := Rect2(275.0, 585.0, 210.0, 52.0)
const TUTORIAL_BUTTON := Rect2(80.0, 655.0, 380.0, 56.0)
const DELETE_DATA_BUTTON := Rect2(80.0, 725.0, 380.0, 56.0)
const BACK_BUTTON := Rect2(80.0, 815.0, 380.0, 58.0)
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


func show_delete_all_confirmation() -> void:
	mode = Mode.CONFIRM_DELETE_ALL
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
	if mode == Mode.SETTINGS:
		if TURKISH_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			controller.set_language(&"tr")
		elif ENGLISH_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			controller.set_language(&"en")
		elif SFX_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			controller.toggle_sfx()
		elif SFX_SLIDER.grow(22.0).has_point(event_position):
			AudioManager.play_ui_click()
			controller.set_sfx_volume(
				(event_position.x - SFX_SLIDER.position.x) / SFX_SLIDER.size.x
			)
		elif MUSIC_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			controller.toggle_music()
		elif MUSIC_SLIDER.grow(22.0).has_point(event_position):
			AudioManager.play_ui_click()
			controller.set_music_volume(
				(event_position.x - MUSIC_SLIDER.position.x) / MUSIC_SLIDER.size.x
			)
		elif SHAKE_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			controller.toggle_screen_shake()
		elif HAPTICS_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			controller.toggle_haptics()
		elif TUTORIAL_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			controller.show_tutorial_from_settings()
		elif DELETE_DATA_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			show_delete_all_confirmation()
		elif BACK_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			controller.close_settings()
	else:
		if CANCEL_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			show_settings()
		elif CONFIRM_BUTTON.has_point(event_position):
			AudioManager.play_ui_click()
			controller.confirm_delete_all_data()


func _draw() -> void:
	DeepUI.draw_cave_background(self, VIEW_SIZE)
	if mode == Mode.SETTINGS:
		_draw_settings()
	else:
		_draw_delete_confirmation()


func _draw_settings() -> void:
	DeepUI.draw_panel(self, Rect2(38.0, 55.0, 464.0, 850.0), Color(DeepUI.PANEL_SOFT, 0.96), DeepUI.BORDER, 22, 2, true)
	DeepUI.draw_title_plate(self, tr("SETTINGS_TITLE"), Rect2(72.0, 82.0, 396.0, 60.0), 30, DeepUI.GOLD)
	DeepUI.draw_centered(self, tr("SETTINGS_LANGUAGE"), Rect2(30.0, 166.0, 480.0, 30.0), 17, DeepUI.MUTED)
	var selected_language := &"tr"
	if controller != null and controller.app_settings != null:
		selected_language = controller.app_settings.language
	_draw_choice(TURKISH_BUTTON, tr("SETTINGS_TURKISH"), selected_language == &"tr")
	_draw_choice(ENGLISH_BUTTON, tr("SETTINGS_ENGLISH"), selected_language == &"en")
	var sfx_enabled := true
	var sfx_volume := 0.8
	var music_enabled := true
	var music_volume := 0.28
	var shake_enabled := true
	var haptics_enabled := true
	if controller != null and controller.app_settings != null:
		sfx_enabled = controller.app_settings.sfx_enabled
		sfx_volume = controller.app_settings.sfx_volume
		music_enabled = controller.app_settings.music_enabled
		music_volume = controller.app_settings.music_volume
		shake_enabled = controller.app_settings.shake_enabled
		haptics_enabled = controller.app_settings.haptics_enabled
	var sfx_label := tr("SETTINGS_SFX_ON") if sfx_enabled else tr("SETTINGS_SFX_OFF")
	DeepUI.draw_button(self, SFX_BUTTON, sfx_label, &"core" if sfx_enabled else &"ghost", 17)
	DeepUI.draw_centered(
		self,
		tr("SETTINGS_SFX_VOLUME") % int(round(sfx_volume * 100.0)),
		Rect2(80.0, 365.0, 380.0, 26.0),
		14,
		DeepUI.MUTED,
	)
	_draw_volume_slider(SFX_SLIDER, sfx_volume)
	var music_label := tr("SETTINGS_MUSIC_ON") if music_enabled else tr("SETTINGS_MUSIC_OFF")
	DeepUI.draw_button(self, MUSIC_BUTTON, music_label, &"core" if music_enabled else &"ghost", 17)
	DeepUI.draw_centered(
		self,
		tr("SETTINGS_MUSIC_VOLUME") % int(round(music_volume * 100.0)),
		Rect2(80.0, 507.0, 380.0, 26.0),
		14,
		DeepUI.MUTED,
	)
	_draw_volume_slider(MUSIC_SLIDER, music_volume)
	var shake_label := tr("SETTINGS_SHAKE_ON") if shake_enabled else tr("SETTINGS_SHAKE_OFF")
	DeepUI.draw_button(self, SHAKE_BUTTON, shake_label, &"secondary" if shake_enabled else &"ghost", 13)
	var haptics_label := tr("SETTINGS_HAPTICS_ON") if haptics_enabled else tr("SETTINGS_HAPTICS_OFF")
	DeepUI.draw_button(self, HAPTICS_BUTTON, haptics_label, &"secondary" if haptics_enabled else &"ghost", 14)
	DeepUI.draw_button(self, TUTORIAL_BUTTON, tr("SETTINGS_TUTORIAL"), &"secondary", 19)
	DeepUI.draw_button(self, DELETE_DATA_BUTTON, tr("SETTINGS_DELETE_DATA"), &"danger", 18)
	if not notice.is_empty():
		DeepUI.draw_centered(self, notice, Rect2(55.0, 785.0, 430.0, 26.0), 12, DeepUI.DANGER)
	DeepUI.draw_button(self, BACK_BUTTON, tr("COMMON_BACK"), &"primary", 19)


func _draw_delete_confirmation() -> void:
	DeepUI.draw_panel(self, Rect2(38.0, 220.0, 464.0, 455.0), DeepUI.PANEL_SOFT, DeepUI.BORDER, 22, 2, true)
	DeepUI.draw_title_plate(self, tr("CONFIRM_DELETE_TITLE"), Rect2(70.0, 260.0, 400.0, 64.0), 28, DeepUI.DANGER)
	DeepUI.draw_centered(self, tr("CONFIRM_DELETE_BODY"), Rect2(45.0, 370.0, 450.0, 64.0), 17, DeepUI.MUTED)
	DeepUI.draw_button(self, CANCEL_BUTTON, tr("COMMON_CANCEL"), &"ghost", 19)
	DeepUI.draw_button(self, CONFIRM_BUTTON, tr("CONFIRM_DELETE_ACTION"), &"danger", 19)


func _draw_volume_slider(rect: Rect2, volume: float) -> void:
	DeepUI.draw_panel(self, rect.grow(4.0), DeepUI.PANEL_RAISED, DeepUI.BORDER_SOFT, 9, 1, false)
	if volume > 0.0:
		DeepUI.draw_panel(
			self,
			Rect2(rect.position, Vector2(rect.size.x * volume, rect.size.y)),
			DeepUI.GOLD,
			DeepUI.GOLD,
			7,
			0,
			false,
		)
	var knob := Vector2(rect.position.x + rect.size.x * volume, rect.get_center().y)
	draw_circle(knob, 11.0, DeepUI.GOLD_LIGHT)
	draw_arc(knob, 11.0, 0.0, TAU, 20, DeepUI.GOLD_DARK, 2.0, true)


func _draw_choice(rect: Rect2, label: String, selected: bool) -> void:
	DeepUI.draw_button(self, rect, label, &"primary" if selected else &"ghost", 19)
