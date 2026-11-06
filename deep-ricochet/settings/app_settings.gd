class_name AppSettings
extends RefCounted

const SCHEMA_VERSION := 1
const SUPPORTED_LANGUAGES := [&"tr", &"en"]

var schema_version := SCHEMA_VERSION
var language: StringName = &"tr"
var sound_enabled := true
var sound_volume := 0.8


func to_dictionary() -> Dictionary:
	return {
		"schemaVersion": schema_version,
		"language": str(language),
		"soundEnabled": sound_enabled,
		"soundVolume": sound_volume,
	}


static func from_dictionary(data: Dictionary) -> AppSettings:
	var settings := AppSettings.new()
	settings.schema_version = int(data.get("schemaVersion", 0))
	settings.language = StringName(str(data.get("language", "tr")))
	settings.sound_enabled = bool(data.get("soundEnabled", true))
	settings.sound_volume = float(data.get("soundVolume", 0.8))
	return settings


func is_valid() -> bool:
	return schema_version == SCHEMA_VERSION \
		and SUPPORTED_LANGUAGES.has(language) \
		and sound_volume >= 0.0 \
		and sound_volume <= 1.0
