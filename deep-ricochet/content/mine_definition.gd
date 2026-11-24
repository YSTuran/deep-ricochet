class_name MineDefinition
extends RefCounted

var mine_id: StringName
var display_name_key: StringName
var order := 1
var unlock_after: StringName
var two_star_score := 1
var three_star_score := 2


func localized_name() -> String:
	var translated := TranslationServer.translate(display_name_key)
	return str(mine_id) if translated == str(display_name_key) else translated


func is_valid() -> bool:
	return not mine_id.is_empty() \
		and not display_name_key.is_empty() \
		and order > 0 \
		and two_star_score > 0 \
		and three_star_score > two_star_score


func stars_for_score(score: int, succeeded: bool) -> int:
	if not succeeded:
		return 0
	if score >= three_star_score:
		return 3
	if score >= two_star_score:
		return 2
	return 1
