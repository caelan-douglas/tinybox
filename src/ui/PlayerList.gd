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

extends VBoxContainer
signal player_removed

@onready var player_list_entry : PackedScene = preload("res://data/scene/ui/PlayerListEntry.tscn")
@export var show_team_names := true

func _ready() -> void:
	find_players()
	multiplayer.peer_disconnected.connect(remove_player_by_id)
	Global.connect("player_list_information_update", update_list)

func find_players() -> void:
	# add existing players if this is added to scene later.
	# if the players are already in the list, it will skip them
	# in add_player.
	for p : RigidPlayer in Global.get_world().rigidplayer_list:
		add_player(p)

func update_list() -> void:
	for entry in get_children():
		for player : RigidPlayer in Global.get_world().rigidplayer_list:
			# compare IDs
			if str(player.name) == str(entry.name):
				var k : Label = entry.get_node("HBoxContainer/K")
				var d : Label = entry.get_node("HBoxContainer/D")
				var capture : Label = entry.get_node("HBoxContainer/CaptureTime")
				var player_team : Label = entry.get_node("HBoxContainer/Team")
				k.text = str(player.kills)
				d.text = str(player.deaths)
				# if player has capture time
				if player.capture_time > -1:
					capture.visible = true
					capture.text = str(player.capture_time)
				# hide capture value when not being used (-1)
				else:
					capture.visible = false
				player_team.text = str(player.team)
				# set colour to our team colour.
				if Global.get_world().get_current_map().get_teams().get_team(player.team) != null:
					var team_colour : Color = Global.get_world().get_current_map().get_teams().get_team(player.team).colour
					# make our list entry the colour of our team.
					entry.self_modulate = team_colour
	sort_by_teams()

func sort_by_teams() -> void:
	var sorted_nodes:= get_children()

	sorted_nodes.sort_custom(
		func(a: Node, b: Node) -> bool: return a.get_node("HBoxContainer/Team").text < b.get_node("HBoxContainer/Team").text
	)
	
	for node in get_children():
		remove_child(node)
	for node in sorted_nodes:
		add_child(node)
	
func add_player(player : RigidPlayer) -> void:
	for l in get_children():
		# if we're already in the list, dont add
		if l.name == str(player.name):
			return
	# otherwise, continue
	var player_list_entry_i : Control = player_list_entry.instantiate()
	var player_label : Label = player_list_entry_i.get_node("HBoxContainer/Label")
	var player_team : Label = player_list_entry_i.get_node("HBoxContainer/Team")
	var player_k : Label = player_list_entry_i.get_node("HBoxContainer/K")
	var player_d : Label = player_list_entry_i.get_node("HBoxContainer/D")
	player_label.text = str(player.display_name)
	player_team.text = str(player.team)
	if !show_team_names:
		player_team.visible = false
	player_k.text = str(player.kills)
	player_d.text = str(player.deaths)
	# set colour to our team colour.
	if Global.get_world().get_current_map().get_teams().get_team(player.team) != null:
		var team_colour : Color = Global.get_world().get_current_map().get_teams().get_team(player.team).colour
		# make our list entry the colour of our team.
		player_list_entry_i.self_modulate = team_colour
	# make the name of the object equal our id.
	player_list_entry_i.name = str(player.name)
	# if we are host, show the crown
	if str(player.name).to_int() == 1:
		player_list_entry_i.get_node("HBoxContainer/Crown").visible = true
	# show "YOU" tag for ourselves, not if you're host though
	elif player.display_name == Global.display_name:
		player_list_entry_i.get_node("HBoxContainer/You").visible = true
	add_child(player_list_entry_i)
	sort_by_teams()

func remove_player_by_id(id : int) -> void:
	remove_player(Global.get_world().get_node_or_null(str(id)) as RigidPlayer)

func remove_player(player : RigidPlayer) -> void:
	if player:
		for l in get_children():
			if l.name == str(player.name):
				l.queue_free()
