class_name GameplayRoomDynamicView
extends Node2D

const COLOR_AIM := Color("ffe0a0")

var room: GameplayRoom


func bind(gameplay_room: GameplayRoom) -> void:
	room = gameplay_room
	queue_redraw()


func _draw() -> void:
	if room == null or room.config == null:
		return
	_draw_aim_preview()
	_draw_balls()
	_draw_forced_collection_effect()
	_draw_piercing_beams()
	_draw_impact_effects()


func _draw_aim_preview() -> void:
	if not room.aiming or not room.aim_valid or room.aim_preview.points.size() <= 1:
		return
	for point_index in range(room.aim_preview.points.size() - 1):
		draw_dashed_line(
			BoardGeometry.world_to_screen(room.aim_preview.points[point_index]),
			BoardGeometry.world_to_screen(room.aim_preview.points[point_index + 1]),
			COLOR_AIM,
			3.0,
			10.0,
			true,
			true,
		)
	if room.aim_preview.has_terminal_contact:
		var contact_screen := BoardGeometry.world_to_screen(room.aim_preview.contact_position_world)
		draw_circle(contact_screen, 7.0, Color("ffcf66"))
		draw_arc(contact_screen, 10.0, 0.0, TAU, 20, DeepUI.TEXT, 2.0, true)


func _draw_balls() -> void:
	var radius := maxf(5.0, room.config.ball_radius * BoardGeometry.WORLD_SCALE)
	for volley_ball: BallState in room.volley.balls:
		if not volley_ball.active:
			continue
		var ball_screen := BoardGeometry.world_to_screen(volley_ball.position_world)
		draw_circle(ball_screen, radius, DeepUI.TEXT)
		draw_arc(ball_screen, radius, 0.0, TAU, 20, Color("d6bc8c"), 1.5, true)


func _draw_forced_collection_effect() -> void:
	if room.forced_collection_positions.is_empty():
		return
	var progress := clampf(
		room.forced_collection_effect_elapsed / room.FORCED_COLLECTION_EFFECT_SECONDS,
		0.0,
		1.0,
	)
	var eased_progress := ease(progress, 2.0)
	for start_world: Vector2 in room.forced_collection_positions:
		var effect_world := start_world.lerp(BoardGeometry.LAUNCHER_WORLD, eased_progress)
		var effect_color := Color(DeepUI.TEXT, 1.0 - progress * 0.65)
		draw_circle(BoardGeometry.world_to_screen(effect_world), 5.0, effect_color)


func _draw_impact_effects() -> void:
	for effect: Dictionary in room.impact_effects:
		var duration := float(effect.get("duration", 0.32))
		var progress := clampf(float(effect.get("elapsed", 0.0)) / duration, 0.0, 1.0)
		var center := BoardGeometry.world_to_screen(effect.get("position", Vector2.ZERO))
		var block_type := int(effect.get("block_type", BlockState.BlockType.NORMAL))
		var destroyed := bool(effect.get("destroyed", false))
		var is_explosion := bool(effect.get("is_explosion", false))
		var blocked := bool(effect.get("blocked", false))
		var high_quality := room.quality_mode == AppSettings.QualityMode.GRAPHICS
		var seed := int(effect.get("seed", 0))
		var color := _impact_color(block_type)
		if blocked:
			_draw_blocked_contact(center, progress, block_type, color, seed, high_quality)
			continue

		var pulse_radius := lerpf(7.0, 24.0 if destroyed else 17.0, progress)
		draw_arc(
			center,
			pulse_radius,
			0.0,
			TAU,
			20 if high_quality else 12,
			Color(color, (1.0 - progress) * (0.9 if high_quality else 0.62)),
			2.5 if high_quality else 1.8,
			true,
		)
		if not destroyed:
			continue

		match block_type:
			BlockState.BlockType.NORMAL:
				_draw_normal_fragments(center, progress, color, seed, high_quality)
			BlockState.BlockType.ORE:
				_draw_ore_sparks(center, progress, color, seed, high_quality)
			BlockState.BlockType.CRACKED:
				_draw_cracked_debris(center, progress, color, seed, high_quality)
			BlockState.BlockType.EXPLOSIVE:
				_draw_explosive_burst(center, progress, color, seed, high_quality)
			BlockState.BlockType.ARMORED:
				_draw_armored_break(center, progress, color, seed, high_quality)
			BlockState.BlockType.CORE:
				_draw_core_burst(center, progress, color, seed, high_quality)
			BlockState.BlockType.ECHO:
				_draw_echo_break(center, progress, color, high_quality)
			BlockState.BlockType.BALL_CACHE:
				_draw_ball_cache_break(center, progress, color, seed, high_quality)
			BlockState.BlockType.PIERCING:
				_draw_piercing_break(center, progress, color, seed, high_quality)
			BlockState.BlockType.ACID_BARREL:
				_draw_acid_burst(center, progress, color, high_quality)
			_:
				_draw_normal_fragments(center, progress, color, seed, high_quality)
		if is_explosion and high_quality and block_type == BlockState.BlockType.EXPLOSIVE:
			draw_arc(center, lerpf(18.0, 78.0, progress), 0.0, TAU, 28, Color(color, 0.42 * (1.0 - progress)), 4.0, true)
		_draw_point_popup(center, progress, int(effect.get("points", 0)), color, high_quality)


