class_name DeepUI
extends RefCounted

const VIEW_SIZE := Vector2(540.0, 960.0)

const BACKGROUND := Color("0b1420")
const BACKGROUND_DEEP := Color("07101a")
const CAVE_DARK := Color("101d2a")
const CAVE_MID := Color("182b3d")
const CAVE_LIGHT := Color("243d52")
const PANEL := Color("12263a")
const PANEL_RAISED := Color("19344c")
const PANEL_SOFT := Color("102134")
const BORDER := Color("31526c")
const BORDER_SOFT := Color("223c52")
const TEXT := Color("f4f0e6")
const MUTED := Color("9fb4c8")
const MUTED_DARK := Color("678399")
const GOLD := Color("f2b65b")
const GOLD_LIGHT := Color("ffd786")
const GOLD_DARK := Color("9b5d17")
const BLUE := Color("4f8fc7")
const BLUE_LIGHT := Color("74b7eb")
const CORE := Color("69d8bc")
const CORE_DARK := Color("1b756a")
const DANGER := Color("d96c5f")
const DANGER_DARK := Color("4a292d")

static var _style_cache: Dictionary = {}
static var _cave_polygons: Array[PackedVector2Array] = []


static func draw_cave_background(canvas: CanvasItem, size: Vector2 = VIEW_SIZE) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_DEEP, true)
	canvas.draw_rect(Rect2(0.0, 0.0, size.x, size.y * 0.58), BACKGROUND, true)
	_ensure_cave_polygons(size)
	canvas.draw_colored_polygon(_cave_polygons[0], CAVE_DARK)
	canvas.draw_colored_polygon(_cave_polygons[1], CAVE_DARK)
	canvas.draw_colored_polygon(_cave_polygons[2], CAVE_MID)
	canvas.draw_colored_polygon(_cave_polygons[3], CAVE_MID)
	canvas.draw_colored_polygon(_cave_polygons[4], CAVE_DARK)
	canvas.draw_line(Vector2(48.0, 116.0), Vector2(23.0, 198.0), CAVE_LIGHT, 3.0)
	canvas.draw_line(Vector2(size.x - 48.0, 312.0), Vector2(size.x - 25.0, 396.0), CAVE_LIGHT, 3.0)


static func draw_panel(
	canvas: CanvasItem,
	rect: Rect2,
	fill: Color = PANEL,
	border: Color = BORDER,
	radius: int = 16,
	border_width: int = 2,
	shadow: bool = true,
) -> void:
	var key := "%s|%s|%d|%d|%s" % [
		fill.to_html(true),
		border.to_html(true),
		radius,
		border_width,
		str(shadow),
	]
	var box: StyleBoxFlat = _style_cache.get(key)
	if box == null:
		box = StyleBoxFlat.new()
		box.bg_color = fill
		box.set_corner_radius_all(radius)
		box.set_border_width_all(border_width)
		box.border_color = border
		if shadow:
			box.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
			box.shadow_size = 8
			box.shadow_offset = Vector2(0.0, 5.0)
		_style_cache[key] = box
	canvas.draw_style_box(box, rect)


static func _ensure_cave_polygons(size: Vector2) -> void:
	if not _cave_polygons.is_empty():
		return
	var left_back := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(72.0, 0.0), Vector2(52.0, 98.0),
		Vector2(76.0, 184.0), Vector2(48.0, 282.0), Vector2(70.0, 392.0),
		Vector2(44.0, 520.0), Vector2(76.0, 654.0), Vector2(52.0, 780.0),
		Vector2(96.0, size.y), Vector2(0.0, size.y),
	])
	var right_back := PackedVector2Array()
	for point: Vector2 in left_back:
		right_back.append(Vector2(size.x - point.x, point.y))
	var left_face := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(38.0, 0.0), Vector2(24.0, 112.0),
		Vector2(47.0, 210.0), Vector2(22.0, 330.0), Vector2(45.0, 450.0),
		Vector2(18.0, 594.0), Vector2(46.0, 742.0), Vector2(26.0, 864.0),
		Vector2(60.0, size.y), Vector2(0.0, size.y),
	])
	var right_face := PackedVector2Array()
	for point: Vector2 in left_face:
		right_face.append(Vector2(size.x - point.x, point.y))
	var bottom_rocks := PackedVector2Array([
		Vector2(0.0, size.y), Vector2(0.0, size.y - 48.0),
		Vector2(62.0, size.y - 72.0), Vector2(116.0, size.y - 42.0),
		Vector2(176.0, size.y - 62.0), Vector2(234.0, size.y - 38.0),
		Vector2(302.0, size.y - 56.0), Vector2(372.0, size.y - 34.0),
		Vector2(438.0, size.y - 66.0), Vector2(size.x, size.y - 42.0),
		Vector2(size.x, size.y),
	])
	_cave_polygons = [left_back, right_back, left_face, right_face, bottom_rocks]


