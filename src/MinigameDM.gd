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

extends Minigame
class_name MinigameDM

# Deathmatch and Team Deathmatch

var dm_limit : int = 15
var tdm_limit : int = 20
var tdm_team_uis := []
var tdm := false
@onready var tdm_team_ui : PackedScene = preload("res://data/scene/ui/minigame/TDMTeam.tscn")

@rpc("any_peer", "call_remote", "reliable")
func sync_properties_with_new_client(new_client_id : int) -> void:
	# RUNS ON SERVER, SENDS PROPS TO CLIENT
	receive_properties_as_new_client.rpc_id(new_client_id, [game_timer.time_left, current_leader_id, winner_name, dm_limit, tdm_limit])

@rpc("any_peer", "call_remote", "reliable")
func receive_properties_as_new_client(args : Array) -> void:
	game_timer.start(args[0] as float)
	current_leader_id = args[1] as int
	winner_name = args[2] as String
	dm_limit = args[3] as int
	tdm_limit = args[4] as int

func _init(_tdm := false) -> void:
	tdm = _tdm

func play_intro_animation(camera : Camera3D) -> void:
	var map_name : String = Global.get_world().get_current_map().name
	if map_name == "Warp":
		camera.get_parent().get_node("AnimationPlayer").play("intro")
	else:
		camera.get_parent().get_node("AnimationPlayer").play("intro_alt")
	if tdm:
		get_tree().current_scene.get_node("GameCanvas").play_intro_animation(str("Team Deathmatch - ", map_name))
	else:
		get_tree().current_scene.get_node("GameCanvas").play_intro_animation(str("Deathmatch - ", map_name))

func play_outro_animation(camera : Camera3D) -> void:
	var player : RigidPlayer = Global.get_player()
	player.change_state(RigidPlayer.DUMMY)
	var outro_spot : Node3D = Global.get_world().get_current_map().get_node_or_null("OutroSpot")
	# others go in a non-visible area
	player.teleport(Vector3(0, 299, 0))
	# teams
	if tdm:
		# get all players in team
		var winning_players : Array = Global.get_world().get_current_map().get_teams().get_players_in_team(winner_name)
		var player_offset := 0
		for winning_player : RigidPlayer in winning_players:
			winning_player.teleport(Vector3(outro_spot.global_position.x + player_offset, outro_spot.global_position.y, outro_spot.global_position.z + player_offset * 0.6))
			winning_player.global_rotation = outro_spot.global_rotation
			winning_player.animator.set("parameters/OutroTimeSeek/seek_request", 0.0)
			winning_player.animator["parameters/BlendOutroPose/blend_amount"] = 1
			player_offset += 1
		await get_tree().create_timer(0.1).timeout
		# move camera
		get_tree().current_scene.get_node("GameCanvas").play_outro_animation(str(winner_name, " team wins!"))
		camera.global_position = Vector3(outro_spot.global_position.x - 1, outro_spot.global_position.y + 1.2, outro_spot.global_position.z - 1)
		var pos_to_look := Vector3(winning_players[0].global_position.x as float, winning_players[0].global_position.y + 1 as float, winning_players[0].global_position.z as float)
		camera.look_at(pos_to_look)
		await get_tree().create_timer(2).timeout
		camera.global_position = Vector3(outro_spot.global_position.x + 1, outro_spot.global_position.y + 1, outro_spot.global_position.z - 1)
		camera.look_at(pos_to_look)
		await get_tree().create_timer(3).timeout
		camera.global_position = Vector3(outro_spot.global_position.x, outro_spot.global_position.y + 0.5, outro_spot.global_position.z - 1)
		camera.look_at(pos_to_look)
		await get_tree().create_timer(5).timeout
		for winning_player : RigidPlayer in winning_players:
			winning_player.animator["parameters/BlendOutroPose/blend_amount"] = 0
	# free for all
	else:
		# make leader player show animation
		var winning_player : RigidPlayer = get_tree().current_scene.get_node_or_null(str("World/", current_leader_id))
		if winning_player != null:
			winning_player.teleport(outro_spot.global_position)
			winning_player.global_rotation = outro_spot.global_rotation
			winning_player.animator.set("parameters/OutroTimeSeek/seek_request", 0.0)
			winning_player.animator["parameters/BlendOutroPose/blend_amount"] = 1
		await get_tree().create_timer(0.1).timeout
		# move camera
		get_tree().current_scene.get_node("GameCanvas").play_outro_animation(str(winner_name, " wins!"))
		camera.global_position = Vector3(outro_spot.global_position.x - 1, outro_spot.global_position.y + 1.2, outro_spot.global_position.z - 1)
		var pos_to_look := Vector3(winning_player.global_position.x, winning_player.global_position.y + 1, winning_player.global_position.z)
		camera.look_at(pos_to_look)
		await get_tree().create_timer(2).timeout
		camera.global_position = Vector3(outro_spot.global_position.x + 1, outro_spot.global_position.y + 1, outro_spot.global_position.z - 1)
		camera.look_at(pos_to_look)
		await get_tree().create_timer(3).timeout
		camera.global_position = Vector3(outro_spot.global_position.x, outro_spot.global_position.y + 0.5, outro_spot.global_position.z - 1)
		camera.look_at(pos_to_look)
		await get_tree().create_timer(5).timeout
		winning_player.animator["parameters/BlendOutroPose/blend_amount"] = 0

