class_name CollisionGeometry
extends RefCounted

const TIME_EPSILON := 0.000001
const NO_HIT := Vector3(INF, 0.0, 0.0)


static func sweep_circle_against_block(
	position: Vector2,
	velocity: Vector2,
	max_time: float,
	radius: float,
	block: BlockState,
) -> Vector3:
	return _swept_point_rect(position, velocity, max_time, block.world_rect().grow(radius))


static func is_touching_block(
	position: Vector2,
	radius: float,
	contact_release_epsilon: float,
	block: BlockState,
) -> bool:
	var release_radius := radius + contact_release_epsilon
	return _point_inside_rect(position, block.world_rect().grow(release_radius))


static func _swept_point_rect(
	position: Vector2,
	velocity: Vector2,
	max_time: float,
	rect: Rect2,
) -> Vector3:
	if _point_inside_rect(position, rect):
		var overlap_normal := _closest_rect_exit_normal(position, rect)
		if velocity.dot(overlap_normal) < -TIME_EPSILON:
			return Vector3(0.0, overlap_normal.x, overlap_normal.y)
		return NO_HIT

	var near_x := -INF
	var far_x := INF
	if absf(velocity.x) <= TIME_EPSILON:
		if position.x < rect.position.x or position.x > rect.end.x:
			return NO_HIT
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
			return NO_HIT
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
		return NO_HIT

	var normal := Vector2.ZERO
	if absf(near_x - near_y) <= TIME_EPSILON:
		normal = Vector2(-signf(velocity.x), -signf(velocity.y)).normalized()
	elif near_x > near_y:
		normal = Vector2(-signf(velocity.x), 0.0)
	else:
		normal = Vector2(0.0, -signf(velocity.y))
	return Vector3(entry_time, normal.x, normal.y)


static func _point_inside_rect(point: Vector2, rect: Rect2) -> bool:
	return (
		point.x >= rect.position.x
		and point.x <= rect.end.x
		and point.y >= rect.position.y
		and point.y <= rect.end.y
	)


static func _closest_rect_exit_normal(point: Vector2, rect: Rect2) -> Vector2:
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

