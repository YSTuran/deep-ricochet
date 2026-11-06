class_name AtomicJsonStore
extends RefCounted

var primary_path: String
var backup_path: String
var temporary_path: String
var last_error: String
var load_had_invalid_data := false
var loaded_from_backup := false


func _init(path: String) -> void:
	primary_path = path
	backup_path = "%s.bak" % path
	temporary_path = "%s.tmp" % path


func load_dictionary() -> Variant:
	last_error = ""
	load_had_invalid_data = false
	loaded_from_backup = false
	var primary: Variant = _read_dictionary(primary_path)
	if primary != null:
		return primary
	load_had_invalid_data = FileAccess.file_exists(primary_path)
	var backup: Variant = _read_dictionary(backup_path)
	if backup != null:
		loaded_from_backup = true
		return backup
	load_had_invalid_data = load_had_invalid_data or FileAccess.file_exists(backup_path)
	return null


func restore_primary_from_backup() -> bool:
	last_error = ""
	if not loaded_from_backup:
		return true
	if not FileAccess.file_exists(backup_path):
		last_error = "Geri yüklenecek veri yedeği bulunamadı."
		return false
	if FileAccess.file_exists(temporary_path) and _remove(temporary_path) != OK:
		last_error = "Eski geçici veri dosyası kaldırılamadı."
		return false
	if FileAccess.file_exists(primary_path) and _remove(primary_path) != OK:
		last_error = "Bozuk etkin veri dosyası kaldırılamadı."
		return false

	var copy_error := DirAccess.copy_absolute(
		_absolute(backup_path),
		_absolute(temporary_path),
	)
	if copy_error != OK:
		last_error = "Veri yedeği geçici dosyaya kopyalanamadı: %s" % copy_error
		return false
	var promote_error := DirAccess.rename_absolute(
		_absolute(temporary_path),
		_absolute(primary_path),
	)
	if promote_error != OK:
		last_error = "Kurtarılan veri etkin dosyaya taşınamadı: %s" % promote_error
		_remove(temporary_path)
		return false
	loaded_from_backup = false
	return true


func save_dictionary(data: Dictionary) -> bool:
	last_error = ""
	if FileAccess.file_exists(temporary_path):
		_remove(temporary_path)
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		last_error = "Geçici veri dosyası açılamadı: %s" % FileAccess.get_open_error()
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()

	var moved_primary := false
	var preserve_loaded_backup := loaded_from_backup and FileAccess.file_exists(backup_path)
	if FileAccess.file_exists(primary_path):
		if preserve_loaded_backup:
			if _remove(primary_path) != OK:
				last_error = "Bozuk etkin veri dosyası kaldırılamadı."
				_remove(temporary_path)
				return false
		else:
			if FileAccess.file_exists(backup_path) and _remove(backup_path) != OK:
				last_error = "Eski veri yedeği kaldırılamadı."
				_remove(temporary_path)
				return false
			if DirAccess.rename_absolute(_absolute(primary_path), _absolute(backup_path)) != OK:
				last_error = "Mevcut veri yedeğe taşınamadı."
				_remove(temporary_path)
				return false
			moved_primary = true

	var promote_error := DirAccess.rename_absolute(
		_absolute(temporary_path),
		_absolute(primary_path),
	)
	if promote_error == OK:
		loaded_from_backup = false
		return true
	last_error = "Geçici veri etkin dosyaya taşınamadı: %s" % promote_error
	if moved_primary and not FileAccess.file_exists(primary_path):
		DirAccess.rename_absolute(_absolute(backup_path), _absolute(primary_path))
	_remove(temporary_path)
	return false


func clear_all() -> bool:
	last_error = ""
	var succeeded := true
	for path: String in [primary_path, backup_path, temporary_path]:
		if FileAccess.file_exists(path):
			var remove_error := _remove(path)
			if remove_error != OK:
				succeeded = false
				last_error = "Veri dosyası kaldırılamadı: %s (%s)" % [path, remove_error]
	if succeeded:
		loaded_from_backup = false
	return succeeded


func quarantine_invalid() -> void:
	loaded_from_backup = false
	var suffix := ".corrupt.%d" % int(Time.get_unix_time_from_system())
	for path: String in [primary_path, backup_path]:
		if FileAccess.file_exists(path):
			DirAccess.rename_absolute(_absolute(path), _absolute("%s%s" % [path, suffix]))


func _read_dictionary(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return null
	return json.data


func _remove(path: String) -> Error:
	return DirAccess.remove_absolute(_absolute(path))


func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path)
