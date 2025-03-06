@tool
extends Window

const ICONS_DIR := "res://addons/blazium_icons_editor/icons/filled"

var def_theme := ThemeDB.get_default_theme()

@onready var icons_container: HFlowContainer = $"%IconsContainer"
@onready var selected_container: HFlowContainer = $"%SelectedContainer"
@onready var selected_scroll: ScrollContainer = $"%SelectedScroll"
@onready var search_box: LineEdit = $"%SearchBox"
@onready var icon_preview: TextureRect = $"%IconPreview"
@onready var icon_label: Label = $"%IconLabel"
@onready var use_accent_color: Button = $"%AccentColorButton"
@onready var use_font_color: Button = $"%FontColorButton"
@onready var use_custom_color: Button = $"%CustomColorButton"
@onready var color_picker_button: ColorPickerButton = $"%ColorPickerButton"
@onready var save_button: Button = $"%SaveButton"
@onready var size_spinbox: SpinBox = $"%SizeSpinBox"
@onready var size_slider: HSlider = $"%SizeSlider"
@onready var icons_menu: MenuButton = $"%IconsMenu"
@onready var use_small_icons_button: Button = $"%UseSmallIconsButton"

@onready var settings_window: Window = $"%SettingsWindow"
@onready var settings_size_spinbox: SpinBox = $"%SettingsSizeSpinBox"
@onready var settings_size_slider: HSlider = $"%SettingsSizeSlider"
@onready var settings_font_color_button: Button = $"%SettingsFontColorButton"
@onready var settings_accent_color_button: Button = $"%SettingsAccentColorButton"
@onready var settings_custom_color_button: Button = $"%SettingsCustomColorButton"
@onready var settings_color_picker_button: ColorPickerButton = $"%SettingsColorPickerButton"
@onready var settings_save_button: Button = $"%SettingsSaveButton"


var selected_icons := {}
var generated_icons := {}
var cfg := ConfigFile.new()
var default_size := 32
var default_color := "red"
var small_icons := true

var selected: IconButton:
	set(value):
		selected = value
		if selected:
			_update_icon()
			icon_label.text = selected.tooltip_text
			if not selected.has_focus():
				selected.grab_focus()


func _update_icon():
	if not selected:
		return
	if selected.color in ["#0f0", "red"]:
		var col_str: String = "font" if selected.color == "red" else "accent"
		var col := def_theme.get_color("%s_color" % col_str, "Colors")
		icon_preview.texture = selected.generate_texture("#%s" % col.to_html(false), selected.icon_size, 2)
	else:
		icon_preview.texture = selected.generate_texture(selected.color, selected.icon_size, 2)


func _reload_icons():
	var selected_idx := 0
	if selected:
		selected_idx = selected.get_index()
	selected = null

	for icon_button: IconButton in icons_container.get_children():
		icons_container.remove_child(icon_button)
		icon_button.free()

	for child: TextureRect in selected_container.get_children():
			selected_container.remove_child(child)
			child.free()

	generated_icons.clear()

	var icons_dir := DirAccess.open(ProjectSettings.globalize_path(ICONS_DIR))
	var sources = icons_dir.get_files()

	for icon_file in sources:
		var source = FileAccess.get_file_as_string(ICONS_DIR.path_join(icon_file))
		var icon_button := IconButton.new(icon_file, source, default_size, default_color)
		icons_container.add_child(icon_button)
		icon_button.focus_entered.connect(_on_icon_selected.bind(icon_button.get_index()))
		if selected_icons.has(icon_file):
			icon_button.icon_size = selected_icons[icon_file][0]
			icon_button.color = selected_icons[icon_file][1]
			icon_button.set_pressed_no_signal(true)
			generated_icons[icon_button.tooltip_text] = icon_button.get_generated_source()
			_add_to_selected_icons(icon_button)

	if selected_idx < icons_container.get_child_count():
		selected = icons_container.get_child(selected_idx)
	ThemeDB.icons_changed.emit()


func _update_generated_icons():
	for child: TextureRect in selected_container.get_children():
		selected_container.remove_child(child)
		child.free()
	selected_icons.clear()
	generated_icons.clear()
	for child: IconButton in icons_container.get_children():
		if not child.button_pressed:
			continue
		generated_icons[child.tooltip_text] = child.get_generated_source()
		_add_to_selected_icons(child)
	BlaziumIconsEditor.singleton.update_generated_icons(generated_icons)


