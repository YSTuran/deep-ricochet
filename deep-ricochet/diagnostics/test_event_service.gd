class_name TestEventService
extends RefCounted

const DEFAULT_PATH := "user://deep_ricochet_test_events.json"
const SCHEMA_VERSION := 1
const DEFAULT_MAX_EVENTS := 500

const ALLOWED_EVENTS := [
	&"run_started",
	&"shot_started",
	&"shot_resolved",
	&"room_completed",
	&"route_offered",
	&"route_selected",
	&"run_ended",
	&"run_restarted",
	&"session_resumed",
	&"save_recovered",
]

const ALLOWED_DATA_FIELDS := [
	"runKind",
	"firstTemplateId",
	"templateId",
	"optionId",
	"optionIds",
	"templateIds",
	"multipliersBps",
	"shotsRemaining",
	"ballsLaunched",
	"ballsCollected",
	"ballsForcedCollected",
	"breakScore",
	"reward",
	"multiplierBps",
	"succeeded",
	"roomFinished",
	"coresBroken",
	"routeChoices",
	"totalScore",
	"previousRunId",
	"sameSeed",
	"source",
	"recoveredBackup",
	"interruptedShot",
]

var store: AtomicJsonStore
var max_events: int
var events: Array[Dictionary] = []
var last_error: String
var dirty := false


func _init(path: String = DEFAULT_PATH, event_limit: int = DEFAULT_MAX_EVENTS) -> void:
	store = AtomicJsonStore.new(path)
	max_events = maxi(1, event_limit)
	_load()


func record_event(
	event_name: StringName,
	context: Dictionary,
	data: Dictionary = {},
	persist_immediately := true,
) -> bool:
	last_error = ""
	if not ALLOWED_EVENTS.has(event_name):
		last_error = "Desteklenmeyen test olayı: %s" % event_name
		return false
	var event := {
		"eventName": str(event_name),
		"timestampUtc": _utc_now(),
		"runId": str(context.get("runId", "")),
		"mineId": str(context.get("mineId", "")),
		"room": maxi(0, int(context.get("room", 0))),
		"seed": int(context.get("seed", 0)),
		"contentVersion": str(context.get("contentVersion", "")),
		"data": _sanitize_data(data),
	}
	events.append(event)
	while events.size() > max_events:
		events.pop_front()
	dirty = true
	return flush() if persist_immediately else true


func event_count() -> int:
	return events.size()


func event_names() -> PackedStringArray:
	var names := PackedStringArray()
	for event: Dictionary in events:
		names.append(str(event.get("eventName", "")))
	return names


func export_json() -> String:
	return JSON.stringify(_envelope(), "\t")


func flush() -> bool:
	if not dirty:
		return true
	if _save():
		dirty = false
		return true
	return false


func clear_all() -> bool:
	last_error = ""
	if not store.clear_all():
		last_error = store.last_error
		return false
	events.clear()
	dirty = false
	return true


func _load() -> void:
	events.clear()
	dirty = false
	last_error = ""
	var raw: Variant = store.load_dictionary(_is_valid_envelope_data)
	if raw == null:
		if store.load_had_invalid_data and not store.quarantine_invalid():
			last_error = store.last_error
		return
	if not _load_envelope(raw):
		if not store.quarantine_invalid():
			last_error = store.last_error
			events.clear()
			return
		events.clear()
		last_error = "Geçersiz test olay dosyası karantinaya alındı."
		return
	if store.loaded_from_backup and not store.restore_primary_from_backup():
		last_error = store.last_error


func _load_envelope(raw: Variant) -> bool:
	if typeof(raw) != TYPE_DICTIONARY or not _is_valid_envelope_data(raw):
		return false
	var envelope: Dictionary = raw
	if int(envelope.get("schemaVersion", 0)) != SCHEMA_VERSION:
		return false
	var raw_events: Variant = envelope.get("events", [])
	if typeof(raw_events) != TYPE_ARRAY:
		return false
	for raw_event: Variant in raw_events:
		var event := _validated_event(raw_event)
		if event.is_empty():
			return false
		events.append(event)
	while events.size() > max_events:
		events.pop_front()
	return true


func _is_valid_envelope_data(envelope: Dictionary) -> bool:
	if int(envelope.get("schemaVersion", 0)) != SCHEMA_VERSION:
		return false
	var raw_events: Variant = envelope.get("events", [])
	if typeof(raw_events) != TYPE_ARRAY:
		return false
	for raw_event: Variant in raw_events:
		if _validated_event(raw_event).is_empty():
			return false
	return true


func _validated_event(raw_event: Variant) -> Dictionary:
	if typeof(raw_event) != TYPE_DICTIONARY:
		return {}
	var event: Dictionary = raw_event
	var event_name := StringName(str(event.get("eventName", "")))
	if not ALLOWED_EVENTS.has(event_name):
		return {}
	var timestamp := str(event.get("timestampUtc", ""))
	if timestamp.is_empty():
		return {}
	var raw_data: Variant = event.get("data", {})
	if typeof(raw_data) != TYPE_DICTIONARY:
		return {}
	return {
		"eventName": str(event_name),
		"timestampUtc": timestamp,
		"runId": str(event.get("runId", "")),
		"mineId": str(event.get("mineId", "")),
		"room": maxi(0, int(event.get("room", 0))),
		"seed": int(event.get("seed", 0)),
		"contentVersion": str(event.get("contentVersion", "")),
		"data": _sanitize_data(raw_data),
	}


func _sanitize_data(data: Dictionary) -> Dictionary:
	var sanitized := {}
	for field: String in ALLOWED_DATA_FIELDS:
		if not data.has(field):
			continue
		var value: Variant = _sanitize_value(data[field])
		if value != null:
			sanitized[field] = value
	return sanitized


func _sanitize_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return str(value)
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, \
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var sanitized_array: Array = []
			for item: Variant in value:
				if sanitized_array.size() >= 32:
					break
				var sanitized_item: Variant = _sanitize_value(item)
				if sanitized_item != null and typeof(sanitized_item) != TYPE_ARRAY:
					sanitized_array.append(sanitized_item)
			return sanitized_array
	return null


func _save() -> bool:
	if store.save_dictionary(_envelope()):
		return true
	last_error = store.last_error
	return false


func _envelope() -> Dictionary:
	return {
		"schemaVersion": SCHEMA_VERSION,
		"updatedAtUtc": _utc_now(),
		"events": events.duplicate(true),
	}


func _utc_now() -> String:
	return "%sZ" % Time.get_datetime_string_from_system(true, false)
