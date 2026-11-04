class_name RouteOption
extends RefCounted

var option_id: StringName
var template: RoomTemplate


func _init(route_id: StringName = &"", room_template: RoomTemplate = null) -> void:
	option_id = route_id
	template = room_template


func title() -> String:
	if template != null and template.family == RoomTemplate.Family.BONUS:
		return "Dar Damar"
	return "Geniş Geçit"
