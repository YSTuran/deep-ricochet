extends SceneTree

const CONTENT_VERSION := "p2-mines-1"
const OUTPUT_DIR := "res://content/mines/rooms"
const CATALOG_PATH := "res://content/mines/catalog.json"

const ARCHETYPES := [
	{
		"slug": "start", "role": "start", "family": "safe", "key": "START",
		"passage": [3, 4], "core_x": 3,
		"blocks": [[0, 1, "normal", 2], [6, 1, "ore", 3], [1, 3, "rock", 0], [5, 3, "normal", 3], [2, 5, "ore", 4], [6, 5, "normal", 4], [0, 7, "normal", 5], [5, 7, "ore", 5]],
	},
	{
		"slug": "wide_01", "role": "wide", "family": "safe", "key": "WIDE_01",
		"passage": [3, 4], "core_x": 3,
		"blocks": [[1, 1, "normal", 2], [7, 2, "ore", 3], [0, 3, "rock", 0], [5, 4, "normal", 3], [2, 5, "ore", 4], [6, 6, "rock", 0], [1, 7, "normal", 5], [5, 7, "ore", 5]],
	},
	{
		"slug": "wide_02", "role": "wide", "family": "safe", "key": "WIDE_02",
		"passage": [3, 4], "core_x": 3,
		"blocks": [[2, 1, "normal", 2], [6, 2, "rock", 0], [0, 4, "ore", 3], [5, 4, "normal", 3], [1, 5, "normal", 4], [7, 6, "ore", 4], [2, 7, "rock", 0], [6, 7, "normal", 5]],
	},
	{
		"slug": "wide_03", "role": "wide", "family": "safe", "key": "WIDE_03",
		"passage": [3, 4], "core_x": 3,
		"blocks": [[0, 2, "rock", 0], [5, 2, "normal", 2], [2, 3, "ore", 3], [7, 4, "normal", 3], [1, 5, "rock", 0], [6, 5, "ore", 4], [0, 7, "normal", 5], [5, 7, "normal", 5]],
	},
	{
		"slug": "narrow_01", "role": "narrow", "family": "bonus", "key": "NARROW_01",
		"passage": [3], "core_x": 3,
		"blocks": [[0, 1, "normal", 3], [5, 1, "ore", 3], [2, 3, "normal", 3], [4, 3, "rock", 0], [1, 5, "ore", 4], [6, 5, "normal", 4], [2, 7, "ore", 5], [4, 7, "normal", 5]],
	},
	{
		"slug": "narrow_02", "role": "narrow", "family": "bonus", "key": "NARROW_02",
		"passage": [3], "core_x": 3,
		"blocks": [[2, 1, "rock", 0], [6, 2, "normal", 3], [0, 3, "ore", 3], [4, 4, "normal", 4], [1, 5, "rock", 0], [5, 6, "ore", 5], [2, 7, "normal", 5], [6, 7, "ore", 6]],
	},
	{
		"slug": "narrow_03", "role": "narrow", "family": "bonus", "key": "NARROW_03",
		"passage": [3], "core_x": 3,
		"blocks": [[1, 1, "ore", 3], [5, 2, "normal", 3], [2, 3, "rock", 0], [7, 4, "ore", 4], [0, 5, "normal", 4], [4, 5, "rock", 0], [1, 7, "normal", 5], [5, 7, "ore", 6]],
	},
]

const DISPLAY_NAMES := [
	["Kıyı Galerisi", "Açık Basamak", "Mavi Koridor", "Yankı Kemeri", "Altın Yarık", "Dar Şaft", "Cevher Boğazı"],
	["Derin Giriş", "Kömür Salonu", "Kırık Galeri", "Sessiz Kemer", "Karanlık Oluk", "Sıkışık Damar", "Kristal Boğazı"],
	["Çekirdek Kapısı", "Basınç Tüneli", "Kızıl Salon", "Derin Kemer", "Erimiş Yarık", "Keskin Damar", "Son Şaft"],
]


