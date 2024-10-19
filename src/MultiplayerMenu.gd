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
@onready var nametag : LineEdit = $DisplayName

func _ready() -> void:
	Global.connect("appearance_changed", preview_player.change_appearance)
	$MainMenu/Appearance.connect("pressed", show_appearance_settings)
	# play hair swing animation on new hair selected
	#$AppearanceMenu/HairPanel/HairPanelContainer/Picker.connect("item_selected", play_preview_character_appearance_animation)
	$AppearanceMenu/Back.connect("pressed", hide_appearance_settings)
	$MainMenu/Play.connect("pressed", show_hide.bind("PlayMenu", "MainMenu"))
	$PlayMenu/Back.connect("pressed", show_hide.bind("MainMenu", "PlayMenu"))
	$PlayMenu/HostHbox/Edit.connect("pressed", show_hide.bind("HostSettingsMenu", "PlayMenu"))
	$HostSettingsMenu/Back.connect("pressed", show_hide.bind("PlayMenu", "HostSettingsMenu"))
	$MainMenu/Settings.connect("pressed", show_hide.bind("SettingsScroll", "MainMenu"))
	$MainMenu/Credits.connect("pressed", show_hide.bind("CreditsMenu", "MainMenu"))
	$CreditsMenu/Back.connect("pressed", show_hide.bind("MainMenu", "CreditsMenu"))
	$SettingsScroll/SettingsMenu/SaveButton.connect("pressed", show_hide.bind("MainMenu", "SettingsScroll"))
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
	var shirt_reset : Button = $AppearanceMenu/ShirtPanel/ShirtPanelContainer/TextureResetContainer/ResetButton
	shirt_reset.connect("pressed", Global.reset_shirt_texture)
	
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
	var map : Node3D = Global.get_world().get_current_map()
	if map.has_node("AnimationPlayer"):
		map.get_node("AnimationPlayer").play("appearance_in")
	preview_player.change_appearance()

func hide_appearance_settings() -> void:
	$MainMenu.visible = true
	$AppearanceMenu.visible = false
	var map : Node3D = Global.get_world().get_current_map()
	if map.has_node("AnimationPlayer"):
		map.get_node("AnimationPlayer").play("appearance_out")
	# Save appearance on back
	Global.save_appearance()

func show_hide(a : String, b : String) -> void:
	get_node(a).visible = true
	get_node(b).visible = false

func quit() -> void:
	get_tree().quit()

func _process(delta : float) -> void:
	if visible:
		var camera : Camera3D = get_viewport().get_camera_3d()
		# align nametag above player head
		if preview_player != null && camera != null:
			nametag.position = camera.unproject_position(preview_player.global_position + Vector3.UP*1.8)
			nametag.position.x -= nametag.size.x/2
		# rotate character when mouse is outside of panel area
		if $AppearanceMenu.visible && (get_viewport().get_mouse_position().x / get_viewport().size.x < 0.7):
			preview_player.global_rotation.y = (get_viewport().get_mouse_position().x / get_viewport().size.x) * PI * 2 + (PI*-1.3)
