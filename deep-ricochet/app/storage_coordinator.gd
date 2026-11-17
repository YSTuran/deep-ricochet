extends RefCounted


func save_profile(controller) -> void:
	if controller.profile_service == null:
		return
	if controller.profile_service.save_profile(controller.profile):
		mark_write_succeeded(controller, &"profile")
	else:
		report_error(controller, controller.profile_service.last_error, &"profile")


func save_settings(controller) -> void:
	if controller.settings_service == null:
		return
	if controller.settings_service.save_settings(controller.app_settings):
		mark_write_succeeded(controller, &"settings")
	else:
		report_error(controller, controller.settings_service.last_error, &"settings")


func save_stable(controller) -> void:
	if not controller.persistence_enabled or controller.save_service == null:
		return
	var snapshot: RunSnapshot = controller.create_snapshot()
	if controller.save_service.save_stable(snapshot):
		mark_write_succeeded(controller, &"run")
	else:
		report_error(controller, controller.save_service.last_error, &"run")


func report_error(
	controller,
	error_message: String = "",
	channel: StringName = &"run",
) -> void:
	controller.last_save_error = error_message
	if controller.last_save_error.is_empty():
		controller.last_save_error = controller.save_service.last_error \
			if controller.save_service != null else "Kayıt servisi hazır değil."
	push_warning("Yerel veri yazılamadı: %s" % controller.last_save_error)
	var failure_episode_active: bool = not controller.failed_storage_channels.is_empty()
	controller.failed_storage_channels[channel] = true
	if failure_episode_active:
		return
	if is_instance_valid(controller.storage_notice):
		controller.storage_notice.show_notice(controller.tr("NOTICE_STORAGE_FAILED"))


func mark_write_succeeded(controller, channel: StringName) -> void:
	controller.failed_storage_channels.erase(channel)


func clear_failure_state(controller) -> void:
	controller.failed_storage_channels.clear()
	if is_instance_valid(controller.storage_notice):
		controller.storage_notice.hide_notice()
