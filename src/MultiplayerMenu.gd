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

@onready var preview_player : RigidPlayer = Global.get_world().get_current_map().get_node("RigidPlayer")

func _ready() -> void:
	Global.connect("appearance_changed", preview_player.change_appearance)
	$MainMenu/Appearance.connect("pressed", show_appearance_settings)
	# play hair swing animation on new hair selected
	#$AppearanceMenu/HairPanel/HairPanelContainer/Picker.connect("item_selected", play_preview_character_appearance_animation)
	$AppearanceMenu/Back.connect("pressed", hide_appearance_settings)
	$MainMenu/Play.connect("pressed", show_hide.bind("PlayMenu", "MainMenu"))
	$PlayMenu/Back.connect("pressed", show_hide.bind("MainMenu", "PlayMenu"))
	$PlayMenu/HostHbox/Edit.connect("pressed", show_hide.bind("HostSettingsMenu", "PlayMenu"))
	$PlayMenu/JoinHbox/Edit.connect("pressed", show_hide.bind("JoinSettingsMenu", "PlayMenu"))
	$HostSettingsMenu/Back.connect("pressed", show_hide.bind("PlayMenu", "HostSettingsMenu"))
	$JoinSettingsMenu/Back.connect("pressed", show_hide.bind("PlayMenu", "JoinSettingsMenu"))
	$MainMenu/Settings.connect("pressed", show_settings)
	$MainMenu/Quit.connect("pressed", quit)
	
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
	var shirt_tex_picker : Button = $AppearanceMenu/ShirtPanel/ShirtPanelContainer/TextureBoxContainer/UploadButton
	shirt_tex_picker.connect("pressed", Global.upload_shirt_texture)
	
	# Set to loaded settings
	hair_colour_picker.color = Global.hair_colour
	shirt_colour_picker.color = Global.shirt_colour
	pants_colour_picker.color = Global.pants_colour
	skin_colour_picker.color = Global.skin_colour
	hair_picker.selected = Global.hair
	shirt_picker.selected = Global.shirt

func show_appearance_settings() -> void:
	$MainMenu.visible = false
	$AppearanceMenu.visible = true
	preview_player.change_appearance()

func hide_appearance_settings() -> void:
	$MainMenu.visible = true
	$AppearanceMenu.visible = false
	# Save appearance on back
	Global.save_appearance()

func show_hide(a : String, b : String) -> void:
	get_node(a).visible = true
	get_node(b).visible = false

func show_settings() -> void:
	$SettingsMenu.visible = true

func quit() -> void:
	get_tree().quit()
