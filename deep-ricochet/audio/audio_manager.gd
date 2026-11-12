extends Node

const BOARD_WIDTH := 8.0
const SFX_POOL_SIZE := 12
const UI_POOL_SIZE := 4
const MIN_NOTE_INTERVAL_USEC := 45_000
const MELODY_RESET_USEC := 650_000
const MATERIAL_INTERVAL_USEC := 85_000
const PENTATONIC_PITCHES := [1.0, 1.189207, 1.33484, 1.498307, 1.781797]
const AMBIENT_MIX_RATE := 22_050
const AMBIENT_DURATION_SECONDS := 8

const COLLISION_NOTE: AudioStream = preload("res://assets/audio/sfx/collision_note.ogg")
const LAUNCH: AudioStream = preload("res://assets/audio/sfx/launch.ogg")
const NORMAL_HIT: AudioStream = preload("res://assets/audio/sfx/normal_hit.ogg")
const ORE_HIT: AudioStream = preload("res://assets/audio/sfx/ore_hit.ogg")
const ROCK_HIT: AudioStream = preload("res://assets/audio/sfx/rock_hit.ogg")
const BLOCK_BREAK: AudioStream = preload("res://assets/audio/sfx/block_break.ogg")
const CORE_BREAK: AudioStream = preload("res://assets/audio/sfx/core_break.ogg")
const UI_CLICK: AudioStream = preload("res://assets/audio/sfx/ui_click.ogg")
const UI_CONFIRM: AudioStream = preload("res://assets/audio/sfx/ui_confirm.ogg")
const ROUTE_SELECT: AudioStream = preload("res://assets/audio/sfx/route_select.ogg")
const ROOM_SUCCESS: AudioStream = preload("res://assets/audio/sfx/room_success.ogg")
const ROOM_FAILURE: AudioStream = preload("res://assets/audio/sfx/room_failure.ogg")
const NEW_BEST: AudioStream = preload("res://assets/audio/sfx/new_best.ogg")

var sfx_enabled := true
var sfx_volume := 0.8
var music_enabled := true
var music_volume := 0.28
var melody_index := 0
var played_event_count := 0

var _last_note_usec := -MELODY_RESET_USEC
var _last_material_usec: Dictionary[int, int] = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _sfx_cursor := 0
var _ui_cursor := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(&"SFX")
	_ensure_bus(&"UI")
	_ensure_bus(&"Music")
	_sfx_players = _create_pool(SFX_POOL_SIZE, &"SFX")
	_ui_players = _create_pool(UI_POOL_SIZE, &"UI")
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "AmbientMusicPlayer"
	_music_player.bus = &"Music"
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player.stream = _create_ambient_loop()
	add_child(_music_player)
	_music_player.play()
	_apply_bus_settings()


func _exit_tree() -> void:
	stop_all()


func stop_all() -> void:
	for player: AudioStreamPlayer in _sfx_players + _ui_players:
		player.stop()
		player.stream = null
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null


func apply_settings(settings: AppSettings) -> void:
	if settings == null:
		return
	sfx_enabled = settings.sfx_enabled
	sfx_volume = settings.sfx_volume
	music_enabled = settings.music_enabled
	music_volume = settings.music_volume
	_apply_bus_settings()


func begin_volley() -> void:
	melody_index = 0
	_last_note_usec = -MELODY_RESET_USEC
	_last_material_usec.clear()


func play_launch() -> void:
	_play_sfx(LAUNCH, -8.0, 0.92)


func play_collision(block_type: int, position_x: float) -> bool:
	if not sfx_enabled:
		return false
	var now := Time.get_ticks_usec()
	if now - _last_note_usec < MIN_NOTE_INTERVAL_USEC:
		return false
	if now - _last_note_usec > MELODY_RESET_USEC:
		melody_index = 0
	var pitch := float(PENTATONIC_PITCHES[melody_index % PENTATONIC_PITCHES.size()])
	match block_type:
		BlockState.BlockType.ORE:
			pitch *= 2.0
		BlockState.BlockType.ROCK:
			pitch *= 0.5
		BlockState.BlockType.CORE:
			pitch *= 1.5
		BlockState.BlockType.EXPLOSIVE:
			pitch *= 0.75
		BlockState.BlockType.CRACKED:
			pitch *= 1.12
		BlockState.BlockType.ARMORED:
			pitch *= 0.62
	_play_sfx(COLLISION_NOTE, -11.0, pitch)
	melody_index += 1
	_last_note_usec = now
	_play_material_layer(block_type, now, position_x)
	return true


func play_break(block_type: int) -> void:
	if block_type == BlockState.BlockType.CORE:
		_play_sfx(CORE_BREAK, -3.0, 1.0)
	elif block_type == BlockState.BlockType.EXPLOSIVE:
		_play_sfx(BLOCK_BREAK, -3.0, 0.72)
	else:
		_play_sfx(BLOCK_BREAK, -7.0, 0.96)


