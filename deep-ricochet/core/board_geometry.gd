class_name BoardGeometry
extends RefCounted

const BLOCK_GRID_SIZE := Vector2i(8, 8)
const WORLD_GRID_SIZE := Vector2i(8, 10)
const CORE_ROW := 8
const SCREEN_ORIGIN := Vector2(30.0, 150.0)
const WORLD_SCALE := 60.0
const LAUNCHER_WORLD := Vector2(4.0, 0.45)
const SCREEN_RECT := Rect2(SCREEN_ORIGIN, Vector2(WORLD_GRID_SIZE) * WORLD_SCALE)


static func world_to_screen(world_position: Vector2) -> Vector2:
	return SCREEN_ORIGIN + Vector2(
		world_position.x * WORLD_SCALE,
		(float(WORLD_GRID_SIZE.y) - world_position.y) * WORLD_SCALE,
	)


static func screen_to_world(screen_position: Vector2) -> Vector2:
	var local := (screen_position - SCREEN_ORIGIN) / WORLD_SCALE
	return Vector2(local.x, float(WORLD_GRID_SIZE.y) - local.y)


static func world_rect_to_screen(world_rect: Rect2, margin: float = 4.0) -> Rect2:
	var top_left := world_to_screen(world_rect.position + Vector2(0.0, world_rect.size.y))
	var size := world_rect.size * WORLD_SCALE
	return Rect2(top_left + Vector2.ONE * margin, size - Vector2.ONE * margin * 2.0)


static func preview_row_for_cell(cell_y: int) -> int:
	return clampi(WORLD_GRID_SIZE.y - 1 - cell_y, 0, WORLD_GRID_SIZE.y - 1)
