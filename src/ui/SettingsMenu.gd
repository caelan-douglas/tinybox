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
@export var show_save_button : bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	graphics_button.connect("pressed", toggle_graphics_presets)
	if !show_save_button:
		save_button.visible = false
	var current_preset : int = Global.load_graphics_preset()
	match current_preset:
		0:
			graphics_button.text = JsonHandler.find_entry_in_file("ui/graphics_settings/cool")
		1:
			graphics_button.text = JsonHandler.find_entry_in_file("ui/graphics_settings/bad")
		2:
			graphics_button.text = JsonHandler.find_entry_in_file("ui/graphics_settings/awful")

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
