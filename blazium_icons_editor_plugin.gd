@tool
class_name BlaziumIconsEditor
extends EditorPlugin

const ICONS_PATH := "gui/theme/user_icons"
const DATA_PATH := "res://user_icons_data"
const LOADER_PATH := "res://user_icons_loader.gd"
const LOADER_SCRIPT := "extends Node


func _init() -> void:
	var icons: Dictionary = ProjectSettings.get_setting(\"%s\", {})
	for icon in icons:
		ThemeDB.add_user_icon(icon, icons[icon])

"

var icons_editor: Window
var user_icons := PackedStringArray()

static var singleton: BlaziumIconsEditor


func _enter_tree() -> void:
	if not ProjectSettings.has_setting(ICONS_PATH):
		ProjectSettings.set_setting(ICONS_PATH, {})
		ProjectSettings.save()

	if Engine.is_editor_hint():
		icons_editor = preload("./icons_editor.tscn").instantiate()
		icons_editor.hide()
		EditorInterface.get_base_control().add_child(icons_editor)
		add_tool_menu_item("Blazium Icons Editor", _show_icons_editor)
		ThemeDB.icons_changed.connect(_update_icons)

	update_generated_icons(ProjectSettings.get_setting(ICONS_PATH, {}))

	if not FileAccess.file_exists(LOADER_PATH):
		var file = FileAccess.open(LOADER_PATH, FileAccess.WRITE)
		file.store_string(LOADER_SCRIPT % ICONS_PATH)
		file.close()
		EditorInterface.get_resource_filesystem().scan.call_deferred()

	add_autoload_singleton.call_deferred("UserIconsLoader", LOADER_PATH)
	singleton = self


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		remove_tool_menu_item("Blazium Icons Editor")
		EditorInterface.get_base_control().remove_child(icons_editor)
		icons_editor.free()
		icons_editor = null
		ThemeDB.icons_changed.disconnect(_update_icons)
		clear_user_icons()

	remove_autoload_singleton("UserIconsLoader")
	singleton = null


func _update_icons():
	icons_editor.update_selected_icons()


func _show_icons_editor():
	if Engine.is_editor_hint():
		if icons_editor.visible:
			icons_editor.grab_focus()
		else:
			icons_editor.show()


func clear_user_icons():
	for user_icon in user_icons:
		ThemeDB.remove_user_icon(user_icon)
	user_icons.clear()


func update_generated_icons(generated_icons: Dictionary):
	ProjectSettings.set_setting(ICONS_PATH, generated_icons)
	ProjectSettings.save()
	clear_user_icons()
	for icon_name in generated_icons:
		user_icons.append(icon_name)
		ThemeDB.add_user_icon(icon_name, generated_icons[icon_name])
	ThemeDB.icons_changed.emit()
