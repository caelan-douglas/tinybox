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
class_name EditorCanvas

@onready var world_name : LineEdit = $PauseMenu/ScrollContainer/Sections/Editor/SaveWorldName
@onready var pause_menu : Control = $PauseMenu
@onready var options_button : Button = $OptionsButton
@onready var coordinates_tooltip : Label = $Coordinates
@onready var toggle_player_visual_button : Button = $TogglePlayerVisual

@onready var water_button : Button = $"PauseMenu/ScrollContainer/Sections/World Properties/Water"
@onready var water_type_button : Button = $"PauseMenu/ScrollContainer/Sections/World Properties/WaterType"
@onready var env_button : Button = $"PauseMenu/ScrollContainer/Sections/World Properties/Environment"
@onready var bg_button : Button = $"PauseMenu/ScrollContainer/Sections/World Properties/Background"
@onready var grav_slider : HSlider = $"PauseMenu/ScrollContainer/Sections/World Properties/GravScale"
@onready var water_height_adj : Adjuster = $"PauseMenu/ScrollContainer/Sections/World Properties/WaterHeightAdjuster"
@onready var death_lim_low_adj : Adjuster = $"PauseMenu/ScrollContainer/Sections/World Properties/DeathLimitLow"
@onready var death_lim_hi_adj : Adjuster = $"PauseMenu/ScrollContainer/Sections/World Properties/DeathLimitHigh"
@onready var respawn_time_adj : Adjuster = $"PauseMenu/ScrollContainer/Sections/World Properties/RespawnTime"
@onready var save_world_button : Button = $PauseMenu/ScrollContainer/Sections/Editor/SaveWorld

@onready var select_mode_ui_animator : AnimationPlayer = $SelectModeOffset/SelectModeUI/AnimationPlayer

var mouse_just_captured : bool = false

func _ready() -> void:
	save_world_button.connect("pressed", _on_save_world_pressed)
	Global.get_world().connect("map_loaded", _on_map_loaded)

func _on_map_loaded() -> void:
	var editor : Map = Global.get_world().get_current_map()
	if editor is Editor:
		water_button.connect("pressed", (editor as Editor).toggle_water)
		water_type_button.connect("pressed", (editor as Editor).switch_water_type.bind(water_type_button.get_path()))
		env_button.connect("pressed", (editor as Editor).switch_environment)
		bg_button.connect("pressed", (editor as Editor).switch_background)
		
		# map property adjusters
		grav_slider.connect("value_changed", (editor as Editor).set_gravity_scale)
		water_height_adj.connect("value_changed", (editor as Editor).adjust_water_height)
		death_lim_low_adj.connect("value_changed", (editor as Editor).adjust_death_limit_low)
		death_lim_hi_adj.connect("value_changed", (editor as Editor).adjust_death_limit_high)
		respawn_time_adj.connect("value_changed", (editor as Editor).adjust_respawn_time)
		respawn_time_adj.max = 10
		respawn_time_adj.min = 1
		
		$EntryScreen/Panel/Menu/New.connect("pressed", _on_new_world_pressed)
		$EntryScreen/Panel/Menu/Load.connect("pressed", _on_load_world_pressed.bind($EntryScreen/Panel/Menu/MapList))
		$PauseMenu/ScrollContainer/Sections/Editor/Load.connect("pressed", _on_load_world_pressed.bind($PauseMenu/ScrollContainer/Sections/Editor/MapList, true))
		$PauseMenu/ScrollContainer/Sections/Editor/TestWorld.connect("pressed", _on_test_world_pressed.bind(false))
		$PauseMenu/ScrollContainer/Sections/Editor/TestWorldAtSpot.connect("pressed", _on_test_world_pressed.bind(true))
		
		$EntryScreen/Panel/Menu/New.grab_focus()
		
		options_button.connect("pressed", toggle_pause_menu)
		
		# disable tools for entry screen
		editor.editor_tool_inventory.set_disabled(true)

func _on_test_world_pressed(at_spot : bool = false) -> void:
	if world_name.text == "":
		UIHandler.show_alert("Please enter a world name before testing!", 4, false, UIHandler.alert_colour_error)
	else:
		var editor : Node3D = Global.get_world().get_current_map()
		if editor is Editor:
			editor.enter_test_mode(str(world_name.text), at_spot)

func _on_new_world_pressed() -> void:
	var editor : Node3D = Global.get_world().get_current_map()
	if editor is Editor:
		editor.editor_tool_inventory.set_disabled(false)
		editor.editor_tool_inventory.get_tools()[0].set_tool_active(true)
	$EntryScreen.set_visible(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_load_world_pressed(map_selector : MapList, confirm := false) -> void:
	if confirm:
		var actions := UIHandler.show_alert_with_actions("Are you sure? Any unsaved changes will be lost.", ["Load world", "Cancel"], true)
		actions[0].connect("pressed", _load_world.bind(map_selector))
	else:
		_load_world(map_selector)

func _load_world(map_selector : MapList) -> void:
	# delete old environment
	var editor : Node3D = Global.get_world().get_current_map()
	if editor is Editor:
		(editor as Editor).delete_environment()
	# load file
	$EntryScreen.set_visible(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# remove ".tbw" from string
	Global.get_world().open_tbw(map_selector.selected_lines)
	# set save field name to loaded world name
	world_name.text = str(map_selector.selected_name)
	# wait so that we don't place a brick on the same frame as action click
	await get_tree().process_frame
	if editor is Editor:
		editor.editor_tool_inventory.set_disabled(false)
		editor.editor_tool_inventory.get_tools()[0].set_tool_active(true)

func toggle_pause_menu() -> void:
	# only do this in editor mode
	if visible:
		if pause_menu.visible:
			# hide if visible
			hide_pause_menu()
		else:
			show_pause_menu()

func toggle_select_mode_ui(mode : bool) -> void:
	if mode:
		select_mode_ui_animator.play("show")
	else:
		select_mode_ui_animator.play("hide")

func hide_pause_menu() -> void:
	Global.is_paused = false
	var editor : Node3D = Global.get_world().get_current_map()
	if editor is Editor:
		if !editor.test_mode:
			editor.editor_tool_inventory.set_disabled(false)
	$PauseMenu.visible = false
	$Controls.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	options_button.text = JsonHandler.find_entry_in_file("ui/editor/options_button")

func show_pause_menu() -> void:
	Global.is_paused = true
	var editor : Node3D = Global.get_world().get_current_map()
	if editor is Editor:
		editor.editor_tool_inventory.set_disabled(true)
	$PauseMenu.visible = true
	$Controls.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	options_button.text = JsonHandler.find_entry_in_file("ui/editor/options_button_hide")

func _on_save_world_pressed() -> void:
	if world_name.text == "":
		UIHandler.show_alert("Please enter a world name above!", 4, false, UIHandler.alert_colour_error)
	else:
		Global.get_world().save_tbw(str(world_name.text))
