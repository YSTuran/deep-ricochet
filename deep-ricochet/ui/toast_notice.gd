class_name ToastNotice
extends Control

const NOTICE_RECT := Rect2(38.0, 842.0, 464.0, 68.0)
const DEFAULT_DURATION_SECONDS := 4.0

var message: String
var remaining_seconds := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func show_notice(text: String, duration_seconds: float = DEFAULT_DURATION_SECONDS) -> void:
	message = text
	remaining_seconds = maxf(0.1, duration_seconds)
	visible = true
	set_process(true)
	queue_redraw()


func hide_notice() -> void:
	remaining_seconds = 0.0
	visible = false
	set_process(false)


func _process(delta: float) -> void:
	remaining_seconds = maxf(0.0, remaining_seconds - delta)
	if remaining_seconds > 0.0:
		return
	hide_notice()


func _draw() -> void:
	DeepUI.draw_panel(
		self,
		NOTICE_RECT,
		Color(DeepUI.PANEL_RAISED, 0.98),
		DeepUI.DANGER,
		13,
		2,
		true,
	)
	DeepUI.draw_centered(self, message, NOTICE_RECT.grow(-10.0), 14, DeepUI.TEXT)
