class_name MineSelectView
extends Control

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

var controller: RunController
var page_index := 0


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
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _gui_input(event: InputEvent) -> void:
	if DeepUI.is_emulated_mouse_event(event):
		return
	var released := false
	var position := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		released = not event.pressed
		position = event.position
	elif event is InputEventScreenTouch:
		accept_event()
		released = not event.pressed and not event.canceled
		position = event.position
	if not released or controller == null:
		return
	for index in range(CARD_RECTS.size()):
		if CARD_RECTS[index].has_point(position):
			var mine_order := page_index * PAGE_SIZE + index + 1
			var mine_id := controller.mine_registry.mine_id_for_order(mine_order)
			if controller.profile.is_mine_unlocked(mine_id):
				AudioManager.play_ui_click()
				controller.request_mine_run(mine_id)
			return
	if PREVIOUS_BUTTON.has_point(position) and page_index > 0:
		AudioManager.play_ui_click()
		page_index -= 1
		queue_redraw()
	elif NEXT_BUTTON.has_point(position) and page_index + 1 < _page_count():
		AudioManager.play_ui_click()
		page_index += 1
		queue_redraw()
	elif BACK_BUTTON.has_point(position):
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
		_draw_mine_card(CARD_RECTS[index], controller.mine_registry.mines[first_index + index])
	DeepUI.draw_button(
		self,
		PREVIOUS_BUTTON,
		tr("COMMON_PREVIOUS"),
		&"ghost",
		14,
		page_index > 0,
	)
	DeepUI.draw_button(self, BACK_BUTTON, tr("COMMON_BACK"), &"ghost", 20)
	DeepUI.draw_button(
		self,
		NEXT_BUTTON,
		tr("COMMON_NEXT"),
		&"ghost",
		14,
		page_index + 1 < _page_count(),
	)


func _draw_mine_card(rect: Rect2, mine: MineDefinition) -> void:
	var unlocked := controller.profile.is_mine_unlocked(mine.mine_id)
	var accent := DeepUI.CORE if unlocked else DeepUI.BORDER_SOFT
	DeepUI.draw_panel(self, rect, DeepUI.PANEL_SOFT, accent, 15, 2, true)
	DeepUI.draw_text(self, mine.localized_name(), rect.position + Vector2(16.0, 24.0), 18, DeepUI.TEXT if unlocked else DeepUI.MUTED_DARK)
	var state_text := tr("MINE_UNLOCKED") if unlocked else tr("MINE_LOCKED")
	DeepUI.draw_chip(self, Rect2(rect.end.x - 104.0, rect.position.y + 7.0, 86.0, 24.0), state_text, accent, 10)
	DeepUI.draw_centered(
		self,
		tr("MINE_STATS") % [
			controller.profile.best_for_mine(mine.mine_id),
			controller.profile.completions_for_mine(mine.mine_id),
		],
		Rect2(rect.position + Vector2(12.0, 28.0), Vector2(rect.size.x - 24.0, 20.0)),
		11,
		DeepUI.MUTED,
	)
	DeepUI.draw_button(
		self,
		Rect2(rect.position + Vector2(88.0, 53.0), Vector2(rect.size.x - 176.0, 23.0)),
		tr("MINE_SELECT") if unlocked else tr("MINE_COMPLETE_PREVIOUS"),
		&"core" if unlocked else &"ghost",
		10,
		unlocked,
	)


func _page_count() -> int:
	if controller == null or controller.mine_registry == null:
		return 0
	return ceili(float(controller.mine_registry.mines.size()) / float(PAGE_SIZE))
