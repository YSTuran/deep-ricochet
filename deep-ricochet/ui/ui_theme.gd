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
static var high_quality_enabled := false


static func set_high_quality(enabled: bool) -> void:
	high_quality_enabled = enabled


static func is_emulated_mouse_event(event: InputEvent) -> bool:
	return (
		(event is InputEventMouseButton or event is InputEventMouseMotion)
		and event.device == InputEvent.DEVICE_ID_EMULATION
	)


static func draw_cave_background(canvas: CanvasItem, size: Vector2 = VIEW_SIZE) -> void:
	_draw_background_depth(canvas, size)
	_ensure_cave_polygons(size)
	canvas.draw_colored_polygon(_cave_polygons[0], CaveTheme.color(&"cave_dark"))
	canvas.draw_colored_polygon(_cave_polygons[1], CaveTheme.color(&"cave_dark"))
	var face_color := CaveTheme.color(&"cave_mid") \
		if high_quality_enabled else CaveTheme.color(&"cave_dark").lightened(0.08)
	canvas.draw_colored_polygon(_cave_polygons[2], face_color)
	canvas.draw_colored_polygon(_cave_polygons[3], face_color)
	canvas.draw_colored_polygon(_cave_polygons[4], CaveTheme.color(&"cave_dark"))
	_draw_theme_signature(canvas, size)
	_draw_stone_grain(canvas, size)
	canvas.draw_line(
		Vector2(48.0, 116.0),
		Vector2(23.0, 198.0),
		Color(CaveTheme.color(&"cave_light"), 0.72 if high_quality_enabled else 0.42),
		3.0 if high_quality_enabled else 2.0,
	)
	canvas.draw_line(
		Vector2(size.x - 48.0, 312.0),
		Vector2(size.x - 25.0, 396.0),
		Color(CaveTheme.color(&"cave_light"), 0.72 if high_quality_enabled else 0.42),
		3.0 if high_quality_enabled else 2.0,
	)


static func _draw_background_depth(canvas: CanvasItem, size: Vector2) -> void:
	var top := CaveTheme.color(&"background")
	var bottom := CaveTheme.color(&"background_deep")
	var band_count := 28 if high_quality_enabled else 18
	var band_height := size.y / float(band_count)
	for band_index in range(band_count):
		var progress := float(band_index) / float(maxi(band_count - 1, 1))
		var eased := smoothstep(0.0, 1.0, progress)
		canvas.draw_rect(
			Rect2(0.0, float(band_index) * band_height, size.x, band_height + 1.0),
			top.lerp(bottom, eased),
			true,
		)
	var glow_color := CaveTheme.block_color(BlockState.BlockType.CORE)
	var glow_center := Vector2(size.x * 0.52, size.y * 0.34)
	var glow_layers := 5 if high_quality_enabled else 3
	for glow_index in range(glow_layers, 0, -1):
		var progress := float(glow_index) / float(glow_layers)
		canvas.draw_circle(
			glow_center,
			size.x * (0.18 + progress * 0.40),
			Color(glow_color, (0.012 if high_quality_enabled else 0.009) * float(glow_layers - glow_index + 1)),
		)
	var strata_color := Color(CaveTheme.color(&"cave_light"), 0.055 if high_quality_enabled else 0.035)
	for strata_index in range(4):
		var y := size.y * (0.18 + float(strata_index) * 0.19)
		canvas.draw_line(
			Vector2(size.x * 0.13, y),
			Vector2(size.x * 0.87, y + size.y * 0.025),
			strata_color,
			1.0,
		)


static func _draw_theme_signature(canvas: CanvasItem, size: Vector2) -> void:
	match CaveTheme.current_theme:
		CaveTheme.AMETHYST:
			_draw_amethyst_details(canvas, size)
		CaveTheme.VOLCANIC:
			_draw_volcanic_details(canvas, size)
		CaveTheme.MOSSY:
			_draw_mossy_details(canvas, size)
		CaveTheme.GLACIAL:
			_draw_glacial_details(canvas, size)
		_:
			_draw_sapphire_details(canvas, size)


