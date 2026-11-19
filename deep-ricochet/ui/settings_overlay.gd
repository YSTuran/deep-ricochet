class_name SettingsOverlay
extends Control

const TouchControlsScript := preload("res://ui/touch_controls.gd")

enum Mode {
	SETTINGS,
	CONFIRM_DELETE_ALL,
}

enum Page {
	ROOT,
	GENERAL,
	AUDIO,
	DISPLAY_FEEDBACK,
}

const VIEW_SIZE := Vector2(540.0, 960.0)
const GENERAL_CATEGORY_BUTTON := Rect2(80.0, 220.0, 380.0, 64.0)
const AUDIO_CATEGORY_BUTTON := Rect2(80.0, 365.0, 380.0, 64.0)
const DISPLAY_CATEGORY_BUTTON := Rect2(80.0, 510.0, 380.0, 64.0)
const TURKISH_BUTTON := Rect2(55.0, 245.0, 210.0, 58.0)
const ENGLISH_BUTTON := Rect2(275.0, 245.0, 210.0, 58.0)
const TUTORIAL_BUTTON := Rect2(80.0, 390.0, 380.0, 58.0)
const DELETE_DATA_BUTTON := Rect2(80.0, 500.0, 380.0, 58.0)
const SFX_BUTTON := Rect2(80.0, 220.0, 380.0, 58.0)
const SFX_SLIDER := Rect2(80.0, 345.0, 380.0, 14.0)
const MUSIC_BUTTON := Rect2(80.0, 455.0, 380.0, 58.0)
const MUSIC_SLIDER := Rect2(80.0, 580.0, 380.0, 14.0)
const PERFORMANCE_BUTTON := Rect2(55.0, 255.0, 210.0, 54.0)
const GRAPHICS_BUTTON := Rect2(275.0, 255.0, 210.0, 54.0)
const SHAKE_BUTTON := Rect2(80.0, 400.0, 380.0, 58.0)
const HAPTICS_BUTTON := Rect2(80.0, 495.0, 380.0, 58.0)
const BACK_BUTTON := Rect2(80.0, 835.0, 380.0, 58.0)
const CANCEL_BUTTON := Rect2(55.0, 570.0, 200.0, 70.0)
const CONFIRM_BUTTON := Rect2(285.0, 570.0, 200.0, 70.0)

const ACTION_GENERAL := &"general"
const ACTION_AUDIO := &"audio"
const ACTION_DISPLAY := &"display"
const ACTION_TURKISH := &"turkish"
const ACTION_ENGLISH := &"english"
const ACTION_TUTORIAL := &"tutorial"
const ACTION_DELETE_DATA := &"delete_data"
const ACTION_SFX := &"sfx"
const ACTION_SFX_SLIDER := &"sfx_slider"
const ACTION_MUSIC := &"music"
const ACTION_MUSIC_SLIDER := &"music_slider"
const ACTION_PERFORMANCE := &"performance"
const ACTION_GRAPHICS := &"graphics"
const ACTION_SHAKE := &"shake"
const ACTION_HAPTICS := &"haptics"
const ACTION_BACK := &"back"
const ACTION_CANCEL := &"cancel"
const ACTION_CONFIRM := &"confirm"

var controller: RunController
var mode: Mode = Mode.SETTINGS
var page: Page = Page.ROOT
var notice: String
var touch_controls = TouchControlsScript.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind(run_controller: RunController) -> void:
	controller = run_controller


func show_settings(message: String = "", requested_page: Page = Page.ROOT) -> void:
	mode = Mode.SETTINGS
	page = requested_page
	notice = message
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func show_delete_all_confirmation() -> void:
	mode = Mode.CONFIRM_DELETE_ALL
	page = Page.GENERAL
	notice = ""
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func hide_overlay() -> void:
	touch_controls.reset()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh_locale() -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not TouchControlsScript.handles(event) or DeepUI.is_emulated_mouse_event(event):
		return
	accept_event()
	var action: StringName = touch_controls.process(event, _touch_targets())
	if touch_controls.changed:
		queue_redraw()
	if controller == null:
		return
	if touch_controls.active_action == ACTION_SFX_SLIDER \
		and touch_controls.phase in [&"pressed", &"dragged"]:
		_set_sfx_from_position(touch_controls.last_position)
		return
	if touch_controls.active_action == ACTION_MUSIC_SLIDER \
		and touch_controls.phase in [&"pressed", &"dragged"]:
		_set_music_from_position(touch_controls.last_position)
		return
	if action.is_empty():
		return
	if action == ACTION_SFX_SLIDER:
		_set_sfx_from_position(touch_controls.last_position)
		return
	if action == ACTION_MUSIC_SLIDER:
		_set_music_from_position(touch_controls.last_position)
		return
	AudioManager.play_ui_click()
	_activate_action(action)


