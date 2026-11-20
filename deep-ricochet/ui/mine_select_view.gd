class_name MineSelectView
extends Control

const TouchControlsScript := preload("res://ui/touch_controls.gd")

const VIEW_SIZE := Vector2(540.0, 960.0)
const PAGE_SIZE := 7
const CARD_RECTS := [
	Rect2(36.0, 146.0, 468.0, 82.0),
	Rect2(36.0, 236.0, 468.0, 82.0),
	Rect2(36.0, 326.0, 468.0, 82.0),
	Rect2(36.0, 416.0, 468.0, 82.0),
	Rect2(36.0, 506.0, 468.0, 82.0),
	Rect2(36.0, 596.0, 468.0, 82.0),
	Rect2(36.0, 686.0, 468.0, 82.0),
]
const PREVIOUS_BUTTON := Rect2(36.0, 815.0, 112.0, 58.0)
const BACK_BUTTON := Rect2(156.0, 815.0, 228.0, 58.0)
const NEXT_BUTTON := Rect2(392.0, 815.0, 112.0, 58.0)
const ACTION_PREVIOUS := &"previous"
const ACTION_BACK := &"back"
const ACTION_NEXT := &"next"
const MINE_ACTION_PREFIX := "mine_"

var controller: RunController
var page_index := 0
var touch_controls = TouchControlsScript.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind(run_controller: RunController) -> void:
	controller = run_controller


func show_selector() -> void:
	if controller != null and controller.profile != null:
		page_index = clampi(
			floori(float(controller.profile.highest_unlocked_mine - 1) / float(PAGE_SIZE)),
			0,
			maxi(_page_count() - 1, 0),
		)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func hide_selector() -> void:
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
	if String(action).begins_with(MINE_ACTION_PREFIX):
		var card_index := String(action).trim_prefix(MINE_ACTION_PREFIX).to_int()
		var mine_order := page_index * PAGE_SIZE + card_index + 1
		var mine_id := controller.mine_registry.mine_id_for_order(mine_order)
		if controller.profile.is_mine_unlocked(mine_id):
			AudioManager.play_ui_click()
			controller.request_mine_run(mine_id)
		return
	if action == ACTION_PREVIOUS and page_index > 0:
		AudioManager.play_ui_click()
		page_index -= 1
		queue_redraw()
	elif action == ACTION_NEXT and page_index + 1 < _page_count():
		AudioManager.play_ui_click()
		page_index += 1
		queue_redraw()
	elif action == ACTION_BACK:
		AudioManager.play_ui_click()
		controller.close_mine_selection()


func _draw() -> void:
	DeepUI.draw_cave_background(self, VIEW_SIZE)
	DeepUI.draw_title_plate(self, tr("MINE_SELECT_TITLE"), Rect2(68.0, 42.0, 404.0, 64.0), 28, DeepUI.GOLD)
	DeepUI.draw_centered(
		self,
		tr("MINE_SELECT_PAGE") % [page_index + 1, maxi(_page_count(), 1)],
		Rect2(40.0, 112.0, 460.0, 28.0),
		14,
		DeepUI.MUTED,
	)
	if controller == null or controller.mine_registry == null or controller.profile == null:
		return
	var first_index := page_index * PAGE_SIZE
	var visible_count := mini(PAGE_SIZE, controller.mine_registry.mines.size() - first_index)
	for index in range(maxi(visible_count, 0)):
		_draw_mine_card(
			CARD_RECTS[index],
			controller.mine_registry.mines[first_index + index],
			index,
		)
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
		self, BACK_BUTTON, tr("COMMON_BACK"), &"ghost", 20, true,
		touch_controls.is_pressed(ACTION_BACK),
	)
	DeepUI.draw_button(
		self,
		NEXT_BUTTON,
		tr("COMMON_NEXT"),
		&"ghost",
		14,
		page_index + 1 < _page_count(),
		touch_controls.is_pressed(ACTION_NEXT),
	)


func _draw_mine_card(rect: Rect2, mine: MineDefinition, card_index: int) -> void:
	var unlocked := controller.profile.is_mine_unlocked(mine.mine_id)
	var accent := DeepUI.CORE if unlocked else DeepUI.BORDER_SOFT
	var action := StringName("%s%d" % [MINE_ACTION_PREFIX, card_index])
	var pressed: bool = unlocked and touch_controls.is_pressed(action)
	var card_rect := Rect2(rect.position + (Vector2(0.0, 3.0) if pressed else Vector2.ZERO), rect.size)
	var fill := DeepUI.PANEL_RAISED.darkened(0.08) if pressed else DeepUI.PANEL_SOFT
	DeepUI.draw_panel(self, card_rect, fill, accent, 15, 2, not pressed)
	DeepUI.draw_chip(
		self,
		Rect2(card_rect.position + Vector2(12.0, 14.0), Vector2(52.0, 52.0)),
		"%02d" % mine.order,
		accent,
		18,
	)
	DeepUI.draw_text(
		self,
		mine.localized_name(),
		card_rect.position + Vector2(76.0, 29.0),
		18,
		DeepUI.TEXT if unlocked else DeepUI.MUTED_DARK,
	)
	var state_text := tr("MINE_UNLOCKED") if unlocked else tr("MINE_LOCKED")
	DeepUI.draw_chip(self, Rect2(card_rect.end.x - 104.0, card_rect.position.y + 7.0, 86.0, 24.0), state_text, accent, 10)
	DeepUI.draw_text(
		self,
		tr("MINE_STATS") % [
			controller.profile.best_for_mine(mine.mine_id),
			controller.profile.completions_for_mine(mine.mine_id),
		],
		card_rect.position + Vector2(76.0, 56.0),
		11,
		DeepUI.MUTED,
	)
func _page_count() -> int:
	if controller == null or controller.mine_registry == null:
		return 0
	return ceili(float(controller.mine_registry.mines.size()) / float(PAGE_SIZE))


func _touch_targets() -> Dictionary:
	var targets := {
		ACTION_BACK: BACK_BUTTON,
	}
	if page_index > 0:
		targets[ACTION_PREVIOUS] = PREVIOUS_BUTTON
	if page_index + 1 < _page_count():
		targets[ACTION_NEXT] = NEXT_BUTTON
	if controller == null or controller.mine_registry == null or controller.profile == null:
		return targets
	var first_index := page_index * PAGE_SIZE
	var visible_count := mini(PAGE_SIZE, controller.mine_registry.mines.size() - first_index)
	for card_index in range(maxi(visible_count, 0)):
		var mine: MineDefinition = controller.mine_registry.mines[first_index + card_index]
		if controller.profile.is_mine_unlocked(mine.mine_id):
			targets[StringName("%s%d" % [MINE_ACTION_PREFIX, card_index])] = CARD_RECTS[card_index]
	return targets
