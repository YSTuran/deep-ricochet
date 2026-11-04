class_name RunController
extends Node

@onready var gameplay_room: GameplayRoom = $GameplayRoom
@onready var flow_view: RunFlowView = $Interface/RunFlowView

var config: GameConfig
var catalog: RoomCatalog
var run_session: RunSession
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	config = GameConfig.load_from_file()
	catalog = RoomCatalog.load_default()
	if catalog == null:
		push_error("Oda kataloğu yüklenemedi; koşu başlatılmadı.")
		return
	gameplay_room.room_finished.connect(_on_room_finished)
	flow_view.bind(self)
	start_new_run()
	print("Deep Ricochet koşusu hazır. İçerik: %s" % catalog.content_version)


func start_new_run(requested_seed: int = 0) -> bool:
	if catalog == null:
		return false
	var run_seed := requested_seed
	if run_seed == 0:
		run_seed = int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_usec()
	rng.seed = run_seed
	var first_template := catalog.pick_first_room(rng)
	if first_template == null:
		push_error("İlk güvenli oda seçilemedi.")
		return false

	var new_session := RunSession.new()
	if not new_session.start_run(run_seed, catalog.content_version, config.room_count, first_template):
		push_error("Koşu oturumu başlatılamadı.")
		return false
	run_session = new_session
	flow_view.show_gameplay()
	return _load_current_room(first_template)


func select_route(option_id: StringName) -> bool:
	if run_session == null:
		return false
	var selected_template := run_session.select_route(option_id)
	if selected_template == null:
		return false
	flow_view.show_gameplay()
	return _load_current_room(selected_template)


func _on_room_finished(resolution: RoomResolution) -> void:
	if run_session == null or not run_session.resolve_room(resolution):
		return
	gameplay_room.set_input_enabled(false)
	if run_session.ended:
		flow_view.show_run_result(run_session)
		return

	var options := catalog.create_route_options(
		run_session.room_number + 1,
		rng,
		run_session.used_template_ids(),
	)
	if not run_session.set_route_options(options):
		push_error("Sonraki oda için rota seçenekleri üretilemedi.")
		return
	flow_view.show_route_selection(run_session)


func _load_current_room(template: RoomTemplate) -> bool:
	gameplay_room.set_run_context(
		run_session.room_number,
		run_session.room_count,
		run_session.banked_score,
	)
	return gameplay_room.load_room(template)