func play_room_result(succeeded: bool) -> void:
	_play_sfx(ROOM_SUCCESS if succeeded else ROOM_FAILURE, -5.0, 1.0)


func play_new_best() -> void:
	_play_ui(NEW_BEST, -3.0, 1.0)


func play_route_select() -> void:
	_play_ui(ROUTE_SELECT, -6.0, 1.0)


func play_ui_click() -> void:
	_play_ui(UI_CLICK, -10.0, 1.0)


func play_ui_confirm() -> void:
	_play_ui(UI_CONFIRM, -6.0, 1.0)


func _play_material_layer(block_type: int, now: int, _position_x: float) -> void:
	if block_type < 0:
		return
	var previous: int = _last_material_usec.get(block_type, -MATERIAL_INTERVAL_USEC)
	if now - previous < MATERIAL_INTERVAL_USEC:
		return
	_last_material_usec[block_type] = now
	match block_type:
		BlockState.BlockType.NORMAL:
			_play_sfx(NORMAL_HIT, -19.0, 1.0)
		BlockState.BlockType.ORE:
			_play_sfx(ORE_HIT, -17.0, 1.05)
		BlockState.BlockType.CORE:
			_play_sfx(ORE_HIT, -15.0, 0.78)
		BlockState.BlockType.ROCK:
			_play_sfx(ROCK_HIT, -16.0, 0.9)
		BlockState.BlockType.EXPLOSIVE:
			_play_sfx(ORE_HIT, -15.0, 0.72)
		BlockState.BlockType.CRACKED:
			_play_sfx(NORMAL_HIT, -17.0, 1.18)
		BlockState.BlockType.ARMORED:
			_play_sfx(ROCK_HIT, -14.0, 0.72)


func _play_sfx(stream: AudioStream, volume_db: float, pitch: float) -> void:
	if not sfx_enabled or stream == null:
		return
	var player := _acquire_player(_sfx_players, false)
	_configure_and_play(player, stream, volume_db, pitch)


func _play_ui(stream: AudioStream, volume_db: float, pitch: float) -> void:
	if not sfx_enabled or stream == null:
		return
	var player := _acquire_player(_ui_players, true)
	_configure_and_play(player, stream, volume_db, pitch)


func _configure_and_play(
	player: AudioStreamPlayer,
	stream: AudioStream,
	volume_db: float,
	pitch: float,
) -> void:
	player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch, 0.35, 2.5)
	player.play()
	played_event_count += 1


func _acquire_player(pool: Array[AudioStreamPlayer], ui_pool: bool) -> AudioStreamPlayer:
	for player: AudioStreamPlayer in pool:
		if not player.playing:
			return player
	var cursor := _ui_cursor if ui_pool else _sfx_cursor
	var selected := pool[cursor % pool.size()]
	if ui_pool:
		_ui_cursor = (cursor + 1) % pool.size()
	else:
		_sfx_cursor = (cursor + 1) % pool.size()
	return selected


func _create_pool(count: int, bus_name: StringName) -> Array[AudioStreamPlayer]:
	var pool: Array[AudioStreamPlayer] = []
	for player_index in range(count):
		var player := AudioStreamPlayer.new()
		player.name = "%sPlayer%02d" % [bus_name, player_index]
		player.bus = bus_name
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		pool.append(player)
	return pool


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _apply_bus_settings() -> void:
	for bus_name: StringName in [&"SFX", &"UI"]:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			continue
		AudioServer.set_bus_mute(bus_index, not sfx_enabled)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(sfx_volume, 0.0001)))
	var music_bus := AudioServer.get_bus_index(&"Music")
	if music_bus >= 0:
		AudioServer.set_bus_mute(music_bus, not music_enabled)
		AudioServer.set_bus_volume_db(
			music_bus,
			linear_to_db(maxf(music_volume, 0.0001)) - 14.0,
		)


func _create_ambient_loop() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AMBIENT_MIX_RATE
	stream.stereo = true
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var frame_count := AMBIENT_MIX_RATE * AMBIENT_DURATION_SECONDS
	stream.loop_begin = 0
	stream.loop_end = frame_count
	var data := PackedByteArray()
	data.resize(frame_count * 4)
	for frame_index in range(frame_count):
		var time := float(frame_index) / float(AMBIENT_MIX_RATE)
		var cycle := time / float(AMBIENT_DURATION_SECONDS)
		var breath := 0.62 + 0.18 * sin(TAU * cycle)
		var base := sin(TAU * 55.0 * time) * 0.055
		var fifth := sin(TAU * 82.5 * time + 0.35) * 0.032
		var shimmer := sin(TAU * 165.0 * time + sin(TAU * cycle) * 0.5) * 0.012
		var left_sample := clampf((base + fifth + shimmer) * breath, -1.0, 1.0)
		var right_sample := clampf((base + fifth - shimmer) * breath, -1.0, 1.0)
		data.encode_s16(frame_index * 4, int(left_sample * 32767.0))
		data.encode_s16(frame_index * 4 + 2, int(right_sample * 32767.0))
	stream.data = data
	return stream
