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
class_name MinigameKing

# Kings mode.

var hill_limit_seconds = 180
# Keeps track of each player's hill time via their ID.
# eg. player_hill_time[str(id)] will return their hill time in seconds.
var player_hill_time = {}
var hill : Node3D = null
var hill_area : Area3D = null
var king : RigidPlayer = null

@onready var tdm_team_ui = preload("res://data/scene/ui/minigame/TDMTeam.tscn")

@rpc("any_peer", "call_remote", "reliable")
func sync_properties_with_new_client(new_client_id) -> void:
	# RUNS ON SERVER, SENDS PROPS TO CLIENT
	receive_properties_as_new_client.rpc_id(new_client_id, [game_timer.time_left, current_leader_id, winner_name, king.get_multiplayer_authority()])

@rpc("any_peer", "call_remote", "reliable")
func receive_properties_as_new_client(args : Array) -> void:
	game_timer.start(args[0])
	current_leader_id = args[1]
	winner_name = args[2]
	# king is sent as id
	king = get_tree().current_scene.get_node_or_null(str("World/", str(args[3])))

func play_intro_animation(camera):
	var map_name = Global.get_world().get_current_map().name
	if map_name == "Warp":
		camera.get_parent().get_node("AnimationPlayer").play("intro")
	else:
		camera.get_parent().get_node("AnimationPlayer").play("intro_alt")
	get_tree().current_scene.get_node("GameCanvas").play_intro_animation(str("Kings - ", map_name))

func play_outro_animation(camera):
	var player = Global.get_player()
	player.change_state(RigidPlayer.DUMMY)
	var outro_spot = Global.get_world().get_current_map().get_node_or_null("OutroSpot")
	# others go in a non-visible area
	Global.get_world().teleport_player(player, Vector3(0, 299, 0))
	# make leader player show animation
	var winning_player = get_tree().current_scene.get_node_or_null(str("World/", current_leader_id))
	if winning_player != null:
		Global.get_world().teleport_player(winning_player, outro_spot.global_position)
		winning_player.global_rotation = outro_spot.global_rotation
		winning_player.animator.set("parameters/OutroTimeSeek/seek_request", 0.0)
		winning_player.animator["parameters/BlendOutroPose/blend_amount"] = 1
	await get_tree().create_timer(0.1).timeout
	# move camera
	get_tree().current_scene.get_node("GameCanvas").play_outro_animation(str(winner_name, " wins!"))
	camera.global_position = Vector3(outro_spot.global_position.x - 1, outro_spot.global_position.y + 1.2, outro_spot.global_position.z - 1)
	var pos_to_look = Vector3(winning_player.global_position.x, winning_player.global_position.y + 1, winning_player.global_position.z)
	camera.look_at(pos_to_look)
	await get_tree().create_timer(2).timeout
	camera.global_position = Vector3(outro_spot.global_position.x + 1, outro_spot.global_position.y + 1, outro_spot.global_position.z - 1)
	camera.look_at(pos_to_look)
	await get_tree().create_timer(3).timeout
	camera.global_position = Vector3(outro_spot.global_position.x, outro_spot.global_position.y + 0.5, outro_spot.global_position.z - 1)
	camera.look_at(pos_to_look)
	await get_tree().create_timer(5).timeout
	winning_player.animator["parameters/BlendOutroPose/blend_amount"] = 0

func _ready():
	super._ready()
	await Signal(self, "intro_completed")
	# find hill
	hill = Global.get_world().get_current_map().get_node("KingsHill")
	hill_area = Global.get_world().get_current_map().get_node("KingsHill/Area3D")
	UIHandler.show_alert(str("Hold the hill for ", hill_limit_seconds/60, " minutes to win!"), 10, false, false, true)
	# 20 minutes
	game_time = 1200
	
	game_timer.wait_time = game_time
	game_timer.start()
	# show each player's score
	show_kings_score_on_playerlist(true)
	# run a func every second to add king points
	check_hill()
	var player = Global.get_player()
	# set tools
	player.get_tool_inventory().delete_all_tools()
	player.get_tool_inventory().give_minigame_tools()
	# adjust ui
	team_target_hp_ui.visible = false
	team_cash_ui.visible = false
	# for keeping track of hill time
	dm_leader_ui.visible = true
	dm_leader_ui.max_value = hill_limit_seconds
	dm_leader_ui.value = 0
	dm_leader_ui_text.text = str("(Hold for ", hill_limit_seconds/60, "m) No king yet.")
	
	game_timer_ui.max_value = game_timer.time_left
	Global.get_world().get_current_map().get_node("TeamConfines/collider").disabled = true
	Global.get_world().get_current_map().get_node("TeamConfines/caution").visible = false
	
	# sync with server
	if from_new_peer_connection:
		sync_properties_with_new_client.rpc_id(1, multiplayer.get_unique_id())
	
	minigame_ui.visible = true
	minigame_ui.get_node("AnimationPlayer").play("flash_controls")

