class_name SaveService
extends RefCounted

const DEFAULT_SAVE_PATH := "user://deep_ricochet_active_run.json"

var store: AtomicJsonStore
var primary_path: String
var backup_path: String
var temporary_path: String
var last_error: String


func _init(save_path: String = DEFAULT_SAVE_PATH) -> void:
	store = AtomicJsonStore.new(save_path)
	primary_path = store.primary_path
	backup_path = store.backup_path
	temporary_path = store.temporary_path


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
	var data: Variant = store.load_dictionary(_is_valid_envelope_data.bind(catalog, config))
	last_error = store.last_error
	if data == null and not store.load_had_invalid_data:
		result.status = SaveLoadResult.Status.NO_SAVE
		return result

	if data != null:
		result.envelope = SaveEnvelope.from_dictionary(data)
		if store.loaded_from_backup:
			result.status = SaveLoadResult.Status.RECOVERED_BACKUP
			result.message = "Ana kayıt açılamadı; son geçerli yedek yüklendi."
		else:
			result.status = SaveLoadResult.Status.LOADED
		return result

	result.status = SaveLoadResult.Status.INVALID
	result.message = "Aktif oyun kaydı ve yedeği doğrulanamadı."
	return result


func clear_all() -> bool:
	var cleared := store.clear_all()
	last_error = store.last_error
	return cleared


func discard_primary() -> bool:
	var discarded := store.discard_primary()
	last_error = store.last_error
	return discarded


func quarantine_invalid() -> void:
	store.quarantine_invalid()


func _write_envelope(envelope: SaveEnvelope) -> bool:
	if envelope == null:
		last_error = "Kayıt zarfı eksik."
		return false
	var saved := store.save_dictionary(envelope.to_dictionary())
	last_error = store.last_error
	return saved


func _is_valid_envelope_data(
	data: Dictionary,
	catalog: RoomCatalog,
	config: GameConfig,
) -> bool:
	var envelope := SaveEnvelope.from_dictionary(data)
	return envelope != null and envelope.validation_errors(catalog, config).is_empty()