func _ready() -> void:
	if is_part_of_edited_scene():
		return
	if FileAccess.file_exists(BlaziumIconsEditor.singleton.DATA_PATH):
		cfg.load(BlaziumIconsEditor.singleton.DATA_PATH)
		default_size = cfg.get_value("data", "default_size", 32) as int
		default_color = cfg.get_value("data", "default_color", "red") as String
		small_icons = cfg.get_value("data", "use_small_icons", true) as bool
		selected_icons = cfg.get_value("data", "selected_icons", {}) as Dictionary
	else:
		cfg.set_value("data", "default_size", 32)
		cfg.set_value("data", "default_color", "red")
		cfg.set_value("data", "use_small_icons", true)
		cfg.set_value("data", "selected_icons", selected_icons)
		save()
	use_small_icons_button.button_pressed = small_icons
	use_small_icons_button.toggled.connect(_on_small_icons_toggled)
	save_button.pressed.connect(_on_save_button_pressed)
	search_box.right_icon = get_editor_icon("Search")
	use_font_color.toggled.connect(_on_color_button_toggled.bind(0))
	use_accent_color.toggled.connect(_on_color_button_toggled.bind(1))
	use_custom_color.toggled.connect(_on_color_button_toggled.bind(2))
	color_picker_button.color_changed.connect(_on_custom_color_changed)
	close_requested.connect(hide)
	size_spinbox.share(size_slider)
	size_spinbox.value_changed.connect(_change_icon_size)
	search_box.text_changed.connect(_filter_icons)
	icon_label.gui_input.connect(on_icon_label_gui_input)
	icons_menu.icon = get_editor_icon("GuiTabMenuHl")
	icons_menu.get_popup().index_pressed.connect(_on_menu_item_index_pressed)
	settings_window.close_requested.connect(_on_settings_window_close_requested)
	_reload_icons()
	icons_container.get_child(0).grab_focus()
	settings_size_spinbox.share(settings_size_slider)
	settings_save_button.pressed.connect(_save_settings)
	var pnl: Panel = get_child(0) as Panel
	pnl.add_theme_stylebox_override("panel", get_editor_style("PanelForeground"))
	var settings_pnl: Panel = settings_window.get_child(0) as Panel
	settings_pnl.add_theme_stylebox_override("panel", get_editor_style("PanelForeground"))
	selected_scroll.get_theme_stylebox("panel").border_color = EditorInterface.get_editor_theme().get_color("font_color", "Label")
	use_small_icons_button.icon = get_editor_icon("CenterView")


func _on_small_icons_toggled(enabled: bool):
	if small_icons == enabled:
		return

	small_icons = enabled
	cfg.set_value("data", "use_small_icons", small_icons)
	save()
	var new_size = Vector2(32, 32) if small_icons else Vector2(64, 64)
	for selected: SelectedIcon in selected_container.get_children():
		selected.custom_minimum_size = new_size


func _on_menu_item_index_pressed(idx: int):
	var item_text = icons_menu.get_popup().get_item_text(idx)
	if item_text.is_empty():
		return

	match item_text:
		"Reload All Icons":
			_reload_icons()
		"Settings":
			_update_settings_window()
			settings_window.show()
		_:
			print(item_text)


func _update_settings_window():
	settings_size_spinbox.value = default_size
	match default_color:
		"red":
			settings_font_color_button.button_pressed = true
		"#0f0":
			settings_accent_color_button.button_pressed = true
		_:
			settings_custom_color_button.button_pressed = true
			settings_color_picker_button.color = Color(default_color)


func _save_settings():
	var prev_size := default_size
	var prev_color := default_color
	default_size = settings_size_spinbox.value
	if settings_font_color_button.button_pressed:
		default_color = "red"
	elif settings_accent_color_button.button_pressed:
		default_color = "#0f0"
	else:
		default_color = "#" + settings_color_picker_button.color.to_html(false)
	if prev_size != default_size or prev_color != default_color:
		_reload_icons()
		cfg.set_value("data", "default_size", default_size)
		cfg.set_value("data", "default_color", default_color)
		save()


func save():
	var path := BlaziumIconsEditor.singleton.DATA_PATH
	var err = cfg.save(path)
	if err != OK:
		print("Failed saving icons data to path: %s" % path)
		return
	EditorInterface.get_resource_filesystem().scan.call_deferred()


func _on_settings_window_close_requested():
	settings_window.hide()


func _on_custom_color_changed(col: Color):
	if not selected:
		return
	if not use_custom_color.button_pressed:
		return
	selected.color = "#" + col.to_html(false)
	_update_icon()


func get_editor_icon(icon_name: String) -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(icon_name, "EditorIcons")


