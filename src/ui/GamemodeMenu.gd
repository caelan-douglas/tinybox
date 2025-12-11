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

@onready var selector : OptionButton = $GamemodeSelector
@onready var button : Button = $StartGamemode
@onready var end_button : Button = $EndGamemode
@onready var param_list : VBoxContainer = $ParameterList
@onready var modifier_list : VBoxContainer = $ModifierList
@onready var adjuster_label : PackedScene = load("res://data/scene/ui/AdjusterLabel.tscn")
var gamemode_names_list : Array = []
var selected_mode_params : Array = []
var selected_mode_mods : Array = []

func _ready() -> void:
	super()
	# automatically populate gamemode list based on map
	Global.get_world().connect("tbw_loaded", _on_tbw_loaded)
	button.connect("pressed", _on_start_gamemode_pressed)
	end_button.connect("pressed", _on_end_gamemode_pressed)
	selector.connect("item_selected", _on_item_selected)
	multiplayer.peer_connected.connect(_on_peer_connected)

func _on_start_gamemode_pressed() -> void:
	Global.server_start_gamemode.rpc_id(1, selector.selected, selected_mode_params, selected_mode_mods)

func _on_peer_connected(id : int) -> void:
	# only execute from the owner
	if !multiplayer.is_server(): return
	_populate_client_gamemode_list.rpc_id(id, gamemode_names_list)

func _on_end_gamemode_pressed() -> void:
	if !multiplayer.is_server(): return
	var e : Event = Event.new(Event.EventType.END_ACTIVE_GAMEMODE, [])
	e.start()

func _on_tbw_loaded() -> void:
	# server handles
	if !multiplayer.is_server(): return
	# delete old list
	selector.clear()
	# for populating client lists
	gamemode_names_list = []
	# add new gamemodes
	for gm : Gamemode in Global.get_world().gamemode_list:
		gamemode_names_list.append(gm.gamemode_name)
	# as server: populate all peers' gamemode lists
	# including self
	_populate_client_gamemode_list.rpc(gamemode_names_list)
	
@rpc("any_peer", "call_local", "reliable")
func _populate_client_gamemode_list(gamemode_names : Array) -> void:
	if multiplayer.get_remote_sender_id() != 1 && multiplayer.get_remote_sender_id() != get_multiplayer_authority() && multiplayer.get_remote_sender_id() != 0:
		return
	# delete old list
	selector.clear()
	# add new gamemodes
	for gm : String in gamemode_names:
		selector.add_item(gm)
	# load default params
	_on_item_selected(0)

func _on_item_selected(index : int) -> void:
	# The selected mode from the dropdown
	var gm : String = selector.get_item_text(index)
	# clear existing params to default
	selected_mode_params = [0, 0]
	selected_mode_mods = [0, 0, 0, false]
	for c : Node in param_list.get_children():
		c.queue_free()
	for c : Node in modifier_list.get_children():
		c.queue_free()
	# load new params
	
	# time limit for all
	add_param_or_mod_adjuster(true, 0, 10, "Time limit (mins)", 1, 999)
	# player speed and jump modifier
	add_param_or_mod_adjuster(false, 0, 5, "Player speed", 5, 10)
	add_param_or_mod_adjuster(false, 2, 1, "Player jump multiplier", 1, 5, true)
	# player health modifier
	add_param_or_mod_adjuster(false, 1, 20, "Player maximum health", 1, 100)
	# low grav toggle modifier
	add_param_or_mod_toggle(false, 3, false, "Low gravity")
	
	# gamemode-specific
	match (gm):
			"Deathmatch", "Team Deathmatch":
				pass
			"Hide & Seek":
				# change number of starting seekers
				add_param_or_mod_adjuster(true, 1, 1, "# of Seekers", 1, Global.get_world().rigidplayer_list.size() - 1)
			"Capture", "Team Capture":
				# change limit for capture time
				add_param_or_mod_adjuster(true, 1, 60, "Capture Time Limit (s)", 15, 240)
			"Home Run", "Team Home Run":
				# change bat knockback force
				add_param_or_mod_adjuster(true, 1, 10, "Bat Hit Force", 5, 50)

func _update_gamemode_params(new_param : int, param_idx : int) -> void:
	selected_mode_params[param_idx] = new_param

func _update_gamemode_mods(new_mod : int, mod_idx : int) -> void:
	selected_mode_mods[mod_idx] = new_mod

func add_param_or_mod_adjuster(parameter : bool, adj_idx : int, def_val : int, label : String, min_val : int, max_val : int, is_multiplier : bool = false) -> void:
	var adjuster : Control = adjuster_label.instantiate()
	if parameter:
		param_list.add_child(adjuster)
	else:
		modifier_list.add_child(adjuster)
	adjuster.get_node("List/Label").text = label
	var c_adj := adjuster.get_node("List/Adjuster") as Adjuster
	if parameter:
		c_adj.connect("value_changed", _update_gamemode_params.bind(adj_idx))
	else:
		c_adj.connect("value_changed", _update_gamemode_mods.bind(adj_idx))
	c_adj.set_min(min_val)
	c_adj.set_max(max_val)
	c_adj.is_multiplier = is_multiplier
	c_adj.set_value(def_val)
	# different bg colour for modifiers
	if !parameter:
		adjuster.self_modulate = Color("#00f5bd")

func add_param_or_mod_toggle(parameter : bool, adj_idx : int, def_val : bool, label : String) -> void:
	var checkbox : CheckBox = CheckBox.new()
	if parameter:
		param_list.add_child(checkbox)
	else:
		modifier_list.add_child(checkbox)
	checkbox.text = label.capitalize()
	checkbox.button_pressed = def_val as bool
	if parameter:
		checkbox.connect("toggled", _update_gamemode_params.bind(adj_idx))
	else:
		checkbox.connect("toggled", _update_gamemode_mods.bind(adj_idx))
	if parameter:
		checkbox.self_modulate = Color("#fdc0bd")
	else:
		checkbox.self_modulate = Color("#00f5bd")
