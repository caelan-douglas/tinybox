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

func _ready():
	$PauseMenu/Menu/SaveWorld.connect("pressed", _on_save_world_pressed)
	Global.get_world().connect("map_loaded", _on_map_loaded)

func _on_map_loaded() -> void:
	var editor = Global.get_world().get_current_map()
	if editor is Editor:
		$WorldProperties/Menu/Water.connect("pressed", editor.toggle_water)
		$WorldProperties/Menu/WaterHeightAdjuster/DownBig.connect("pressed", editor.adjust_water_height.bind(-10))
		$WorldProperties/Menu/WaterHeightAdjuster/Down.connect("pressed", editor.adjust_water_height.bind(-1))
		$WorldProperties/Menu/WaterHeightAdjuster/Up.connect("pressed", editor.adjust_water_height.bind(1))
		$WorldProperties/Menu/WaterHeightAdjuster/UpBig.connect("pressed", editor.adjust_water_height.bind(10))
		$EntryScreen/Menu/New.connect("pressed", _on_new_world_pressed)
		$EntryScreen/Menu/Load.connect("pressed", _on_load_world_pressed)

func _on_new_world_pressed():
	$EntryScreen.set_visible(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_load_world_pressed():
	var world_name = $EntryScreen/Menu/LoadName.text
	$EntryScreen.set_visible(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Global.get_world().load_tbw(world_name)

func hide_pause_menu() -> void:
	$PauseMenu.visible = false
	Global.get_player().locked = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func show_pause_menu() -> void:
	$PauseMenu.visible = true
	Global.get_player().locked = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta):
	if Input.is_action_just_pressed("pause") && visible:
		if $PauseMenu.visible:
			hide_pause_menu()
		else:
			show_pause_menu()

func _on_save_world_pressed() -> void:
	var world_name = $PauseMenu/Menu/SaveWorldName.text
	if world_name == "":
		UIHandler.show_alert("Please enter a world name above!", 4, false, true, false)
	else:
		Global.get_world().save_tbw(str(world_name))
