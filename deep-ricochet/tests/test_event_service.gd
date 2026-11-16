class_name TestEventServiceTests
extends RefCounted

const TEST_PATH := "user://tests/deep_ricochet_events_test.json"
const LIMIT_PATH := "user://tests/deep_ricochet_events_limit_test.json"


static func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	_test_round_trip_and_privacy()
	_test_event_limit()


static func _test_round_trip_and_privacy() -> void:
	var service := TestEventService.new(TEST_PATH, 32)
	assert(service.clear_all())
	var context := {
		"runId": "run_test_1",
		"mineId": "mine_03",
		"room": 2,
		"seed": 12_345,
		"contentVersion": "test-content",
		"email": "ignored@example.com",
	}
	for event_name: StringName in TestEventService.ALLOWED_EVENTS:
		assert(service.record_event(event_name, context, {
			"templateId": "template_test",
			"shotsRemaining": 2,
			"succeeded": true,
			"templateIds": ["wide_test", "narrow_test"],
			"email": "ignored@example.com",
		}))
	assert(service.event_count() == TestEventService.ALLOWED_EVENTS.size())
	var exported: Variant = JSON.parse_string(service.export_json())
	assert(typeof(exported) == TYPE_DICTIONARY)
	assert(int(exported["schemaVersion"]) == TestEventService.SCHEMA_VERSION)
	assert(exported["events"].size() == TestEventService.ALLOWED_EVENTS.size())
	var first_event: Dictionary = exported["events"][0]
	assert(first_event["runId"] == "run_test_1")
	assert(first_event["mineId"] == "mine_03")
	assert(first_event["room"] == 2)
	assert(first_event["seed"] == 12_345)
	assert(first_event["contentVersion"] == "test-content")
	assert(not first_event.has("email"))
	assert(not first_event["data"].has("email"))
	assert(first_event["data"]["templateIds"] == ["wide_test", "narrow_test"])

	var restored := TestEventService.new(TEST_PATH, 32)
	assert(restored.event_count() == service.event_count())
	assert(restored.event_names() == service.event_names())
	var count_before_invalid := restored.event_count()
	assert(not restored.record_event(&"unsupported_event", context))
	assert(restored.event_count() == count_before_invalid)
	assert(restored.clear_all())


static func _test_event_limit() -> void:
	var service := TestEventService.new(LIMIT_PATH, 3)
	assert(service.clear_all())
	var context := {
		"runId": "run_limit",
		"mineId": "mine_01",
		"room": 1,
		"seed": 99,
		"contentVersion": "test-content",
	}
	for index in range(5):
		assert(service.record_event(&"shot_started", context, {
			"shotsRemaining": index,
		}))
	assert(service.event_count() == 3)
	assert(int(service.events[0]["data"]["shotsRemaining"]) == 2)
	assert(int(service.events[2]["data"]["shotsRemaining"]) == 4)
	assert(service.clear_all())
