class_name GameConfig
extends RefCounted

const DEFAULT_PATH := "res://content/config/game_config.json"

var config_version: String = "prototype-1"
var room_count: int = 4
var shots_per_room: int = 3
var ball_count: int = 8
var ball_speed: float = 18.0
var ball_radius: float = 0.07
var launch_interval_seconds: float = 0.08
var volley_limit_seconds: float = 10.0
var aim_min_degrees: float = 15.0
var aim_max_degrees: float = 165.0
var aim_min_distance: float = 0.5
var preview_max_solid_bounces: int = 2
var safe_multiplier_bps: int = 10_000
var bonus_multiplier_bps: int = 15_000
var normal_break_points: int = 10
var ore_break_points: int = 25
var core_break_points: int = 100
var unused_shot_bonus: int = 20


static func load_from_file(path: String = DEFAULT_PATH) -> GameConfig:
	var config := GameConfig.new()
	if not FileAccess.file_exists(path):
		push_error("Oyun ayar dosyası bulunamadı: %s" % path)
		return config

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Oyun ayar dosyası geçerli bir JSON nesnesi değil: %s" % path)
		return config

	var data: Dictionary = parsed
	config.config_version = str(data.get("configVersion", config.config_version))
	config.room_count = int(data.get("roomCount", config.room_count))
	config.shots_per_room = int(data.get("shotsPerRoom", config.shots_per_room))
	config.ball_count = int(data.get("ballCount", config.ball_count))
	config.ball_speed = float(data.get("ballSpeed", config.ball_speed))
	config.ball_radius = float(data.get("ballRadius", config.ball_radius))
	config.launch_interval_seconds = float(data.get("launchIntervalSeconds", config.launch_interval_seconds))
	config.volley_limit_seconds = float(data.get("volleyLimitSeconds", config.volley_limit_seconds))
	config.aim_min_degrees = float(data.get("aimMinDegrees", config.aim_min_degrees))
	config.aim_max_degrees = float(data.get("aimMaxDegrees", config.aim_max_degrees))
	config.aim_min_distance = float(data.get("aimMinDistance", config.aim_min_distance))
	config.preview_max_solid_bounces = int(data.get("previewMaxSolidBounces", config.preview_max_solid_bounces))
	config.safe_multiplier_bps = int(data.get("safeMultiplierBps", config.safe_multiplier_bps))
	config.bonus_multiplier_bps = int(data.get("bonusMultiplierBps", config.bonus_multiplier_bps))
	config.normal_break_points = int(data.get("normalBreakPoints", config.normal_break_points))
	config.ore_break_points = int(data.get("oreBreakPoints", config.ore_break_points))
	config.core_break_points = int(data.get("coreBreakPoints", config.core_break_points))
	config.unused_shot_bonus = int(data.get("unusedShotBonus", config.unused_shot_bonus))
	return config
