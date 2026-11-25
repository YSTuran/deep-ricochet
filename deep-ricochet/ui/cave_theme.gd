class_name CaveTheme
extends RefCounted

const DEEP_SAPPHIRE := 0
const AMETHYST := 1
const VOLCANIC := 2
const MOSSY := 3
const GLACIAL := 4
const THEME_COUNT := 5
const GENERATED_TEXTURE_SIZE := 256
const FULL_TEXTURE_REFERENCE_SIZE := Vector2(1254.0, 1254.0)
const FULL_TEXTURE_SOURCE_REGIONS := {
	BlockState.BlockType.ECHO: Rect2(138.0, 156.0, 978.0, 943.0),
	BlockState.BlockType.BALL_CACHE: Rect2(128.0, 163.0, 998.0, 984.0),
	BlockState.BlockType.PIERCING: Rect2(100.0, 80.0, 1054.0, 1103.0),
}

const NAME_KEYS := [
	&"THEME_DEEP_SAPPHIRE",
	&"THEME_AMETHYST",
	&"THEME_VOLCANIC",
	&"THEME_MOSSY",
	&"THEME_GLACIAL",
]

const PALETTES := [
	{
		&"background_deep": Color("07101a"),
		&"background": Color("0b1420"),
		&"cave_dark": Color("101d2a"),
		&"cave_mid": Color("182b3d"),
		&"cave_light": Color("243d52"),
		&"board": Color("0a1724"),
		&"board_border": Color("31526c"),
		&"grid": Color("20364a"),
		&"normal": Color("3478b5"),
		&"ore": Color("f2a93b"),
		&"rock": Color("35434b"),
		&"rock_light": Color("52606b"),
		&"rock_dark": Color("202a33"),
		&"rock_mark": Color("c5cbd0"),
		&"core": Color("57d8c5"),
		&"explosive": Color("70452c"),
		&"cracked": Color("b7a58b"),
		&"armored": Color("35434b"),
		&"armored_weak": Color("f064a4"),
		&"echo": Color("36c9c2"),
		&"ball_cache": Color("70452c"),
		&"piercing": Color("6e3fa6"),
	},
	{
		&"background_deep": Color("100b18"),
		&"background": Color("191225"),
		&"cave_dark": Color("241b32"),
		&"cave_mid": Color("352548"),
		&"cave_light": Color("503868"),
		&"board": Color("160f21"),
		&"board_border": Color("624b78"),
		&"grid": Color("3b2b4c"),
		&"normal": Color("7650a8"),
		&"ore": Color("d65baa"),
		&"rock": Color("3a3445"),
		&"rock_light": Color("625573"),
		&"rock_dark": Color("211c2a"),
		&"rock_mark": Color("d5c9e5"),
		&"core": Color("9f8cff"),
		&"explosive": Color("633843"),
		&"cracked": Color("625573"),
		&"armored": Color("3a3445"),
		&"armored_weak": Color("55d5d0"),
		&"echo": Color("5bc6c6"),
		&"ball_cache": Color("563746"),
		&"piercing": Color("9b5be8"),
	},
	{
		&"background_deep": Color("0d0c0d"),
		&"background": Color("171719"),
		&"cave_dark": Color("282426"),
		&"cave_mid": Color("3b2c2b"),
		&"cave_light": Color("5b3a32"),
		&"board": Color("151113"),
		&"board_border": Color("684238"),
		&"grid": Color("3d2a29"),
		&"normal": Color("8a3f35"),
		&"ore": Color("f28b30"),
		&"rock": Color("343437"),
		&"rock_light": Color("514445"),
		&"rock_dark": Color("1d1c1e"),
		&"rock_mark": Color("d7c5b4"),
		&"core": Color("ff6b35"),
		&"explosive": Color("4d3026"),
		&"cracked": Color("514445"),
		&"armored": Color("343437"),
		&"armored_weak": Color("ffd45a"),
		&"echo": Color("e07b45"),
		&"ball_cache": Color("4d3026"),
		&"piercing": Color("b64a7e"),
	},
	{
		&"background_deep": Color("0b1713"),
		&"background": Color("12251f"),
		&"cave_dark": Color("1c3028"),
		&"cave_mid": Color("294238"),
		&"cave_light": Color("3f5d4e"),
		&"board": Color("0d1c18"),
		&"board_border": Color("45675a"),
		&"grid": Color("29443a"),
		&"normal": Color("507864"),
		&"ore": Color("d5a743"),
		&"rock": Color("35433d"),
		&"rock_light": Color("667c6e"),
		&"rock_dark": Color("1e2924"),
		&"rock_mark": Color("d2d8c5"),
		&"core": Color("6be4b6"),
		&"explosive": Color("624632"),
		&"cracked": Color("667c6e"),
		&"armored": Color("35433d"),
		&"armored_weak": Color("f07e72"),
		&"echo": Color("62c9aa"),
		&"ball_cache": Color("624632"),
		&"piercing": Color("7661a8"),
	},
	{
		&"background_deep": Color("091821"),
		&"background": Color("102431"),
		&"cave_dark": Color("18313f"),
		&"cave_mid": Color("234555"),
		&"cave_light": Color("38657a"),
		&"board": Color("0b1d27"),
		&"board_border": Color("4b7286"),
		&"grid": Color("294a5b"),
		&"normal": Color("5b91b5"),
		&"ore": Color("a6d8e8"),
		&"rock": Color("3a4a55"),
		&"rock_light": Color("708a98"),
		&"rock_dark": Color("21303a"),
		&"rock_mark": Color("e7f5fa"),
		&"core": Color("70f0e0"),
		&"explosive": Color("665c55"),
		&"cracked": Color("708a98"),
		&"armored": Color("3a4a55"),
		&"armored_weak": Color("d875e8"),
		&"echo": Color("73d9e8"),
		&"ball_cache": Color("665c55"),
		&"piercing": Color("a665d1"),
	},
]

