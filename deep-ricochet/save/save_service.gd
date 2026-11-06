class_name SaveService
extends RefCounted

const DEFAULT_SAVE_PATH := "user://deep_ricochet_active_run.json"

var primary_path: String
var backup_path: String
var temporary_path: String
var last_error: String


func _init(save_path: String = DEFAULT_SAVE_PATH) -> void:
	primary_path = save_path
	backup_path = "%s.bak" % save_path
	temporary_path = "%s.tmp" % save_path


func save_stable(snapshot: RunSnapshot) -> bool:
	if snapshot == null:
		last_error = "Kararlı koşu snapshot eksik."
		return false
	return _write_envelope(SaveEnvelope.create(snapshot))


func save_pre_shot(snapshot: RunSnapshot) -> bool:
	if snapshot == null:
		last_error = "Atış öncesi koşu snapshot eksik."
		return false
	return _write_envelope(SaveEnvelope.create(snapshot, snapshot))


func load_active(catalog: RoomCatalog, config: GameConfig) -> SaveLoadResult:
	var result := SaveLoadResult.new()
	var primary_exists := FileAccess.file_exists(primary_path)
	var backup_exists := FileAccess.file_exists(backup_path)
	if not primary_exists and not backup_exists:
		result.status = SaveLoadResult.Status.NO_SAVE
		return result

	var primary_envelope := _read_valid_envelope(primary_path, catalog, config)
	if primary_envelope != null:
		result.status = SaveLoadResult.Status.LOADED
		result.envelope = primary_envelope
		return result

	var backup_envelope := _read_valid_envelope(backup_path, catalog, config)
	if backup_envelope != null:
		result.status = SaveLoadResult.Status.RECOVERED_BACKUP
		result.envelope = backup_envelope
		result.message = "Ana kayıt açılamadı; son geçerli yedek yüklendi."
		return result

	result.status = SaveLoadResult.Status.INVALID
	result.message = "Aktif oyun kaydı ve yedeği doğrulanamadı."
	return result


func clear_all() -> bool:
	last_error = ""
	var succeeded := true
	for path: String in [primary_path, backup_path, temporary_path]:
		if FileAccess.file_exists(path):
			var remove_error := _remove(path)
			if remove_error != OK:
				succeeded = false
				last_error = "Kayıt dosyası kaldırılamadı: %s (%s)" % [path, remove_error]
	return succeeded


func discard_primary() -> bool:
	return not FileAccess.file_exists(primary_path) or _remove(primary_path) == OK


func quarantine_invalid() -> void:
	var suffix := ".corrupt.%d" % int(Time.get_unix_time_from_system())
	for path: String in [primary_path, backup_path]:
		if not FileAccess.file_exists(path):
			continue
		var destination := "%s%s" % [path, suffix]
		DirAccess.rename_absolute(_absolute(path), _absolute(destination))


func _write_envelope(envelope: SaveEnvelope) -> bool:
	last_error = ""
	if envelope == null:
		last_error = "Kayıt zarfı eksik."
		return false
	if FileAccess.file_exists(temporary_path):
		_remove(temporary_path)
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		last_error = "Geçici kayıt dosyası açılamadı: %s" % FileAccess.get_open_error()
		return false
	file.store_string(JSON.stringify(envelope.to_dictionary(), "\t"))
	file.flush()
	file.close()

	var moved_primary := false
	if FileAccess.file_exists(primary_path):
		if FileAccess.file_exists(backup_path) and _remove(backup_path) != OK:
			last_error = "Eski kayıt yedeği kaldırılamadı."
			_remove(temporary_path)
			return false
		var backup_error := DirAccess.rename_absolute(_absolute(primary_path), _absolute(backup_path))
		if backup_error != OK:
			last_error = "Mevcut kayıt yedeğe taşınamadı: %s" % backup_error
			_remove(temporary_path)
			return false
		moved_primary = true

	var promote_error := DirAccess.rename_absolute(_absolute(temporary_path), _absolute(primary_path))
	if promote_error == OK:
		return true
	last_error = "Geçici kayıt etkin kayda taşınamadı: %s" % promote_error
	if moved_primary and not FileAccess.file_exists(primary_path):
		DirAccess.rename_absolute(_absolute(backup_path), _absolute(primary_path))
	_remove(temporary_path)
	return false


func _read_valid_envelope(
	path: String,
	catalog: RoomCatalog,
	config: GameConfig,
) -> SaveEnvelope:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	var envelope := SaveEnvelope.from_dictionary(json.data)
	return envelope if envelope.validation_errors(catalog, config).is_empty() else null


func _remove(path: String) -> Error:
	return DirAccess.remove_absolute(_absolute(path))


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)
