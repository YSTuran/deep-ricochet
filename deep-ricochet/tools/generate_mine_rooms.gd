extends SceneTree

const CONTENT_VERSION := "p2-mines-9"
const CRACKED_HIT_POINTS := 8
const NARROW_DURABILITY_BONUS := 1
const MAX_ROOM_BLOCKS := 24
const ENTRY_CLEAR_MAX_ROW := 3
const MAX_LAYOUT_SIMILARITY := 0.80
const MAX_VISUAL_SIMILARITY := 0.70
const OUTPUT_DIR := "res://content/mines/rooms"
const CATALOG_PATH := "res://content/mines/catalog.json"

const ROOM_SLOTS := [
	{"slug": "start", "role": "start", "family": "safe", "key": "START"},
	{"slug": "wide_01", "role": "wide", "family": "safe", "key": "WIDE_01"},
	{"slug": "wide_02", "role": "wide", "family": "safe", "key": "WIDE_02"},
	{"slug": "wide_03", "role": "wide", "family": "safe", "key": "WIDE_03"},
	{"slug": "narrow_01", "role": "narrow", "family": "bonus", "key": "NARROW_01"},
	{"slug": "narrow_02", "role": "narrow", "family": "bonus", "key": "NARROW_02"},
	{"slug": "narrow_03", "role": "narrow", "family": "bonus", "key": "NARROW_03"},
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

var _config: GameConfig


func _initialize() -> void:
	call_deferred("_generate")


func _generate() -> void:
	_config = GameConfig.load_from_file()
	if _config == null or not _config.validation_errors().is_empty():
		push_error("Oda üretimi için oyun ayarları yüklenemedi.")
		quit(1)
		return

	var generated_rooms: Array[Dictionary] = []
	for mine_index in range(DISPLAY_NAMES.size()):
		for slot_index in range(ROOM_SLOTS.size()):
			var data := _room_data(mine_index, slot_index)
			if data.is_empty():
				quit(1)
				return
			generated_rooms.append(data)

	var uniqueness_errors := _layout_uniqueness_errors(generated_rooms)
	if not uniqueness_errors.is_empty():
		push_error("Oda yerleşimleri yeterince özgün değil:\n- %s" % "\n- ".join(uniqueness_errors))
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_generated_rooms()
	var paths: Array[String] = []
	for data: Dictionary in generated_rooms:
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
	print("[MINE_GEN] %d özgün ve çözülebilir oda üretildi." % paths.size())
	quit()


func _clear_generated_rooms() -> void:
	var directory := DirAccess.open(OUTPUT_DIR)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		if file_name.get_extension().to_lower() == "json":
			directory.remove(file_name)


func _room_data(mine_index: int, slot_index: int) -> Dictionary:
	var slot: Dictionary = ROOM_SLOTS[slot_index]
	var mine_number := mine_index + 1
	var role := str(slot["role"])
	var family := str(slot["family"])
	var room_id := "m%d_%s" % [mine_number, slot["slug"]]
	var core_cell := _core_cell(mine_index, slot_index)
	var passage := _passage_columns(mine_index, slot_index, role)
	var target_count := _target_block_count(mine_index, slot_index, role)
	var rock_target := _target_rock_count(mine_index, slot_index, role)

	var occupied: Dictionary[Vector2i, bool] = {core_cell: true}
	var solution_cells := _solution_cells(core_cell)
	var entries: Array[Dictionary] = []
	_add_core_gates(entries, occupied, core_cell, mine_index, slot_index)

	var rock_candidates := _rock_candidates(
		mine_index,
		slot_index,
		role,
		core_cell,
		passage,
		occupied,
		solution_cells,
	)
	for cell: Vector2i in rock_candidates:
		if _count_type(entries, "rock") >= rock_target:
			break
		if occupied.has(cell) or solution_cells.has(cell) \
			or _is_identity_gap(cell, mine_index, slot_index) \
			or (passage.has(cell.x) and cell.y <= ENTRY_CLEAR_MAX_ROW):
			continue
		entries.append({"cell": cell, "type": "rock", "base_hp": 0, "gate": false})
		occupied[cell] = true

	var fill_candidates := _fill_candidates(
		mine_index,
		slot_index,
		role,
		core_cell,
		passage,
		occupied,
		solution_cells,
	)
	var fill_index := 0
	while entries.size() + 1 < target_count and not fill_candidates.is_empty():
		var cell: Vector2i = fill_candidates.pop_front()
		if occupied.has(cell):
			continue
		var type_name := _type_for_cell(mine_index, slot_index, role, cell, fill_index)
		entries.append({
			"cell": cell,
			"type": type_name,
			"base_hp": 2 + posmod(cell.x * 3 + cell.y + slot_index, 4),
			"gate": false,
		})
		occupied[cell] = true
		fill_index += 1

	if entries.size() + 1 != target_count:
		push_error("Hedef blok yoğunluğu üretilemedi: %s (%d/%d)." % [
			room_id,
			entries.size() + 1,
			target_count,
		])
		return {}

	_ensure_required_types(entries, occupied, mine_index, slot_index)
	var blocks := _block_data(entries, occupied, mine_number, slot_index, mine_index, role)
	var core_hit_points := mini(8, 6 + floori(float(mine_index) / 5.0))
	if role == "narrow":
		core_hit_points = mini(8, core_hit_points + NARROW_DURABILITY_BONUS)
	blocks.append({
		"id": mine_number * 10_000 + slot_index * 100 + 99,
		"type": "core",
		"cell": [core_cell.x, core_cell.y],
		"hitPoints": core_hit_points,
	})

	var data := {
		"schemaVersion": 1,
		"id": room_id,
		"displayName": DISPLAY_NAMES[mine_index][slot_index],
		"displayNameKey": "MINE_%d_%s" % [mine_number, slot["key"]],
		"mineId": "mine_%02d" % mine_number,
		"role": role,
		"family": family,
		"contentVersion": CONTENT_VERSION,
		"width": BoardGeometry.BLOCK_GRID_SIZE.x,
		"height": BoardGeometry.BLOCK_GRID_SIZE.y,
		"multiplierBps": 15_000 if family == "bonus" else 10_000,
		"passageColumns": passage,
		"exampleAngles": [_direct_angle(core_cell), _direct_angle(core_cell), _direct_angle(core_cell)],
		"blocks": blocks,
	}
	var solved_angles := _solve_example_angles(data, core_cell)
	if solved_angles.is_empty():
		push_error("Oda için üç atışlık çözüm bulunamadı: %s" % room_id)
		return {}
	data["exampleAngles"] = solved_angles
	return data


func _core_cell(mine_index: int, slot_index: int) -> Vector2i:
	var room_index := mine_index * ROOM_SLOTS.size() + slot_index
	var position_index := posmod(room_index * 5, 18)
	var x := 1 + posmod(position_index, 6)
	var y := BoardGeometry.CORE_MIN_ROW + floori(float(position_index) / 6.0)
	return Vector2i(x, y)


func _passage_columns(mine_index: int, slot_index: int, role: String) -> Array[int]:
	if role == "narrow":
		return [3 + posmod(mine_index + slot_index, 2)]
	var pairs: Array = [[2, 3], [3, 4], [4, 5]]
	var selected: Array = pairs[posmod(mine_index + slot_index * 2, pairs.size())]
	var result: Array[int] = []
	for column: int in selected:
		result.append(column)
	return result


func _target_block_count(mine_index: int, slot_index: int, role: String) -> int:
	var tier := floori(float(mine_index) / 3.0)
	var wide_target := mini(22, 14 + tier * 2 + posmod(mine_index + slot_index, 2))
	if role == "narrow":
		return mini(MAX_ROOM_BLOCKS, wide_target + 2)
	return wide_target


func _target_rock_count(mine_index: int, slot_index: int, role: String) -> int:
	if role == "narrow":
		return mini(9, 5 + floori(float(mine_index) / 5.0) + posmod(mine_index + slot_index, 2))
	return mini(5, 2 + floori(float(mine_index) / 5.0) + posmod(slot_index, 2))


func _solution_cells(core_cell: Vector2i) -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	for y in range(RoomTemplate.MIN_BLOCK_ROW, core_cell.y):
		cells[_solution_cell(core_cell, y)] = true
	return cells


func _solution_cell(core_cell: Vector2i, cell_y: int) -> Vector2i:
	var launcher := BoardGeometry.LAUNCHER_WORLD
	var core_center := Vector2(core_cell) + Vector2.ONE * 0.5
	var sample_y := float(cell_y) + 0.5
	var progress := (sample_y - launcher.y) / (core_center.y - launcher.y)
	var sample_x := launcher.x + (core_center.x - launcher.x) * progress
	return Vector2i(clampi(floori(sample_x), 0, 7), cell_y)


func _add_core_gates(
	entries: Array[Dictionary],
	occupied: Dictionary[Vector2i, bool],
	core_cell: Vector2i,
	mine_index: int,
	slot_index: int,
) -> void:
	var gate_rows := [maxi(4, core_cell.y - 3), core_cell.y - 1]
	for gate_index in range(gate_rows.size()):
		var cell := _solution_cell(core_cell, gate_rows[gate_index])
		if occupied.has(cell):
			continue
		var type_name := "ore" if posmod(mine_index + slot_index + gate_index, 3) == 0 else "normal"
		entries.append({
			"cell": cell,
			"type": type_name,
			"base_hp": 3 + gate_index,
			"gate": true,
		})
		occupied[cell] = true


func _rock_candidates(
	mine_index: int,
	slot_index: int,
	role: String,
	core_cell: Vector2i,
	passage: Array[int],
	occupied: Dictionary[Vector2i, bool],
	solution_cells: Dictionary[Vector2i, bool],
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if role == "narrow":
		var pattern := posmod(mine_index * ROOM_SLOTS.size() + slot_index, 4)
		var rows: Array[int] = [2, 3, 4, 5, 6, 7]
		for row_offset in range(rows.size()):
			var y := rows[posmod(row_offset + mine_index + slot_index, rows.size())]
			var left := 0
			var right := 7
			if pattern == 1 and y >= 5:
				left = 1
				right = 6
			elif pattern == 2 and posmod(y + mine_index, 2) == 0:
				left = 1
			elif pattern == 3:
				left = 1 if posmod(y + slot_index, 3) != 0 else 0
				right = 6 if posmod(y + mine_index, 3) == 0 else 7
			result.append(Vector2i(left, y))
			result.append(Vector2i(right, y))
			result.append(Vector2i(1 if left == 0 else 0, y))
			result.append(Vector2i(6 if right == 7 else 7, y))

	var scored := _scored_open_cells(
		mine_index,
		slot_index,
		role,
		core_cell,
		passage,
		occupied,
		solution_cells,
		true,
	)
	result.append_array(scored)
	return _unique_cells(result)


func _fill_candidates(
	mine_index: int,
	slot_index: int,
	role: String,
	core_cell: Vector2i,
	passage: Array[int],
	occupied: Dictionary[Vector2i, bool],
	solution_cells: Dictionary[Vector2i, bool],
) -> Array[Vector2i]:
	return _scored_open_cells(
		mine_index,
		slot_index,
		role,
		core_cell,
		passage,
		occupied,
		solution_cells,
		false,
	)


func _scored_open_cells(
	mine_index: int,
	slot_index: int,
	role: String,
	core_cell: Vector2i,
	passage: Array[int],
	occupied: Dictionary[Vector2i, bool],
	solution_cells: Dictionary[Vector2i, bool],
	for_rocks: bool,
) -> Array[Vector2i]:
	var scored: Array[Dictionary] = []
	for y in range(RoomTemplate.MIN_BLOCK_ROW, BoardGeometry.BLOCK_GRID_SIZE.y):
		for x in range(BoardGeometry.BLOCK_GRID_SIZE.x):
			var cell := Vector2i(x, y)
			if cell == core_cell or occupied.has(cell):
				continue
			if _is_identity_gap(cell, mine_index, slot_index):
				continue
			if passage.has(x) and y <= ENTRY_CLEAR_MAX_ROW:
				continue
			if solution_cells.has(cell):
				continue
			var score := _cell_hash(mine_index, slot_index, x, y)
			var edge_distance := mini(x, 7 - x)
			if for_rocks:
				score += edge_distance * (180_000 if role == "narrow" else 90_000)
			else:
				if role == "narrow":
					score -= y * 24_000
					score += edge_distance * 4_000
				else:
					score += abs(y - (4 + posmod(slot_index, 3))) * 7_000
			scored.append({"cell": cell, "score": score})
	scored.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left["score"]) < int(right["score"])
	)
	var result: Array[Vector2i] = []
	for item: Dictionary in scored:
		result.append(item["cell"])
	return result