static var current_theme := DEEP_SAPPHIRE
static var _texture_cache: Dictionary = {}


static func is_supported(theme_id: int) -> bool:
	return theme_id >= DEEP_SAPPHIRE and theme_id < THEME_COUNT


static func set_current_theme(theme_id: int) -> bool:
	if not is_supported(theme_id):
		return false
	if current_theme != theme_id:
		current_theme = theme_id
		_texture_cache.clear()
	return true


static func name_key(theme_id: int) -> StringName:
	if not is_supported(theme_id):
		return NAME_KEYS[DEEP_SAPPHIRE]
	return NAME_KEYS[theme_id]


static func color(key: StringName) -> Color:
	return color_for_theme(current_theme, key)


static func color_for_theme(theme_id: int, key: StringName) -> Color:
	var safe_theme := theme_id if is_supported(theme_id) else DEEP_SAPPHIRE
	return PALETTES[safe_theme].get(key, Color.WHITE)


static func block_color(block_type: int) -> Color:
	return color(_block_key(block_type))


static func swatch_colors(theme_id: int) -> PackedColorArray:
	return PackedColorArray([
		color_for_theme(theme_id, &"background"),
		color_for_theme(theme_id, &"normal"),
		color_for_theme(theme_id, &"ore"),
		color_for_theme(theme_id, &"rock"),
		color_for_theme(theme_id, &"core"),
	])


static func draw_hard_rock(canvas: CanvasItem, rect: Rect2) -> void:
	var scale := minf(rect.size.x, rect.size.y) / 50.0
	var cut := 7.0 * scale
	var points := PackedVector2Array([
		rect.position + Vector2(cut, 0.0),
		rect.position + Vector2(rect.size.x - cut, 0.0),
		rect.position + Vector2(rect.size.x, cut),
		rect.end - Vector2(0.0, cut),
		rect.end - Vector2(cut, 0.0),
		rect.position + Vector2(cut, rect.size.y),
		rect.position + Vector2(0.0, rect.size.y - cut),
		rect.position + Vector2(0.0, cut),
	])
	canvas.draw_colored_polygon(points, color(&"rock"))
	canvas.draw_polyline(
		points + PackedVector2Array([points[0]]),
		color(&"rock_dark"),
		4.0 * scale,
		true,
	)
	canvas.draw_colored_polygon(PackedVector2Array([
		points[0],
		points[1],
		rect.position + Vector2(rect.size.x * 0.62, rect.size.y * 0.34),
	]), color(&"rock_light"))
	canvas.draw_colored_polygon(PackedVector2Array([
		points[4],
		points[5],
		rect.position + Vector2(rect.size.x * 0.42, rect.size.y * 0.66),
	]), color(&"rock_dark"))
	var inset := 15.0 * scale
	var a := rect.position + Vector2(inset, inset)
	var b := rect.end - Vector2(inset, inset)
	var c := Vector2(rect.end.x - inset, rect.position.y + inset)
	var d := Vector2(rect.position.x + inset, rect.end.y - inset)
	canvas.draw_line(a, b, color(&"rock_dark").darkened(0.35), 10.0 * scale, true)
	canvas.draw_line(c, d, color(&"rock_dark").darkened(0.35), 10.0 * scale, true)
	canvas.draw_line(a, b, color(&"rock_mark"), 5.0 * scale, true)
	canvas.draw_line(c, d, color(&"rock_mark"), 5.0 * scale, true)


static func draw_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	destination: Rect2,
	source_rect: Rect2,
	block_type: int,
	modulate: Color = Color.WHITE,
) -> void:
	if current_theme == DEEP_SAPPHIRE:
		canvas.draw_texture_rect_region(texture, destination, source_rect, modulate)
		return
	var themed_texture := _themed_texture(texture, source_rect, block_type)
	if themed_texture == null:
		canvas.draw_texture_rect_region(texture, destination, source_rect, modulate)
		return
	canvas.draw_texture_rect(themed_texture, destination, false, modulate)