static func _draw_sapphire_details(canvas: CanvasItem, size: Vector2) -> void:
	var vein := Color(CaveTheme.block_color(BlockState.BlockType.NORMAL), 0.32)
	_draw_vein(canvas, size, [
		Vector2(35.0, 238.0), Vector2(58.0, 265.0), Vector2(43.0, 309.0),
		Vector2(69.0, 347.0),
	], vein, 2.0)
	_draw_vein(canvas, size, [
		Vector2(505.0, 585.0), Vector2(478.0, 617.0), Vector2(498.0, 664.0),
	], Color(CaveTheme.block_color(BlockState.BlockType.CORE), 0.24), 2.0)


static func _draw_amethyst_details(canvas: CanvasItem, size: Vector2) -> void:
	var primary := CaveTheme.block_color(BlockState.BlockType.ORE)
	var secondary := CaveTheme.block_color(BlockState.BlockType.CORE)
	_draw_crystal_cluster(canvas, size, Vector2(42.0, 305.0), 1.0, primary, false)
	_draw_crystal_cluster(canvas, size, Vector2(498.0, 690.0), 0.86, secondary, true)
	if high_quality_enabled:
		_draw_crystal_cluster(canvas, size, Vector2(48.0, 785.0), 0.66, secondary, false)
		_draw_sparkles(canvas, size, primary, [
			Vector2(88.0, 178.0), Vector2(456.0, 248.0), Vector2(103.0, 656.0),
			Vector2(437.0, 807.0),
		])


static func _draw_volcanic_details(canvas: CanvasItem, size: Vector2) -> void:
	var lava := CaveTheme.block_color(BlockState.BlockType.CORE)
	_draw_glowing_vein(canvas, size, [
		Vector2(28.0, 160.0), Vector2(55.0, 206.0), Vector2(39.0, 260.0),
		Vector2(69.0, 318.0), Vector2(47.0, 382.0),
	], lava)
	_draw_glowing_vein(canvas, size, [
		Vector2(512.0, 512.0), Vector2(483.0, 559.0), Vector2(501.0, 618.0),
		Vector2(474.0, 676.0),
	], CaveTheme.block_color(BlockState.BlockType.ORE))
	if high_quality_enabled:
		for ember_index in range(12):
			var x := fposmod(73.0 + float(ember_index * 97), size.x - 90.0) + 45.0
			var y := fposmod(128.0 + float(ember_index * ember_index * 41), size.y - 190.0) + 80.0
			canvas.draw_circle(Vector2(x, y), 1.5 + float(ember_index % 2), Color(lava, 0.34))


static func _draw_mossy_details(canvas: CanvasItem, size: Vector2) -> void:
	var moss := CaveTheme.block_color(BlockState.BlockType.CORE).darkened(0.18)
	var moss_light := CaveTheme.block_color(BlockState.BlockType.NORMAL).lightened(0.24)
	var left_vine := _scaled_points(size, [
		Vector2(31.0, 118.0), Vector2(54.0, 171.0), Vector2(39.0, 225.0),
		Vector2(62.0, 286.0), Vector2(46.0, 344.0),
	])
	canvas.draw_polyline(left_vine, Color(moss, 0.58), 4.0, true)
	var right_vine := _scaled_points(size, [
		Vector2(509.0, 554.0), Vector2(486.0, 611.0), Vector2(502.0, 668.0),
		Vector2(480.0, 729.0),
	])
	canvas.draw_polyline(right_vine, Color(moss, 0.48), 4.0, true)
	for leaf in [Vector2(50.0, 180.0), Vector2(46.0, 276.0), Vector2(489.0, 620.0), Vector2(487.0, 710.0)]:
		canvas.draw_circle(_scaled_point(size, leaf), 5.0, Color(moss_light, 0.56))
	if high_quality_enabled:
		for spore_index in range(10):
			var x := fposmod(61.0 + float(spore_index * 113), size.x - 100.0) + 50.0
			var y := fposmod(170.0 + float(spore_index * 67), size.y - 250.0) + 100.0
			canvas.draw_circle(Vector2(x, y), 2.0, Color(moss_light, 0.22))


