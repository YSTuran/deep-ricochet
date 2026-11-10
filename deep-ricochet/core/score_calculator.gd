class_name ScoreCalculator
extends RefCounted


static func break_points(block_type: int, config: GameConfig) -> int:
	match block_type:
		BlockState.BlockType.NORMAL:
			return config.normal_break_points
		BlockState.BlockType.ORE:
			return config.ore_break_points
		BlockState.BlockType.CORE:
			return config.core_break_points
	return 0


static func room_reward(
	break_score: int,
	remaining_shots: int,
	multiplier_bps: int,
	succeeded: bool,
	config: GameConfig,
) -> int:
	var raw_total := break_score
	if succeeded:
		raw_total += maxi(0, remaining_shots) * config.unused_shot_bonus
	@warning_ignore("integer_division")
	return (raw_total * multiplier_bps) / 10_000