func get_editor_style(style_name: String) -> StyleBox:
	return EditorInterface.get_editor_theme().get_stylebox(style_name, "EditorStyles")


func _filter_icons(new_text: String):
	new_text = new_text.to_lower().replace(" ", "_")
	if new_text.is_empty():
		for child: IconButton in icons_container.get_children():
			child.show()
		return
	for child: IconButton in icons_container.get_children():
		child.visible = child.tooltip_text.contains(new_text)


func _focus_icon(idx: int, copy: bool):
	icons_container.get_child(idx).grab_focus()
	if copy:
		copy_to_clipboard(selected.tooltip_text)


func _change_icon_size(new_size: float):
	if not selected:
		return
	selected.icon_size = new_size
	_update_icon()


func _on_icon_selected(idx: int):
	selected = icons_container.get_child(idx)
	match selected.color:
		"red":
			use_font_color.set_pressed(true)
		"#0f0":
			use_accent_color.set_pressed(true)
		_:
			use_custom_color.set_pressed(true)
			color_picker_button.color = Color(selected.color)
	size_spinbox.set_value_no_signal(selected.icon_size)


func _on_save_button_pressed():
	_update_generated_icons()
	cfg.set_value("data", "selected_icons", selected_icons)
	save()
	ThemeDB.icons_changed.emit()
	print(ThemeDB.get_user_icon_list())


func update_selected_icons():
	for child: TextureRect in selected_container.get_children():
		child.texture = ThemeDB.get_user_icon(child.tooltip_text)
	_update_icon.call_deferred()


func _add_to_selected_icons(selected: IconButton):
	selected_icons[selected.tooltip_text] = [selected.icon_size, selected.color]
	var preview_size = Vector2(32, 32) if small_icons else Vector2(64, 64)
	var tex := SelectedIcon.new(selected.get_index(), preview_size)
	tex.select_icon.connect(_focus_icon)
	tex.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tex.tooltip_text = selected.tooltip_text
	selected_container.add_child(tex)


func _on_color_button_toggled(enabled: bool, idx: int):
	if not selected:
		return
	if not enabled:
		return
	match idx:
		0:
			selected.color = "red"
			color_picker_button.disabled = true
		1:
			selected.color = "#0f0"
			color_picker_button.disabled = true
		2:
			selected.color = "#" + color_picker_button.color.to_html(false)
			color_picker_button.disabled = false
	_update_icon()


func on_icon_label_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return
	if event.is_pressed():
		copy_to_clipboard(icon_label.text)


func copy_to_clipboard(text: String):
	if text.is_empty():
		return
	DisplayServer.clipboard_set(text)
	print("Copied %s to clipboard" % text)


class SelectedIcon extends TextureRect:
	signal select_icon(icon_index: int, copy: bool)

	var idx := -1


	func _gui_input(event: InputEvent) -> void:
		if not event is InputEventMouseButton:
			return
		if not event.is_pressed():
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			select_icon.emit(idx, false)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			select_icon.emit(idx, true)


	func _init(_idx: int, icon_size := Vector2(32, 32)) -> void:
		idx = _idx
		custom_minimum_size = icon_size
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE


class IconButton extends Button:
	var source := ""
	# font_color = "red", accent_color = "#0f0", custom_color = "#any"
	var color := "red"
	var icon_size := 24


	func _init(icon_name: String, icon_source: String, default_size := 32, default_color := "red") -> void:
		name = icon_name.capitalize()
		toggle_mode = true
		tooltip_text = icon_name
		icon_size = default_size
		color = default_color
		var pos := icon_source.findn("\"0 0 24 24\"")
		var new_str = "width=\"%d\" height=\"%d\""
		icon_source = icon_source.replacen("width=\"24\" height=\"24\"", new_str)
		icon_source = icon_source.insert(pos + 11, " fill=\"%s\"")
		source = icon_source
		icon = generate_texture("white", 24, 2)


	func _gui_input(event: InputEvent) -> void:
		if not event is InputEventMouseButton:
			return
		if not (event.button_index == MOUSE_BUTTON_RIGHT and event.is_pressed()):
			return
		grab_focus()


	func generate_texture(fill_color: String, base_size: int, scale: float) -> ImageTexture:
		var icon_source = source % [base_size, base_size, fill_color]
		var img := Image.new()
		img.load_svg_from_string(icon_source, scale)
		img.fix_alpha_edges()
		return ImageTexture.create_from_image(img)


	func get_generated_source() -> String:
		return source % [icon_size, icon_size, color]
