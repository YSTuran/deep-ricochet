extends SceneTree

const ROCK_OUTPUT := "res://assets/images/blocks/blok_kaya.png"
const THEME_OUTPUT_DIRECTORY := "res://assets/images/themes"
const THEME_OUTPUTS := [
	"deep_sapphire.png",
	"amethyst_vein.png",
	"volcanic_shaft.png",
	"mossy_cavern.png",
	"glacial_mine.png",
]
const ROCK_IMAGE_SIZE := Vector2i(512, 512)
const THEME_IMAGE_SIZE := Vector2i(1840, 260)


class PreviewCanvas:
	extends Node2D

	const NORMAL_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_normal.png")
	const ORE_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_cevher.png")
	const CORE_TEXTURE: Texture2D = preload("res://assets/images/blocks/cekirdek.png")
	const CRACKED_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_catlak.png")
	const EXPLOSIVE_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_patlayici.png")
	const ARMORED_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_zirhli_sol_alt.png")
	const ECHO_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_yanki.png")
	const BALL_CACHE_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_top_haznesi.png")
	const PIERCING_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_delici_kristal.png")
	const ACID_BARREL_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_asit_varili.png")
	const NORMAL_SOURCE := Rect2(139.0, 159.0, 976.0, 939.0)
	const ORE_SOURCE := Rect2(209.0, 220.0, 837.0, 831.0)
	const CRACKED_SOURCE := Rect2(32.0, 36.0, 447.0, 454.0)
	const EXPLOSIVE_SOURCE := Rect2(54.0, 65.0, 404.0, 407.0)
	const ARMORED_SOURCE := Rect2(5.0, 5.0, 503.0, 503.0)

	var rock_only := false


	func _draw() -> void:
		if rock_only:
			CaveTheme.draw_hard_rock(self, Rect2(32.0, 32.0, 448.0, 448.0))
			return
		_draw_theme_background()
		_draw_block_lineup()


	func _draw_theme_background() -> void:
		var image_size := Vector2(1840.0, 260.0)
		var top := CaveTheme.color(&"background")
		var bottom := CaveTheme.color(&"background_deep")
		for band_index in range(20):
			var progress := float(band_index) / 19.0
			draw_rect(
				Rect2(0.0, float(band_index) * 13.0, image_size.x, 14.0),
				top.lerp(bottom, smoothstep(0.0, 1.0, progress)),
				true,
			)
		var left_rock := PackedVector2Array([
			Vector2(0.0, 0.0), Vector2(92.0, 0.0), Vector2(62.0, 54.0),
			Vector2(86.0, 112.0), Vector2(54.0, 178.0), Vector2(104.0, 260.0),
			Vector2(0.0, 260.0),
		])
		draw_colored_polygon(left_rock, CaveTheme.color(&"cave_dark"))
		var right_rock := PackedVector2Array()
		for point: Vector2 in left_rock:
			right_rock.append(Vector2(image_size.x - point.x, point.y))
		draw_colored_polygon(right_rock, CaveTheme.color(&"cave_dark"))
		var panel := Rect2(70.0, 31.0, 1700.0, 198.0)
		draw_rect(panel, CaveTheme.color(&"board"), true)
		draw_rect(panel, CaveTheme.color(&"board_border"), false, 4.0)
		for column in range(1, 11):
			var x := panel.position.x + float(column) * panel.size.x / 11.0
			draw_line(
				Vector2(x, panel.position.y),
				Vector2(x, panel.end.y),
				Color(CaveTheme.color(&"grid"), 0.68),
				1.0,
			)
		for row in range(1, 3):
			var y := panel.position.y + float(row) * panel.size.y / 3.0
			draw_line(
				Vector2(panel.position.x, y),
				Vector2(panel.end.x, y),
				Color(CaveTheme.color(&"grid"), 0.54),
				1.0,
			)


	func _draw_block_lineup() -> void:
		var size := Vector2(118.0, 118.0)
		var y := 71.0
		var positions: Array[float] = []
		for index in range(11):
			positions.append(130.0 + float(index) * 156.0)
		var destinations: Array[Rect2] = []
		for center_x: float in positions:
			destinations.append(Rect2(Vector2(center_x - size.x * 0.5, y), size))

		CaveTheme.draw_texture_region(
			self, NORMAL_TEXTURE, destinations[0], NORMAL_SOURCE, BlockState.BlockType.NORMAL,
		)
		_draw_value(destinations[0], "6")
		CaveTheme.draw_texture_region(
			self, ORE_TEXTURE, destinations[1], ORE_SOURCE, BlockState.BlockType.ORE,
		)
		_draw_value(destinations[1], "7")
		CaveTheme.draw_hard_rock(self, destinations[2])
		DeepUI.draw_glow(self, destinations[3].get_center(), 48.0, CaveTheme.color(&"core"))
		CaveTheme.draw_texture(
			self, CORE_TEXTURE, destinations[3], BlockState.BlockType.CORE,
		)
		_draw_value(destinations[3], "8", Color("0b1420"))
		CaveTheme.draw_texture_region(
			self,
			EXPLOSIVE_TEXTURE,
			destinations[4],
			EXPLOSIVE_SOURCE,
			BlockState.BlockType.EXPLOSIVE,
		)
		_draw_value(destinations[4], "5")
		CaveTheme.draw_texture_region(
			self,
			CRACKED_TEXTURE,
			destinations[5],
			CRACKED_SOURCE,
			BlockState.BlockType.CRACKED,
		)
		_draw_value(destinations[5], "8")
		CaveTheme.draw_texture_region(
			self,
			ARMORED_TEXTURE,
			destinations[6],
			ARMORED_SOURCE,
			BlockState.BlockType.ARMORED,
		)
		_draw_value(destinations[6], "6")
		CaveTheme.draw_texture(
			self, ECHO_TEXTURE, destinations[7], BlockState.BlockType.ECHO,
		)
		_draw_value(destinations[7], "6")
		CaveTheme.draw_texture(
			self, BALL_CACHE_TEXTURE, destinations[8], BlockState.BlockType.BALL_CACHE,
		)
		_draw_value(destinations[8], "4")
		CaveTheme.draw_texture(
			self, PIERCING_TEXTURE, destinations[9], BlockState.BlockType.PIERCING,
		)
		_draw_value(destinations[9], "7")
		CaveTheme.draw_texture(
			self, ACID_BARREL_TEXTURE, destinations[10], BlockState.BlockType.ACID_BARREL,
		)
		_draw_value(destinations[10], "9")


	func _draw_value(rect: Rect2, value: String, color: Color = Color("f4f1e8")) -> void:
		DeepUI.draw_centered(self, value, rect, 34, color, 0.66)


