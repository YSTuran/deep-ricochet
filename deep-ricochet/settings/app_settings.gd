class_name AppSettings
extends RefCounted

const SCHEMA_VERSION := 4
const SUPPORTED_LANGUAGES := [&"tr", &"en"]

enum QualityMode {
	PERFORMANCE,
	GRAPHICS,
}

var schema_version := SCHEMA_VERSION
var language: StringName = &"tr"
var sfx_enabled := true
var sfx_volume := 0.8
var music_enabled := true
var music_volume := 0.28
var shake_enabled := true
var haptics_enabled := true
var quality_mode: int = QualityMode.PERFORMANCE


func to_dictionary() -> Dictionary:
	return {
		"schemaVersion": schema_version,
		"language": str(language),
		"sfxEnabled": sfx_enabled,
		"sfxVolume": sfx_volume,
		"musicEnabled": music_enabled,
		"musicVolume": music_volume,
		"shakeEnabled": shake_enabled,
		"hapticsEnabled": haptics_enabled,
		"qualityMode": quality_mode,
	}


static func from_dictionary(data: Dictionary) -> AppSettings:
	var settings := AppSettings.new()
	var source_schema := int(data.get("schemaVersion", 0))
	if source_schema not in [1, 2, 3, SCHEMA_VERSION]:
		settings.schema_version = source_schema
		return settings
	settings.schema_version = SCHEMA_VERSION
	settings.language = StringName(str(data.get("language", "tr")))
	if source_schema == 1:
		settings.sfx_enabled = bool(data.get("soundEnabled", true))
		settings.sfx_volume = float(data.get("soundVolume", 0.8))
	else:
		settings.sfx_enabled = bool(data.get("sfxEnabled", true))
		settings.sfx_volume = float(data.get("sfxVolume", 0.8))
	settings.music_enabled = bool(data.get("musicEnabled", true))
	settings.music_volume = float(data.get("musicVolume", 0.28))
	settings.shake_enabled = bool(data.get("shakeEnabled", true))
	settings.haptics_enabled = bool(data.get("hapticsEnabled", true))
	settings.quality_mode = int(data.get("qualityMode", QualityMode.PERFORMANCE))
	return settings


func is_valid() -> bool:
	return schema_version == SCHEMA_VERSION \
		and SUPPORTED_LANGUAGES.has(language) \
		and sfx_volume >= 0.0 \
		and sfx_volume <= 1.0 \
		and music_volume >= 0.0 \
		and music_volume <= 1.0 \
		and quality_mode >= QualityMode.PERFORMANCE \
		and quality_mode <= QualityMode.GRAPHICS