static func draw_texture(
	canvas: CanvasItem,
	texture: Texture2D,
	destination: Rect2,
	block_type: int,
	modulate: Color = Color.WHITE,
) -> void:
	draw_texture_region(
		canvas,
		texture,
		destination,
		block_texture_source_rect(texture, block_type),
		block_type,
		modulate,
	)


static func block_texture_source_rect(texture: Texture2D, block_type: int) -> Rect2:
	var full_rect := Rect2(Vector2.ZERO, texture.get_size())
	if not FULL_TEXTURE_SOURCE_REGIONS.has(block_type):
		return full_rect
	var reference_region: Rect2 = FULL_TEXTURE_SOURCE_REGIONS[block_type]
	var source_scale := texture.get_size() / FULL_TEXTURE_REFERENCE_SIZE
	return Rect2(
		reference_region.position * source_scale,
		reference_region.size * source_scale,
	)


static func _themed_texture(
	texture: Texture2D,
	source_rect: Rect2,
	block_type: int,
) -> Texture2D:
	var cache_key := "%d|%s|%d|%d|%d|%d|%d" % [
		current_theme,
		texture.resource_path,
		block_type,
		roundi(source_rect.position.x),
		roundi(source_rect.position.y),
		roundi(source_rect.size.x),
		roundi(source_rect.size.y),
	]
	var cached: Texture2D = _texture_cache.get(cache_key)
	if cached != null:
		return cached
	var source_image := texture.get_image()
	if source_image == null or source_image.is_empty():
		return null
	var source_bounds := Rect2i(Vector2i.ZERO, source_image.get_size())
	var requested_region := Rect2i(
		Vector2i(roundi(source_rect.position.x), roundi(source_rect.position.y)),
		Vector2i(roundi(source_rect.size.x), roundi(source_rect.size.y)),
	)
	var safe_region := source_bounds.intersection(requested_region)
	if safe_region.size.x <= 0 or safe_region.size.y <= 0:
		return null
	var image := source_image.get_region(safe_region)
	image.convert(Image.FORMAT_RGBA8)
	image.resize(
		GENERATED_TEXTURE_SIZE,
		GENERATED_TEXTURE_SIZE,
		Image.INTERPOLATE_LANCZOS,
	)
	_recolor_image(image, block_type)
	var generated := ImageTexture.create_from_image(image)
	_texture_cache[cache_key] = generated
	return generated


static func _recolor_image(image: Image, block_type: int) -> void:
	var key := _block_key(block_type)
	var source_reference := color_for_theme(DEEP_SAPPHIRE, key)
	var target_reference := color(key)
	var hue_shift := target_reference.h - source_reference.h
	var saturation_scale := clampf(
		target_reference.s / maxf(source_reference.s, 0.12),
		0.45,
		1.85,
	)
	var value_scale := clampf(
		target_reference.v / maxf(source_reference.v, 0.12),
		0.65,
		1.35,
	)
	var minimum_saturation := target_reference.s * 0.24
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.001:
				continue
			if block_type == BlockState.BlockType.ARMORED \
				and pixel.s >= 0.38 \
				and (pixel.h >= 0.82 or pixel.h <= 0.03):
				var weak_color := color(&"armored_weak")
				var weak_saturation := clampf(
					maxf(pixel.s * 0.9, weak_color.s * 0.7),
					0.0,
					1.0,
				)
				var weak_value := clampf(
					pixel.v * weak_color.v / 0.95,
					0.0,
					1.0,
				)
				image.set_pixel(
					x,
					y,
					Color.from_hsv(weak_color.h, weak_saturation, weak_value, pixel.a),
				)
				continue
			var hue := target_reference.h if pixel.s < 0.06 \
				else fposmod(pixel.h + hue_shift + 1.0, 1.0)
			var highlight := smoothstep(0.72, 1.0, pixel.v)
			var saturation := clampf(
				maxf(pixel.s * saturation_scale, minimum_saturation * (1.0 - highlight)),
				0.0,
				1.0,
			)
			var value := clampf(pixel.v * value_scale, 0.0, 1.0)
			var recolored := Color.from_hsv(hue, saturation, value, pixel.a)
			image.set_pixel(x, y, recolored)


static func _block_key(block_type: int) -> StringName:
	match block_type:
		BlockState.BlockType.ORE:
			return &"ore"
		BlockState.BlockType.ROCK:
			return &"rock"
		BlockState.BlockType.CORE:
			return &"core"
		BlockState.BlockType.EXPLOSIVE:
			return &"explosive"
		BlockState.BlockType.CRACKED:
			return &"cracked"
		BlockState.BlockType.ARMORED:
			return &"armored"
		BlockState.BlockType.ECHO:
			return &"echo"
		BlockState.BlockType.BALL_CACHE:
			return &"ball_cache"
		BlockState.BlockType.PIERCING:
			return &"piercing"
	return &"normal"
