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

extends Button

@export var default_key = KEY_1
@export var keybind_for_what = "BuildTool"

@onready var defaults_button = get_parent().get_parent().get_node_or_null("DefaultsButton")
var waiting_for_input = false

var allowed_keys = [KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_Q, KEY_E, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P, KEY_G, KEY_H, KEY_J, KEY_K, KEY_L, KEY_V, KEY_B, KEY_N, KEY_M, MOUSE_BUTTON_MIDDLE]

# Called when the node enters the scene tree for the first time.
func _ready():
	connect("pressed", _on_pressed)
	# if there is a defaults button
	if defaults_button != null:
		defaults_button.connect("pressed", _on_defaults_pressed)
	
	# if not automatic
	if UserPreferences.has_section("keybinds"):
		if defaults_button:
			defaults_button.text = "Enable Auto Keybinds"
		# load existing pref
		var loaded_key = UserPreferences.load_pref(str("keybind_", keybind_for_what), "keybinds")
		if loaded_key != null:
			text = loaded_key
		else:
			# save default in keybinds section for now
			var key_as_string = OS.get_keycode_string(default_key)
			text = key_as_string
			UserPreferences.save_pref(str("keybind_", keybind_for_what), key_as_string, "keybinds")
	else:
		if defaults_button:
			defaults_button.text = "Enable Custom Keybinds"
		text = "(Auto)"
		disabled = true

func _on_pressed() -> void:
	waiting_for_input = true
	text = "Awaiting input"

func _input(event):
	# (disabled - waiting for input)
	if waiting_for_input:
		if((event is InputEventKey || event is InputEventMouseButton) and event.pressed == true):
			waiting_for_input = false
			# check if matches allowed keys
			for key in allowed_keys:
				if event is InputEventKey:
					if event.keycode == key:
						# success
						var key_as_string = OS.get_keycode_string(event.keycode)
						text = key_as_string
						disabled = false
						# save pref
						UserPreferences.save_pref(str("keybind_", keybind_for_what), key_as_string, "keybinds")
						return
				elif event is InputEventMouseButton:
					if event.button_index == MOUSE_BUTTON_MIDDLE:
						# success
						text = "MMB"
						disabled = false
						UserPreferences.save_pref(str("keybind_", keybind_for_what), "MMB", "keybinds")
						return
			# invalid key
			UIHandler.show_alert("That key is invalid or reserved (must be 0-9, non-reserved letter, or middle mouse button).", 8, false, true)
			disabled = false
			var key_as_string = OS.get_keycode_string(default_key)
			text = key_as_string

func _on_defaults_pressed() -> void:
	# if on auto
	if disabled:
		disabled = false
		# save default in keybinds section for now
		var key_as_string = OS.get_keycode_string(default_key)
		text = key_as_string
		UserPreferences.save_pref(str("keybind_", keybind_for_what), key_as_string, "keybinds")
		
		defaults_button.text = "Enable Auto Keybinds"
	# if setting back to auto
	else:
		UserPreferences.delete_pref("keybinds", str("keybind_", keybind_for_what))
		text = "(Auto)"
		disabled = true
		
		defaults_button.text = "Enable Custom Keybinds"
