class_name ShotSimulator
extends RefCounted

const MAX_COLLISIONS_PER_STEP := 8
const TIME_EPSILON := 0.000001
const POSITION_EPSILON := 0.0001
const CONTACT_RELEASE_EPSILON := 0.001


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
			var block_hit := CollisionGeometry.sweep_circle_against_block(
				ball.position_world,
				ball.velocity_world,
				remaining,
				radius,
				block,
			)
			var block_time := block_hit.x
			if block_time >= time_to_hit:
				continue
			time_to_hit = block_time
			hit_normal = Vector2(block_hit.y, block_hit.z)
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
				result.block_contacts.append(BlockContactEvent.new(
					hit_block.id,
					int(hit_block.type),
					ball.position_world,
					hit_normal,
				))

		ball.velocity_world = ball.velocity_world.bounce(hit_normal)
		ball.position_world += hit_normal * POSITION_EPSILON
		if hit_kind == &"wall" or (
			hit_kind == &"block"
			and hit_block != null
			and (
				hit_block.type == BlockState.BlockType.ROCK
				or (
					hit_block.type == BlockState.BlockType.ARMORED
					and not hit_block.accepts_contact(hit_normal)
				)
			)
		):
			result.preview_bounce_count += 1
		collision_count += 1

	_refresh_active_contacts(ball, blocks, radius)
	return result


func _refresh_active_contacts(
	ball: BallState,
	blocks: Array[BlockState],
	radius: float,
) -> void:
	if ball.active_contacts.is_empty():
		return
	var released_contacts: Array[int] = []
	for block_id: int in ball.active_contacts:
		var active_block: BlockState = null
		for block: BlockState in blocks:
			if block.id == block_id and not block.is_destroyed():
				active_block = block
				break
		if active_block == null or not CollisionGeometry.is_touching_block(
			ball.position_world,
			radius,
			CONTACT_RELEASE_EPSILON,
			active_block,
		):
			released_contacts.append(block_id)
	for block_id: int in released_contacts:
		ball.active_contacts.erase(block_id)
