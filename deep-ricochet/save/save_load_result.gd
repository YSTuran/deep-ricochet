class_name SaveLoadResult
extends RefCounted

enum Status {
	NO_SAVE,
	LOADED,
	RECOVERED_BACKUP,
	INVALID,
}

var status: Status = Status.NO_SAVE
var envelope: SaveEnvelope
var message: String


func snapshot_for_restore() -> RunSnapshot:
	return envelope.snapshot_for_restore() if envelope != null else null


func interrupted_shot() -> bool:
	return envelope != null and envelope.pre_shot_snapshot != null


func has_valid_save() -> bool:
	return status == Status.LOADED or status == Status.RECOVERED_BACKUP
