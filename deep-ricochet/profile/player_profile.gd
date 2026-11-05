class_name PlayerProfile
extends RefCounted

const SCHEMA_VERSION := 1

var schema_version := SCHEMA_VERSION
var best_score := 0
var last_score := 0
var runs_played := 0
var successful_runs := 0
var total_cores_broken := 0
var tutorial_completed := false
var last_recorded_run_id: String


func record_run(run_id: String, score: int, succeeded: bool, cores_broken: int) -> bool:
	if run_id.is_empty() or run_id == last_recorded_run_id:
		return false
	var is_new_best := score > best_score
	last_score = maxi(0, score)
	best_score = maxi(best_score, last_score)
	runs_played += 1
	if succeeded:
		successful_runs += 1
	total_cores_broken += maxi(0, cores_broken)
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
	}


static func from_dictionary(data: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	profile.schema_version = int(data.get("schemaVersion", 0))
	profile.best_score = int(data.get("bestScore", -1))
	profile.last_score = int(data.get("lastScore", -1))
	profile.runs_played = int(data.get("runsPlayed", -1))
	profile.successful_runs = int(data.get("successfulRuns", -1))
	profile.total_cores_broken = int(data.get("totalCoresBroken", -1))
	profile.tutorial_completed = bool(data.get("tutorialCompleted", false))
	profile.last_recorded_run_id = str(data.get("lastRecordedRunId", ""))
	return profile


func is_valid() -> bool:
	return schema_version == SCHEMA_VERSION \
		and best_score >= 0 \
		and last_score >= 0 \
		and runs_played >= 0 \
		and successful_runs >= 0 \
		and successful_runs <= runs_played \
		and total_cores_broken >= 0
