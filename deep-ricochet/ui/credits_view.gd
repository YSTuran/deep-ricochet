class_name CreditsView
extends Control

const TouchControlsScript := preload("res://ui/touch_controls.gd")

const DATA_PATH := "res://content/credits.json"
const SUPPORTED_SCHEMA_VERSION := 1
const VIEW_SIZE := Vector2(540.0, 960.0)
const CONTENT_RECT := Rect2(28.0, 142.0, 484.0, 648.0)
const PREVIOUS_BUTTON := Rect2(36.0, 826.0, 112.0, 58.0)
const BACK_BUTTON := Rect2(156.0, 826.0, 228.0, 58.0)
const NEXT_BUTTON := Rect2(392.0, 826.0, 112.0, 58.0)
const ACTION_PREVIOUS := &"previous"
const ACTION_BACK := &"back"
const ACTION_NEXT := &"next"

var controller: RunController
var pages: Array = []
var page_index := 0
var load_error: String
var touch_controls = TouchControlsScript.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_content()


func bind(run_controller: RunController) -> void:
	controller = run_controller


func show_credits() -> void:
	page_index = 0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func hide_credits() -> void:
	touch_controls.reset()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func page_count() -> int:
	return pages.size()


func _gui_input(event: InputEvent) -> void:
	if not TouchControlsScript.handles(event) or DeepUI.is_emulated_mouse_event(event):
		return
	accept_event()
	var action: StringName = touch_controls.process(event, _touch_targets())
	if touch_controls.changed:
		queue_redraw()
	if action.is_empty():
		return
	AudioManager.play_ui_click()
	if action == ACTION_PREVIOUS and page_index > 0:
		page_index -= 1
		queue_redraw()
	elif action == ACTION_NEXT and page_index + 1 < page_count():
		page_index += 1
		queue_redraw()
	elif action == ACTION_BACK and controller != null:
		controller.close_credits()


func _draw() -> void:
	DeepUI.draw_cave_background(self, VIEW_SIZE)
	DeepUI.draw_title_plate(
		self,
		tr("CREDITS_TITLE"),
		Rect2(58.0, 38.0, 424.0, 66.0),
		28,
		DeepUI.GOLD,
	)
	DeepUI.draw_centered(
		self,
		tr("CREDITS_PAGE_COUNT") % [page_index + 1, maxi(page_count(), 1)],
		Rect2(40.0, 108.0, 460.0, 28.0),
		14,
		DeepUI.MUTED,
	)
	DeepUI.draw_panel(
		self,
		CONTENT_RECT,
		Color(DeepUI.PANEL_SOFT, 0.95),
		DeepUI.BORDER,
		18,
		2,
		true,
	)
	if not load_error.is_empty():
		DeepUI.draw_wrapped(self, load_error, CONTENT_RECT.grow(-28.0), 17, DeepUI.DANGER)
	elif page_count() > 0:
		_draw_page(pages[page_index])
	DeepUI.draw_button(
		self,
		PREVIOUS_BUTTON,
		tr("COMMON_PREVIOUS"),
		&"ghost",
		14,
		page_index > 0,
		touch_controls.is_pressed(ACTION_PREVIOUS),
	)
	DeepUI.draw_button(
		self, BACK_BUTTON, tr("COMMON_BACK"), &"secondary", 20, true,
		touch_controls.is_pressed(ACTION_BACK),
	)
	DeepUI.draw_button(
		self,
		NEXT_BUTTON,
		tr("COMMON_NEXT"),
		&"ghost",
		14,
		page_index + 1 < page_count(),
		touch_controls.is_pressed(ACTION_NEXT),
	)


func _draw_page(page: Dictionary) -> void:
	DeepUI.draw_centered(
		self,
		tr(StringName(str(page.get("titleKey", "")))),
		Rect2(48.0, 158.0, 444.0, 36.0),
		21,
		DeepUI.GOLD_LIGHT,
	)
	var y := 204.0
	var sections: Array = page.get("sections", [])
	for section: Variant in sections:
		if typeof(section) != TYPE_DICTIONARY:
			continue
		var section_data: Dictionary = section
		DeepUI.draw_text(
			self,
			tr(StringName(str(section_data.get("titleKey", "")))),
			Vector2(54.0, y + 20.0),
			16,
			DeepUI.CORE,
		)
		draw_line(Vector2(54.0, y + 29.0), Vector2(486.0, y + 29.0), DeepUI.BORDER_SOFT, 1.0)
		y += 40.0
		var entries: Array = section_data.get("entries", [])
		for entry: Variant in entries:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var entry_data: Dictionary = entry
			DeepUI.draw_text(
				self,
				tr(StringName(str(entry_data.get("labelKey", "")))),
				Vector2(62.0, y + 15.0),
				12,
				DeepUI.MUTED,
			)
			DeepUI.draw_text(
				self,
				str(entry_data.get("value", "")),
				Vector2(62.0, y + 38.0),
				15,
				DeepUI.TEXT,
			)
			y += 52.0
		y += 8.0


func _load_content() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		load_error = "Credits data is missing."
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		load_error = "Credits data could not be read."
		return
	var data: Dictionary = parsed
	if int(data.get("schemaVersion", 0)) != SUPPORTED_SCHEMA_VERSION:
		load_error = "Credits data version is not supported."
		return
	var raw_pages: Variant = data.get("pages", [])
	if typeof(raw_pages) != TYPE_ARRAY or raw_pages.is_empty():
		load_error = "Credits pages are empty."
		return
	pages = raw_pages.duplicate(true)


func _touch_targets() -> Dictionary:
	var targets := {ACTION_BACK: BACK_BUTTON}
	if page_index > 0:
		targets[ACTION_PREVIOUS] = PREVIOUS_BUTTON
	if page_index + 1 < page_count():
		targets[ACTION_NEXT] = NEXT_BUTTON
	return targets
