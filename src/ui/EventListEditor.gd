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


# Special list UI element for adding custom events and watchers.

extends Node
signal event_list_changed(list : Array)

enum ListType {
	EVENT,
	WATCHER
}

@export var list_type := ListType.EVENT
var event_list : Array = []
var max_events : int = 32
var show_watcher_end_events : bool = false

@onready var add_button := $List/Title/Button

func _ready() -> void:
	match (list_type):
		ListType.EVENT:
			add_button.connect("pressed", add_event.bind(0, []))
		ListType.WATCHER:
			add_button.connect("pressed", add_watcher.bind(0, []))
			add_button.text = "+ Add watcher"

func _add_base_ui() -> HBoxContainer:
	# set up base button
	var hbox := HBoxContainer.new()
	hbox.name = "OuterHbox"
	var opt := CustomOptionButton.new()
	opt.name = "Selector"
	hbox.add_child(opt)
	# for holding unique event controls
	var inner_hbox := HBoxContainer.new()
	inner_hbox.name = "InnerHbox"
	inner_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(inner_hbox)
	var del_button := DynamicButton.new()
	del_button.name = "DelButton"
	del_button.text = "X"
	del_button.self_modulate = Color.RED
	hbox.add_child(del_button)
	return hbox

func add_event(event_type : Event.EventType, args : Array) -> void:
	if event_list.size() >= max_events:
		UIHandler.show_alert("Max events reached.", 3, false, UIHandler.alert_colour_error)
		return
	# set up base button
	var hbox := _add_base_ui()
	# hook delete button
	hbox.get_node("DelButton").connect("pressed", _remove_event_list_item.bind(hbox))
	# add to main list
	$List/EventList.add_child(hbox)
	var selector : OptionButton = hbox.get_node("Selector")
	
	# disallowed types list
	var disallowed_types : Array[String] = []
	disallowed_types += Event.EDITOR_DISALLOWED_TYPES
	# don't show watcher end events like podium for start events
	if !show_watcher_end_events:
		disallowed_types += Event.WATCHER_END_ONLY_TYPES
	# add events to opt list
	for e : String in Event.EventType.keys():
		if !disallowed_types.has(e):
			selector.add_item(str(JsonHandler.find_entry_in_file(str("enum/event_type/", e))), Event.EventType.get(e) as int)
	selector.selected = event_type
	selector.connect("item_selected_with_id", _set_list_event_type.bind(hbox))
	# add unique elements
	event_list.append([event_type, args])
	_set_list_event_type(event_type, hbox)

func add_watcher(watcher_type : Watcher.WatcherType, args : Array) -> void:
	if event_list.size() >= max_events:
		UIHandler.show_alert("Max watchers reached.", 3, false, UIHandler.alert_colour_error)
		return
	# set up inner base button
	var hbox := _add_base_ui()
	var selector : OptionButton = hbox.get_node("Selector")
	# set up outer box
	var vbox := VBoxContainer.new()
	var spacer : Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)
	vbox.add_child(hbox)
	# hook delete button
	hbox.get_node("DelButton").connect("pressed", _remove_event_list_item.bind(vbox))
	# add to main list
	$List/EventList.add_child(vbox)
	# add event list editor for watcher end events
	# don't preload this to avoid recursion
	var list_editor : Control = (load("res://data/scene/ui/EventListEditor.tscn") as PackedScene).instantiate()
	# end events for watcher
	list_editor.list_type = ListType.EVENT
	list_editor.get_node("List/Title/Label").text = "When this condition is met, do..."
	list_editor.modulate = Color("#b5adff")
	list_editor.size_flags_horizontal = Control.SIZE_SHRINK_END
	list_editor.show_watcher_end_events = true
	vbox.add_child(list_editor)
	# add watchers to opt list
	for w : String in Watcher.WatcherType.keys():
		if !Watcher.EDITOR_DISALLOWED_TYPES.has(w):
			selector.add_item(str(JsonHandler.find_entry_in_file(str("enum/watcher_type/", w))), Watcher.WatcherType.get(w) as int)
	selector.selected = watcher_type
	selector.connect("item_selected_with_id", _set_list_watcher_type.bind(vbox, list_editor))
	# add unique elements
	event_list.append([watcher_type, args])
	_set_list_watcher_type(watcher_type, vbox, list_editor)