func _cell_hash(mine_index: int, slot_index: int, x: int, y: int) -> int:
	var value := (mine_index + 1) * 73_856_093
	value = value ^ ((slot_index + 1) * 19_349_663)
	value = value ^ ((x + 1) * 83_492_791)
	value = value ^ ((y + 1) * 2_654_435_761)
	value = value ^ ((mine_index + 3) * (x + 5) * 97_531)
	value = value ^ ((slot_index + 7) * (y + 11) * 421_009)
	value = (value ^ (value >> 13)) * 1_274_126_177
	return posmod(value, 100_000)


func _is_identity_gap(cell: Vector2i, mine_index: int, slot_index: int) -> bool:
	for gap_index in range(4):
		var gap_x := posmod(_cell_hash(mine_index, slot_index, gap_index, 9), 8)
		var gap_y := RoomTemplate.MIN_BLOCK_ROW \
			+ posmod(_cell_hash(mine_index, slot_index, 9, gap_index), 6)
		if cell == Vector2i(gap_x, gap_y):
			return true
	return false


func _unique_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		if seen.has(cell):
			continue
		seen[cell] = true
		result.append(cell)
	return result


func _type_for_cell(
	mine_index: int,
	slot_index: int,
	role: String,
	cell: Vector2i,
	fill_index: int,
) -> String:
	var cycle: Array[String]
	if mine_index <= 5:
		cycle = ["normal", "ore", "normal", "ore", "normal"]
	elif mine_index <= 9:
		cycle = ["normal", "ore", "explosive", "normal", "cracked", "ore"]
	else:
		cycle = ["normal", "ore", "armored", "explosive", "normal", "cracked", "ore", "armored"]
	var offset := posmod(mine_index * 3 + slot_index * 5 + cell.x + cell.y, cycle.size())
	var type_name := cycle[posmod(fill_index + offset, cycle.size())]
	if role == "narrow" and cell.y >= 5 and type_name == "normal" \
		and posmod(cell.x + cell.y + slot_index, 2) == 0:
		type_name = "ore"
	return type_name