func _initialize() -> void:
	call_deferred("_generate")


func _generate() -> void:
	var theme_directory := ProjectSettings.globalize_path(THEME_OUTPUT_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(theme_directory)
	if directory_error != OK:
		push_error("README tema görseli dizini oluşturulamadı: %s" % theme_directory)
		quit(1)
		return

	CaveTheme.set_current_theme(CaveTheme.DEEP_SAPPHIRE)
	if not await _render_image(ROCK_IMAGE_SIZE, ROCK_OUTPUT, true, true):
		quit(1)
		return
	for theme_id in range(CaveTheme.THEME_COUNT):
		CaveTheme.set_current_theme(theme_id)
		var output_path := "%s/%s" % [THEME_OUTPUT_DIRECTORY, THEME_OUTPUTS[theme_id]]
		if not await _render_image(THEME_IMAGE_SIZE, output_path, false, false):
			quit(1)
			return
	CaveTheme.set_current_theme(CaveTheme.DEEP_SAPPHIRE)
	print("[PASS] Sert kaya asseti ve README tema görselleri üretildi.")
	quit(0)


func _render_image(
	size: Vector2i,
	output_path: String,
	transparent: bool,
	rock_only: bool,
) -> bool:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = transparent
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := PreviewCanvas.new()
	canvas.rock_only = rock_only
	viewport.add_child(canvas)
	await process_frame
	RenderingServer.force_draw()
	await process_frame
	RenderingServer.force_draw()
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	if image == null or image.is_empty():
		push_error("README görseli oluşturulamadı: %s" % output_path)
		return false
	var absolute_path := ProjectSettings.globalize_path(output_path)
	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		push_error("README görseli kaydedilemedi: %s" % absolute_path)
		return false
	return true
