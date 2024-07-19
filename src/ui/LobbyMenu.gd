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
signal win_condition_changed(new_win_condition : Lobby.GameWinCondition)

var lobby : Node = null
var win_condition := Lobby.GameWinCondition.DEATHMATCH

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$PlayerMenu/ChangeTeam.connect("pressed", change_team)
	$PlayerMenu/BalanceTeams.connect("pressed", balance_teams)
	$SettingsMenu/Start.connect("pressed", send_pre_game)
	$SettingsMenu/WinCondition.connect("pressed", change_win_condition)
	change_win_condition_peers.rpc(win_condition)
	Global.get_world().teleport_all_players(Vector3(0, 51, 0))
	lobby = Global.get_world().get_current_map()
	# only hosts can change settings
	if !multiplayer.is_server():
		for b in $SettingsMenu.get_children():
			if b is Button:
				b.disabled = true
		$PlayerMenu/BalanceTeams.disabled = true
	# server balance teams
	else:
		await get_tree().process_frame
		balance_teams()

func send_pre_game() -> void:
	pre_game.rpc()

func change_win_condition() -> void:
	match (win_condition):
		# if we are switching from base defense:
		Lobby.GameWinCondition.BASE_DEFENSE:
			$PlayerMenu/ChangeTeam.disabled = true
			win_condition = Lobby.GameWinCondition.DEATHMATCH
		# if we are switching from deathmatch:
		Lobby.GameWinCondition.DEATHMATCH:
			$PlayerMenu/ChangeTeam.disabled = false
			win_condition = Lobby.GameWinCondition.TEAM_DEATHMATCH
		Lobby.GameWinCondition.TEAM_DEATHMATCH:
			$PlayerMenu/ChangeTeam.disabled = true
			win_condition = Lobby.GameWinCondition.KINGS
		Lobby.GameWinCondition.KINGS:
			$PlayerMenu/ChangeTeam.disabled = false
			win_condition = Lobby.GameWinCondition.BASE_DEFENSE
	balance_teams()
	change_win_condition_peers.rpc(win_condition)

@rpc("any_peer", "call_local", "reliable")
func change_win_condition_peers(new : Lobby.GameWinCondition) -> void:
	var new_text := "Type: Base Defense"
	match (new):
		Lobby.GameWinCondition.BASE_DEFENSE:
			new_text = "Type: Base Defense"
		Lobby.GameWinCondition.DEATHMATCH:
			new_text = "Type: Deathmatch"
		Lobby.GameWinCondition.TEAM_DEATHMATCH:
			new_text = "Type: Team Deathmatch"
		Lobby.GameWinCondition.KINGS:
			new_text = "Type: Kings"
			
	$SettingsMenu/WinCondition.text = new_text
	$PreGameMenu/MapVoteLabel.text = str("Map Vote (for ", new_text, ")")
	emit_signal("win_condition_changed", new)

var votes : Array[int] = [0, 0, 0, 0]
@rpc("any_peer", "call_local", "reliable")
func add_ready(num : int) -> void:
	votes[num] += 1
	# update display
	var voted_map_count_text : Label = get_node_or_null(str("PreGameMenu/Maps/", num, "/VoteCount"))
	if voted_map_count_text:
		voted_map_count_text.text = str(votes[num])
	# server starts
	if multiplayer.is_server():
		var participants : Array = Global.get_world().rigidplayer_list
		var sum := 0
		for v in votes:
			sum += v
		# if all votes have been cast, start
		if sum == participants.size():
			var selected_map := 0
			# determine vote winner
			var highest_vote := 0
			for i in range(votes.size()):
				if votes[i] > highest_vote:
					selected_map = i
					highest_vote = votes[i]
			# fallback map
			var voted_map_name := "Frozen Field"
			# get voted map name
			var voted_map_label : Label = get_node_or_null(str("PreGameMenu/Maps/", selected_map, "/Name"))
			if voted_map_label:
				voted_map_name = voted_map_label.text
			# load map
			Global.get_world().start_minigame.rpc(voted_map_name, win_condition)

func _on_map_vote(num : int) -> void:
	for c in $PreGameMenu/Maps.get_children():
		c.disabled = true
	add_ready.rpc(num)

@rpc("any_peer", "call_local", "reliable")
func pre_game() -> void:
	var player : RigidPlayer = Global.get_player()
	var teams : Teams = Global.get_world().get_current_map().get_teams()
	var team_idx : int = teams.get_team_index(str(player.team))
	var camera : Camera3D = get_viewport().get_camera_3d()
	
	match team_idx:
		1:
			camera.get_parent().get_node("AnimationPlayer").play("move_to_left_side")
		_:
			camera.get_parent().get_node("AnimationPlayer").play("move_to_right_side")
	
	$SettingsMenu.visible = false
	$PlayerMenu.visible = false
	$PreGameMenu.visible = true
	
	
	for c in $PreGameMenu/Maps.get_children():
		c.connect("pressed", _on_map_vote.bind(c.name.to_int()))

func balance_teams() -> void:
	if !multiplayer.is_server(): return
	
	var teams : Teams = Global.get_world().get_current_map().get_teams()
	var participants : Array = Global.get_world().rigidplayer_list
	
	for i in range(participants.size()):
		if win_condition == Lobby.GameWinCondition.BASE_DEFENSE || win_condition == Lobby.GameWinCondition.TEAM_DEATHMATCH:
			if (i % 2) == 0:
				participants[i].update_team.rpc(teams.get_team_list()[1].name)
			else:
				participants[i].update_team.rpc(teams.get_team_list()[2].name)
		# default team for no-team games
		else:
			participants[i].update_team.rpc(teams.get_team_list()[0].name)
		update_team.rpc(str(participants[i].name))
		# update player positions in lobby
		update_auth_player_position.rpc_id(participants[i].get_multiplayer_authority() as int)

@rpc("any_peer", "call_local", "reliable")
func update_auth_player_position() -> void:
	var player : RigidPlayer = Global.get_player()
	var teams : Teams = Global.get_world().get_current_map().get_teams()
	var team_idx : int = teams.get_team_index(str(player.team))
	
	match team_idx:
		1:
			player.teleport(Vector3(randf_range(-1, -3), 50, randf_range(-1, -3)))
		_:
			player.teleport(Vector3(randf_range(1, 3), 50, randf_range(-1, -3)))

func change_team() -> void:
	var player : RigidPlayer = Global.get_player()
	var teams : Teams = Global.get_world().get_current_map().get_teams()
	var team_idx : int = teams.get_team_index(str(player.team))
	team_idx += 1
	if team_idx >= teams.get_team_list().size():
		# start at 1 to exclude Default
		team_idx = 1
	
	player.update_team.rpc(teams.get_team_list()[team_idx].name)
	player.update_info()
	update_auth_player_position()
	update_team.rpc(multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func update_team(id : int) -> void:
	Global.update_player_list_information()