func _activate_action(action: StringName) -> void:
	match action:
		ACTION_GENERAL:
			_open_page(Page.GENERAL, false)
		ACTION_AUDIO:
			_open_page(Page.AUDIO, false)
		ACTION_DISPLAY:
			_open_page(Page.DISPLAY_FEEDBACK, false)
		ACTION_TURKISH:
			controller.set_language(&"tr")
		ACTION_ENGLISH:
			controller.set_language(&"en")
		ACTION_TUTORIAL:
			controller.show_tutorial_from_settings()
		ACTION_DELETE_DATA:
			show_delete_all_confirmation()
		ACTION_SFX:
			controller.toggle_sfx()
		ACTION_MUSIC:
			controller.toggle_music()
		ACTION_PERFORMANCE:
			controller.set_quality_mode(AppSettings.QualityMode.PERFORMANCE)
		ACTION_GRAPHICS:
			controller.set_quality_mode(AppSettings.QualityMode.GRAPHICS)
		ACTION_SHAKE:
			controller.toggle_screen_shake()
		ACTION_HAPTICS:
			controller.toggle_haptics()
		ACTION_CANCEL:
			show_settings("", Page.GENERAL)
		ACTION_CONFIRM:
			controller.confirm_delete_all_data()
		ACTION_BACK:
			if page == Page.ROOT:
				controller.close_settings()
			else:
				_open_page(Page.ROOT, false)


func _set_sfx_from_position(position: Vector2) -> void:
	controller.set_sfx_volume(clampf(
		(position.x - SFX_SLIDER.position.x) / SFX_SLIDER.size.x,
		0.0,
		1.0,
	))
	queue_redraw()


func _set_music_from_position(position: Vector2) -> void:
	controller.set_music_volume(clampf(
		(position.x - MUSIC_SLIDER.position.x) / MUSIC_SLIDER.size.x,
		0.0,
		1.0,
	))
	queue_redraw()


func _open_page(next_page: Page, play_sound: bool = true) -> void:
	if play_sound:
		AudioManager.play_ui_click()
	page = next_page
	notice = ""
	queue_redraw()


func _draw() -> void:
	DeepUI.draw_cave_background(self, VIEW_SIZE)
	if mode == Mode.CONFIRM_DELETE_ALL:
		_draw_delete_confirmation()
		return
	DeepUI.draw_panel(
		self,
		Rect2(38.0, 30.0, 464.0, 900.0),
		Color(DeepUI.PANEL_SOFT, 0.96),
		DeepUI.BORDER,
		22,
		2,
		true,
	)
	match page:
		Page.ROOT:
			_draw_root_page()
		Page.GENERAL:
			_draw_general_page()
		Page.AUDIO:
			_draw_audio_page()
		Page.DISPLAY_FEEDBACK:
			_draw_display_page()


func _draw_root_page() -> void:
	_draw_page_title(tr("SETTINGS_TITLE"))
	DeepUI.draw_centered(
		self,
		tr("SETTINGS_CATEGORY_HINT"),
		Rect2(50.0, 155.0, 440.0, 32.0),
		15,
		DeepUI.MUTED,
	)
	DeepUI.draw_button(
		self, GENERAL_CATEGORY_BUTTON, tr("SETTINGS_GENERAL"), &"secondary", 22, true,
		touch_controls.is_pressed(ACTION_GENERAL),
	)
	DeepUI.draw_centered(self, tr("SETTINGS_GENERAL_HINT"), Rect2(60.0, 290.0, 420.0, 32.0), 14, DeepUI.MUTED)
	DeepUI.draw_button(
		self, AUDIO_CATEGORY_BUTTON, tr("SETTINGS_AUDIO"), &"secondary", 22, true,
		touch_controls.is_pressed(ACTION_AUDIO),
	)
	DeepUI.draw_centered(self, tr("SETTINGS_AUDIO_HINT"), Rect2(60.0, 435.0, 420.0, 32.0), 14, DeepUI.MUTED)
	DeepUI.draw_button(
		self, DISPLAY_CATEGORY_BUTTON, tr("SETTINGS_DISPLAY_FEEDBACK"), &"secondary", 20, true,
		touch_controls.is_pressed(ACTION_DISPLAY),
	)
	DeepUI.draw_centered(self, tr("SETTINGS_DISPLAY_HINT"), Rect2(60.0, 580.0, 420.0, 40.0), 14, DeepUI.MUTED)
	if not notice.is_empty():
		DeepUI.draw_centered(self, notice, Rect2(55.0, 750.0, 430.0, 40.0), 12, DeepUI.DANGER)
	_draw_back_button()


