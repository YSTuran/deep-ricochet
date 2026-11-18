extends SceneTree

const CONTENT_VERSION := "p2-mines-5"
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
		"blocks": [[1, 1, "normal", 2], [7, 2, "ore", 3], [0, 3, "rock", 0], [5, 4, "normal", 3], [2, 5, "ore", 4], [6, 5, "rock", 0], [1, 6, "normal", 5], [5, 7, "ore", 5]],
	},
	{
		"slug": "wide_02", "role": "wide", "family": "safe", "key": "WIDE_02",
		"passage": [3, 4], "core_x": 3,
		"blocks": [[2, 1, "normal", 2], [6, 2, "rock", 0], [2, 3, "rock", 0], [0, 4, "ore", 3], [5, 4, "normal", 3], [1, 5, "normal", 4], [7, 6, "ore", 4], [6, 7, "normal", 5]],
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
		"blocks": [[2, 1, "rock", 0], [6, 2, "normal", 3], [2, 2, "normal", 5], [0, 3, "ore", 3], [4, 4, "normal", 4], [1, 5, "rock", 0], [5, 6, "ore", 5], [6, 7, "ore", 6]],
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
	["Kadim Kapı", "Muhafız Tüneli", "Volkan Salonu", "Demir Kemer", "Son Yarık", "Tek Açık Damar", "Derin Çekirdek"],
	["Obsidyen Eşiği", "Kristal Burç", "Kara Örs", "Muhafız Kemeri", "Zırhlı Yarık", "Nöbetçi Damar", "Derin Mahzen"],
	["Uçurum Kapısı", "Son İniş", "Çekirdek Hisarı", "Son Kemer", "Titan Yarığı", "Mühürlü Damar", "Derinlik Kalbi"],
	["Barut Girişi", "Kıvılcım Galerisi", "Barut Koridoru", "Çatlak Kemer", "Patlama Yarığı", "Çelik Damar", "Kızıl Boğaz"],
	["Kıvılcım Eşiği", "Ateş Galerisi", "Parlak Koridor", "Köz Kemeri", "Kor Yarığı", "Sıcak Damar", "Ateş Boğazı"],
	["Çatlak Kapı", "Kırık Basamak", "Yarık Salonu", "Sarsıntı Kemeri", "Kaya Çatlağı", "Kırılgan Damar", "Tozlu Şaft"],
	["Patlama Eşiği", "Fitilsiz Salon", "Barut Mahzeni", "Kızıl Kemer", "Derin Patlak", "Tehlikeli Damar", "Köz Çukuru"],
	["Zırh Kapısı", "Demir Galeri", "Çelik Koridor", "Muhafız Kemeri", "Pembe Yarık", "Zırhlı Damar", "Kalkan Boğazı"],
	["Muhafız Eşiği", "Nöbetçi Salonu", "Kara Burç", "Bekçi Kemeri", "Kapalı Yarık", "Sert Damar", "Derin Karakol"],
	["Titan Kapısı", "Ağır Basamak", "Dev Salonu", "Titan Kemeri", "Büyük Yarık", "Mühürlü Damar", "Taş Hisar"],
	["Son Derinlik", "Dip Galerisi", "Çekirdek Hisarı", "Son Kemer", "Nihai Yarık", "Derin Damar", "Maden Kalbi"],
]


func _initialize() -> void:
	call_deferred("_generate")


func _generate() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_generated_rooms()
	var paths: Array[String] = []
	for mine_index in range(DISPLAY_NAMES.size()):
		for archetype_index in range(ARCHETYPES.size()):
			var data := _room_data(mine_index, archetype_index)
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


func _clear_generated_rooms() -> void:
	var directory := DirAccess.open(OUTPUT_DIR)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		if file_name.get_extension().to_lower() == "json":
			directory.remove(file_name)