func _draw_blocked_contact(
	center: Vector2,
	progress: float,
	block_type: int,
	color: Color,
	seed: int,
	high_quality: bool,
) -> void:
	var count := 6 if high_quality else 2
	var base_color := Color("b9c4cc") if block_type == BlockState.BlockType.ARMORED else color
	for index in range(count):
		var angle := _effect_angle(index, count, seed) - PI * 0.5
		var direction := Vector2.from_angle(angle)
		var start := center + direction * (5.0 + progress * 5.0)
		var finish := center + direction * (12.0 + progress * 21.0)
		draw_line(start, finish, Color(base_color, 1.0 - progress), 2.2 if high_quality else 1.5, true)
	if high_quality:
		draw_circle(center, lerpf(7.0, 3.0, progress), Color(base_color, 0.18 * (1.0 - progress)))


func _draw_normal_fragments(
	center: Vector2, progress: float, color: Color, seed: int, high_quality: bool,
) -> void:
	var count := 7 if high_quality else 3
	for index in range(count):
		var direction := Vector2.from_angle(_effect_angle(index, count, seed))
		var fragment_center := center + direction * lerpf(8.0, 38.0, progress)
		var size := lerpf(5.0, 2.0, progress)
		draw_rect(Rect2(fragment_center - Vector2.ONE * size * 0.5, Vector2.ONE * size), Color(color.lightened(0.12), 1.0 - progress), true)


func _draw_ore_sparks(
	center: Vector2, progress: float, color: Color, seed: int, high_quality: bool,
) -> void:
	var count := 10 if high_quality else 4
	for index in range(count):
		var direction := Vector2.from_angle(_effect_angle(index, count, seed))
		var spark_center := center + direction * lerpf(6.0, 45.0, progress)
		var radius := lerpf(5.0, 1.5, progress)
		var diamond := PackedVector2Array([
			spark_center + Vector2(0.0, -radius),
			spark_center + Vector2(radius * 0.62, 0.0),
			spark_center + Vector2(0.0, radius),
			spark_center + Vector2(-radius * 0.62, 0.0),
		])
		draw_colored_polygon(diamond, Color(color.lightened(0.3), 1.0 - progress))
	if high_quality:
		draw_circle(center, 15.0 * (1.0 - progress), Color(color, 0.16 * (1.0 - progress)))


func _draw_cracked_debris(
	center: Vector2, progress: float, color: Color, seed: int, high_quality: bool,
) -> void:
	var count := 8 if high_quality else 3
	for index in range(count):
		var direction := Vector2.from_angle(_effect_angle(index, count, seed))
		var start := center + direction * lerpf(5.0, 13.0, progress)
		var sideways := direction.orthogonal() * (3.0 if index % 2 == 0 else -3.0)
		var end := center + direction * lerpf(14.0, 39.0, progress) + sideways
		draw_line(start, end, Color(color.lightened(0.18), 1.0 - progress), 2.4 if high_quality else 1.6, true)


