class_name RoomResultRecord
extends RefCounted

const SCHEMA_VERSION := 1

var schema_version := SCHEMA_VERSION
var room_number: int
var template_id: StringName
var multiplier_bps: int
var break_score: int
var remaining_shots: int
var unused_shot_bonus: int
var reward: int
var succeeded: bool


static func from_resolution(
	completed_room_number: int,
	completed_template_id: StringName,
	resolution: RoomResolution,
) -> RoomResultRecord:
	if resolution == null:
		return null
	var record := RoomResultRecord.new()
	record.room_number = completed_room_number
	record.template_id = completed_template_id
	record.multiplier_bps = resolution.multiplier_bps
	record.break_score = resolution.break_score
	record.remaining_shots = resolution.remaining_shots
	record.unused_shot_bonus = resolution.unused_shot_bonus
	record.reward = resolution.reward
	record.succeeded = resolution.succeeded
	return record


static func from_dictionary(data: Dictionary) -> RoomResultRecord:
	var record := RoomResultRecord.new()
	record.schema_version = int(data.get("schemaVersion", 0))
	record.room_number = int(data.get("roomNumber", 0))
	record.template_id = StringName(str(data.get("templateId", "")))
	record.multiplier_bps = int(data.get("multiplierBps", 0))
	record.break_score = int(data.get("breakScore", -1))
	record.remaining_shots = int(data.get("remainingShots", -1))
	record.unused_shot_bonus = int(data.get("unusedShotBonus", -1))
	record.reward = int(data.get("reward", -1))
	record.succeeded = bool(data.get("succeeded", false))
	return record


func to_dictionary() -> Dictionary:
	return {
		"schemaVersion": schema_version,
		"roomNumber": room_number,
		"templateId": str(template_id),
		"multiplierBps": multiplier_bps,
		"breakScore": break_score,
		"remainingShots": remaining_shots,
		"unusedShotBonus": unused_shot_bonus,
		"reward": reward,
		"succeeded": succeeded,
	}


func validation_errors(catalog: RoomCatalog, config: GameConfig) -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != SCHEMA_VERSION:
		errors.append("Desteklenmeyen oda sonucu sürümü.")
	if room_number < 1 or room_number > config.room_count:
		errors.append("Oda sonucu sıra numarası geçersiz.")
	var template := catalog.get_template(template_id) if catalog != null else null
	if template == null:
		errors.append("Oda sonucu şablonu katalogda bulunamadı.")
	elif multiplier_bps != template.multiplier_bps:
		errors.append("Oda sonucu çarpanı şablonla uyuşmuyor.")
	if break_score < 0 or remaining_shots < 0 or remaining_shots > config.shots_per_room:
		errors.append("Oda sonucu puanı veya kalan atışı geçersiz.")
	var expected_bonus := config.unused_shot_bonus * remaining_shots if succeeded else 0
	if unused_shot_bonus != expected_bonus:
		errors.append("Oda sonucu kullanılmayan atış bonusu geçersiz.")
	var expected_reward := ScoreCalculator.room_reward(
		break_score,
		remaining_shots,
		multiplier_bps,
		succeeded,
		config,
	)
	if reward != expected_reward:
		errors.append("Oda sonucu ödülü puan formülüyle uyuşmuyor.")
	return errors
