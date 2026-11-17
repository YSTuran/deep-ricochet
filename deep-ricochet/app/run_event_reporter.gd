class_name RunEventReporter
extends RefCounted

var write_warning_shown := false


func record(
	service: TestEventService,
	session: RunSession,
	event_name: StringName,
	data: Dictionary = {},
	persist_immediately := true,
) -> void:
	if service == null:
		return
	var context := {}
	if session != null:
		context = {
			"runId": session.run_id,
			"mineId": str(session.mine_id),
			"room": session.room_number,
			"seed": session.seed,
			"contentVersion": session.content_version,
		}
	if service.record_event(event_name, context, data, persist_immediately):
		write_warning_shown = false
		return
	_warn_once("Test olayı kaydedilemedi: %s" % service.last_error)


func record_snapshot(
	service: TestEventService,
	event_name: StringName,
	snapshot: RunSnapshot,
	data: Dictionary = {},
) -> void:
	if service == null or snapshot == null:
		return
	var context := {
		"runId": snapshot.run_id,
		"mineId": str(snapshot.mine_id),
		"room": snapshot.room_number,
		"seed": snapshot.seed,
		"contentVersion": snapshot.content_version,
	}
	if service.record_event(event_name, context, data):
		write_warning_shown = false
		return
	_warn_once("Test olayı kaydedilemedi: %s" % service.last_error)


func flush(service: TestEventService) -> void:
	if service == null:
		return
	if service.flush():
		write_warning_shown = false
		return
	_warn_once("Test olayları diske yazılamadı: %s" % service.last_error)


func _warn_once(message: String) -> void:
	if write_warning_shown:
		return
	write_warning_shown = true
	push_warning(message)