func _initialize() -> void:
	call_deferred("_generate")


func _generate() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var paths: Array[String] = []
	for mine_index in range(3):
		for archetype_index in range(ARCHETYPES.size()):
			for mirrored in [false, true]:
				var data := _room_data(mine_index, archetype_index, mirrored)
				var path := "%s/%s.json" % [OUTPUT_DIR, data["id"]]
				var file := FileAccess.open(path, FileAccess.WRITE)
				if file == null:
					push_error("Oda yazılamadı: %s" % path)
					quit(1)
					return
				file.store_string(JSON.stringify(data, "  "))
				file.close()
				paths.append(path)
	var catalog := {
		"schemaVersion": 1,
		"contentVersion": CONTENT_VERSION,
		"templates": paths,
	}
	var catalog_file := FileAccess.open(CATALOG_PATH, FileAccess.WRITE)
	if catalog_file == null:
		push_error("Maden kataloğu yazılamadı.")
		quit(1)
		return
	catalog_file.store_string(JSON.stringify(catalog, "  "))
	catalog_file.close()
	print("[MINE_GEN] %d oda üretildi." % paths.size())
	quit()


func _room_data(mine_index: int, archetype_index: int, mirrored: bool) -> Dictionary:
	var archetype: Dictionary = ARCHETYPES[archetype_index]
	var suffix := "b" if mirrored else "a"
	var mine_number := mine_index + 1
	var room_id := "m%d_%s_%s" % [mine_number, archetype["slug"], suffix]
	var blocks: Array[Dictionary] = []
	var raw_blocks: Array = archetype["blocks"]
	for block_index in range(raw_blocks.size()):
		var source: Array = raw_blocks[block_index]
		var x := int(source[0])
		if mirrored:
			x = 7 - x
		var type_name := _type_for_mine(str(source[2]), mine_index, block_index)
		var hp := _hit_points(type_name, int(source[3]), mine_index)
		blocks.append({
			"id": mine_number * 10_000 + archetype_index * 100 + (50 if mirrored else 0) + block_index + 1,
			"type": type_name,
			"cell": [x, int(source[1])],
			"hitPoints": hp,
		})
	var core_x := int(archetype["core_x"])
	if mirrored:
		core_x = 7 - core_x
	blocks.append({
		"id": mine_number * 10_000 + archetype_index * 100 + (50 if mirrored else 0) + 99,
		"type": "core",
		"cell": [core_x, 8],
		"hitPoints": 6,
	})
	var passage: Array = []
	for raw_column: Variant in archetype["passage"]:
		passage.append(7 - int(raw_column) if mirrored else int(raw_column))
	passage.sort()
	return {
		"schemaVersion": 1,
		"id": room_id,
		"displayName": DISPLAY_NAMES[mine_index][archetype_index],
		"displayNameKey": "MINE_%d_%s" % [mine_number, archetype["key"]],
		"mineId": "mine_%02d" % mine_number,
		"role": archetype["role"],
		"family": archetype["family"],
		"contentVersion": CONTENT_VERSION,
		"width": 8,
		"height": 8,
		"multiplierBps": 15_000 if archetype["family"] == "bonus" else 10_000,
		"passageColumns": passage,
		"exampleAngles": [86.5 if mirrored else 93.5],
		"blocks": blocks,
	}


func _type_for_mine(base_type: String, mine_index: int, block_index: int) -> String:
	if base_type == "rock":
		return base_type
	if mine_index == 1 and block_index % 3 == 0:
		return "ore" if base_type == "normal" else "normal"
	if mine_index == 2 and block_index % 2 == 1:
		return "ore" if base_type == "normal" else "normal"
	return base_type


func _hit_points(type_name: String, base_hp: int, mine_index: int) -> int:
	if type_name == "rock":
		return 0
	var minimum := 3 if type_name == "ore" else 2
	return clampi(base_hp + mine_index, minimum, 6)
