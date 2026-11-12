class_name GameConfig
extends RefCounted

const DEFAULT_PATH := "res://content/config/game_config.json"
const INTEGER_FIELDS := [
	"roomCount",
	"shotsPerRoom",
	"ballCount",
	"previewMaxSolidBounces",
	"safeMultiplierBps",
	"bonusMultiplierBps",
	"normalBreakPoints",
	"oreBreakPoints",
	"coreBreakPoints",
	"explosiveBreakPoints",
	"crackedBreakPoints",
	"armoredBreakPoints",
	"unusedShotBonus",
]
const NUMBER_FIELDS := [
	"ballSpeed",
	"ballRadius",
	"launchIntervalSeconds",
	"volleyLimitSeconds",
	"aimMinDegrees",
	"aimMaxDegrees",
	"aimMinDistance",
]

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
var explosive_break_points: int = 10
var cracked_break_points: int = 6
var armored_break_points: int = 10
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
	var schema_errors := _schema_errors(data)
	if not schema_errors.is_empty():
		push_error("Oyun ayar dosyası şemaya uymuyor:\n- %s" % "\n- ".join(schema_errors))
		return config
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
	config.explosive_break_points = int(data.get("explosiveBreakPoints", config.explosive_break_points))
	config.cracked_break_points = int(data.get("crackedBreakPoints", config.cracked_break_points))
	config.armored_break_points = int(data.get("armoredBreakPoints", config.armored_break_points))
	config.unused_shot_bonus = int(data.get("unusedShotBonus", config.unused_shot_bonus))
	var validation_errors := config.validation_errors()
	if not validation_errors.is_empty():
		push_error("Oyun ayar değerleri geçersiz:\n- %s" % "\n- ".join(validation_errors))
		return GameConfig.new()
	return config


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if config_version.strip_edges().is_empty():
		errors.append("Yapılandırma sürümü boş olamaz.")
	if room_count <= 0:
		errors.append("Oda sayısı pozitif olmalıdır.")
	if shots_per_room <= 0:
		errors.append("Oda başına atış sayısı pozitif olmalıdır.")
	if ball_count <= 0 or ball_count > 64:
		errors.append("Top sayısı 1 ile 64 arasında olmalıdır.")
	if not _is_positive_finite(ball_speed):
		errors.append("Top hızı pozitif ve sonlu olmalıdır.")
	if not _is_positive_finite(ball_radius):
		errors.append("Top yarıçapı pozitif ve sonlu olmalıdır.")
	if not _is_non_negative_finite(launch_interval_seconds):
		errors.append("Top çıkış aralığı negatif olamaz ve sonlu olmalıdır.")
	if not _is_positive_finite(volley_limit_seconds):
		errors.append("Yaylım süresi pozitif ve sonlu olmalıdır.")
	if (
		ball_count > 0
		and _is_non_negative_finite(launch_interval_seconds)
		and _is_positive_finite(volley_limit_seconds)
		and float(ball_count - 1) * launch_interval_seconds >= volley_limit_seconds
	):
		errors.append("Son top yaylım süresi dolmadan fırlatılabilmelidir.")
	if (
		not _is_finite_number(aim_min_degrees)
		or not _is_finite_number(aim_max_degrees)
		or aim_min_degrees < 0.0
		or aim_max_degrees > 180.0
		or aim_min_degrees >= aim_max_degrees
	):
		errors.append("Nişan açıları 0–180 aralığında ve küçükten büyüğe olmalıdır.")
	if not _is_positive_finite(aim_min_distance):
		errors.append("Minimum nişan mesafesi pozitif ve sonlu olmalıdır.")
	if preview_max_solid_bounces < 0 or preview_max_solid_bounces > 64:
		errors.append("Önizleme sekme sayısı 0 ile 64 arasında olmalıdır.")
	if safe_multiplier_bps <= 0 or bonus_multiplier_bps < safe_multiplier_bps:
		errors.append("Rota çarpanları pozitif olmalı ve bonus güvenli rotadan düşük olmamalıdır.")
	if normal_break_points < 0 or ore_break_points < 0 or core_break_points <= 0 \
		or explosive_break_points != 10 or cracked_break_points != 6 \
		or armored_break_points < 0:
		errors.append("Blok puanları negatif olamaz; çekirdek puanı pozitif olmalıdır.")
	if unused_shot_bonus < 0:
		errors.append("Kullanılmayan atış bonusu negatif olamaz.")
	return errors


static func _schema_errors(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if data.has("configVersion") and typeof(data["configVersion"]) != TYPE_STRING:
		errors.append("configVersion metin olmalıdır.")
	for field: String in INTEGER_FIELDS:
		if not data.has(field):
			continue
		var value: Variant = data[field]
		if (
			typeof(value) not in [TYPE_INT, TYPE_FLOAT]
			or not _is_finite_number(float(value))
			or float(value) != roundf(float(value))
		):
			errors.append("%s tam sayı olmalıdır." % field)
	for field: String in NUMBER_FIELDS:
		if data.has(field) and typeof(data[field]) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append("%s sayı olmalıdır." % field)
	return errors


static func _is_finite_number(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _is_positive_finite(value: float) -> bool:
	return _is_finite_number(value) and value > 0.0


static func _is_non_negative_finite(value: float) -> bool:
	return _is_finite_number(value) and value >= 0.0
