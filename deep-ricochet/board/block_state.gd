class_name BlockState
extends RefCounted

enum BlockType {
	NORMAL,
	ORE,
	ROCK,
	CORE,
	EXPLOSIVE,
	CRACKED,
	ARMORED,
	ECHO,
	BALL_CACHE,
	PIERCING,
	ACID_BARREL,
}

enum BeamDirection {
	NONE,
	UP,
	RIGHT,
	DOWN,
	LEFT,
}

enum VulnerableSide {
	LEFT = 1,
	RIGHT = 2,
	TOP = 4,
	BOTTOM = 8,
}

const ALL_VULNERABLE_SIDES := VulnerableSide.LEFT \
	| VulnerableSide.RIGHT \
	| VulnerableSide.TOP \
	| VulnerableSide.BOTTOM

var id: int
var type: BlockType
var cell: Vector2i
var hit_points: int
var vulnerable_sides: int
var beam_direction: BeamDirection


func _init(
	block_id: int = 0,
	block_type: BlockType = BlockType.NORMAL,
	block_cell: Vector2i = Vector2i.ZERO,
	initial_hit_points: int = 1,
	initial_vulnerable_sides: int = ALL_VULNERABLE_SIDES,
	initial_beam_direction: BeamDirection = BeamDirection.NONE,
) -> void:
	id = block_id
	type = block_type
	cell = block_cell
	hit_points = initial_hit_points
	vulnerable_sides = initial_vulnerable_sides
	beam_direction = initial_beam_direction


func is_breakable() -> bool:
	return type != BlockType.ROCK


func apply_damage(amount: int = 1) -> bool:
	if not is_breakable() or amount <= 0:
		return false
	hit_points = maxi(0, hit_points - amount)
	return true


func apply_contact_damage(amount: int, contact_normal: Vector2) -> bool:
	if type == BlockType.ARMORED and not accepts_contact(contact_normal):
		return false
	return apply_damage(amount)


func accepts_contact(contact_normal: Vector2) -> bool:
	if type != BlockType.ARMORED:
		return true
	var side := vulnerable_side_for_contact(contact_normal)
	return side != 0 and (vulnerable_sides & side) != 0


static func vulnerable_side_for_contact(contact_normal: Vector2) -> int:
	if contact_normal.is_zero_approx():
		return 0
	if absf(contact_normal.x) > absf(contact_normal.y):
		return VulnerableSide.LEFT if contact_normal.x < 0.0 else VulnerableSide.RIGHT
	# Dünya koordinatının +Y yönü ekranda yukarıya çizilir.
	return VulnerableSide.BOTTOM if contact_normal.y < 0.0 else VulnerableSide.TOP


func is_destroyed() -> bool:
	return is_breakable() and hit_points <= 0


func world_rect() -> Rect2:
	return Rect2(Vector2(float(cell.x), float(cell.y)), Vector2.ONE)


func collision_center_world() -> Vector2:
	# Görsel efektlerin ve çizimin merkezidir. Fizik alanı world_rect() ile karedir.
	return world_rect().get_center()


static func beam_vector(direction: BeamDirection) -> Vector2i:
	match direction:
		BeamDirection.UP:
			return Vector2i.DOWN
		BeamDirection.RIGHT:
			return Vector2i.RIGHT
		BeamDirection.DOWN:
			return Vector2i.UP
		BeamDirection.LEFT:
			return Vector2i.LEFT
	return Vector2i.ZERO


static func opposite_beam_direction(direction: BeamDirection) -> BeamDirection:
	match direction:
		BeamDirection.UP:
			return BeamDirection.DOWN
		BeamDirection.RIGHT:
			return BeamDirection.LEFT
		BeamDirection.DOWN:
			return BeamDirection.UP
		BeamDirection.LEFT:
			return BeamDirection.RIGHT
	return BeamDirection.NONE
