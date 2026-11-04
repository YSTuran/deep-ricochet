class_name SaveEnvelope
extends RefCounted

const SCHEMA_VERSION := 1

var schema_version: int = SCHEMA_VERSION
var saved_at_utc: String
var state: RunSnapshot
var pre_shot_snapshot: RunSnapshot


static func create(current_state: RunSnapshot, pre_shot: RunSnapshot = null) -> SaveEnvelope:
	var envelope := SaveEnvelope.new()
	envelope.saved_at_utc = Time.get_datetime_string_from_system(true, true)
	envelope.state = current_state
	envelope.pre_shot_snapshot = pre_shot
	return envelope


static func from_dictionary(data: Dictionary) -> SaveEnvelope:
	var envelope := SaveEnvelope.new()
	envelope.schema_version = int(data.get("schemaVersion", 0))
	envelope.saved_at_utc = str(data.get("savedAtUtc", ""))
	var raw_state: Variant = data.get("state", {})
	if typeof(raw_state) == TYPE_DICTIONARY:
		envelope.state = RunSnapshot.from_dictionary(raw_state)
	var raw_pre_shot: Variant = data.get("preShotSnapshot", null)
	if typeof(raw_pre_shot) == TYPE_DICTIONARY:
		envelope.pre_shot_snapshot = RunSnapshot.from_dictionary(raw_pre_shot)
	return envelope


func to_dictionary() -> Dictionary:
	return {
		"schemaVersion": schema_version,
		"savedAtUtc": saved_at_utc,
		"state": state.to_dictionary() if state != null else {},
		"preShotSnapshot": pre_shot_snapshot.to_dictionary() \
			if pre_shot_snapshot != null else null,
	}


func validation_errors(catalog: RoomCatalog, config: GameConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != SCHEMA_VERSION:
		errors.append("Desteklenmeyen kayıt zarfı sürümü.")
	if saved_at_utc.strip_edges().is_empty():
		errors.append("Kayıt zamanı eksik.")
	if state == null:
		errors.append("Kayıt durumu eksik.")
	else:
		errors.append_array(state.validation_errors(catalog, config))
	if pre_shot_snapshot != null:
		errors.append_array(pre_shot_snapshot.validation_errors(catalog, config))
		if state != null and pre_shot_snapshot.run_id != state.run_id:
			errors.append("Atış öncesi snapshot başka bir koşuya ait.")
		if state != null and pre_shot_snapshot.to_dictionary() != state.to_dictionary():
			errors.append("Atış öncesi snapshot kararlı kayıt durumuyla uyuşmuyor.")
		if pre_shot_snapshot.phase != RunSession.Phase.PLAYING:
			errors.append("Atış öncesi snapshot yalnızca oynanış aşamasında olabilir.")
	return errors


func snapshot_for_restore() -> RunSnapshot:
	return pre_shot_snapshot if pre_shot_snapshot != null else state
