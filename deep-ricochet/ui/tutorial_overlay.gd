class_name TutorialOverlay
extends Control

const TouchControlsScript := preload("res://ui/touch_controls.gd")

enum Mode {
	WALKTHROUGH,
	COACH,
}

const VIEW_SIZE := Vector2(540.0, 960.0)
const SKIP_BUTTON := Rect2(35.0, 845.0, 170.0, 65.0)
const NEXT_BUTTON := Rect2(275.0, 845.0, 230.0, 65.0)
const PAGE_COUNT := 9
const COACH_PAGE_BY_STEP := [0, 1, 8]
const NORMAL_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_normal.png")
const ORE_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_cevher.png")
const CORE_TEXTURE: Texture2D = preload("res://assets/images/blocks/cekirdek.png")
const CRACKED_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_catlak.png")
const EXPLOSIVE_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_patlayici.png")
const ARMORED_BOTTOM_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_zirhli_alt.png")
const ARMORED_LEFT_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_zirhli_sol_alt.png")
const ARMORED_RIGHT_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_zirhli_sag_alt.png")
const ECHO_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_yanki.png")
const BALL_CACHE_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_top_haznesi.png")
const PIERCING_TEXTURE: Texture2D = preload("res://assets/images/blocks/blok_delici_kristal.png")
const NORMAL_SOURCE_RECT := Rect2(139.0, 159.0, 976.0, 939.0)
const ORE_SOURCE_RECT := Rect2(209.0, 220.0, 837.0, 831.0)
const CRACKED_SOURCE_RECT := Rect2(32.0, 36.0, 447.0, 454.0)
const EXPLOSIVE_SOURCE_RECT := Rect2(54.0, 65.0, 404.0, 407.0)
const ARMORED_SOURCE_RECT := Rect2(5.0, 6.0, 502.0, 502.0)
const ARMORED_LEFT_SOURCE_RECT := Rect2(5.0, 5.0, 503.0, 503.0)
const ARMORED_RIGHT_SOURCE_RECT := Rect2(4.0, 5.0, 503.0, 503.0)
const ACTION_SKIP := &"skip"
const ACTION_NEXT := &"next"

var controller: RunController
var page_index := 0
var mode: Mode = Mode.WALKTHROUGH
var touch_controls = TouchControlsScript.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind(run_controller: RunController) -> void:
	controller = run_controller


func show_tutorial() -> void:
	mode = Mode.WALKTHROUGH
	page_index = 0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func show_coach(step: int) -> void:
	mode = Mode.COACH
	var coach_step := clampi(step, 0, COACH_PAGE_BY_STEP.size() - 1)
	page_index = COACH_PAGE_BY_STEP[coach_step]
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func is_modal() -> bool:
	return visible and mode == Mode.WALKTHROUGH


func hide_overlay() -> void:
	touch_controls.reset()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh_locale() -> void:
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if mode == Mode.COACH:
		return
	if not TouchControlsScript.handles(event) or DeepUI.is_emulated_mouse_event(event):
		return
	accept_event()
	var action: StringName = touch_controls.process(event, {
		ACTION_SKIP: SKIP_BUTTON,
		ACTION_NEXT: NEXT_BUTTON,
	})
	if touch_controls.changed:
		queue_redraw()
	if action.is_empty() or controller == null:
		return
	if action == ACTION_SKIP:
		AudioManager.play_ui_click()
		controller.complete_tutorial()
	elif action == ACTION_NEXT:
		AudioManager.play_ui_click()
		if page_index >= PAGE_COUNT - 1:
			controller.complete_tutorial()
		else:
			page_index += 1
			queue_redraw()


func _draw() -> void:
	if mode == Mode.COACH:
		_draw_coach()
		return
	DeepUI.draw_cave_background(self, VIEW_SIZE)
	DeepUI.draw_panel(self, Rect2(35.0, 60.0, 470.0, 755.0), Color(DeepUI.PANEL_SOFT, 0.96), DeepUI.BORDER, 22, 2, true)
	_draw_illustration()
	DeepUI.draw_title_plate(
		self,
		tr("TUTORIAL_TITLE_%d" % (page_index + 1)),
		Rect2(62.0, 492.0, 416.0, 64.0),
		27,
		DeepUI.GOLD,
	)
	DeepUI.draw_wrapped(
		self,
		tr("TUTORIAL_BODY_%d" % (page_index + 1)),
		Rect2(55.0, 585.0, 430.0, 125.0),
		18,
		DeepUI.MUTED,
	)
	var dot_start_x := 270.0 - float(PAGE_COUNT - 1) * 10.0
	for dot_index in range(PAGE_COUNT):
		var dot_color := DeepUI.GOLD if dot_index == page_index else DeepUI.BORDER
		draw_circle(Vector2(dot_start_x + float(dot_index) * 20.0, 775.0), 5.0, dot_color)
	DeepUI.draw_button(
		self, SKIP_BUTTON, tr("TUTORIAL_SKIP"), &"ghost", 19, true,
		touch_controls.is_pressed(ACTION_SKIP),
	)
	var next_label := tr("TUTORIAL_START") if page_index == PAGE_COUNT - 1 else tr("TUTORIAL_NEXT")
	DeepUI.draw_button(
		self, NEXT_BUTTON, next_label, &"primary", 19, true,
		touch_controls.is_pressed(ACTION_NEXT),
	)


