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
var gamemode_names_list : Array = []

func _ready() -> void:
	super()
	# automatically populate gamemode list based on map
	Global.get_world().connect("tbw_loaded", _on_tbw_loaded)
	button.connect("pressed", _on_start_gamemode_pressed)
	end_button.connect("pressed", _on_end_gamemode_pressed)
	multiplayer.peer_connected.connect(_on_peer_connected)

func _on_start_gamemode_pressed() -> void:
	server_start_gamemode.rpc_id(1, selector.selected)

func _on_peer_connected(id : int) -> void:
	# only execute from the owner
	if !multiplayer.is_server(): return
	_populate_client_gamemode_list.rpc_id(id, gamemode_names_list)

@rpc("any_peer", "call_local", "reliable")
func server_start_gamemode(idx : int) -> void:
	if Global.get_world().gamemode_list.size() > 0:
		Global.get_world().gamemode_list[idx].connect("gamemode_ended", _on_gamemode_ended.bind(idx))
		button.disabled = true
		end_button.disabled = false
		Global.get_world().gamemode_list[idx].start()
	else:
		UIHandler.show_alert("There are no gamemodes to start!")

func _on_end_gamemode_pressed() -> void:
	if !multiplayer.is_server(): return
	var e : Event = Event.new(Event.EventType.END_ACTIVE_GAMEMODE, [])
	e.start()

func _on_gamemode_ended(idx : int) -> void:
	if Global.get_world().gamemode_list[idx].is_connected("gamemode_ended", _on_gamemode_ended.bind(idx)):
		Global.get_world().gamemode_list[idx].disconnect("gamemode_ended", _on_gamemode_ended.bind(idx))
	if multiplayer.is_server():
		button.disabled = false
	end_button.disabled = true

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
		print(gm)
		selector.add_item(gm)
		match (gm):
			"Deathmatch":
				selector.set_item_tooltip(selector.item_count - 1, "A classic arena Deathmatch mode.\n\nStart with a ball and a bat; if the map has them, you can\ncollect pickups like rockets, bombs and missiles.")
			"Team Deathmatch":
				selector.set_item_tooltip(selector.item_count - 1, "A classic arena Deathmatch mode, but with teams.\n\nStart with a ball and a bat; if the map has them, you can\ncollect pickups like rockets, bombs and missiles.")
			"Hide & Seek":
				selector.set_item_tooltip(selector.item_count - 1, "Hide & Seek following the manhunt rules.\n\nStarts with one Seeker; the rest of the players are hiders.\nWhen the seeker hits a hider with their bat, they too become a seeker.\nThe seekers win if all the hiders are found before the time limit.\nThe hiders win if at least one of them lasts till the time limit.")