func _ensure_required_types(
	entries: Array[Dictionary],
	occupied: Dictionary[Vector2i, bool],
	mine_index: int,
	slot_index: int,
) -> void:
	var required: Array[String] = ["normal", "ore"]
	if mine_index >= 6:
		required.append_array(["explosive", "cracked"])
	if mine_index >= 10:
		required.append("armored")
	for required_type: String in required:
		if _count_type(entries, required_type) > 0:
			continue
		for entry_index in range(entries.size() - 1, -1, -1):
			var entry: Dictionary = entries[entry_index]
			if bool(entry.get("gate", false)) or str(entry["type"]) == "rock":
				continue
			if required_type == "armored" \
				and _accessible_armor_sides(entry["cell"], occupied, mine_index, slot_index, entry_index).is_empty():
				continue
			entry["type"] = required_type
			entries[entry_index] = entry
			break


func _block_data(
	entries: Array[Dictionary],
	occupied: Dictionary[Vector2i, bool],
	mine_number: int,
	slot_index: int,
	mine_index: int,
	role: String,
) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	for entry_index in range(entries.size()):
		var entry: Dictionary = entries[entry_index]
		var cell: Vector2i = entry["cell"]
		var type_name := str(entry["type"])
		var vulnerable_sides: Array[String] = []
		if type_name == "armored":
			vulnerable_sides = _accessible_armor_sides(
				cell,
				occupied,
				mine_index,
				slot_index,
				entry_index,
			)
			if vulnerable_sides.is_empty():
				type_name = "ore"
		var block := {
			"id": mine_number * 10_000 + slot_index * 100 + entry_index + 1,
			"type": type_name,
			"cell": [cell.x, cell.y],
			"hitPoints": _hit_points(
				type_name,
				int(entry["base_hp"]),
				mine_index,
				role,
				entry_index,
				cell,
			),
		}
		if type_name == "armored":
			block["vulnerableSides"] = vulnerable_sides
		blocks.append(block)
	return blocks


