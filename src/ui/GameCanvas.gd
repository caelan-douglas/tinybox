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

@onready var pause_tip_text : Label = $PauseMenu/ScrollContainer/Pause/Tip

const NUM_OF_TIPS = 17

func _ready() -> void:
	$PauseMenu/ScrollContainer/Pause/ChangeMap.connect("pressed", _send_on_change_map_pressed)
	$PauseMenu/ScrollContainer/Pause/SaveWorld.connect("pressed", _on_save_world_pressed)

func hide_pause_menu() -> void:
	Global.is_paused = false
	if Global.get_world().get_current_map() is Editor:
		$TestModePauseMenu.visible = false
		Global.get_player().locked = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		$PauseMenu.visible = false
		if Global.get_player() != null:
			Global.get_player().locked = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func show_pause_menu() -> void:
	Global.is_paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# if in editor world, we are testing, so show test pause menu
	if Global.get_world().get_current_map() is Editor:
		var editor : Editor = Global.get_world().get_current_map()
		$TestModePauseMenu.visible = true
		Global.get_player().locked = true
		$TestModePauseMenu/Menu/ReturnToEditor.connect("pressed", editor.exit_test_mode)
	else:
		$PauseMenu.visible = true
		if Global.get_player() != null:
			Global.get_player().locked = true
		# show tip on pause screen
		var tipnum : int = randi() % NUM_OF_TIPS
		pause_tip_text.text = JsonHandler.find_entry_in_file(str("tip/", tipnum))

func _process(delta : float) -> void:
	if Input.is_action_just_pressed("pause") && visible:
		# in editor testing mode
		if Global.get_world().get_current_map() is Editor:
			if $TestModePauseMenu.visible:
				hide_pause_menu()
			else:
				show_pause_menu()
		else:
			if $PauseMenu.visible:
				hide_pause_menu()
			else:
				show_pause_menu()

func _send_on_change_map_pressed() -> void:
	var map_selector : MapList = $PauseMenu/ScrollContainer/Pause/MapList
	# load tbw with switching flag
	# clients must wait 15s between loading worlds to avoid spam
	Global.get_world().ask_server_to_open_tbw.rpc_id(1, Global.display_name, map_selector.selected_name, map_selector.selected_lines)
	if !multiplayer.is_server():
		UIHandler.show_alert(str("Your request to load \"", map_selector.selected_name, "\" was sent to the host."), 4)

func _on_save_world_pressed() -> void:
	var world_name : String = $PauseMenu/ScrollContainer/Pause/SaveWorldName.text
	if world_name == "":
		UIHandler.show_alert("Please enter a world name above!", 4, false, UIHandler.alert_colour_error)
	else:
		Global.get_world().save_tbw(str(world_name))
