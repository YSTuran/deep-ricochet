class_name ProfileService
extends RefCounted

const DEFAULT_PATH := "user://deep_ricochet_profile.json"

var store: AtomicJsonStore
var last_error: String


func _init(path: String = DEFAULT_PATH) -> void:
	store = AtomicJsonStore.new(path)


func load_profile() -> PlayerProfile:
	var data: Variant = store.load_dictionary()
	if data == null:
		if store.load_had_invalid_data:
			store.quarantine_invalid()
			last_error = "Profil dosyası okunamadı; varsayılan profil oluşturuldu."
		return PlayerProfile.new()
	var profile := PlayerProfile.from_dictionary(data)
	if profile.is_valid():
		if store.loaded_from_backup and not store.restore_primary_from_backup():
			last_error = store.last_error
		else:
			last_error = ""
		return profile
	store.quarantine_invalid()
	last_error = "Profil doğrulanamadı; varsayılan profil oluşturuldu."
	return PlayerProfile.new()


func save_profile(profile: PlayerProfile) -> bool:
	if profile == null or not profile.is_valid():
		last_error = "Kaydedilecek profil geçersiz."
		return false
	var saved := store.save_dictionary(profile.to_dictionary())
	last_error = store.last_error
	return saved


func clear_all() -> bool:
	var cleared := store.clear_all()
	last_error = store.last_error
	return cleared
