class_name PlayerProfile
extends RefCounted

const SCHEMA_VERSION := 2
const LEGACY_SCHEMA_VERSION := 1
const MINE_COUNT := 3

var schema_version := SCHEMA_VERSION
var best_score := 0
var last_score := 0
var runs_played := 0
var successful_runs := 0
var total_cores_broken := 0
var tutorial_completed := false
var last_recorded_run_id: String
var highest_unlocked_mine := 1
var mine_best_scores: Dictionary = {}
var mine_completions: Dictionary = {}
var daily_key: String
var daily_best_score := 0
var daily_attempts := 0


func record_run(
	run_id: String,
	score: int,
	succeeded: bool,
	cores_broken: int,
	mine_id: StringName = &"mine_01",
	is_daily := false,
	run_daily_key: String = "",
) -> bool:
	if run_id.is_empty() or run_id == last_recorded_run_id:
		return false
	var is_new_best := score > best_score
	last_score = maxi(0, score)
	best_score = maxi(best_score, last_score)
	runs_played += 1
	if succeeded:
		successful_runs += 1
	total_cores_broken += maxi(0, cores_broken)
	var mine_key := str(mine_id)
	if is_daily:
		if daily_key != run_daily_key:
			daily_key = run_daily_key
			daily_best_score = 0
			daily_attempts = 0
		daily_attempts += 1
		daily_best_score = maxi(daily_best_score, last_score)
	else:
		mine_best_scores[mine_key] = maxi(int(mine_best_scores.get(mine_key, 0)), last_score)
		if succeeded:
			mine_completions[mine_key] = int(mine_completions.get(mine_key, 0)) + 1
			highest_unlocked_mine = mini(MINE_COUNT, maxi(highest_unlocked_mine, _mine_order(mine_id) + 1))
	last_recorded_run_id = run_id
	return is_new_best


func to_dictionary() -> Dictionary:
	return {
		"schemaVersion": schema_version,
		"bestScore": best_score,
		"lastScore": last_score,
		"runsPlayed": runs_played,
		"successfulRuns": successful_runs,
		"totalCoresBroken": total_cores_broken,
		"tutorialCompleted": tutorial_completed,
		"lastRecordedRunId": last_recorded_run_id,
		"highestUnlockedMine": highest_unlocked_mine,
		"mineBestScores": mine_best_scores.duplicate(true),
		"mineCompletions": mine_completions.duplicate(true),
		"dailyKey": daily_key,
		"dailyBestScore": daily_best_score,
		"dailyAttempts": daily_attempts,
	}


static func from_dictionary(data: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	var source_schema := int(data.get("schemaVersion", 0))
	profile.schema_version = SCHEMA_VERSION if source_schema in [LEGACY_SCHEMA_VERSION, SCHEMA_VERSION] else source_schema
	profile.best_score = int(data.get("bestScore", -1))
	profile.last_score = int(data.get("lastScore", -1))
	profile.runs_played = int(data.get("runsPlayed", -1))
	profile.successful_runs = int(data.get("successfulRuns", -1))
	profile.total_cores_broken = int(data.get("totalCoresBroken", -1))
	profile.tutorial_completed = bool(data.get("tutorialCompleted", false))
	profile.last_recorded_run_id = str(data.get("lastRecordedRunId", ""))
	profile.highest_unlocked_mine = int(data.get("highestUnlockedMine", 1))
	var raw_best: Variant = data.get("mineBestScores", {})
	if typeof(raw_best) == TYPE_DICTIONARY:
		profile.mine_best_scores = raw_best.duplicate(true)
	var raw_completions: Variant = data.get("mineCompletions", {})
	if typeof(raw_completions) == TYPE_DICTIONARY:
		profile.mine_completions = raw_completions.duplicate(true)
	profile.daily_key = str(data.get("dailyKey", ""))
	profile.daily_best_score = int(data.get("dailyBestScore", 0))
	profile.daily_attempts = int(data.get("dailyAttempts", 0))
	return profile


func is_valid() -> bool:
	return schema_version == SCHEMA_VERSION \
		and best_score >= 0 \
		and last_score >= 0 \
		and runs_played >= 0 \
		and successful_runs >= 0 \
		and successful_runs <= runs_played \
		and total_cores_broken >= 0 \
		and highest_unlocked_mine >= 1 \
		and highest_unlocked_mine <= MINE_COUNT \
		and daily_best_score >= 0 \
		and daily_attempts >= 0 \
		and _dictionary_values_non_negative(mine_best_scores) \
		and _dictionary_values_non_negative(mine_completions)


func is_mine_unlocked(mine_id: StringName) -> bool:
	var order := _mine_order(mine_id)
	return order > 0 and order <= highest_unlocked_mine


func best_for_mine(mine_id: StringName) -> int:
	return int(mine_best_scores.get(str(mine_id), 0))


func completions_for_mine(mine_id: StringName) -> int:
	return int(mine_completions.get(str(mine_id), 0))


static func _mine_order(mine_id: StringName) -> int:
	var mine_text := str(mine_id)
	if not mine_text.begins_with("mine_"):
		return 0
	var suffix := mine_text.trim_prefix("mine_")
	if not suffix.is_valid_int():
		return 0
	var value := suffix.to_int()
	return value if value >= 1 and value <= MINE_COUNT else 0


static func _dictionary_values_non_negative(values: Dictionary) -> bool:
	for value: Variant in values.values():
		if int(value) < 0:
			return false
	return true