static func _draw_glacial_details(canvas: CanvasItem, size: Vector2) -> void:
	var ice := CaveTheme.block_color(BlockState.BlockType.ORE)
	var frost := CaveTheme.block_color(BlockState.BlockType.CORE)
	_draw_ice_facet(canvas, size, [
		Vector2(10.0, 245.0), Vector2(58.0, 215.0), Vector2(73.0, 286.0),
		Vector2(39.0, 335.0),
	], ice)
	_draw_ice_facet(canvas, size, [
		Vector2(530.0, 610.0), Vector2(485.0, 574.0), Vector2(469.0, 652.0),
		Vector2(505.0, 704.0),
	], frost)
	_draw_vein(canvas, size, [
		Vector2(38.0, 558.0), Vector2(64.0, 596.0), Vector2(45.0, 638.0),
	], Color(frost, 0.36), 2.0)
	if high_quality_enabled:
		_draw_sparkles(canvas, size, ice, [
			Vector2(92.0, 142.0), Vector2(448.0, 214.0), Vector2(111.0, 718.0),
			Vector2(431.0, 824.0), Vector2(276.0, 104.0),
		])


static func _draw_crystal_cluster(
	canvas: CanvasItem,
	size: Vector2,
	base: Vector2,
	scale: float,
	color: Color,
	mirrored: bool,
) -> void:
	var direction := -1.0 if mirrored else 1.0
	var scaled_base := _scaled_point(size, base)
	if high_quality_enabled:
		draw_glow(canvas, scaled_base + Vector2(14.0 * direction, -20.0) * scale, 24.0 * scale, color)
	for crystal_index in range(3):
		var offset_x := float(crystal_index) * 15.0 * direction * scale
		var height := (44.0 - float(crystal_index) * 8.0) * scale
		var width := (18.0 + float(crystal_index) * 2.0) * scale
		var center := scaled_base + Vector2(offset_x, 0.0)
		var points := PackedVector2Array([
			center + Vector2(-width * 0.5, 0.0),
			center + Vector2(-width * 0.35, -height * 0.62),
			center + Vector2(0.0, -height),
			center + Vector2(width * 0.38, -height * 0.58),
			center + Vector2(width * 0.5, 0.0),
		])
		var crystal_color := color.lightened(float(crystal_index) * 0.08)
		canvas.draw_colored_polygon(points, Color(crystal_color, 0.48))
		canvas.draw_polyline(points + PackedVector2Array([points[0]]), Color(crystal_color, 0.72), 1.2, true)
		canvas.draw_line(points[2], center, Color(TEXT, 0.24), 1.0)


static func _draw_glowing_vein(
	canvas: CanvasItem,
	size: Vector2,
	points: Array[Vector2],
	color: Color,
) -> void:
	var scaled := _scaled_points(size, points)
	canvas.draw_polyline(scaled, Color(color.darkened(0.55), 0.48), 8.0, true)
	canvas.draw_polyline(scaled, Color(color, 0.22 if not high_quality_enabled else 0.34), 4.0, true)
	canvas.draw_polyline(scaled, Color(color.lightened(0.22), 0.72), 1.4, true)


static func _draw_ice_facet(
	canvas: CanvasItem,
	size: Vector2,
	points: Array[Vector2],
	color: Color,
) -> void:
	var scaled := _scaled_points(size, points)
	canvas.draw_colored_polygon(scaled, Color(color, 0.11 if not high_quality_enabled else 0.18))
	canvas.draw_polyline(scaled + PackedVector2Array([scaled[0]]), Color(color, 0.42), 1.5, true)
	canvas.draw_line(scaled[0], scaled[2], Color(color.lightened(0.25), 0.23), 1.0)


