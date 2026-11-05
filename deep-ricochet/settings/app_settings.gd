class_name AppSettings
extends RefCounted

const SCHEMA_VERSION := 1
const SUPPORTED_LANGUAGES := [&"tr", &"en"]

var schema_version := SCHEMA_VERSION
var language: StringName = &"tr"


func to_dictionary() -> Dictionary:
	return {
		"schemaVersion": schema_version,
		"language": str(language),
	}


static func from_dictionary(data: Dictionary) -> AppSettings:
	var settings := AppSettings.new()
	settings.schema_version = int(data.get("schemaVersion", 0))
	settings.language = StringName(str(data.get("language", "tr")))
	return settings


func is_valid() -> bool:
	return schema_version == SCHEMA_VERSION and SUPPORTED_LANGUAGES.has(language)