func _accessible_armor_sides(
	cell: Vector2i,
	occupied: Dictionary[Vector2i, bool],
	mine_index: int,
	slot_index: int,
	entry_index: int,
) -> Array[String]:
	# Mevcut zırhlı blok görsellerinin üçü de alt zayıf noktayı gösterir.
	# Bu kenar kapalıysa blok üretmeyerek görsel ile hasar maskesinin ayrışmasını önleriz.
	if not _is_side_accessible(cell, "bottom", occupied):
		return []
	var sides: Array[String] = ["bottom"]
	if mine_index >= 12:
		return sides
	var side_candidates: Array[String] = ["left", "right"]
	var rotation := posmod(mine_index + slot_index + entry_index, side_candidates.size())
	for side_offset in range(side_candidates.size()):
		var side := side_candidates[posmod(side_offset + rotation, side_candidates.size())]
		if _is_side_accessible(cell, side, occupied):
			sides.append(side)
			break
	return sides


func _is_side_accessible(
	cell: Vector2i,
	side: String,
	occupied: Dictionary[Vector2i, bool],
) -> bool:
	var neighbor := cell
	match side:
		"left":
			neighbor += Vector2i.LEFT
		"right":
			neighbor += Vector2i.RIGHT
		"bottom":
			neighbor += Vector2i.UP
		_:
			return false
	return neighbor.x >= 0 and neighbor.x < BoardGeometry.WORLD_GRID_SIZE.x \
		and neighbor.y >= 0 and neighbor.y < BoardGeometry.WORLD_GRID_SIZE.y \
		and not occupied.has(neighbor)


