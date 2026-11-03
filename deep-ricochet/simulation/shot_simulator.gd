class_name ShotSimulator
extends RefCounted

const MAX_COLLISIONS_PER_STEP := 8
const TIME_EPSILON := 0.000001
const POSITION_EPSILON := 0.0001
const CONTACT_RELEASE_EPSILON := 0.001
const DEFAULT_PREVIEW_STEP := 1.0 / 120.0
const DEFAULT_PREVIEW_SECONDS := 3.0


func advance_ball(
	ball: BallState,
	delta: float,
	board_size: Vector2,
	radius: float,
	blocks: Array[BlockState] = [],
) -> CollisionResult:
	var result := CollisionResult.new()
	if not ball.active or delta <= 0.0:
		return result

	_refresh_active_contacts(ball, blocks, radius)
	var remaining := delta
	var collision_count := 0
	while remaining > TIME_EPSILON and collision_count < MAX_COLLISIONS_PER_STEP:
		var time_to_hit := remaining + 1.0
		var hit_normal := Vector2.ZERO
		var hit_kind: StringName = &"none"
		var hit_block: BlockState = null

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

		for block: BlockState in blocks:
			if block.is_destroyed():
				continue
			var block_hit := _swept_circle_against_block(
				ball.position_world,
				ball.velocity_world,
				remaining,
				radius,
				block,
			)
			if block_hit.is_empty():
				continue
			var block_time := float(block_hit.get("time", remaining + 1.0))
			if block_time < time_to_hit:
				time_to_hit = block_time
				hit_normal = block_hit.get("normal", Vector2.ZERO)
				hit_kind = &"block"
				hit_block = block

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

		if hit_kind == &"block" and hit_block != null:
			result.block_id = hit_block.id
			result.block_type = int(hit_block.type)
			if not ball.active_contacts.has(hit_block.id):
				ball.active_contacts[hit_block.id] = true
				result.contact_started = true
				if hit_block.apply_damage():
					result.damage_applied = true
					result.block_destroyed = hit_block.is_destroyed()

		ball.velocity_world = ball.velocity_world.bounce(hit_normal)
		ball.position_world += hit_normal * POSITION_EPSILON
		result.solid_bounce_count += 1
		collision_count += 1

	_refresh_active_contacts(ball, blocks, radius)
	ball.simulation_age += delta
	return result


func build_preview_path(
	origin: Vector2,
	velocity: Vector2,
	board_size: Vector2,
	radius: float,
	blocks: Array[BlockState],
	max_solid_bounces: int,
	time_step: float = DEFAULT_PREVIEW_STEP,
	max_seconds: float = DEFAULT_PREVIEW_SECONDS,
) -> PackedVector2Array:
	var points := PackedVector2Array([origin])
	if velocity.is_zero_approx() or max_solid_bounces <= 0:
		return points

	var preview_blocks: Array[BlockState] = []
	for block: BlockState in blocks:
		preview_blocks.append(block.duplicate_state())

	var preview_ball := BallState.new()
	preview_ball.launch(origin, velocity)
	var elapsed := 0.0
	var solid_bounces := 0
	while preview_ball.active and elapsed < max_seconds:
		var step := minf(time_step, max_seconds - elapsed)
		var collision := advance_ball(preview_ball, step, board_size, radius, preview_blocks)
		elapsed += step

		if not collision.happened:
			continue
		if points[points.size() - 1].distance_to(collision.position_world) > POSITION_EPSILON:
			points.append(collision.position_world)
		if collision.kind == &"collector":
			return points

		solid_bounces += collision.solid_bounce_count
		if solid_bounces >= max_solid_bounces:
			return points

	if preview_ball.active and points[points.size() - 1].distance_to(preview_ball.position_world) > POSITION_EPSILON:
		points.append(preview_ball.position_world)
	return points


func _swept_circle_against_block(
	position: Vector2,
	velocity: Vector2,
	max_time: float,
	radius: float,
	block: BlockState,
) -> Dictionary:
	if block.type == BlockState.BlockType.CORE:
		return _swept_point_circle(
			position,
			velocity,
			max_time,
			block.collision_center_world(),
			BlockState.CORE_COLLISION_RADIUS + radius,
		)
	return _swept_point_rect(position, velocity, max_time, block.world_rect().grow(radius))


