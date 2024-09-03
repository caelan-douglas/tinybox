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

extends Node

var curr_start_events : Array = []
var curr_watchers : Array = []
var curr_name : String = ""

# for custom gamemode maker
@onready var add_start_event_title := $Panel/ScrollContainer/Settings/StartEventPropertyEditor/List/Title
@onready var add_watcher_title := $Panel/ScrollContainer/Settings/WatcherPropertyEditor/List/Title

@onready var start_event_list := $Panel/ScrollContainer/Settings/StartEventPropertyEditor
@onready var watcher_list := $Panel/ScrollContainer/Settings/WatcherPropertyEditor
@onready var gamemode_name := $Panel/ScrollContainer/Settings/GamemodeName

# for list of world gamemodes
@onready var add_to_world_button := $AddToWorldGamemodes
@onready var world_gamemodes_list := $WorldGamemodesPanel/ScrollContainer/VBoxContainer

func _ready() -> void:
	add_watcher_title.get_node("Label").text = "Once started, watch for conditions..."
	
	start_event_list.connect("event_list_changed", _on_start_event_list_changed)
	watcher_list.connect("event_list_changed", _on_watcher_list_changed)
	gamemode_name.connect("text_changed", _on_gamemode_name_text_changed)
	add_to_world_button.connect("pressed", _on_add_to_world_pressed)
	
	# load from tbw
	update_world_gamemodes_list()
	Global.get_world().connect("tbw_loaded", update_world_gamemodes_list)

func _on_add_to_world_pressed() -> void:
	if curr_start_events.size() < 1:
		UIHandler.show_alert("You need at least one starting event!", 4, false, UIHandler.alert_colour_error)
		return
	if curr_watchers.size() < 1:
		UIHandler.show_alert("You need at least one condition to watch!", 4, false, UIHandler.alert_colour_error)
		return
	if curr_name == "":
		UIHandler.show_alert("Please enter a name for the gamemode!", 4, false, UIHandler.alert_colour_error)
		return
	if world_has_gamemode_with_name(curr_name):
		UIHandler.show_alert("This world already has a gamemode\nwith that name!", 4, false, UIHandler.alert_colour_error)
		return
	var no_previews := true
	for obj in Global.get_world().get_children():
		if obj is CameraPreviewPoint:
			no_previews = false
			break
	if no_previews:
		UIHandler.show_alert("You need at least one\nCamera Preview Point in the world!\n(Check the 'Special' section in the object selector.)", 8, false, UIHandler.alert_colour_error)
		return
	
	# success, add to world for saving
	var gm : Gamemode = Gamemode.new()
	gm.create(curr_name, curr_start_events, curr_watchers)
	Global.get_world().add_child(gm)
	update_world_gamemodes_list()
	# alert user of success
	UIHandler.show_alert(str("The gamemode \"", curr_name, "\" has been added to the world."), 4, false, UIHandler.alert_colour_gold)

func _on_gamemode_name_text_changed(new_text : String) -> void:
	curr_name = new_text

func _on_start_event_list_changed(new_list : Array) -> void:
	curr_start_events = new_list

func _on_watcher_list_changed(new_list : Array) -> void:
	curr_watchers = new_list

func update_world_gamemodes_list() -> void:
	# clear ui list
	for c : Node in world_gamemodes_list.get_children():
		c.queue_free()
	# repopulate list
	for g in Global.get_world().get_children():
		if g is Gamemode:
			var gamemode : Gamemode = g as Gamemode
			var gm_hbox : HBoxContainer = HBoxContainer.new()
			var gm_label : Label = Label.new()
			var gm_del_button : Button = Button.new()
			
			world_gamemodes_list.add_child(gm_hbox)
			gm_hbox.add_child(gm_label)
			
			gm_label.text = gamemode.gamemode_name
			if gamemode.built_in:
				gm_label.text += " (Built-in)"
			# can't delete built-in modes
			else:
				gm_del_button.text = "Delete this gamemode (no undo)"
				gm_del_button.self_modulate = Color.RED
				# make fill whole width
				gm_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				# make fill whole width
				gm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				gm_hbox.add_child(gm_del_button)
				# when delete pressed delete both the gm and ui element
				var lambda := func() -> void:
					gamemode.queue_free()
					gm_hbox.queue_free()
				gm_del_button.connect("pressed", lambda)

func world_has_gamemode_with_name(what : String) -> bool:
	for g in Global.get_world().get_children():
		if g is Gamemode:
			var gamemode : Gamemode = g as Gamemode
			if gamemode.gamemode_name == what:
				return true
	return false