func _hit_points(
	type_name: String,
	base_hp: int,
	mine_index: int,
	role: String,
	entry_index: int,
	cell: Vector2i,
) -> int:
	if type_name == "rock":
		return 0
	if type_name == "cracked":
		return CRACKED_HIT_POINTS
	var role_bonus := NARROW_DURABILITY_BONUS if role == "narrow" else 0
	if type_name == "explosive":
		return clampi(base_hp + floori(float(mine_index - 6) / 3.0) + role_bonus, 2, 8)
	if type_name == "armored":
		return clampi(base_hp + 1 + floori(float(mine_index - 10) / 2.0) + role_bonus, 3, 8)
	var minimum := 3 if type_name == "ore" else 2
	var difficulty_bonus := floori(float(mine_index) / 2.0)
	if mine_index % 2 == 1 and (entry_index + cell.x + cell.y) % 2 == 0:
		difficulty_bonus += 1
	return clampi(base_hp + difficulty_bonus + role_bonus, minimum, 8)


func _count_type(entries: Array[Dictionary], type_name: String) -> int:
	var count := 0
	for entry: Dictionary in entries:
		if str(entry["type"]) == type_name:
			count += 1
	return count


func _direct_angle(core_cell: Vector2i) -> float:
	var direction := Vector2(core_cell) + Vector2.ONE * 0.5 - BoardGeometry.LAUNCHER_WORLD
	return snappedf(clampf(rad_to_deg(direction.angle()), 15.0, 165.0), 0.5)


