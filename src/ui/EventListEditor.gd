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

@onready var add_button := $Title/Button

func _ready() -> void:
	match (list_type):
		ListType.EVENT:
			add_button.connect("pressed", add_event.bind(0, []))
		ListType.WATCHER:
			add_button.connect("pressed", add_watcher.bind(0, []))

func _add_base_ui() -> HBoxContainer:
	# set up base button
	var hbox := HBoxContainer.new()
	$List.add_child(hbox)
	var opt := OptionButton.new()
	opt.name = "Selector"
	hbox.add_child(opt)
	# for holding unique event controls
	var inner_hbox := HBoxContainer.new()
	inner_hbox.name = "InnerHbox"
	inner_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(inner_hbox)
	var del_button := Button.new()
	del_button.text = "X"
	del_button.self_modulate = Color.RED
	hbox.add_child(del_button)
	# hook delete button
	del_button.connect("pressed", _remove_event_list_item.bind(hbox))
	return hbox

func add_event(event_type : Event.EventType, args : Array) -> void:
	if event_list.size() >= max_events:
		UIHandler.show_alert("Max events reached.", 3, false, UIHandler.alert_colour_error)
		return
	# set up base button
	var hbox := _add_base_ui()
	var selector : OptionButton = hbox.get_node("Selector")
	# add events to opt list
	for e : String in Event.EventType.keys():
		selector.add_item(str(JsonHandler.find_entry_in_file(str("enum/event_type/", e))))
	selector.selected = event_type
	selector.connect("item_selected", _set_list_event_type.bind(hbox))
	# add unique elements
	event_list.append([event_type, args])
	_set_list_event_type(event_type, hbox)

func add_watcher(watcher_type : Watcher.WatcherType, args : Array) -> void:
	if event_list.size() >= max_events:
		UIHandler.show_alert("Max watchers reached.", 3, false, UIHandler.alert_colour_error)
		return
	# set up base button
	var hbox := _add_base_ui()
	var selector : OptionButton = hbox.get_node("Selector")
	# add events to opt list
	for w : String in Watcher.WatcherType.keys():
		selector.add_item(str(JsonHandler.find_entry_in_file(str("enum/watcher_type/", w))))
	selector.selected = watcher_type
	selector.connect("item_selected", _set_list_watcher_type.bind(hbox))
	# add unique elements
	event_list.append([watcher_type, args])
	_set_list_watcher_type(watcher_type, hbox)

func _set_list_event_type(event_type : Event.EventType, event_ui : HBoxContainer) -> void:
	var my_idx : int = event_ui.get_index()
	var inner_hbox := event_ui.get_node("InnerHbox")
	for c : Control in inner_hbox.get_children():
		c.queue_free()
	match (event_type):
		Event.EventType.CLEAR_LEADERBOARD, Event.EventType.BALANCE_TEAMS, Event.EventType.MOVE_ALL_PLAYERS_TO_SPAWN:
			# get text value of enum from int, ie 2 -> "BALANCE_TEAMS"
			_update_event_list(event_ui, [Event.EventType.keys()[event_type], []])
		Event.EventType.TELEPORT_ALL_PLAYERS:
			_update_event_list(event_ui, [Event.EventType.keys()[event_type], []])
		_:
			var label := Label.new()
			label.text = "(Not implemented)"
			inner_hbox.add_child(label)

var adjuster : PackedScene = preload("res://data/scene/ui/Adjuster.tscn")
func _set_list_watcher_type(watcher_type : Watcher.WatcherType, watcher_ui : HBoxContainer) -> void:
	var my_idx : int = watcher_ui.get_index()
	var inner_hbox := watcher_ui.get_node("InnerHbox")
	for c : Control in inner_hbox.get_children():
		c.queue_free()
	match (watcher_type):
		_:
			# set default val
			# get text value of enum from int, ie 2 -> "PLAYER_CUSTOM_VARIABLE_EXCEEDS"
			_update_event_list(watcher_ui, [Watcher.WatcherType.keys()[watcher_type], [0]])
			# create ui
			var adjuster_i : Adjuster = adjuster.instantiate()
			inner_hbox.add_child(adjuster_i)
			adjuster_i.value_changed.connect(func(new_val : int) -> void: _update_event_list(watcher_ui, [Watcher.WatcherType.keys()[watcher_type], [new_val]]))

func _remove_event_list_item(event_ui : HBoxContainer) -> void:
	event_list.remove_at(event_ui.get_index())
	event_ui.queue_free()
	emit_signal("event_list_changed", event_list)

func _update_event_list(event_ui : HBoxContainer, event : Array, remove := false) -> void:
	event_list[event_ui.get_index()] = event
	emit_signal("event_list_changed", event_list)
