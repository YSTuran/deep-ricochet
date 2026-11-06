class_name SettingsService
extends RefCounted

const DEFAULT_PATH := "user://deep_ricochet_settings.json"

var store: AtomicJsonStore
var last_error: String


func _init(path: String = DEFAULT_PATH) -> void:
	store = AtomicJsonStore.new(path)


func load_settings() -> AppSettings:
	var data: Variant = store.load_dictionary()
	if data == null:
		if store.load_had_invalid_data:
			store.quarantine_invalid()
			last_error = "Ayar dosyası okunamadı; varsayılanlar kullanılıyor."
		return AppSettings.new()
	var settings := AppSettings.from_dictionary(data)
	if settings.is_valid():
		if store.loaded_from_backup and not store.restore_primary_from_backup():
			last_error = store.last_error
		else:
			last_error = ""
		return settings
	store.quarantine_invalid()
	last_error = "Ayarlar doğrulanamadı; varsayılanlar kullanılıyor."
	return AppSettings.new()


func save_settings(settings: AppSettings) -> bool:
	if settings == null or not settings.is_valid():
		last_error = "Kaydedilecek ayarlar geçersiz."
		return false
	var saved := store.save_dictionary(settings.to_dictionary())
	last_error = store.last_error
	return saved


func clear_all() -> bool:
	var cleared := store.clear_all()
	last_error = store.last_error
	return cleared
