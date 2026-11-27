class_name MainMenuView
extends Control

const TouchControlsScript := preload("res://ui/touch_controls.gd")

const VIEW_SIZE := Vector2(540.0, 960.0)
const CONTINUE_BUTTON := Rect2(80.0, 500.0, 380.0, 66.0)
const NEW_GAME_BUTTON := Rect2(80.0, 580.0, 380.0, 66.0)
const DAILY_BUTTON := Rect2(80.0, 660.0, 380.0, 66.0)
const SETTINGS_BUTTON := Rect2(80.0, 740.0, 380.0, 62.0)
const CREDITS_LINK := Rect2(145.0, 867.0, 250.0, 36.0)
const CORE_TEXTURE: Texture2D = preload("res://assets/images/blocks/cekirdek.png")
const ACTION_CONTINUE := &"continue"
const ACTION_NEW_GAME := &"new_game"
const ACTION_DAILY := &"daily"
const ACTION_SETTINGS := &"settings"
const ACTION_CREDITS := &"credits"

var controller: RunController
var continue_available := false
var notice: String
var touch_controls = TouchControlsScript.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind(run_controller: RunController) -> void:
	controller = run_controller


func show_menu(can_continue: bool, message: String = "") -> void:
	if controller != null:
		controller._sync_daily_record()
	continue_available = can_continue
	notice = message
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func hide_menu() -> void:
	touch_controls.reset()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if not TouchControlsScript.handles(event) or DeepUI.is_emulated_mouse_event(event):
		return
	accept_event()
	var action: StringName = touch_controls.process(event, _touch_targets())
	if touch_controls.changed:
		queue_redraw()
	if action.is_empty() or controller == null:
		return
	AudioManager.play_ui_click()
	match action:
		ACTION_CONTINUE:
			controller.continue_saved_run()
		ACTION_NEW_GAME:
			controller.request_new_game_from_menu()
		ACTION_DAILY:
			controller.request_daily_run()
		ACTION_SETTINGS:
			controller.open_settings_from_main_menu()
		ACTION_CREDITS:
			controller.open_credits()


func _draw() -> void:
	DeepUI.draw_cave_background(self, VIEW_SIZE)
	var core_color := CaveTheme.block_color(BlockState.BlockType.CORE)
	DeepUI.draw_glow(self, Vector2(270.0, 208.0), 70.0, core_color)
	CaveTheme.draw_texture(
		self,
		CORE_TEXTURE,
		Rect2(190.0, 128.0, 160.0, 160.0),
		BlockState.BlockType.CORE,
	)
	DeepUI.draw_title_plate(
		self,
		"DEEP RICOCHET",
		Rect2(70.0, 310.0, 400.0, 68.0),
		36,
		core_color,
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
			tr("PROFILE_LAST_SCORE") % controller.profile.last_score,
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
		DeepUI.draw_button(
			self, CONTINUE_BUTTON, tr("MENU_CONTINUE"), &"primary", 24, true,
			touch_controls.is_pressed(ACTION_CONTINUE),
		)
	DeepUI.draw_button(
		self,
		_new_game_button_rect(),
		tr("MENU_NEW_GAME"),
		&"secondary" if continue_available else &"primary",
		22,
		true,
		touch_controls.is_pressed(ACTION_NEW_GAME),
	)
	var daily_label := tr("MENU_DAILY_MINE")
	if controller != null and controller.profile != null \
		and controller.profile.daily_attempts > 0 \
		and controller.profile.daily_key == controller.current_daily_key():
		daily_label = tr("MENU_DAILY_SCORE") % controller.profile.best_for_daily_key(
			controller.current_daily_key()
		)
	DeepUI.draw_button(
		self, _daily_button_rect(), daily_label, &"core", 19, true,
		touch_controls.is_pressed(ACTION_DAILY),
	)
	DeepUI.draw_button(
		self, _settings_button_rect(), tr("MENU_SETTINGS"), &"ghost", 19, true,
		touch_controls.is_pressed(ACTION_SETTINGS),
	)
	if not notice.is_empty():
		DeepUI.draw_centered(self, notice, Rect2(45.0, 818.0, 450.0, 52.0), 14, DeepUI.MUTED)
	var credits_color := DeepUI.GOLD_LIGHT \
		if touch_controls.is_pressed(ACTION_CREDITS) else DeepUI.MUTED
	DeepUI.draw_centered(
		self,
		tr("MENU_CREDITS"),
		CREDITS_LINK,
		13,
		credits_color,
	)
	draw_line(
		Vector2(CREDITS_LINK.position.x + 58.0, CREDITS_LINK.end.y - 5.0),
		Vector2(CREDITS_LINK.end.x - 58.0, CREDITS_LINK.end.y - 5.0),
		Color(credits_color, 0.7),
		1.0,
	)
	DeepUI.draw_centered(
		self,
		tr("MENU_OFFLINE"),
		Rect2(30.0, 914.0, 480.0, 26.0),
		12,
		Color(DeepUI.MUTED, 0.7),
	)


func _new_game_button_rect() -> Rect2:
	return NEW_GAME_BUTTON if continue_available else CONTINUE_BUTTON


func _settings_button_rect() -> Rect2:
	return SETTINGS_BUTTON if continue_available else DAILY_BUTTON


func _daily_button_rect() -> Rect2:
	return DAILY_BUTTON if continue_available else NEW_GAME_BUTTON


func _touch_targets() -> Dictionary:
	var targets := {
		ACTION_NEW_GAME: _new_game_button_rect(),
		ACTION_DAILY: _daily_button_rect(),
		ACTION_SETTINGS: _settings_button_rect(),
		ACTION_CREDITS: CREDITS_LINK,
	}
	if continue_available:
		targets[ACTION_CONTINUE] = CONTINUE_BUTTON
	return targets
