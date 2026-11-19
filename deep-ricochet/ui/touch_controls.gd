class_name TouchControls
extends RefCounted

const MOUSE_POINTER_ID := -2

var active_action: StringName = &""
var active_pointer_id := -1
var inside := false
var changed := false
var phase: StringName = &""
var last_position := Vector2.ZERO


static func handles(event: InputEvent) -> bool:
	return event is InputEventScreenTouch \
		or event is InputEventScreenDrag \
		or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) \
		or event is InputEventMouseMotion


func process(event: InputEvent, targets: Dictionary) -> StringName:
	changed = false
	phase = &""
	if DeepUI.is_emulated_mouse_event(event):
		return &""
	if event is InputEventScreenTouch:
		last_position = event.position
		if event.pressed:
			_begin(_target_at(last_position, targets), event.index)
			phase = &"pressed"
			return &""
		if event.canceled:
			_cancel(event.index)
			phase = &"canceled"
			return &""
		phase = &"released"
		return _finish(last_position, event.index, targets)
	if event is InputEventScreenDrag:
		if event.index != active_pointer_id:
			return &""
		last_position = event.position
		phase = &"dragged"
		_update_inside(targets)
		return &""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		last_position = event.position
		if event.pressed:
			_begin(_target_at(last_position, targets), MOUSE_POINTER_ID)
			phase = &"pressed"
			return &""
		phase = &"released"
		return _finish(last_position, MOUSE_POINTER_ID, targets)
	if event is InputEventMouseMotion and active_pointer_id == MOUSE_POINTER_ID:
		last_position = event.position
		phase = &"dragged"
		_update_inside(targets)
	return &""


func is_pressed(action: StringName) -> bool:
	return inside and active_action == action


func reset() -> void:
	var had_state := not active_action.is_empty()
	active_action = &""
	active_pointer_id = -1
	inside = false
	changed = changed or had_state


func _begin(action: StringName, pointer_id: int) -> void:
	if active_pointer_id != -1:
		return
	var state_changed := active_action != action or active_pointer_id != pointer_id or not inside
	active_action = action
	# An outside press is tracked too. This prevents a finger that started away
	# from the controls from activating a button only by releasing over it.
	active_pointer_id = pointer_id
	inside = not action.is_empty()
	changed = changed or state_changed


func _finish(position: Vector2, pointer_id: int, targets: Dictionary) -> StringName:
	# Release-only events are retained for deterministic UI tests. Real touch and
	# mouse sequences always enter through _begin(), so drag-out safety is kept.
	if active_pointer_id == -1:
		return _target_at(position, targets)
	if pointer_id != active_pointer_id:
		return &""
	var completed := &""
	if not active_action.is_empty() and _rect_for(active_action, targets).has_point(position):
		completed = active_action
	reset()
	return completed


func _cancel(pointer_id: int) -> void:
	if pointer_id == active_pointer_id:
		reset()


func _update_inside(targets: Dictionary) -> void:
	if active_action.is_empty():
		return
	var next_inside := _rect_for(active_action, targets).has_point(last_position)
	if next_inside != inside:
		inside = next_inside
		changed = true


func _target_at(position: Vector2, targets: Dictionary) -> StringName:
	for key: Variant in targets:
		var action := StringName(key)
		if _rect_for(action, targets).has_point(position):
			return action
	return &""


func _rect_for(action: StringName, targets: Dictionary) -> Rect2:
	var value: Variant = targets.get(action, Rect2())
	return value if value is Rect2 else Rect2()
