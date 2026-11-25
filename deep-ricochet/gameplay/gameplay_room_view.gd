class_name GameplayRoomView
extends Node2D

const NORMAL_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_normal.png")
const ORE_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_cevher.png")
const CORE_TEXTURE: Texture2D = preload("res://assets/images/blocks/cekirdek.png")
const CRACKED_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_catlak.png")
const EXPLOSIVE_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_patlayici.png")
const ARMORED_BOTTOM_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_zirhli_alt.png")
const ARMORED_LEFT_BOTTOM_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_zirhli_sol_alt.png")
const ARMORED_RIGHT_BOTTOM_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_zirhli_sag_alt.png")
const ECHO_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_yanki.png")
const BALL_CACHE_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_top_haznesi.png")
const PIERCING_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_delici_kristal.png")
const CRACKED_SOURCE := Rect2(32.0, 36.0, 447.0, 454.0)
const EXPLOSIVE_SOURCE := Rect2(54.0, 65.0, 404.0, 407.0)
const ARMORED_BOTTOM_SOURCE := Rect2(5.0, 6.0, 502.0, 502.0)
const ARMORED_LEFT_BOTTOM_SOURCE := Rect2(5.0, 5.0, 503.0, 503.0)
const ARMORED_RIGHT_BOTTOM_SOURCE := Rect2(4.0, 5.0, 503.0, 503.0)

var room: GameplayRoom
@onready var background_layer: GameplayRoomBackgroundView = $Background
@onready var dynamic_layer: GameplayRoomDynamicView = $Dynamic
var shake_remaining := 0.0
var shake_duration := 0.0
var shake_strength := 0.0


func bind(gameplay_room: GameplayRoom) -> void:
	room = gameplay_room
	dynamic_layer.bind(gameplay_room)
	queue_redraw()


func refresh() -> void:
	queue_redraw()
	dynamic_layer.queue_redraw()


func refresh_background() -> void:
	background_layer.refresh()


func refresh_static() -> void:
	queue_redraw()


func refresh_dynamic() -> void:
	dynamic_layer.queue_redraw()


func start_screen_shake(strength: float, duration: float) -> void:
	var incoming_strength := maxf(0.0, strength)
	var incoming_duration := maxf(0.01, duration)
	if shake_remaining > 0.0 and shake_duration > 0.0:
		var current_strength := shake_strength * shake_remaining / shake_duration
		shake_strength = maxf(current_strength, incoming_strength)
		shake_duration = maxf(shake_remaining, incoming_duration)
		shake_remaining = shake_duration
	else:
		shake_strength = incoming_strength
		shake_duration = incoming_duration
		shake_remaining = incoming_duration
	set_process(true)


func _process(delta: float) -> void:
	if shake_remaining <= 0.0:
		_finish_screen_shake()
		return
	shake_remaining = maxf(0.0, shake_remaining - delta)
	var progress := 1.0 - shake_remaining / shake_duration
	var amplitude := shake_strength * (1.0 - progress)
	position = Vector2(
		sin(progress * 52.0 * TAU),
		sin(progress * 37.0 * TAU + 0.8),
	) * amplitude
	if shake_remaining <= 0.0:
		_finish_screen_shake()


func _finish_screen_shake() -> void:
	position = Vector2.ZERO
	shake_remaining = 0.0
	shake_duration = 0.0
	shake_strength = 0.0
	set_process(false)


func _draw() -> void:
	if room == null or room.config == null or room.current_template == null:
		return

	_draw_text(
		Vector2(30.0, 48.0),
		tr("HUD_TITLE") % room.current_template.localized_display_name(),
		20,
		DeepUI.TEXT,
	)
	DeepUI.draw_chip(
		self,
		Rect2(30.0, 58.0, 104.0, 28.0),
		tr("HUD_ROOM_CHIP") % [room.run_room_number, room.run_room_count],
		DeepUI.BLUE,
		12,
	)
	DeepUI.draw_chip(
		self,
		Rect2(140.0, 58.0, 104.0, 28.0),
		tr("HUD_SHOTS_CHIP") % [room.room.shots_remaining, room.shots_per_room],
		DeepUI.GOLD,
		12,
	)
	DeepUI.draw_chip(
		self,
		Rect2(250.0, 58.0, 78.0, 28.0),
		"×%.1f" % (float(room.room.multiplier_bps) / 10_000.0),
		DeepUI.GOLD,
		13,
	)
	var score_chip_width := 284.0 if room.room.next_shot_ball_bonus > 0 else 418.0
	DeepUI.draw_chip(
		self,
		Rect2(30.0, 92.0, score_chip_width, 28.0),
		tr("HUD_SCORE_SUMMARY") % [room.banked_score, room.room.break_score],
		DeepUI.BORDER,
		12,
	)
	if room.room.next_shot_ball_bonus > 0:
		DeepUI.draw_chip(
			self,
			Rect2(320.0, 92.0, 128.0, 28.0),
			tr("HUD_NEXT_SHOT_BONUS") % room.room.next_shot_ball_bonus,
			CaveTheme.block_color(BlockState.BlockType.BALL_CACHE),
			12,
		)

	for block: BlockState in room.board.blocks:
		if block.is_destroyed():
			continue
		match block.type:
			BlockState.BlockType.NORMAL:
				_draw_texture_block(
					block.world_rect(),
					NORMAL_TEXTURE,
					Rect2(139.0, 159.0, 976.0, 939.0),
					str(block.hit_points),
					BlockState.BlockType.NORMAL,
				)
			BlockState.BlockType.ORE:
				_draw_texture_block(
					block.world_rect(),
					ORE_TEXTURE,
					Rect2(209.0, 220.0, 837.0, 831.0),
					str(block.hit_points),
					BlockState.BlockType.ORE,
				)
			BlockState.BlockType.ROCK:
				_draw_hard_rock(block.world_rect())
			BlockState.BlockType.CORE:
				_draw_core(block.collision_center_world(), str(block.hit_points))
			BlockState.BlockType.EXPLOSIVE:
				_draw_illustrated_block(
					block.world_rect(),
					EXPLOSIVE_TEXTURE,
					EXPLOSIVE_SOURCE,
					str(block.hit_points),
					BlockState.BlockType.EXPLOSIVE,
				)
			BlockState.BlockType.CRACKED:
				_draw_illustrated_block(
					block.world_rect(),
					CRACKED_TEXTURE,
					CRACKED_SOURCE,
					str(block.hit_points),
					BlockState.BlockType.CRACKED,
				)
			BlockState.BlockType.ARMORED:
				_draw_armored(block)
			BlockState.BlockType.ECHO:
				_draw_full_texture_block(block, ECHO_TEXTURE)
			BlockState.BlockType.BALL_CACHE:
				_draw_full_texture_block(block, BALL_CACHE_TEXTURE)
			BlockState.BlockType.PIERCING:
				_draw_piercing(block)



