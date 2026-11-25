class_name BlockDamageResult
extends RefCounted

var block_id: int = -1
var block_type: int = -1
var contact_valid: bool = false
var damage_applied: bool = false
var destroyed: bool = false
var remaining_hit_points: int = 0
var damage_amount: int = 0
var is_explosion: bool = false
var is_echo: bool = false
var is_piercing: bool = false
var piercing_origin_cell := Vector2i(-1, -1)
var piercing_direction: int = BlockState.BeamDirection.NONE
var blocked_by_armor: bool = false

