extends Node

const BOARD_SIZE := Vector2(8.0, 10.0)
const BALL_RADIUS := 0.07
const BALL_SPEED := 18.0
const BALL_COUNT := 8
const STEP_COUNT := 12_000
const STEP_SECONDS := 1.0 / 60.0


func _ready() -> void:
	AudioManager.stop_all()
	await get_tree().create_timer(0.15, true, false, true).timeout
	var metrics := _run_benchmark()
	print(
		"PERF_BENCHMARK elapsed_ms=%.3f calls=%d collisions=%d usec_per_call=%.3f"
		% [
			float(metrics["elapsed_usec"]) / 1000.0,
			int(metrics["call_count"]),
			int(metrics["collision_count"]),
			float(metrics["elapsed_usec"]) / float(metrics["call_count"]),
		]
	)
	AudioManager.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


func _run_benchmark() -> Dictionary:
	var blocks: Array[BlockState] = []
	var block_id := 1
	for y in range(2, 9, 2):
		for x in range(1, 8, 2):
			blocks.append(BlockState.new(
				block_id,
				BlockState.BlockType.ROCK,
				Vector2i(x, y),
				0,
			))
			block_id += 1

	var balls: Array[BallState] = []
	for index in range(BALL_COUNT):
		var ball := BallState.new()
		_launch_ball(ball, index)
		balls.append(ball)

	var simulator := ShotSimulator.new()
	var collision_count := 0
	var started_usec := Time.get_ticks_usec()
	for step_index in range(STEP_COUNT):
		for ball_index in range(BALL_COUNT):
			var ball := balls[ball_index]
			if not ball.active:
				_launch_ball(ball, ball_index + step_index)
			var result := simulator.advance_ball(
				ball,
				STEP_SECONDS,
				BOARD_SIZE,
				BALL_RADIUS,
				blocks,
			)
			if result.happened:
				collision_count += 1
	var elapsed_usec := Time.get_ticks_usec() - started_usec
	return {
		"elapsed_usec": elapsed_usec,
		"call_count": STEP_COUNT * BALL_COUNT,
		"collision_count": collision_count,
	}


func _launch_ball(ball: BallState, seed: int) -> void:
	var x := 0.55 + float(seed % BALL_COUNT) * 0.96
	var angle := deg_to_rad(52.0 + float(seed % 7) * 11.0)
	ball.launch(Vector2(x, 0.45), Vector2.from_angle(angle) * BALL_SPEED)
