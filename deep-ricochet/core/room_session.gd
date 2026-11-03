class_name RoomSession
extends RefCounted

var shots_remaining: int = 0
var break_score: int = 0
var multiplier_bps: int = 10_000
var shot_in_progress: bool = false
var room_finished: bool = false
var room_succeeded: bool = false
var final_reward: int = 0

var _scored_block_ids: Dictionary[int, bool] = {}


func start(initial_shots: int, room_multiplier_bps: int) -> void:
	shots_remaining = maxi(0, initial_shots)
	break_score = 0
	multiplier_bps = room_multiplier_bps
	shot_in_progress = false
	room_finished = false
	room_succeeded = false
	final_reward = 0
	_scored_block_ids.clear()


func commit_shot() -> bool:
	if not can_commit_shot():
		return false
	shots_remaining -= 1
	shot_in_progress = true
	return true


func can_commit_shot() -> bool:
	return not room_finished and not shot_in_progress and shots_remaining > 0


func record_damage_result(result: BlockDamageResult, config: GameConfig) -> int:
	if room_finished or not shot_in_progress:
		return 0
	if not result.damage_applied or not result.destroyed:
		return 0
	if _scored_block_ids.has(result.block_id):
		return 0
	_scored_block_ids[result.block_id] = true
	var awarded_points := ScoreCalculator.break_points(result.block_type, config)
	break_score += awarded_points
	return awarded_points


func resolve_shot(board: BoardModel, config: GameConfig) -> RoomResolution:
	var resolution := RoomResolution.new()
	resolution.break_score = break_score
	resolution.remaining_shots = shots_remaining
	resolution.reward = final_reward
	resolution.room_finished = room_finished
	resolution.succeeded = room_succeeded
	if room_finished or not shot_in_progress:
		return resolution

	shot_in_progress = false
	resolution.processed = true
	room_succeeded = board.is_core_destroyed()
	if room_succeeded:
		room_finished = true
	elif shots_remaining <= 0:
		room_finished = true

	if room_finished:
		final_reward = ScoreCalculator.room_reward(
			break_score,
			shots_remaining,
			multiplier_bps,
			room_succeeded,
			config,
		)

	resolution.room_finished = room_finished
	resolution.succeeded = room_succeeded
	resolution.break_score = break_score
	resolution.remaining_shots = shots_remaining
	resolution.reward = final_reward
	return resolution
