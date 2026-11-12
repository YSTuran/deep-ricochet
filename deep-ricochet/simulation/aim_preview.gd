class_name AimPreview
extends RefCounted

const DEFAULT_TIME_STEP := 1.0 / 60.0
const DEFAULT_MAX_SECONDS := 3.0
const POINT_EPSILON := 0.0001


func build_path(
	simulator: ShotSimulator,
	origin: Vector2,
	velocity: Vector2,
	board_size: Vector2,
	radius: float,
	blocks: Array[BlockState],
	max_solid_bounces: int,
	time_step: float = DEFAULT_TIME_STEP,
	max_seconds: float = DEFAULT_MAX_SECONDS,
) -> AimPreviewResult:
	var preview := AimPreviewResult.new(origin)
	if velocity.is_zero_approx() or max_solid_bounces < 0:
		return preview

	var preview_ball := BallState.new()
	preview_ball.launch(origin, velocity)
	var elapsed := 0.0
	var solid_bounces := 0
	while preview_ball.active and elapsed < max_seconds:
		var step := minf(time_step, max_seconds - elapsed)
		var collision := simulator.advance_ball(preview_ball, step, board_size, radius, blocks)
		elapsed += step

		if not collision.happened:
			continue

		for contact: BlockContactEvent in collision.block_contacts:
			var contact_block := _block_by_id(blocks, contact.block_id)
			if contact.block_type == BlockState.BlockType.ROCK \
				or (
					contact_block != null
					and contact_block.type == BlockState.BlockType.ARMORED
					and not contact_block.accepts_contact(contact.normal)
				):
				continue
			_append_point(preview.points, contact.position_world)
			preview.has_terminal_contact = true
			preview.contact_position_world = contact.position_world
			preview.contact_block_id = contact.block_id
			return preview

		_append_point(preview.points, collision.position_world)
		if collision.kind == &"collector":
			return preview

		solid_bounces += collision.preview_bounce_count
		if solid_bounces >= max_solid_bounces:
			return preview

	if preview_ball.active:
		_append_point(preview.points, preview_ball.position_world)
	return preview


func _block_by_id(blocks: Array[BlockState], block_id: int) -> BlockState:
	for block: BlockState in blocks:
		if block.id == block_id:
			return block
	return null


func _append_point(points: PackedVector2Array, point: Vector2) -> void:
	if points[points.size() - 1].distance_to(point) > POINT_EPSILON:
		points.append(point)
