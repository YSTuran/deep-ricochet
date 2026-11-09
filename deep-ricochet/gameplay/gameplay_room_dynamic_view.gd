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
		var progress := clampf(float(effect.get("elapsed", 0.0)) / 0.32, 0.0, 1.0)
		var center := BoardGeometry.world_to_screen(effect.get("position", Vector2.ZERO))
		var destroyed := bool(effect.get("destroyed", false))
		var radius := lerpf(8.0, 34.0 if destroyed else 22.0, progress)
		var color := Color(COLOR_AIM, 1.0 - progress)
		draw_arc(center, radius, 0.0, TAU, 16, color, 3.0, true)
		if destroyed:
			for ray_index in range(6):
				var direction := Vector2.from_angle(float(ray_index) * TAU / 6.0)
				draw_line(
					center + direction * (10.0 + progress * 8.0),
					center + direction * (18.0 + progress * 28.0),
					color,
					2.0,
				)