func _draw_general_page() -> void:
	_draw_page_title(tr("SETTINGS_GENERAL"))
	DeepUI.draw_centered(self, tr("SETTINGS_LANGUAGE"), Rect2(30.0, 190.0, 480.0, 30.0), 17, DeepUI.MUTED)
	var selected_language := &"tr"
	if controller != null and controller.app_settings != null:
		selected_language = controller.app_settings.language
	_draw_choice(TURKISH_BUTTON, tr("SETTINGS_TURKISH"), selected_language == &"tr", ACTION_TURKISH)
	_draw_choice(ENGLISH_BUTTON, tr("SETTINGS_ENGLISH"), selected_language == &"en", ACTION_ENGLISH)
	DeepUI.draw_button(
		self, TUTORIAL_BUTTON, tr("SETTINGS_TUTORIAL"), &"secondary", 19, true,
		touch_controls.is_pressed(ACTION_TUTORIAL),
	)
	DeepUI.draw_button(
		self, DELETE_DATA_BUTTON, tr("SETTINGS_DELETE_DATA"), &"danger", 18, true,
		touch_controls.is_pressed(ACTION_DELETE_DATA),
	)
	if not notice.is_empty():
		DeepUI.draw_centered(self, notice, Rect2(55.0, 600.0, 430.0, 54.0), 12, DeepUI.MUTED)
	_draw_back_button()


func _draw_audio_page() -> void:
	_draw_page_title(tr("SETTINGS_AUDIO"))
	var sfx_enabled := true
	var sfx_volume := 0.8
	var music_enabled := true
	var music_volume := 0.28
	if controller != null and controller.app_settings != null:
		sfx_enabled = controller.app_settings.sfx_enabled
		sfx_volume = controller.app_settings.sfx_volume
		music_enabled = controller.app_settings.music_enabled
		music_volume = controller.app_settings.music_volume
	var sfx_label := tr("SETTINGS_SFX_ON") if sfx_enabled else tr("SETTINGS_SFX_OFF")
	DeepUI.draw_button(
		self, SFX_BUTTON, sfx_label, &"core" if sfx_enabled else &"ghost", 17, true,
		touch_controls.is_pressed(ACTION_SFX),
	)
	DeepUI.draw_centered(
		self,
		tr("SETTINGS_SFX_VOLUME") % int(round(sfx_volume * 100.0)),
		Rect2(80.0, 300.0, 380.0, 26.0),
		14,
		DeepUI.MUTED,
	)
	_draw_volume_slider(SFX_SLIDER, sfx_volume, touch_controls.is_pressed(ACTION_SFX_SLIDER))
	var music_label := tr("SETTINGS_MUSIC_ON") if music_enabled else tr("SETTINGS_MUSIC_OFF")
	DeepUI.draw_button(
		self, MUSIC_BUTTON, music_label, &"core" if music_enabled else &"ghost", 17, true,
		touch_controls.is_pressed(ACTION_MUSIC),
	)
	DeepUI.draw_centered(
		self,
		tr("SETTINGS_MUSIC_VOLUME") % int(round(music_volume * 100.0)),
		Rect2(80.0, 535.0, 380.0, 26.0),
		14,
		DeepUI.MUTED,
	)
	_draw_volume_slider(MUSIC_SLIDER, music_volume, touch_controls.is_pressed(ACTION_MUSIC_SLIDER))
	_draw_back_button()


func _draw_display_page() -> void:
	_draw_page_title(tr("SETTINGS_DISPLAY_FEEDBACK"))
	var shake_enabled := true
	var haptics_enabled := true
	var quality_mode := AppSettings.QualityMode.PERFORMANCE
	if controller != null and controller.app_settings != null:
		shake_enabled = controller.app_settings.shake_enabled
		haptics_enabled = controller.app_settings.haptics_enabled
		quality_mode = controller.app_settings.quality_mode
	DeepUI.draw_centered(self, tr("SETTINGS_QUALITY"), Rect2(55.0, 205.0, 430.0, 28.0), 15, DeepUI.MUTED)
	_draw_choice(
		PERFORMANCE_BUTTON, tr("SETTINGS_PERFORMANCE"),
		quality_mode == AppSettings.QualityMode.PERFORMANCE, ACTION_PERFORMANCE,
	)
	_draw_choice(
		GRAPHICS_BUTTON, tr("SETTINGS_GRAPHICS"),
		quality_mode == AppSettings.QualityMode.GRAPHICS, ACTION_GRAPHICS,
	)
	var shake_label := tr("SETTINGS_SHAKE_ON") if shake_enabled else tr("SETTINGS_SHAKE_OFF")
	DeepUI.draw_button(
		self, SHAKE_BUTTON, shake_label, &"secondary" if shake_enabled else &"ghost", 15, true,
		touch_controls.is_pressed(ACTION_SHAKE),
	)
	var haptics_label := tr("SETTINGS_HAPTICS_ON") if haptics_enabled else tr("SETTINGS_HAPTICS_OFF")
	DeepUI.draw_button(
		self, HAPTICS_BUTTON, haptics_label, &"secondary" if haptics_enabled else &"ghost", 16, true,
		touch_controls.is_pressed(ACTION_HAPTICS),
	)
	_draw_back_button()


