extends Node


func _ready() -> void:
	print("Deep Ricochet altyapısı hazır. Config: %s" % GameConfig.load_from_file().config_version)