func _set_list_event_type(event_type : Event.EventType, event_ui : HBoxContainer) -> void:
	var inner_hbox := event_ui.get_node("InnerHbox")
	for c : Control in inner_hbox.get_children():
		c.queue_free()
	match (event_type):
		# 0 arg events
		Event.EventType.CLEAR_LEADERBOARD,\
		Event.EventType.BALANCE_TEAMS,\
		Event.EventType.MOVE_ALL_PLAYERS_TO_SPAWN,\
		Event.EventType.END_ACTIVE_GAMEMODE,\
		Event.EventType.SHOW_PODIUM,\
		Event.EventType.SHOW_WORLD_PREVIEW:
			# get text value of enum from int, ie 2 -> "BALANCE_TEAMS"
			_update_event_list(event_ui, [Event.EventType.keys()[event_type], []])
		Event.EventType.TELEPORT_ALL_PLAYERS:
			_update_event_list(event_ui, [Event.EventType.keys()[event_type], []])
		Event.EventType.LOCK_PLAYER_STATES:
			var prop_chooser : OptionButton = OptionButton.new()
			prop_chooser.add_item("Roll")
			prop_chooser.add_item("Slide")
			inner_hbox.add_child(prop_chooser)
		Event.EventType.WAIT_FOR_SECONDS:
			# create adjuster for seconds value
			var adjuster_i : Adjuster = adjuster.instantiate()
			inner_hbox.add_child(adjuster_i)
			# create checkbox for showing visual to players
			var checkbox_i : CheckBox = CheckBox.new()
			checkbox_i.text = JsonHandler.find_entry_in_file("ui/editor/gamemode_event_show_countdown")
			inner_hbox.add_child(checkbox_i)
			# connect the resulting value from value changed to the args part of the function using a lambda
			adjuster_i.value_changed.connect(\
				func(new_val : int) -> void:\
					_update_event_list(event_ui, [Event.EventType.keys()[event_type], [new_val]]))
		_:
			var label := Label.new()
			label.text = "(Not implemented)"
			inner_hbox.add_child(label)

var adjuster : PackedScene = preload("res://data/scene/ui/Adjuster.tscn")
func _set_list_watcher_type(watcher_type : Watcher.WatcherType, watcher_ui : Control, watcher_end_event_list : Control) -> void:
	var inner_hbox := watcher_ui.get_node("OuterHbox/InnerHbox")
	for c : Control in inner_hbox.get_children():
		c.queue_free()
	match (watcher_type):
		Watcher.WatcherType.PLAYER_PROPERTY_EXCEEDS,\
		Watcher.WatcherType.PLAYER_PROPERTY_FALLS_BELOW:
			_update_event_list(watcher_ui, [Watcher.WatcherType.keys()[watcher_type], ["kills", 0]])
			# create options for property name
			var prop_chooser : OptionButton = OptionButton.new()
			prop_chooser.add_item("kills")
			prop_chooser.add_item("deaths")
			prop_chooser.add_item("height")
			prop_chooser.add_item("health")
			prop_chooser.add_item("velocity")
			inner_hbox.add_child(prop_chooser)
			# create adjuster for property value
			var adjuster_i : Adjuster = adjuster.instantiate()
			inner_hbox.add_child(adjuster_i)
			# connect the resulting value from value changed to the args part of the function using a lambda
			# watcher also needs end events in its constructor
			#                                                                               > watcher    type                                       arg 1 prop   arg 2 val   end events
			adjuster_i.value_changed.connect(\
				func(new_val : int) -> void:\
					_update_event_list(watcher_ui, [Watcher.WatcherType.keys()[watcher_type], [prop_chooser.get_item_text(prop_chooser.selected), new_val], watcher_end_event_list.event_list]))
			prop_chooser.item_selected.connect(\
				func(new_prop_name : String) -> void:\
					_update_event_list(watcher_ui, [Watcher.WatcherType.keys()[watcher_type], [prop_chooser.get_item_text(prop_chooser.selected), adjuster_i.val], watcher_end_event_list.event_list]))
		_:
			# set default val
			# get text value of enum from int, ie 2 -> "PLAYER_CUSTOM_VARIABLE_EXCEEDS"
			_update_event_list(watcher_ui, [Watcher.WatcherType.keys()[watcher_type], [0]])
			# create ui
			var adjuster_i : Adjuster = adjuster.instantiate()
			inner_hbox.add_child(adjuster_i)
			# connect the resulting value from value changed to the args part of the function using a lambda
			#                                                                               > watcher    type                                       args       end events
			adjuster_i.value_changed.connect(func(new_val : int) -> void: _update_event_list(watcher_ui, [Watcher.WatcherType.keys()[watcher_type], [new_val], watcher_end_event_list.event_list]))


func _remove_event_list_item(event_ui : Control) -> void:
	event_list.remove_at(event_ui.get_index())
	event_ui.queue_free()
	emit_signal("event_list_changed", event_list)

func _update_event_list(event_ui : Control, event : Array) -> void:
	event_list[event_ui.get_index()] = event
	emit_signal("event_list_changed", event_list)