func _draw_page_title(title: String) -> void:
	DeepUI.draw_title_plate(self, title, Rect2(72.0, 72.0, 396.0, 60.0), 28, DeepUI.GOLD)


func _draw_delete_confirmation() -> void:
	DeepUI.draw_panel(self, Rect2(38.0, 220.0, 464.0, 455.0), DeepUI.PANEL_SOFT, DeepUI.BORDER, 22, 2, true)
	DeepUI.draw_title_plate(self, tr("CONFIRM_DELETE_TITLE"), Rect2(70.0, 260.0, 400.0, 64.0), 28, DeepUI.DANGER)
	DeepUI.draw_wrapped(self, tr("CONFIRM_DELETE_BODY"), Rect2(45.0, 360.0, 450.0, 84.0), 17, DeepUI.MUTED)
	DeepUI.draw_button(
		self, CANCEL_BUTTON, tr("COMMON_CANCEL"), &"ghost", 19, true,
		touch_controls.is_pressed(ACTION_CANCEL),
	)
	DeepUI.draw_button(
		self, CONFIRM_BUTTON, tr("CONFIRM_DELETE_ACTION"), &"danger", 19, true,
		touch_controls.is_pressed(ACTION_CONFIRM),
	)


func _draw_volume_slider(rect: Rect2, volume: float, pressed: bool) -> void:
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
	var knob_radius := 14.0 if pressed else 11.0
	draw_circle(knob, knob_radius, DeepUI.GOLD_LIGHT)
	draw_arc(knob, knob_radius, 0.0, TAU, 20, DeepUI.GOLD_DARK, 2.0, true)


func _draw_choice(rect: Rect2, label: String, selected: bool, action: StringName) -> void:
	DeepUI.draw_button(
		self, rect, label, &"primary" if selected else &"ghost", 19, true,
		touch_controls.is_pressed(action),
	)


func _draw_back_button() -> void:
	DeepUI.draw_button(
		self, BACK_BUTTON, tr("COMMON_BACK"), &"primary", 19, true,
		touch_controls.is_pressed(ACTION_BACK),
	)


func _touch_targets() -> Dictionary:
	if mode == Mode.CONFIRM_DELETE_ALL:
		return {
			ACTION_CANCEL: CANCEL_BUTTON,
			ACTION_CONFIRM: CONFIRM_BUTTON,
		}
	match page:
		Page.ROOT:
			return {
				ACTION_GENERAL: GENERAL_CATEGORY_BUTTON,
				ACTION_AUDIO: AUDIO_CATEGORY_BUTTON,
				ACTION_DISPLAY: DISPLAY_CATEGORY_BUTTON,
				ACTION_BACK: BACK_BUTTON,
			}
		Page.GENERAL:
			return {
				ACTION_TURKISH: TURKISH_BUTTON,
				ACTION_ENGLISH: ENGLISH_BUTTON,
				ACTION_TUTORIAL: TUTORIAL_BUTTON,
				ACTION_DELETE_DATA: DELETE_DATA_BUTTON,
				ACTION_BACK: BACK_BUTTON,
			}
		Page.AUDIO:
			return {
				ACTION_SFX: SFX_BUTTON,
				ACTION_SFX_SLIDER: SFX_SLIDER.grow(24.0),
				ACTION_MUSIC: MUSIC_BUTTON,
				ACTION_MUSIC_SLIDER: MUSIC_SLIDER.grow(24.0),
				ACTION_BACK: BACK_BUTTON,
			}
		Page.DISPLAY_FEEDBACK:
			return {
				ACTION_PERFORMANCE: PERFORMANCE_BUTTON,
				ACTION_GRAPHICS: GRAPHICS_BUTTON,
				ACTION_SHAKE: SHAKE_BUTTON,
				ACTION_HAPTICS: HAPTICS_BUTTON,
				ACTION_BACK: BACK_BUTTON,
			}
	return {}
