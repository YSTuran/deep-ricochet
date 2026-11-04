class_name RoomSnapshot
extends RefCounted

const SCHEMA_VERSION := 1

var schema_version: int = SCHEMA_VERSION
var template_id: StringName
var multiplier_bps: int
var shots_remaining: int
var break_score: int
var room_finished: bool
var room_succeeded: bool
var final_reward: int
var block_states: Array[Dictionary] = []
var scored_block_ids := PackedInt32Array()


static func capture(
	template: RoomTemplate,
	board: BoardModel,
	room: RoomSession,
) -> RoomSnapshot:
	if template == null or board == null or room == null or room.shot_in_progress:
		return null
	var snapshot := RoomSnapshot.new()
	snapshot.template_id = template.room_id
	snapshot.multiplier_bps = room.multiplier_bps
	snapshot.shots_remaining = room.shots_remaining
	snapshot.break_score = room.break_score
	snapshot.room_finished = room.room_finished
	snapshot.room_succeeded = room.room_succeeded
	snapshot.final_reward = room.final_reward
	for block: BlockState in board.blocks:
		snapshot.block_states.append({
			"id": block.id,
			"hitPoints": block.hit_points,
		})
	snapshot.scored_block_ids = room.scored_block_ids()
	return snapshot


static func from_dictionary(data: Dictionary) -> RoomSnapshot:
	var snapshot := RoomSnapshot.new()
	snapshot.schema_version = int(data.get("schemaVersion", 0))
	snapshot.template_id = StringName(str(data.get("templateId", "")))
	snapshot.multiplier_bps = int(data.get("multiplierBps", 0))
	snapshot.shots_remaining = int(data.get("shotsRemaining", -1))
	snapshot.break_score = int(data.get("breakScore", -1))
	snapshot.room_finished = bool(data.get("roomFinished", false))
	snapshot.room_succeeded = bool(data.get("roomSucceeded", false))
	snapshot.final_reward = int(data.get("finalReward", -1))

	var raw_blocks: Variant = data.get("blocks", [])
	if typeof(raw_blocks) == TYPE_ARRAY:
		for raw_block: Variant in raw_blocks:
			if typeof(raw_block) == TYPE_DICTIONARY:
				snapshot.block_states.append(raw_block)
			else:
				snapshot.block_states.append({})
	var raw_scored_ids: Variant = data.get("scoredBlockIds", [])
	if typeof(raw_scored_ids) == TYPE_ARRAY:
		for raw_id: Variant in raw_scored_ids:
			snapshot.scored_block_ids.append(int(raw_id))
	return snapshot


func to_dictionary() -> Dictionary:
	var scored_ids: Array[int] = []
	for block_id: int in scored_block_ids:
		scored_ids.append(block_id)
	return {
		"schemaVersion": schema_version,
		"templateId": str(template_id),
		"multiplierBps": multiplier_bps,
		"shotsRemaining": shots_remaining,
		"breakScore": break_score,
		"roomFinished": room_finished,
		"roomSucceeded": room_succeeded,
		"finalReward": final_reward,
		"blocks": block_states.duplicate(true),
		"scoredBlockIds": scored_ids,
	}


func validation_errors(template: RoomTemplate, config: GameConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != SCHEMA_VERSION:
		errors.append("Desteklenmeyen oda snapshot sürümü.")
	if template == null or template.room_id != template_id:
		errors.append("Oda snapshot şablonu bulunamadı veya kimliği uyuşmuyor.")
		return errors
	if multiplier_bps != template.multiplier_bps:
		errors.append("Oda snapshot çarpanı şablonla uyuşmuyor.")
	if shots_remaining < 0 or shots_remaining > config.shots_per_room:
		errors.append("Kalan atış sayısı geçersiz.")
	if break_score < 0 or final_reward < 0:
		errors.append("Oda puanı veya ödülü negatif olamaz.")
	if room_succeeded and not room_finished:
		errors.append("Başarılı oda bitmiş olmalıdır.")

	var hit_points_by_id: Dictionary[int, int] = {}
	for state: Dictionary in block_states:
		var block_id := int(state.get("id", 0))
		if block_id <= 0 or hit_points_by_id.has(block_id):
			errors.append("Oda snapshot blok kimliği geçersiz veya yineleniyor.")
			continue
		hit_points_by_id[block_id] = int(state.get("hitPoints", -1))
	if hit_points_by_id.size() != template.blocks.size():
		errors.append("Oda snapshot blok sayısı şablonla uyuşmuyor.")

	var scored_ids: Dictionary[int, bool] = {}
	for block_id: int in scored_block_ids:
		if scored_ids.has(block_id):
			errors.append("Puanlanmış blok kimliği yineleniyor.")
		else:
			scored_ids[block_id] = true
	var expected_break_score := 0
	var core_hit_points := -1
	for definition: RoomBlockDefinition in template.blocks:
		if not hit_points_by_id.has(definition.id):
			errors.append("Şablondaki blok oda snapshot içinde eksik: %d." % definition.id)
			continue
		var current_hp := hit_points_by_id[definition.id]
		if definition.block_type == BlockState.BlockType.ROCK:
			if current_hp != 0:
				errors.append("Sert kaya canı değiştirilemez.")
			if scored_ids.has(definition.id):
				errors.append("Sert kaya puanlanmış blok olamaz.")
		else:
			if current_hp < 0 or current_hp > definition.hit_points:
				errors.append("Blok canı geçersiz: %d." % definition.id)
			if scored_ids.has(definition.id):
				if current_hp != 0:
					errors.append("Puanlanmış blok yok edilmiş olmalıdır: %d." % definition.id)
				expected_break_score += ScoreCalculator.break_points(definition.block_type, config)
			elif current_hp == 0:
				errors.append("Yok edilmiş blok puanlanmış blok listesinde eksik: %d." % definition.id)
		if definition.block_type == BlockState.BlockType.CORE:
			core_hit_points = current_hp
	for block_id: int in scored_ids:
		if not hit_points_by_id.has(block_id):
			errors.append("Puanlanmış blok şablonda bulunmuyor: %d." % block_id)
	if break_score != expected_break_score:
		errors.append("Ham oda puanı kırılan bloklarla uyuşmuyor.")
	if room_succeeded != (core_hit_points == 0):
		errors.append("Oda başarı durumu çekirdek canıyla uyuşmuyor.")
	if room_finished and not room_succeeded and shots_remaining > 0:
		errors.append("Başarısız oda yalnızca atışlar bittiğinde sonlanabilir.")
	if not room_finished and shots_remaining == 0:
		errors.append("Atışı kalmayan oda sonuçlanmış olmalıdır.")
	var expected_reward := 0
	if room_finished:
		expected_reward = ScoreCalculator.room_reward(
			break_score,
			shots_remaining,
			multiplier_bps,
			room_succeeded,
			config,
		)
	if final_reward != expected_reward:
		errors.append("Oda ödülü kayıtlı durumla uyuşmuyor.")
	return errors


func hit_points_for(block_id: int) -> int:
	for state: Dictionary in block_states:
		if int(state.get("id", 0)) == block_id:
			return int(state.get("hitPoints", -1))
	return -1
