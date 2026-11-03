class_name ShotSimulator
extends RefCounted

const MAX_COLLISIONS_PER_STEP := 4
const TIME_EPSILON := 0.000001
const POSITION_EPSILON := 0.0001


func advance_ball(
	ball: BallState,
	delta: float,
	board_size: Vector2,
	radius: float,
) -> CollisionResult:
	var result := CollisionResult.new()
	if not ball.active or delta <= 0.0:
		return result

	var remaining := delta
	var collision_count := 0
	while remaining > TIME_EPSILON and collision_count < MAX_COLLISIONS_PER_STEP:
		var time_to_hit := remaining + 1.0
		var hit_normal := Vector2.ZERO
		var hit_kind: StringName = &"none"

		if ball.velocity_world.x < 0.0:
			var left_time := (radius - ball.position_world.x) / ball.velocity_world.x
			if left_time >= 0.0 and left_time < time_to_hit:
				time_to_hit = left_time
				hit_normal = Vector2.RIGHT
				hit_kind = &"wall"
		elif ball.velocity_world.x > 0.0:
			var right_time := (board_size.x - radius - ball.position_world.x) / ball.velocity_world.x
			if right_time >= 0.0 and right_time < time_to_hit:
				time_to_hit = right_time
				hit_normal = Vector2.LEFT
				hit_kind = &"wall"

		if ball.velocity_world.y > 0.0:
			var top_time := (board_size.y - radius - ball.position_world.y) / ball.velocity_world.y
			if top_time >= 0.0 and top_time < time_to_hit:
				time_to_hit = top_time
				hit_normal = Vector2.DOWN
				hit_kind = &"wall"
		elif ball.velocity_world.y < 0.0:
			var collect_time := (-radius - ball.position_world.y) / ball.velocity_world.y
			if collect_time >= 0.0 and collect_time < time_to_hit:
				time_to_hit = collect_time
				hit_normal = Vector2.UP
				hit_kind = &"collector"

		if time_to_hit > remaining:
			ball.position_world += ball.velocity_world * remaining
			remaining = 0.0
			break

		ball.position_world += ball.velocity_world * time_to_hit
		remaining -= time_to_hit
		result.happened = true
		result.kind = hit_kind
		result.normal = hit_normal
		result.position_world = ball.position_world

		if hit_kind == &"collector":
			ball.collect()
			break

		ball.velocity_world = ball.velocity_world.bounce(hit_normal)
		ball.position_world += hit_normal * POSITION_EPSILON
		collision_count += 1

	ball.simulation_age += delta
	return result