func _ready() -> void:
	super._ready()
	await Signal(self, "intro_completed")
	if tdm:
		dm_limit = tdm_limit
		UIHandler.show_alert(str("First team to ", dm_limit, " wins!"), 10, false, false, true)
	else:
		UIHandler.show_alert(str("First to ", dm_limit, " wins!"), 10, false, false, true)
	# 20 minute deathmatches
	game_time = 1200
	
	game_timer.wait_time = game_time
	game_timer.start()
	var player : RigidPlayer = Global.get_player()
	# set tools
	player.get_tool_inventory().delete_all_tools()
	player.get_tool_inventory().give_minigame_tools()
	# no build period in deathmatches
	if multiplayer.is_server():
		Global.connect("player_list_information_update", _on_player_list_update)
	# adjust ui
	team_target_hp_ui.visible = false
	team_cash_ui.visible = false
	# for single dm
	if !tdm:
		dm_leader_ui.visible = true
	# for tdm, create each team a bar
	else:
		dm_leader_ui.visible = false
		for team : String in playing_team_names:
			var i : Control = tdm_team_ui.instantiate()
			# set node name to team name
			i.name = team
			# set bar to team colour
			i.self_modulate = Global.get_world().get_current_map().get_teams().get_team(team).colour
			minigame_ui.add_child(i)
			tdm_team_uis.append(i)
			tdm_update_team_score(team, 0)
	
	game_timer_ui.max_value = game_timer.time_left
	Global.get_world().get_current_map().get_node("TeamConfines/collider").disabled = true
	Global.get_world().get_current_map().get_node("TeamConfines/caution").visible = false
	
	# sync with server
	if from_new_peer_connection:
		sync_properties_with_new_client.rpc_id(1, multiplayer.get_unique_id())
	
	minigame_ui.visible = true
	minigame_ui.get_node("AnimationPlayer").play("flash_controls")

func _on_player_list_update() -> void:
	# deathmatch leader handling
	if multiplayer.is_server() && !tdm:
		var participants : Array = Global.get_world().rigidplayer_list
		var dm_leader : RigidPlayer = participants[0] as RigidPlayer
		# check who is leading
		for p : RigidPlayer in participants:
			if p.kills >= dm_leader.kills && p.kills > 0:
				dm_leader = p
				# player is winner
				if p.kills >= dm_limit && !game_over:
					dm_winner.rpc(dm_leader.get_multiplayer_authority(), dm_leader.display_name)
					return
		# if there is a new leader... (someone with at least 1 kill)
		if dm_leader != null:
			# notify
			dm_new_leader.rpc(dm_leader.get_multiplayer_authority(), dm_leader.display_name, dm_leader.kills)
	# team deathmatch
	elif multiplayer.is_server() && tdm:
		for team : String in playing_team_names:
			var team_players : Array = Global.get_world().get_current_map().get_teams().get_players_in_team(team)
			var team_score := 0
			for player : RigidPlayer in team_players:
				team_score += player.kills
			if team_score >= dm_limit:
				tdm_winner.rpc(team)
				return
			tdm_update_team_score.rpc(team, team_score)

@rpc("any_peer", "call_local", "reliable")
func dm_winner(new_id : int, new_winner_name : String) -> void:
	current_leader_id = new_id
	winner_name = new_winner_name
	end()

@rpc("any_peer", "call_local", "reliable")
func dm_new_leader(new_id : int, new_leader_name : String, new_leader_kills : int) -> void:
	# if the new leader is different from the last
	if new_id != current_leader_id:
		current_leader_id = new_id
		winner_name = new_leader_name
		UIHandler.show_alert(str(new_leader_name, " has taken the lead!"), 7, false, false, true)
	# update anyway for current leader
	dm_leader_ui.max_value = dm_limit
	dm_leader_ui.value = new_leader_kills
	dm_leader_ui_text.text = str("(To ", dm_limit, ") Leader: ", new_leader_name)

@rpc("any_peer", "call_local", "reliable")
func tdm_update_team_score(team_name : String, kills : int) -> void:
	for t : Node in minigame_ui.get_children():
		if t.name == team_name:
			var team_ui : ProgressBar = t
			team_ui.max_value = dm_limit
			team_ui.value = kills
			team_ui.get_node("Label").text = str(team_name, " Team Score: ", kills, " / ", dm_limit)

@rpc("any_peer", "call_local", "reliable")
func tdm_winner(team_winner_name : String) -> void:
	current_leader_id = -1
	winner_name = team_winner_name
	end()

@rpc("any_peer", "call_local", "reliable")
func delete() -> void:
	# reset TDM uis
	for ui : Node in tdm_team_uis:
		ui.queue_free()
	tdm_team_uis = []
	super()

func _process(delta : float) -> void:
	# wait for intro
	if in_intro:
		return
	game_timer_ui.value = game_timer.time_left
	var mins := str(int(game_timer.time_left as int / 60))
	var seconds := str('%02d' % (int(game_timer.time_left as int) % 60))
	game_timer_ui_text.text = str(mins, ":", seconds, " left in match!")
