class_name UiLayout
extends RefCounted

const BASE_SIZE := Vector2(540.0, 960.0)

static var content_transform := Transform2D.IDENTITY


static func refresh() -> void:
	content_transform = Transform2D.IDENTITY
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		return
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe_area := Rect2(DisplayServer.get_display_safe_area())
	var window_position := Vector2(DisplayServer.window_get_position())
	content_transform = calculate_content_transform(
		BASE_SIZE,
		window_size,
		safe_area,
		window_position,
	)


static func calculate_content_transform(
	base_size: Vector2,
	window_size: Vector2,
	safe_area_screen: Rect2,
	window_position: Vector2 = Vector2.ZERO,
) -> Transform2D:
	if base_size.x <= 0.0 or base_size.y <= 0.0 \
		or window_size.x <= 0.0 or window_size.y <= 0.0 \
		or safe_area_screen.size.x <= 0.0 or safe_area_screen.size.y <= 0.0:
		return Transform2D.IDENTITY
	var canvas_scale := minf(window_size.x / base_size.x, window_size.y / base_size.y)
	if canvas_scale <= 0.0:
		return Transform2D.IDENTITY
	var canvas_origin := (window_size - base_size * canvas_scale) * 0.5
	var safe_in_window := Rect2(safe_area_screen.position - window_position, safe_area_screen.size)
	var safe_in_canvas := Rect2(
		(safe_in_window.position - canvas_origin) / canvas_scale,
		safe_in_window.size / canvas_scale,
	).intersection(Rect2(Vector2.ZERO, base_size))
	if safe_in_canvas.size.x <= 0.0 or safe_in_canvas.size.y <= 0.0:
		return Transform2D.IDENTITY
	var safe_scale := minf(
		1.0,
		minf(safe_in_canvas.size.x / base_size.x, safe_in_canvas.size.y / base_size.y),
	)
	var safe_offset := safe_in_canvas.position + (safe_in_canvas.size - base_size * safe_scale) * 0.5
	return Transform2D(
		Vector2(safe_scale, 0.0),
		Vector2(0.0, safe_scale),
		safe_offset,
	)


static func viewport_to_base(position: Vector2) -> Vector2:
	return content_transform.affine_inverse() * position
