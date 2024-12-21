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

extends AnimatedList

@onready var graphics_button : Button = $Graphics
@onready var save_button : Button = $SaveButton
@onready var sensitivity_slider : Slider = $MouseSensitivity
@onready var fov_slider : Slider = $FOV
@export var show_save_button : bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	graphics_button.connect("pressed", toggle_graphics_presets)
	if !show_save_button:
		save_button.visible = false
		
	load_prefs()
	# load prefs when menu is shown
	connect("visibility_changed", load_prefs)
	
	sensitivity_slider.connect("value_changed", _on_sensitivity_changed)
	fov_slider.connect("value_changed", _on_fov_changed)
	
	var current_preset : int = Global.load_graphics_preset()
	match current_preset:
		0:
			graphics_button.text = JsonHandler.find_entry_in_file("ui/graphics_settings/cool")
		1:
			graphics_button.text = JsonHandler.find_entry_in_file("ui/graphics_settings/bad")
		2:
			graphics_button.text = JsonHandler.find_entry_in_file("ui/graphics_settings/awful")

func _on_visiblity_changed(mode : bool) -> void:
	if mode == true:
		load_prefs()

func load_prefs() -> void:
	# load prefs
	var loaded_mouse_sensitivity : Variant = UserPreferences.load_pref("mouse_sensitivity")
	if loaded_mouse_sensitivity != null:
		UserPreferences.mouse_sensitivity = loaded_mouse_sensitivity as float
	var loaded_camera_fov : Variant = UserPreferences.load_pref("camera_fov")
	if loaded_camera_fov != null:
		UserPreferences.camera_fov = loaded_camera_fov as float
		
	sensitivity_slider.value = UserPreferences.mouse_sensitivity
	fov_slider.value = UserPreferences.camera_fov

func _on_sensitivity_changed(value : float) -> void:
	UserPreferences.mouse_sensitivity = value
	print(UserPreferences.mouse_sensitivity)
	UserPreferences.save_pref("mouse_sensitivity", value)
	UIHandler.show_toast(str("Sensitivity multiplier: ", value), 1)

func _on_fov_changed(value : float) -> void:
	UserPreferences.camera_fov = value
	print(UserPreferences.camera_fov)
	UserPreferences.save_pref("camera_fov", value)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		# in game camera only
		if cam is Camera:
			cam.fov = value

# Toggles the graphics presets via Global and saves the setting.
func toggle_graphics_presets() -> void:
	var current_preset : int = Global.get_graphics_preset()
	match current_preset:
		0:
			# set to BAD as we pressed button on COOL
			Global.set_graphics_preset(Global.GraphicsPresets.BAD)
			graphics_button.text = JsonHandler.find_entry_in_file("ui/graphics_settings/bad")
		1:
			# set to AWFUL
			Global.set_graphics_preset(Global.GraphicsPresets.AWFUL)
			graphics_button.text = JsonHandler.find_entry_in_file("ui/graphics_settings/awful")
		2:
			# set to COOL
			Global.set_graphics_preset(Global.GraphicsPresets.COOL)
			graphics_button.text = JsonHandler.find_entry_in_file("ui/graphics_settings/cool")
	UserPreferences.save_pref("graphics_preset", Global.get_graphics_preset())