func _draw_explosive_burst(
	center: Vector2, progress: float, color: Color, seed: int, high_quality: bool,
) -> void:
	var ring_color := Color(color.lightened(0.28), 1.0 - progress)
	draw_arc(center, lerpf(10.0, 72.0, progress), 0.0, TAU, 28 if high_quality else 16, ring_color, 4.0 if high_quality else 2.5, true)
	if high_quality:
		draw_arc(center, lerpf(6.0, 48.0, progress), 0.0, TAU, 24, Color("ff4d2e", 0.72 * (1.0 - progress)), 3.0, true)
	var count := 12 if high_quality else 4
	for index in range(count):
		var direction := Vector2.from_angle(_effect_angle(index, count, seed))
		draw_line(
			center + direction * lerpf(8.0, 18.0, progress),
			center + direction * lerpf(20.0, 62.0, progress),
			Color(ring_color, 0.9 - progress * 0.7),
			3.0 if high_quality else 1.8,
			true,
		)


func _draw_armored_break(
	center: Vector2, progress: float, color: Color, seed: int, high_quality: bool,
) -> void:
	var count := 8 if high_quality else 3
	for index in range(count):
		var direction := Vector2.from_angle(_effect_angle(index, count, seed))
		var shard_center := center + direction * lerpf(8.0, 42.0, progress)
		var shard_color := Color("7d8b94") if index % 2 == 0 else color.lightened(0.2)
		draw_line(
			shard_center - direction * 5.0,
			shard_center + direction * 5.0,
			Color(shard_color, 1.0 - progress),
			4.0 if high_quality else 2.3,
			true,
		)
	if high_quality:
		draw_arc(center, lerpf(9.0, 34.0, progress), 0.0, TAU, 20, Color("ff7ed8", 0.55 * (1.0 - progress)), 2.5, true)


func _draw_core_burst(
	center: Vector2, progress: float, color: Color, seed: int, high_quality: bool,
) -> void:
	var ring_count := 3 if high_quality else 1
	for ring_index in range(ring_count):
		var delayed := clampf(progress * 1.25 - float(ring_index) * 0.14, 0.0, 1.0)
		draw_arc(
			center,
			lerpf(10.0, 64.0 + float(ring_index) * 9.0, delayed),
			0.0,
			TAU,
			30 if high_quality else 18,
			Color(color.lightened(0.25), (1.0 - delayed) * (0.82 - float(ring_index) * 0.16)),
			3.5 if high_quality else 2.2,
			true,
		)
	var count := 12 if high_quality else 4
	for index in range(count):
		var direction := Vector2.from_angle(_effect_angle(index, count, seed))
		var point := center + direction * lerpf(10.0, 52.0, progress)
		draw_circle(point, lerpf(4.0, 1.0, progress), Color(color.lightened(0.35), 1.0 - progress))


func _draw_echo_break(
	center: Vector2, progress: float, color: Color, high_quality: bool,
) -> void:
	var ring_count := 3 if high_quality else 1
	for ring_index in range(ring_count):
		var delayed := clampf(progress * 1.3 - float(ring_index) * 0.16, 0.0, 1.0)
		draw_arc(
			center,
			lerpf(7.0, 54.0 + float(ring_index) * 8.0, delayed),
			0.0,
			TAU,
			28 if high_quality else 14,
			Color(color.lightened(0.3), (1.0 - delayed) * 0.72),
			3.0 if high_quality else 1.8,
			true,
		)


func _draw_ball_cache_break(
	center: Vector2, progress: float, color: Color, seed: int, high_quality: bool,
) -> void:
	var count := 7 if high_quality else 3
	for index in range(count):
		var direction := Vector2.from_angle(_effect_angle(index, count, seed) - PI * 0.5)
		var ball_center := center + direction * lerpf(6.0, 39.0, progress)
		var radius := lerpf(5.0, 2.0, progress)
		draw_circle(ball_center, radius, Color(DeepUI.TEXT, 1.0 - progress))
		draw_arc(
			ball_center,
			radius,
			0.0,
			TAU,
			12,
			Color(color.lightened(0.25), 1.0 - progress),
			1.4,
			true,
		)