static func _draw_sparkles(
	canvas: CanvasItem,
	size: Vector2,
	color: Color,
	positions: Array[Vector2],
) -> void:
	for position: Vector2 in positions:
		var center := _scaled_point(size, position)
		canvas.draw_line(center - Vector2(7.0, 0.0), center + Vector2(7.0, 0.0), Color(color, 0.46), 1.5)
		canvas.draw_line(center - Vector2(0.0, 7.0), center + Vector2(0.0, 7.0), Color(color, 0.46), 1.5)


static func _draw_vein(
	canvas: CanvasItem,
	size: Vector2,
	points: Array[Vector2],
	color: Color,
	width: float,
) -> void:
	canvas.draw_polyline(_scaled_points(size, points), color, width, true)


static func _draw_stone_grain(canvas: CanvasItem, size: Vector2) -> void:
	var count := 24 if high_quality_enabled else 10
	var grain := CaveTheme.color(&"cave_light")
	for grain_index in range(count):
		var x := fposmod(37.0 + float(grain_index * 89 + grain_index * grain_index * 13), size.x - 32.0) + 16.0
		var y := fposmod(83.0 + float(grain_index * 71 + grain_index * grain_index * 19), size.y - 80.0) + 30.0
		var radius := 1.0 + float(grain_index % 3) * 0.45
		canvas.draw_circle(Vector2(x, y), radius, Color(grain, 0.10 if high_quality_enabled else 0.06))


static func _scaled_points(size: Vector2, points: Array[Vector2]) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		result.append(_scaled_point(size, point))
	return result


static func _scaled_point(size: Vector2, point: Vector2) -> Vector2:
	return point * Vector2(size.x / VIEW_SIZE.x, size.y / VIEW_SIZE.y)


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
	pressed: bool = false,
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
	if enabled and pressed:
		rect = Rect2(rect.position + Vector2(0.0, 3.0), rect.size)
		fill = fill.darkened(0.12)
		border = border.lightened(0.08)
	draw_panel(canvas, rect, fill, border, 13, 2, not pressed)
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
	if not high_quality_enabled:
		canvas.draw_circle(center, radius * 1.18, Color(color, 0.10))
		return
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
	var fitted_size := fit_font_size(text, rect.size.x - 8.0, size)
	canvas.draw_string(
		ThemeDB.fallback_font,
		rect.position + Vector2(0.0, rect.size.y * baseline_ratio),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		fitted_size,
		color,
	)


static func fit_font_size(text: String, available_width: float, requested_size: int) -> int:
	var fitted_size := maxi(requested_size, 10)
	var font := ThemeDB.fallback_font
	while fitted_size > 10 \
		and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fitted_size).x > available_width:
		fitted_size -= 1
	return fitted_size


static func draw_wrapped(
	canvas: CanvasItem,
	text: String,
	rect: Rect2,
	size: int,
	color: Color = TEXT,
) -> void:
	var font := ThemeDB.fallback_font
	var lines: Array[String] = []
	var current := ""
	for word: String in text.split(" "):
		var candidate := word if current.is_empty() else "%s %s" % [current, word]
		if not current.is_empty() \
			and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x > rect.size.x:
			lines.append(current)
			current = word
		else:
			current = candidate
	if not current.is_empty():
		lines.append(current)
	var line_height := float(size) * 1.4
	var start_y := rect.position.y + (rect.size.y - line_height * float(lines.size())) * 0.5
	for line_index in range(lines.size()):
		canvas.draw_string(
			font,
			Vector2(rect.position.x, start_y + line_height * float(line_index + 1)),
			lines[line_index],
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