@rpc("any_peer", "call_local", "reliable")
func king_winner(king_id, king_name) -> void:
	current_leader_id = king_id
	winner_name = king_name
	end()

@rpc("any_peer", "call_local", "reliable")
func delete() -> void:
	show_kings_score_on_playerlist(false)
	super()

func check_hill():
	# add players
	for p in Global.get_world().rigidplayer_list:
		if !player_hill_time.has(str(p.get_multiplayer_authority())):
			player_hill_time[str(p.get_multiplayer_authority())] = 0
	
	# server runs rest
	if multiplayer.is_server():
		# determine current king
		var current_king_inside_hill = false
		var players_in_hill = []
		for p in hill_area.get_overlapping_bodies():
			players_in_hill.append(p)
			if p is RigidPlayer:
				if king == null:
					# first king
					king = p
					new_king_rpc.rpc(king.get_multiplayer_authority(), king.display_name)
					current_king_inside_hill = true
				elif king == p && p._state != RigidPlayer.DEAD:
					# for making sure we don't change the king when someone else enters, unless the current
					# king leaves the hill (or dies).
					current_king_inside_hill = true
		# new check with updated king states
		for p in players_in_hill:
			if !current_king_inside_hill:
				if p != king:
					king = p
					new_king_rpc.rpc(king.get_multiplayer_authority(), king.display_name)
		# if there is a king, and they are in the hill
		if king != null && players_in_hill.has(king):
			player_hill_time[str(king.get_multiplayer_authority())] += 1
			update_player_list.rpc(king.display_name, player_hill_time[str(king.get_multiplayer_authority())])
			update_king_info_rpc.rpc(king.get_multiplayer_authority(), king.display_name, player_hill_time[str(king.get_multiplayer_authority())])
			# if king holds for limit time, win
			if player_hill_time[str(king.get_multiplayer_authority())] > hill_limit_seconds:
				king_winner.rpc(king.get_multiplayer_authority(), king.display_name)
	await get_tree().create_timer(1).timeout
	if !game_over:
		check_hill()

func show_kings_score_on_playerlist(mode):
	var player_list = get_tree().current_scene.get_node("GameCanvas/PlayerList")
	for entry in player_list.get_children():
		var kings_score = entry.get_node("HBoxContainer/KingsScore")
		kings_score.visible = mode

@rpc("any_peer", "call_local", "reliable")
func update_player_list(player_name, player_score):
	var player_list = get_tree().current_scene.get_node("GameCanvas/PlayerList")
	for entry in player_list.get_children():
		if str(player_name) == str(entry.get_node("HBoxContainer/Label").text):
			var kings_score = entry.get_node("HBoxContainer/KingsScore")
			kings_score.text = str(player_score)

@rpc("any_peer", "call_local", "reliable")
func new_king_rpc(king_id, king_name):
	UIHandler.show_alert(str(king_name, " is the new king!"), 5, false, false, true)

@rpc("any_peer", "call_local", "reliable")
func update_king_info_rpc(king_id, king_name, king_time):
	player_hill_time[str(king_id)] = king_time
	dm_leader_ui.max_value = hill_limit_seconds
	dm_leader_ui.value = player_hill_time[str(king_id)]
	dm_leader_ui_text.text = str("Current king: ", king_name, " (", king_time, "/", hill_limit_seconds, ")")

func _process(delta):
	# wait for intro
	if in_intro:
		return
	game_timer_ui.value = game_timer.time_left
	var mins = int(game_timer.time_left / 60)
	var seconds = str('%02d' % (int(game_timer.time_left) % 60))
	game_timer_ui_text.text = str(mins, ":", seconds, " left in match!")