func _draw_coach() -> void:
	DeepUI.draw_panel(
		self,
		Rect2(24.0, 858.0, 492.0, 82.0),
		Color(DeepUI.PANEL_SOFT, 0.97),
		DeepUI.GOLD,
		14,
		2,
		true,
	)
	DeepUI.draw_centered(
		self,
		tr("TUTORIAL_TITLE_%d" % (page_index + 1)),
		Rect2(38.0, 866.0, 464.0, 24.0),
		16,
		DeepUI.GOLD_LIGHT,
	)
	DeepUI.draw_wrapped(
		self,
		tr("TUTORIAL_BODY_%d" % (page_index + 1)),
		Rect2(38.0, 892.0, 464.0, 38.0),
		13,
		DeepUI.TEXT,
	)


func _draw_illustration() -> void:
	DeepUI.draw_panel(self, Rect2(55.0, 90.0, 430.0, 360.0), DeepUI.PANEL, DeepUI.BORDER_SOFT, 16, 2, false)
	match page_index:
		0:
			var launcher := Vector2(270.0, 385.0)
			draw_circle(launcher, 14.0, DeepUI.TEXT)
			draw_dashed_line(launcher, Vector2(175.0, 180.0), DeepUI.GOLD_LIGHT, 4.0, 12.0)
			draw_circle(Vector2(175.0, 180.0), 9.0, DeepUI.GOLD)
		1:
			_draw_asset_block(
				NORMAL_TEXTURE,
				NORMAL_SOURCE_RECT,
				Rect2(100.0, 270.0, 105.0, 105.0),
				"3",
				BlockState.BlockType.NORMAL,
			)
			_draw_asset_block(
				ORE_TEXTURE,
				ORE_SOURCE_RECT,
				Rect2(218.0, 270.0, 105.0, 105.0),
				"5",
				BlockState.BlockType.ORE,
			)
			CaveTheme.draw_texture(
				self,
				CORE_TEXTURE,
				Rect2(335.0, 269.0, 106.0, 106.0),
				BlockState.BlockType.CORE,
			)
			DeepUI.draw_centered(self, "6", Rect2(335.0, 290.0, 105.0, 55.0), 25, DeepUI.TEXT)
		2:
			_draw_hard_rock(Rect2(125.0, 230.0, 120.0, 120.0))
			_draw_asset_block(
				CRACKED_TEXTURE,
				CRACKED_SOURCE_RECT,
				Rect2(295.0, 230.0, 120.0, 120.0),
				"8",
				BlockState.BlockType.CRACKED,
			)
		3:
			var blast_origin := Vector2(175.0, 155.0)
			var blast_cell := 38.0
			for blast_y in range(5):
				for blast_x in range(5):
					var blast_rect := Rect2(
						blast_origin + Vector2(blast_x, blast_y) * blast_cell,
						Vector2.ONE * (blast_cell - 2.0),
					)
					draw_rect(blast_rect, Color(DeepUI.DANGER, 0.16), true)
					draw_rect(blast_rect, Color(DeepUI.GOLD, 0.28), false, 1.0)
			_draw_asset_block(
				EXPLOSIVE_TEXTURE,
				EXPLOSIVE_SOURCE_RECT,
				Rect2(222.0, 202.0, 96.0, 96.0),
				"5",
				BlockState.BlockType.EXPLOSIVE,
			)
		4:
			_draw_asset_block(
				ARMORED_LEFT_TEXTURE,
				ARMORED_LEFT_SOURCE_RECT,
				Rect2(100.0, 255.0, 105.0, 105.0),
				"6",
				BlockState.BlockType.ARMORED,
			)
			_draw_asset_block(
				ARMORED_BOTTOM_TEXTURE,
				ARMORED_SOURCE_RECT,
				Rect2(218.0, 255.0, 105.0, 105.0),
				"6",
				BlockState.BlockType.ARMORED,
			)
			_draw_asset_block(
				ARMORED_RIGHT_TEXTURE,
				ARMORED_RIGHT_SOURCE_RECT,
				Rect2(335.0, 255.0, 105.0, 105.0),
				"6",
				BlockState.BlockType.ARMORED,
			)
		5:
			_draw_full_asset_block(
				ECHO_TEXTURE,
				Rect2(120.0, 238.0, 118.0, 118.0),
				"6",
				BlockState.BlockType.ECHO,
			)
			_draw_full_asset_block(
				ECHO_TEXTURE,
				Rect2(302.0, 238.0, 118.0, 118.0),
				"6",
				BlockState.BlockType.ECHO,
			)
			for ring_index in range(3):
				draw_arc(
					Vector2(270.0, 297.0),
					45.0 + float(ring_index) * 20.0,
					0.0,
					TAU,
					28,
					Color(CaveTheme.block_color(BlockState.BlockType.ECHO), 0.42 - float(ring_index) * 0.1),
					2.5,
					true,
				)
		6:
			_draw_full_asset_block(
				BALL_CACHE_TEXTURE,
				Rect2(118.0, 220.0, 125.0, 125.0),
				"4",
				BlockState.BlockType.BALL_CACHE,
			)
			draw_line(Vector2(258.0, 282.0), Vector2(320.0, 282.0), DeepUI.GOLD_LIGHT, 4.0, true)
			draw_colored_polygon(PackedVector2Array([
				Vector2(320.0, 270.0), Vector2(340.0, 282.0), Vector2(320.0, 294.0),
			]), DeepUI.GOLD_LIGHT)
			for ball_index in range(2):
				var ball_center := Vector2(370.0 + float(ball_index) * 34.0, 282.0)
				draw_circle(ball_center, 13.0, DeepUI.TEXT)
				draw_arc(ball_center, 13.0, 0.0, TAU, 20, CaveTheme.block_color(BlockState.BlockType.ECHO), 2.0, true)
			DeepUI.draw_centered(self, "+2", Rect2(338.0, 318.0, 100.0, 40.0), 24, DeepUI.GOLD_LIGHT)
		7:
			_draw_full_asset_block(
				PIERCING_TEXTURE,
				Rect2(211.0, 270.0, 118.0, 118.0),
				"7",
				BlockState.BlockType.PIERCING,
			)
			var beam_color := CaveTheme.block_color(BlockState.BlockType.PIERCING).lightened(0.3)
			draw_line(Vector2(270.0, 270.0), Vector2(270.0, 125.0), Color(beam_color, 0.25), 13.0, true)
			draw_line(Vector2(270.0, 270.0), Vector2(270.0, 125.0), beam_color, 4.0, true)
			_draw_hard_rock(Rect2(223.0, 138.0, 44.0, 44.0))
			_draw_asset_block(
				ORE_TEXTURE,
				ORE_SOURCE_RECT,
				Rect2(273.0, 138.0, 44.0, 44.0),
				"5",
				BlockState.BlockType.ORE,
			)
		8:
			DeepUI.draw_panel(self, Rect2(80.0, 155.0, 175.0, 225.0), Color("173550"), DeepUI.BLUE, 15, 2, true)
			DeepUI.draw_panel(self, Rect2(285.0, 155.0, 175.0, 225.0), Color("4a3923"), DeepUI.GOLD, 15, 2, true)
			DeepUI.draw_centered(self, "×1.0", Rect2(90.0, 195.0, 155.0, 50.0), 25, DeepUI.BLUE_LIGHT)
			DeepUI.draw_centered(self, "×1.5", Rect2(295.0, 195.0, 155.0, 50.0), 25, DeepUI.GOLD)
			DeepUI.draw_centered(self, tr("ROUTE_SAFE"), Rect2(90.0, 300.0, 155.0, 45.0), 17, DeepUI.TEXT)
			DeepUI.draw_centered(self, tr("ROUTE_BONUS"), Rect2(295.0, 300.0, 155.0, 45.0), 17, DeepUI.TEXT)


func _draw_asset_block(
	texture: Texture2D,
	source_rect: Rect2,
	destination: Rect2,
	value: String,
	block_type: int,
) -> void:
	CaveTheme.draw_texture_region(self, texture, destination, source_rect, block_type)
	if not value.is_empty():
		DeepUI.draw_centered(self, value, destination, 25, DeepUI.TEXT, 0.66)


func _draw_hard_rock(rect: Rect2) -> void:
	CaveTheme.draw_hard_rock(self, rect)


func _draw_full_asset_block(
	texture: Texture2D,
	destination: Rect2,
	value: String,
	block_type: int,
) -> void:
	CaveTheme.draw_texture(self, texture, destination, block_type)
	if not value.is_empty():
		DeepUI.draw_centered(self, value, destination, 25, DeepUI.TEXT, 0.69)