func _swept_point_rect(
	position: Vector2,
	velocity: Vector2,
	max_time: float,
	rect: Rect2,
) -> Dictionary:
	if _point_inside_rect(position, rect):
		var overlap_normal := _closest_rect_exit_normal(position, rect)
		if velocity.dot(overlap_normal) < -TIME_EPSILON:
			return {"time": 0.0, "normal": overlap_normal}
		return {}

	var near_x := -INF
	var far_x := INF
	if absf(velocity.x) <= TIME_EPSILON:
		if position.x < rect.position.x or position.x > rect.end.x:
			return {}
	else:
		near_x = (rect.position.x - position.x) / velocity.x
		far_x = (rect.end.x - position.x) / velocity.x
		if near_x > far_x:
			var swap_x := near_x
			near_x = far_x
			far_x = swap_x

	var near_y := -INF
	var far_y := INF
	if absf(velocity.y) <= TIME_EPSILON:
		if position.y < rect.position.y or position.y > rect.end.y:
			return {}
	else:
		near_y = (rect.position.y - position.y) / velocity.y
		far_y = (rect.end.y - position.y) / velocity.y
		if near_y > far_y:
			var swap_y := near_y
			near_y = far_y
			far_y = swap_y

	var entry_time := maxf(near_x, near_y)
	var exit_time := minf(far_x, far_y)
	if entry_time > exit_time or exit_time < 0.0 or entry_time < 0.0 or entry_time > max_time:
		return {}

	var normal := Vector2.ZERO
	if absf(near_x - near_y) <= TIME_EPSILON:
		normal = Vector2(-signf(velocity.x), -signf(velocity.y)).normalized()
	elif near_x > near_y:
		normal = Vector2(-signf(velocity.x), 0.0)
	else:
		normal = Vector2(0.0, -signf(velocity.y))
	return {"time": entry_time, "normal": normal}


func _swept_point_circle(
	position: Vector2,
	velocity: Vector2,
	max_time: float,
	center: Vector2,
	combined_radius: float,
) -> Dictionary:
	var relative := position - center
	if relative.length_squared() <= combined_radius * combined_radius:
		var overlap_normal := relative.normalized()
		if overlap_normal.is_zero_approx():
			overlap_normal = -velocity.normalized()
		if velocity.dot(overlap_normal) < -TIME_EPSILON:
			return {"time": 0.0, "normal": overlap_normal}
		return {}

	var speed_squared := velocity.length_squared()
	if speed_squared <= TIME_EPSILON:
		return {}
	var b := 2.0 * relative.dot(velocity)
	var c := relative.length_squared() - combined_radius * combined_radius
	var discriminant := b * b - 4.0 * speed_squared * c
	if discriminant < 0.0:
		return {}

	var hit_time := (-b - sqrt(discriminant)) / (2.0 * speed_squared)
	if hit_time < 0.0 or hit_time > max_time:
		return {}
	var hit_position := position + velocity * hit_time
	var normal := (hit_position - center).normalized()
	if velocity.dot(normal) >= 0.0:
		return {}
	return {"time": hit_time, "normal": normal}


func _refresh_active_contacts(
	ball: BallState,
	blocks: Array[BlockState],
	radius: float,
) -> void:
	var blocks_by_id: Dictionary[int, BlockState] = {}
	for block: BlockState in blocks:
		if not block.is_destroyed():
			blocks_by_id[block.id] = block

	for block_id: int in ball.active_contacts.keys():
		var block: BlockState = blocks_by_id.get(block_id)
		if block == null or not _is_touching_block(ball.position_world, radius, block):
			ball.active_contacts.erase(block_id)


func _is_touching_block(position: Vector2, radius: float, block: BlockState) -> bool:
	var release_radius := radius + CONTACT_RELEASE_EPSILON
	if block.type == BlockState.BlockType.CORE:
		var combined_radius := BlockState.CORE_COLLISION_RADIUS + release_radius
		return position.distance_squared_to(block.collision_center_world()) <= combined_radius * combined_radius
	return _point_inside_rect(position, block.world_rect().grow(release_radius))


func _point_inside_rect(point: Vector2, rect: Rect2) -> bool:
	return (
		point.x >= rect.position.x
		and point.x <= rect.end.x
		and point.y >= rect.position.y
		and point.y <= rect.end.y
	)


func _closest_rect_exit_normal(point: Vector2, rect: Rect2) -> Vector2:
	var normal := Vector2.LEFT
	var closest_distance := absf(point.x - rect.position.x)
	var right_distance := absf(rect.end.x - point.x)
	if right_distance < closest_distance:
		closest_distance = right_distance
		normal = Vector2.RIGHT
	var bottom_distance := absf(point.y - rect.position.y)
	if bottom_distance < closest_distance:
		closest_distance = bottom_distance
		normal = Vector2.DOWN
	var top_distance := absf(rect.end.y - point.y)
	if top_distance < closest_distance:
		normal = Vector2.UP
	return normal
