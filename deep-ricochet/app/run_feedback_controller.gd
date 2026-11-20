extends RefCounted

const HAPTIC_COOLDOWN_MSEC := 90

var last_haptic_tick_msec := -HAPTIC_COOLDOWN_MSEC


func on_block_destroyed(controller, block_type: int) -> void:
	if controller.app_settings == null:
		return
	var is_core := block_type == BlockState.BlockType.CORE
	var is_explosive := block_type == BlockState.BlockType.EXPLOSIVE
	if controller.app_settings.haptics_enabled:
		try_haptic(70 if is_core else (45 if is_explosive else 20))
	if not controller.app_settings.shake_enabled:
		return
	var quality_scale := 1.0 \
		if controller.app_settings.quality_mode == AppSettings.QualityMode.GRAPHICS else 0.55
	controller.gameplay_room.trigger_screen_shake(
		(7.0 if is_core else (5.0 if is_explosive else 3.0)) * quality_scale,
		(0.26 if is_core else (0.2 if is_explosive else 0.14)) * quality_scale,
	)


func apply_quality_mode(controller) -> void:
	if controller.app_settings == null:
		return
	DeepUI.set_high_quality(
		controller.app_settings.quality_mode == AppSettings.QualityMode.GRAPHICS
	)
	if is_instance_valid(controller.gameplay_room):
		controller.gameplay_room.set_quality_mode(controller.app_settings.quality_mode)
	if is_instance_valid(controller.main_menu_view):
		controller.main_menu_view.queue_redraw()
	if is_instance_valid(controller.flow_view):
		controller.flow_view.queue_redraw()


func apply_color_theme(controller) -> void:
	if controller.app_settings == null \
		or not CaveTheme.set_current_theme(controller.app_settings.color_theme):
		return
	if is_instance_valid(controller.gameplay_room):
		controller.gameplay_room.refresh_locale()
	for view: CanvasItem in [
		controller.main_menu_view,
		controller.mine_select_view,
		controller.pause_overlay,
		controller.settings_overlay,
		controller.tutorial_overlay,
		controller.flow_view,
	]:
		if is_instance_valid(view):
			view.queue_redraw()


func try_haptic(duration_msec: int) -> void:
	if not OS.has_feature("android"):
		return
	var now_msec := Time.get_ticks_msec()
	if now_msec - last_haptic_tick_msec < HAPTIC_COOLDOWN_MSEC:
		return
	last_haptic_tick_msec = now_msec
	Input.vibrate_handheld(duration_msec)