static func draw_button(
	canvas: CanvasItem,
	rect: Rect2,
	label: String,
	variant: StringName = &"secondary",
	font_size: int = 20,
	enabled: bool = true,
) -> void:
	var fill := PANEL_RAISED
	var border := BORDER
	var text_color := TEXT
	match variant:
		&"primary":
			fill = GOLD
			border = GOLD_LIGHT
			text_color = BACKGROUND_DEEP
		&"safe":
			fill = Color("173550")
			border = BLUE
		&"core":
			fill = Color("123b3a")
			border = CORE
		&"danger":
			fill = DANGER_DARK
			border = DANGER
			text_color = Color("f2a299")
		&"ghost":
			fill = PANEL_SOFT
			border = BORDER_SOFT
	if not enabled:
		fill = Color(PANEL_SOFT, 0.76)
		border = Color(BORDER_SOFT, 0.7)
		text_color = Color(MUTED_DARK, 0.72)
	draw_panel(canvas, rect, fill, border, 13, 2, true)
	if enabled and variant == &"primary":
		canvas.draw_line(
			rect.position + Vector2(14.0, 4.0),
			Vector2(rect.end.x - 14.0, rect.position.y + 4.0),
			Color(GOLD_LIGHT, 0.72),
			2.0,
		)
	draw_centered(canvas, label, rect, font_size, text_color)


static func draw_title_plate(
	canvas: CanvasItem,
	text: String,
	rect: Rect2,
	font_size: int = 30,
	accent: Color = GOLD,
) -> void:
	draw_panel(canvas, rect, PANEL_SOFT, Color(accent, 0.72), 14, 2, true)
	canvas.draw_line(
		Vector2(rect.position.x + 18.0, rect.end.y - 3.0),
		Vector2(rect.end.x - 18.0, rect.end.y - 3.0),
		accent,
		2.0,
	)
	draw_centered(canvas, text, rect, font_size, TEXT)


static func draw_chip(
	canvas: CanvasItem,
	rect: Rect2,
	text: String,
	accent: Color = BORDER,
	font_size: int = 14,
) -> void:
	draw_panel(canvas, rect, PANEL_SOFT, accent, 9, 1, false)
	draw_centered(canvas, text, rect, font_size, TEXT)


static func draw_glow(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_circle(center, radius * 1.55, Color(color, 0.06))
	canvas.draw_circle(center, radius * 1.3, Color(color, 0.10))
	canvas.draw_circle(center, radius * 1.12, Color(color, 0.14))


static func draw_centered(
	canvas: CanvasItem,
	text: String,
	rect: Rect2,
	size: int,
	color: Color = TEXT,
	baseline_ratio: float = 0.70,
) -> void:
	canvas.draw_string(
		ThemeDB.fallback_font,
		rect.position + Vector2(0.0, rect.size.y * baseline_ratio),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		size,
		color,
	)


static func draw_text(
	canvas: CanvasItem,
	text: String,
	position: Vector2,
	size: int,
	color: Color = TEXT,
) -> void:
	canvas.draw_string(
		ThemeDB.fallback_font,
		position,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		size,
		color,
	)
