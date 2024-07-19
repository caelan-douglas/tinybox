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

func _ready() -> void:
	$PauseMenu/Menu/SaveWorld.connect("pressed", _on_save_world_pressed)
	Global.get_world().connect("map_loaded", _on_map_loaded)

func _on_map_loaded() -> void:
	var editor : Map = Global.get_world().get_current_map()
	if editor is Editor:
		$WorldProperties/Menu/Water.connect("pressed", (editor as Editor).toggle_water)
		$WorldProperties/Menu/WaterHeightAdjuster/DownBig.connect("pressed", (editor as Editor).adjust_water_height.bind(-10))
		$WorldProperties/Menu/WaterHeightAdjuster/Down.connect("pressed", (editor as Editor).adjust_water_height.bind(-1))
		$WorldProperties/Menu/WaterHeightAdjuster/Up.connect("pressed", (editor as Editor).adjust_water_height.bind(1))
		$WorldProperties/Menu/WaterHeightAdjuster/UpBig.connect("pressed", (editor as Editor).adjust_water_height.bind(10))
		$WorldProperties/Menu/Environment.connect("pressed", (editor as Editor).switch_environment)
		$WorldProperties/Menu/Background.connect("pressed", (editor as Editor).switch_background)
		
		$EntryScreen/Menu/New.connect("pressed", _on_new_world_pressed)
		$EntryScreen/Menu/Load.connect("pressed", _on_load_world_pressed.bind($EntryScreen/Menu/MapSelection))
		$PauseMenu/Menu/Load.connect("pressed", _on_load_world_pressed.bind($PauseMenu/Menu/MapSelection, true))
		$PauseMenu/Menu/TestWorld.connect("pressed", _on_test_world_pressed)
		
		$EntryScreen/Menu/New.grab_focus()
		
		# disable tools for entry screen
		editor.editor_tool_inventory.set_disabled(true)

func _on_test_world_pressed() -> void:
	var world_name : String = $PauseMenu/Menu/SaveWorldName.text
	if world_name == "":
		UIHandler.show_alert("Please enter a world name before testing!", 4, false, true, false)
	else:
		var editor : Node3D = Global.get_world().get_current_map()
		if editor is Editor:
			editor.enter_test_mode(str(world_name))

func _on_new_world_pressed() -> void:
	var editor : Node3D = Global.get_world().get_current_map()
	if editor is Editor:
		editor.editor_tool_inventory.set_disabled(false)
	$EntryScreen.set_visible(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_load_world_pressed(map_selector : OptionButton, confirm := false) -> void:
	var editor : Node3D = Global.get_world().get_current_map()
	if editor is Editor:
		editor.editor_tool_inventory.set_disabled(false)
	if confirm:
		var actions := UIHandler.show_alert_with_actions("Are you sure? Any unsaved changes will be lost.", ["Load world", "Cancel"], true)
		actions[0].connect("pressed", _load_world.bind(map_selector))
	else:
		_load_world(map_selector)

func _load_world(map_selector : OptionButton) -> void:
	# delete old environment
	var editor : Node3D = Global.get_world().get_current_map()
	if editor is Editor:
		(editor as Editor).delete_environment()
	# load file
	var world_name : String = map_selector.get_item_text(map_selector.selected)
	$EntryScreen.set_visible(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# remove ".tbw" from string
	Global.get_world().load_tbw(world_name.split(".")[0], false, false)

func hide_pause_menu() -> void:
	var editor : Node3D = Global.get_world().get_current_map()
	if editor is Editor:
		editor.editor_tool_inventory.set_disabled(false)
	$PauseMenu.visible = false
	Global.get_player().locked = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func show_pause_menu() -> void:
	var editor : Node3D = Global.get_world().get_current_map()
	if editor is Editor:
		editor.editor_tool_inventory.set_disabled(true)
	$PauseMenu.visible = true
	Global.get_player().locked = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta : float) -> void:
	if Input.is_action_just_pressed("pause") && visible:
		if $PauseMenu.visible:
			hide_pause_menu()
		else:
			show_pause_menu()

func _on_save_world_pressed() -> void:
	var world_name : String = $PauseMenu/Menu/SaveWorldName.text
	if world_name == "":
		UIHandler.show_alert("Please enter a world name above!", 4, false, true, false)
	else:
		Global.get_world().save_tbw(str(world_name))