func _draw_piercing_break(
	center: Vector2, progress: float, color: Color, seed: int, high_quality: bool,
) -> void:
	var count := 9 if high_quality else 3
	for index in range(count):
		var direction := Vector2.from_angle(_effect_angle(index, count, seed))
		var shard_center := center + direction * lerpf(5.0, 43.0, progress)
		var tangent := direction.orthogonal() * (3.5 if high_quality else 2.0)
		draw_colored_polygon(PackedVector2Array([
			shard_center + direction * 6.0,
			shard_center - direction * 5.0 + tangent,
			shard_center - direction * 5.0 - tangent,
		]), Color(color.lightened(0.3), 1.0 - progress))


func _draw_acid_burst(
	center: Vector2, progress: float, color: Color, high_quality: bool,
) -> void:
	var alpha := (1.0 - progress) * (0.78 if high_quality else 0.56)
	for radius in range(1, 4):
		var half_side := float(radius) * BoardGeometry.WORLD_SCALE
		var size := Vector2.ONE * half_side * 2.0
		var ring_rect := Rect2(center - Vector2.ONE * half_side, size).intersection(
			BoardGeometry.SCREEN_RECT
		)
		if not ring_rect.has_area():
			continue
		draw_rect(
			ring_rect,
			Color(color, alpha / float(radius)),
			false,
			3.0 if high_quality else 1.5,
		)
	if high_quality:
		draw_circle(center, lerpf(12.0, 35.0, progress), Color(color, alpha * 0.16))


func _draw_piercing_beams() -> void:
	var high_quality := room.quality_mode == AppSettings.QualityMode.GRAPHICS
	var beam_color := CaveTheme.block_color(BlockState.BlockType.PIERCING).lightened(0.28)
	for effect: Dictionary in room.piercing_beam_effects:
		var progress := clampf(
			float(effect.get("elapsed", 0.0)) / room.PIERCING_BEAM_EFFECT_SECONDS,
			0.0,
			1.0,
		)
		var start := BoardGeometry.world_to_screen(effect.get("origin", Vector2.ZERO))
		var finish := BoardGeometry.world_to_screen(effect.get("end", Vector2.ZERO))
		var alpha := (1.0 - progress) * (0.92 if high_quality else 0.72)
		if high_quality:
			draw_line(start, finish, Color(beam_color, alpha * 0.18), 14.0, true)
			draw_line(start, finish, Color(beam_color, alpha * 0.42), 7.0, true)
		draw_line(start, finish, Color(beam_color.lightened(0.42), alpha), 3.0 if high_quality else 2.0, true)


func _draw_point_popup(
	center: Vector2, progress: float, points: int, color: Color, high_quality: bool,
) -> void:
	if points <= 0:
		return
	var popup_rect := Rect2(
		center + Vector2(-38.0, -34.0 - ease(progress, 0.65) * 24.0),
		Vector2(76.0, 28.0),
	)
	if high_quality:
		DeepUI.draw_centered(
			self,
			"+%d" % points,
			Rect2(popup_rect.position + Vector2(1.5, 2.0), popup_rect.size),
			17,
			Color(0.0, 0.0, 0.0, 0.55 * (1.0 - progress)),
		)
	DeepUI.draw_centered(
		self,
		"+%d" % points,
		popup_rect,
		17 if high_quality else 13,
		Color(color.lightened(0.35 if high_quality else 0.12), 1.0 - progress),
	)


func _effect_angle(index: int, count: int, seed: int) -> float:
	var offset := float(posmod(seed, 360)) * PI / 180.0
	return offset + float(index) * TAU / float(maxi(count, 1))


func _impact_color(block_type: int) -> Color:
	if block_type == BlockState.BlockType.ACID_BARREL:
		return CaveTheme.color(&"acid")
	return CaveTheme.block_color(block_type)
