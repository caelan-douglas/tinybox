# Tinybox
# Copyright (C) 2023-present Caelan Douglas
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

extends CanvasLayer
class_name MultiplayerMenu

@onready var preview_player : RigidPlayer = Global.get_world().get_current_map().get_node("Camera3D/RigidPlayer")

func _ready() -> void:
	Global.connect("appearance_changed", preview_player.change_appearance)
	$SettingsMenu/Graphics.connect("pressed", toggle_graphics_presets)
	$MainMenu/LeftColumn/MultiplayerSettings/MultiplayerSettingsContainer/Appearance.connect("pressed", show_appearance_settings)
	# play hair swing animation on new hair selected
	#$AppearanceMenu/HairPanel/HairPanelContainer/Picker.connect("item_selected", play_preview_character_appearance_animation)
	$AppearanceMenu/HBoxContainer/Back.connect("pressed", hide_appearance_settings)
	$MainMenu/LeftColumn/Settings.connect("pressed", show_settings)
	$SettingsMenu/Keybinds.connect("pressed", show_keybinds)
	$MainMenu/LeftColumn/Quit.connect("pressed", quit)
	$SettingsMenu/HBoxContainer/Back.connect("pressed", hide_settings)
	$KeybindsMenu/HBoxContainer/Back.connect("pressed", hide_keybinds)
	
	# Appearance settings
	var hair_colour_picker : Control = $AppearanceMenu/HairPanel/HairPanelContainer/ColorPickerButton
	hair_colour_picker.connect("color_changed", Global.set_hair_colour)
	var shirt_colour_picker : Control = $AppearanceMenu/ShirtPanel/ShirtPanelContainer/ColorPickerButton
	shirt_colour_picker.connect("color_changed", Global.set_shirt_colour)
	var pants_colour_picker : Control = $AppearanceMenu/PantsPanel/PantsPanelContainer/ColorPickerButton
	pants_colour_picker.connect("color_changed", Global.set_pants_colour)
	var skin_colour_picker : Control = $AppearanceMenu/SkinPanel/SkinPanelContainer/ColorPickerButton
	skin_colour_picker.connect("color_changed", Global.set_skin_colour)
	var hair_picker : Control = $AppearanceMenu/HairPanel/HairPanelContainer/Picker
	hair_picker.connect("item_selected", Global.set_hair)
	var shirt_picker : Control = $AppearanceMenu/ShirtPanel/ShirtPanelContainer/TypeBoxContainer/TypePicker
	shirt_picker.connect("item_selected", Global.set_shirt)
	var shirt_tex_picker : Control = $AppearanceMenu/ShirtPanel/ShirtPanelContainer/TextureBoxContainer/TexturePicker
	shirt_tex_picker.connect("item_selected", Global.set_shirt_texture)
	
	# Set to loaded settings
	hair_colour_picker.color = Global.hair_colour
	shirt_colour_picker.color = Global.shirt_colour
	pants_colour_picker.color = Global.pants_colour
	skin_colour_picker.color = Global.skin_colour
	hair_picker.selected = Global.hair
	shirt_picker.selected = Global.shirt
	shirt_tex_picker.selected = Global.shirt_texture
	
	var current_preset : int = Global.load_graphics_preset()
	match current_preset:
		0:
			$SettingsMenu/Graphics.text = JsonHandler.find_entry_in_file("ui/graphics_settings/cool")
		1:
			$SettingsMenu/Graphics.text = JsonHandler.find_entry_in_file("ui/graphics_settings/bad")
		2:
			$SettingsMenu/Graphics.text = JsonHandler.find_entry_in_file("ui/graphics_settings/awful")

# Toggles the graphics presets via Global and saves the setting.
func toggle_graphics_presets() -> void:
	var current_preset : int = Global.get_graphics_preset()
	match current_preset:
		0:
			# set to BAD as we pressed button on COOL
			Global.set_graphics_preset(Global.GraphicsPresets.BAD)
			$SettingsMenu/Graphics.text = JsonHandler.find_entry_in_file("ui/graphics_settings/bad")
		1:
			# set to AWFUL
			Global.set_graphics_preset(Global.GraphicsPresets.AWFUL)
			$SettingsMenu/Graphics.text = JsonHandler.find_entry_in_file("ui/graphics_settings/awful")
		2:
			# set to COOL
			Global.set_graphics_preset(Global.GraphicsPresets.COOL)
			$SettingsMenu/Graphics.text = JsonHandler.find_entry_in_file("ui/graphics_settings/cool")
	UserPreferences.save_pref("graphics_preset", Global.get_graphics_preset())

func show_appearance_settings() -> void:
	$MainMenu.visible = false
	$AppearanceMenu.visible = true
	preview_player.change_appearance()
	preview_player.visible = true

func hide_appearance_settings() -> void:
	$MainMenu.visible = true
	$AppearanceMenu.visible = false
	preview_player.visible = false
	# Save appearance on back
	Global.save_appearance()

func show_settings() -> void:
	$MainMenu.visible = false
	$SettingsMenu.visible = true

func hide_settings() -> void:
	$MainMenu.visible = true
	$SettingsMenu.visible = false

func show_keybinds() -> void:
	$SettingsMenu.visible = false
	$KeybindsMenu.visible = true

func hide_keybinds() -> void:
	$SettingsMenu.visible = true
	$KeybindsMenu.visible = false

func quit() -> void:
	get_tree().quit()
