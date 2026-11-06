class_name RunSession
extends RefCounted

enum Phase {
	PLAYING,
	ROUTE_SELECTION,
	RUN_RESULT,
}

var run_id: String
var seed: int
var content_version: String
var room_count: int = 4
var room_number: int = 1
var phase: Phase = Phase.PLAYING
var banked_score: int = 0
var cores_broken: int = 0
var route_choices_made: int = 0
var ended: bool = false
var succeeded: bool = false
var current_template_id: StringName
var selected_template_ids: Array[StringName] = []
var offered_template_ids: Array[StringName] = []
var pending_routes: Array[RouteOption] = []
var room_results: Array[RoomResultRecord] = []
var last_room_reward: int = 0
var last_room_break_score: int = 0
var last_room_remaining_shots: int = 0
var last_room_succeeded: bool = false


func start_run(
	run_seed: int,
	run_content_version: String,
	total_rooms: int,
	first_template: RoomTemplate,
) -> bool:
	if first_template == null or not first_template.is_valid() or total_rooms <= 0:
		return false
	seed = run_seed
	run_id = "run_%d" % abs(run_seed)
	content_version = run_content_version
	room_count = total_rooms
	room_number = 1
	phase = Phase.PLAYING
	banked_score = 0
	cores_broken = 0
	route_choices_made = 0
	ended = false
	succeeded = false
	current_template_id = first_template.room_id
	selected_template_ids = [first_template.room_id]
	offered_template_ids.clear()
	pending_routes.clear()
	room_results.clear()
	last_room_reward = 0
	last_room_break_score = 0
	last_room_remaining_shots = 0
	last_room_succeeded = false
	return true


func resolve_room(resolution: RoomResolution) -> bool:
	if phase != Phase.PLAYING or ended:
		return false
	if resolution == null or not resolution.processed or not resolution.room_finished:
		return false

	banked_score += resolution.reward
	last_room_reward = resolution.reward
	last_room_break_score = resolution.break_score
	last_room_remaining_shots = resolution.remaining_shots
	last_room_succeeded = resolution.succeeded
	var room_result := RoomResultRecord.from_resolution(
		room_number,
		current_template_id,
		resolution,
	)
	if room_result == null:
		return false
	room_results.append(room_result)
	if resolution.succeeded:
		cores_broken += 1
	else:
		ended = true
		succeeded = false
		phase = Phase.RUN_RESULT
		return true

	if room_number >= room_count:
		ended = true
		succeeded = true
		phase = Phase.RUN_RESULT
	else:
		phase = Phase.ROUTE_SELECTION
	return true


func set_route_options(options: Array[RouteOption]) -> bool:
	if phase != Phase.ROUTE_SELECTION or ended or not pending_routes.is_empty():
		return false
	if options.size() != 2:
		return false
	var option_ids: Dictionary[StringName, bool] = {}
	var family_count: Dictionary[int, int] = {
		RoomTemplate.Family.SAFE: 0,
		RoomTemplate.Family.BONUS: 0,
	}
	var used_ids := used_template_ids()
	for option: RouteOption in options:
		if option == null or option.template == null or not option.template.is_valid():
			return false
		if option_ids.has(option.option_id) or used_ids.has(option.template.room_id):
			return false
		option_ids[option.option_id] = true
		family_count[option.template.family] = family_count.get(option.template.family, 0) + 1
	if family_count[RoomTemplate.Family.SAFE] != 1 \
		or family_count[RoomTemplate.Family.BONUS] != 1:
		return false

	pending_routes = options.duplicate()
	for option: RouteOption in pending_routes:
		offered_template_ids.append(option.template.room_id)
	return true


func select_route(option_id: StringName) -> RoomTemplate:
	if phase != Phase.ROUTE_SELECTION or ended:
		return null
	for option: RouteOption in pending_routes:
		if option.option_id != option_id:
			continue
		current_template_id = option.template.room_id
		selected_template_ids.append(option.template.room_id)
		route_choices_made += 1
		room_number += 1
		phase = Phase.PLAYING
		pending_routes.clear()
		return option.template
	return null


func used_template_ids() -> Dictionary[StringName, bool]:
	var result: Dictionary[StringName, bool] = {}
	for template_id: StringName in selected_template_ids:
		result[template_id] = true
	for template_id: StringName in offered_template_ids:
		result[template_id] = true
	return result
