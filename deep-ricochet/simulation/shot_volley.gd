class_name ShotVolley
extends RefCounted

const TIME_EPSILON := 0.000001

var balls: Array[BallState] = []
var active: bool = false
var elapsed_seconds: float = 0.0
var launched_count: int = 0
var collected_count: int = 0
var forced_collection_count: int = 0
var total_ball_count: int = 0

var _origin := Vector2.ZERO
var _velocity := Vector2.ZERO
var _launch_interval_seconds: float = 0.0
var _time_limit_seconds: float = 0.0
var _launched: Array[bool] = []
var _collected: Array[bool] = []
var _finish_event_pending: bool = false


func start(
	origin: Vector2,
	velocity: Vector2,
	ball_count: int,
	launch_interval_seconds: float,
	time_limit_seconds: float,
) -> bool:
	if active:
		return false
	if velocity.is_zero_approx() or ball_count <= 0:
		return false
	if launch_interval_seconds < 0.0 or time_limit_seconds <= 0.0:
		return false
	if float(ball_count - 1) * launch_interval_seconds >= time_limit_seconds:
		return false

	reset()
	_origin = origin
	_velocity = velocity
	total_ball_count = ball_count
	_launch_interval_seconds = launch_interval_seconds
	_time_limit_seconds = time_limit_seconds
	active = true

	for index in range(total_ball_count):
		balls.append(BallState.new())
		_launched.append(false)
		_collected.append(false)
		if _launch_time(index) <= TIME_EPSILON:
			_launch_ball(index)
	return true


func advance(
	delta: float,
	simulator: ShotSimulator,
	board_size: Vector2,
	ball_radius: float,
	board: BoardModel,
) -> VolleyStepResult:
	var step_result := VolleyStepResult.new()
	if not active or delta <= 0.0:
		return step_result

	var previous_elapsed := elapsed_seconds
	elapsed_seconds = minf(elapsed_seconds + delta, _time_limit_seconds)
	var simulated_delta := elapsed_seconds - previous_elapsed

	for index in range(total_ball_count):
		var launch_time := _launch_time(index)
		if not _launched[index] and launch_time <= elapsed_seconds + TIME_EPSILON:
			_launch_ball(index)

		if not _launched[index] or _collected[index]:
			continue
		var ball_delta := simulated_delta
		if launch_time > previous_elapsed:
			ball_delta = maxf(0.0, elapsed_seconds - launch_time)
		if ball_delta <= TIME_EPSILON:
			continue

		var collision := simulator.advance_ball(
			balls[index],
			ball_delta,
			board_size,
			ball_radius,
			board.blocks,
		)
		for contact: BlockContactEvent in collision.block_contacts:
			var damage_result := board.resolve_contact(contact.block_id, 1, contact.normal)
			step_result.damage_results.append(damage_result)
			if damage_result.destroyed \
				and damage_result.block_type == BlockState.BlockType.EXPLOSIVE:
				step_result.damage_results.append_array(
					board.resolve_explosion(damage_result.block_id, 3)
				)
		if collision.happened:
			step_result.collisions.append(collision)
		if not balls[index].active:
			_mark_collected(index)

	if elapsed_seconds >= _time_limit_seconds - TIME_EPSILON:
		step_result.forced_collection_positions = _force_collect_remaining_balls()
	_finish_if_ready()
	return step_result


func consume_finished_event() -> bool:
	if not _finish_event_pending:
		return false
	_finish_event_pending = false
	return true


func reset() -> void:
	balls.clear()
	_launched.clear()
	_collected.clear()
	active = false
	elapsed_seconds = 0.0
	launched_count = 0
	collected_count = 0
	forced_collection_count = 0
	total_ball_count = 0
	_finish_event_pending = false


func _launch_time(index: int) -> float:
	return float(index) * _launch_interval_seconds


func _launch_ball(index: int) -> void:
	if _launched[index]:
		return
	_launched[index] = true
	launched_count += 1
	balls[index].launch(_origin, _velocity)


func _mark_collected(index: int) -> void:
	if _collected[index]:
		return
	_collected[index] = true
	collected_count += 1


func _force_collect_remaining_balls() -> PackedVector2Array:
	var collected_positions := PackedVector2Array()
	for index in range(total_ball_count):
		if not _launched[index]:
			_launch_ball(index)
		if _collected[index]:
			continue
		if balls[index].active:
			collected_positions.append(balls[index].position_world)
			balls[index].collect()
			forced_collection_count += 1
		_mark_collected(index)
	return collected_positions


func _finish_if_ready() -> void:
	if launched_count < total_ball_count or collected_count < total_ball_count:
		return
	active = false
	_finish_event_pending = true