func _solve_example_angles(data: Dictionary, core_cell: Vector2i) -> Array[float]:
	var direct := _direct_angle(core_cell)
	var candidates: Array[float] = [
		direct,
		direct - 1.0,
		direct + 1.0,
		direct - 2.5,
		direct + 2.5,
		direct - 5.0,
		direct + 5.0,
	]
	for candidate: float in candidates:
		candidate = clampf(candidate, 15.0, 165.0)
		var sequence: Array[float] = [candidate, candidate, candidate]
		if _sequence_breaks_core(data, sequence):
			return sequence
	for step in range(61):
		var candidate := 15.0 + float(step) * 2.5
		var sequence: Array[float] = [candidate, candidate, candidate]
		if _sequence_breaks_core(data, sequence):
			return sequence
	return []


func _sequence_breaks_core(data: Dictionary, angles: Array[float]) -> bool:
	var template := RoomTemplateLoader.from_dictionary(data)
	if template == null or not template.is_valid():
		return false
	var board := template.create_board()
	var simulator := ShotSimulator.new()
	for angle: float in angles:
		var volley := ShotVolley.new()
		if not volley.start(
			BoardGeometry.LAUNCHER_WORLD,
			Vector2.from_angle(deg_to_rad(angle)) * _config.ball_speed,
			_config.ball_count,
			_config.launch_interval_seconds,
			_config.volley_limit_seconds,
		):
			return false
		for tick in range(1300):
			if not volley.active:
				break
			volley.advance(
				1.0 / 120.0,
				simulator,
				Vector2(BoardGeometry.WORLD_GRID_SIZE),
				_config.ball_radius,
				board,
			)
		if board.is_core_destroyed():
			return true
	return false


func _layout_uniqueness_errors(rooms: Array[Dictionary]) -> PackedStringArray:
	var errors := PackedStringArray()
	var cell_sets: Array[Dictionary] = []
	var visual_sets: Array[Dictionary] = []
	for room: Dictionary in rooms:
		var cells: Dictionary[String, bool] = {}
		var visual_cells: Dictionary[String, bool] = {}
		for block: Dictionary in room["blocks"]:
			var cell: Array = block["cell"]
			cells["%d:%d" % [int(cell[0]), int(cell[1])]] = true
			visual_cells["%s:%d:%d" % [
				str(block["type"]),
				int(cell[0]),
				int(cell[1]),
			]] = true
		cell_sets.append(cells)
		visual_sets.append(visual_cells)
	for left_index in range(rooms.size()):
		for right_index in range(left_index + 1, rooms.size()):
			var similarity := _jaccard_similarity(cell_sets[left_index], cell_sets[right_index])
			var visual_similarity := _jaccard_similarity(
				visual_sets[left_index],
				visual_sets[right_index],
			)
			if similarity > MAX_LAYOUT_SIMILARITY \
				or visual_similarity > MAX_VISUAL_SIMILARITY:
				errors.append("%s ile %s yerleşim/görsel benzerliği %.0f%%/%.0f%%." % [
					rooms[left_index]["id"],
					rooms[right_index]["id"],
					similarity * 100.0,
					visual_similarity * 100.0,
				])
				if errors.size() >= 12:
					return errors
	return errors


func _jaccard_similarity(left: Dictionary, right: Dictionary) -> float:
	var intersection := 0
	for cell: String in left:
		if right.has(cell):
			intersection += 1
	var union_size := left.size() + right.size() - intersection
	return float(intersection) / float(maxi(union_size, 1))