func _room_data(mine_index: int, archetype_index: int) -> Dictionary:
	var archetype: Dictionary = ARCHETYPES[archetype_index]
	var mine_number := mine_index + 1
	var room_id := "m%d_%s" % [mine_number, archetype["slug"]]
	var blocks: Array[Dictionary] = []
	var raw_blocks: Array = archetype["blocks"]
	var occupied_cells: Dictionary[Vector2i, bool] = {}
	for raw_block: Array in raw_blocks:
		occupied_cells[Vector2i(int(raw_block[0]), int(raw_block[1]))] = true
	occupied_cells[Vector2i(int(archetype["core_x"]), BoardGeometry.CORE_ROW)] = true
	for block_index in range(raw_blocks.size()):
		var source: Array = raw_blocks[block_index]
		var x := int(source[0])
		var cell := Vector2i(x, int(source[1]))
		var type_name := _type_for_mine(
			str(source[2]),
			mine_index,
			archetype_index,
			block_index,
		)
		if type_name == "armored" \
			and not _is_side_accessible(cell, "bottom", occupied_cells):
			type_name = str(source[2])
		var hp := _hit_points(
			type_name,
			int(source[3]),
			mine_index,
			archetype_index,
			block_index,
		)
		var block_data := {
			"id": mine_number * 10_000 + archetype_index * 100 + block_index + 1,
			"type": type_name,
			"cell": [x, int(source[1])],
			"hitPoints": hp,
		}
		if type_name == "armored":
			block_data["vulnerableSides"] = _vulnerable_sides(
				mine_index,
				archetype_index,
				block_index,
				cell,
				occupied_cells,
			)
		blocks.append(block_data)
	var core_x := int(archetype["core_x"])
	blocks.append({
		"id": mine_number * 10_000 + archetype_index * 100 + 99,
		"type": "core",
		"cell": [core_x, 8],
		"hitPoints": mini(8, 6 + floori(float(mine_index) / 5.0)),
	})
	var passage: Array = []
	for raw_column: Variant in archetype["passage"]:
		passage.append(int(raw_column))
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
		"exampleAngles": [93.5],
		"blocks": blocks,
	}


func _type_for_mine(
	base_type: String,
	mine_index: int,
	archetype_index: int,
	block_index: int,
) -> String:
	if base_type == "rock":
		return base_type
	var selector := archetype_index * 7 + block_index
	match mine_index:
		0, 1, 2, 3, 4, 5:
			return base_type
		6:
			if selector % 10 == 0:
				return "explosive"
			if selector % 10 == 5:
				return "cracked"
		7:
			if selector % 8 == 0:
				return "explosive"
			if selector % 8 == 4:
				return "cracked"
		8:
			if selector % 7 == 2:
				return "explosive"
			if selector % 7 == 5:
				return "cracked"
		9:
			match selector % 6:
				0:
					return "explosive"
				3:
					return "cracked"
		10, 11, 12, 13:
			var period := 9 - (mine_index - 10)
			var remainder := selector % period
			if remainder == 0:
				return "armored"
			if remainder == 2:
				return "explosive"
			if remainder == period - 2:
				return "cracked"
	return base_type


func _hit_points(
	type_name: String,
	base_hp: int,
	mine_index: int,
	archetype_index: int,
	block_index: int,
) -> int:
	if type_name == "rock":
		return 0
	if type_name == "cracked":
		return 1
	if type_name == "explosive":
		return clampi(base_hp + floori(float(mine_index - 6) / 3.0), 2, 7)
	if type_name == "armored":
		return clampi(base_hp + 1 + floori(float(mine_index - 10) / 2.0), 3, 8)
	var minimum := 3 if type_name == "ore" else 2
	var difficulty_bonus := floori(float(mine_index) / 2.0)
	if mine_index % 2 == 1 and (archetype_index + block_index) % 2 == 0:
		difficulty_bonus += 1
	return clampi(base_hp + difficulty_bonus, minimum, 8)


func _vulnerable_sides(
	mine_index: int,
	archetype_index: int,
	block_index: int,
	cell: Vector2i,
	occupied_cells: Dictionary[Vector2i, bool],
) -> Array[String]:
	var sides: Array[String] = ["bottom"]
	var single_side := mine_index >= 12 and (archetype_index + block_index) % 2 == 0
	if single_side:
		return sides
	var side := "left" if (archetype_index + block_index) % 2 == 0 else "right"
	if _is_side_accessible(cell, side, occupied_cells):
		sides.append(side)
	else:
		var alternate := "right" if side == "left" else "left"
		if _is_side_accessible(cell, alternate, occupied_cells):
			sides.append(alternate)
	return sides


func _is_side_accessible(
	cell: Vector2i,
	side: String,
	occupied_cells: Dictionary[Vector2i, bool],
) -> bool:
	var neighbor := cell
	match side:
		"left":
			neighbor += Vector2i.LEFT
		"right":
			neighbor += Vector2i.RIGHT
		"top":
			neighbor += Vector2i.DOWN
		"bottom":
			neighbor += Vector2i.UP
		_:
			return false
	return neighbor.x >= 0 and neighbor.x < BoardGeometry.WORLD_GRID_SIZE.x \
		and neighbor.y >= 0 and neighbor.y < BoardGeometry.WORLD_GRID_SIZE.y \
		and not occupied_cells.has(neighbor)
