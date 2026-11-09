class_name RoomResolution
extends RefCounted

var processed: bool = false
var room_finished: bool = false
var succeeded: bool = false
var break_score: int = 0
var remaining_shots: int = 0
var multiplier_bps: int = 10_000
var unused_shot_bonus: int = 0
var reward: int = 0
var scored_block_ids := PackedInt32Array()

