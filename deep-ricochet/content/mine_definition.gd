class_name MineDefinition
extends RefCounted

var mine_id: StringName
var display_name_key: StringName
var order := 1
var unlock_after: StringName


func localized_name() -> String:
	var translated := TranslationServer.translate(display_name_key)
	return str(mine_id) if translated == str(display_name_key) else translated


func is_valid() -> bool:
	return not mine_id.is_empty() and not display_name_key.is_empty() and order > 0