func _world_rect_to_screen(world_rect: Rect2, margin: float = 4.0) -> Rect2:
	return BoardGeometry.world_rect_to_screen(world_rect, margin)


func _draw_texture_block(
	world_rect: Rect2,
	texture: Texture2D,
	source_rect: Rect2,
	hp_text: String,
	block_type: int,
) -> void:
	var destination := _world_rect_to_screen(world_rect, 4.0)
	CaveTheme.draw_texture_region(
		self,
		texture,
		destination,
		source_rect,
		block_type,
	)
	_draw_centered_text(destination, hp_text, 26, DeepUI.TEXT, 0.66)


func _draw_core(center_world: Vector2, hp_text: String) -> void:
	var center_screen := BoardGeometry.world_to_screen(center_world)
	var destination := Rect2(center_screen - Vector2.ONE * 39.0, Vector2.ONE * 78.0)
	CaveTheme.draw_texture(self, CORE_TEXTURE, destination, BlockState.BlockType.CORE)
	_draw_centered_text(destination, hp_text, 26, DeepUI.TEXT, 0.64)


func _draw_hard_rock(world_rect: Rect2) -> void:
	var rect := _world_rect_to_screen(world_rect, 5.0)
	CaveTheme.draw_hard_rock(self, rect)


func _draw_illustrated_block(
	world_rect: Rect2,
	texture: Texture2D,
	source_rect: Rect2,
	hp_text: String,
	block_type: int,
) -> void:
	var rect := _world_rect_to_screen(world_rect, 4.0)
	CaveTheme.draw_texture_region(self, texture, rect, source_rect, block_type)
	_draw_centered_text(rect, hp_text, 26, DeepUI.TEXT, 0.66)


func _draw_armored(block: BlockState) -> void:
	var texture := ARMORED_BOTTOM_TEXTURE
	var source_rect := ARMORED_BOTTOM_SOURCE
	if (block.vulnerable_sides & BlockState.VulnerableSide.LEFT) != 0:
		texture = ARMORED_LEFT_BOTTOM_TEXTURE
		source_rect = ARMORED_LEFT_BOTTOM_SOURCE
	elif (block.vulnerable_sides & BlockState.VulnerableSide.RIGHT) != 0:
		texture = ARMORED_RIGHT_BOTTOM_TEXTURE
		source_rect = ARMORED_RIGHT_BOTTOM_SOURCE
	_draw_illustrated_block(
		block.world_rect(),
		texture,
		source_rect,
		str(block.hit_points),
		BlockState.BlockType.ARMORED,
	)


func _draw_full_texture_block(block: BlockState, texture: Texture2D) -> void:
	var rect := _world_rect_to_screen(block.world_rect(), 4.0)
	CaveTheme.draw_texture(self, texture, rect, block.type)
	_draw_centered_text(rect, str(block.hit_points), 26, DeepUI.TEXT, 0.66)


func _draw_piercing(block: BlockState) -> void:
	var rect := _world_rect_to_screen(block.world_rect(), 3.0)
	var angle := _beam_screen_rotation(block.beam_direction)
	draw_set_transform(rect.get_center(), angle)
	var local_rect := Rect2(-rect.size * 0.5, rect.size)
	CaveTheme.draw_texture(self, PIERCING_TEXTURE, local_rect, block.type)
	draw_set_transform(Vector2.ZERO, 0.0)
	_draw_centered_text(rect, str(block.hit_points), 26, DeepUI.TEXT, 0.72)


func _beam_screen_rotation(direction: int) -> float:
	match direction:
		BlockState.BeamDirection.RIGHT:
			return PI * 0.5
		BlockState.BeamDirection.DOWN:
			return PI
		BlockState.BeamDirection.LEFT:
			return -PI * 0.5
	return 0.0


func _draw_text(position: Vector2, text: String, size: int, color: Color) -> void:
	DeepUI.draw_text(self, text, position, size, color)


func _draw_centered_text(rect: Rect2, text: String, size: int, color: Color, baseline_ratio: float) -> void:
	draw_string(
		ThemeDB.fallback_font,
		Vector2(rect.position.x, rect.position.y + rect.size.y * baseline_ratio),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x,
		size,
		color,
	)
