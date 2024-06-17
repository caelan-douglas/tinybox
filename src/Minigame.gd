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
class_name Minigame
signal intro_completed

var playing_team_names = []
# local to each client
var my_team
# total game time (includes build time); normally 720
var game_time = 720
var game_timer = null
var in_intro = true
var from_new_peer_connection = false
var game_over = false

var current_leader_id = 1
var winner_name = ""

@onready var minigame_ui = get_tree().current_scene.get_node("GameCanvas/MinigameControls")
@onready var game_timer_ui = get_tree().current_scene.get_node("GameCanvas/MinigameControls/GameTimer")
@onready var game_timer_ui_text = get_tree().current_scene.get_node("GameCanvas/MinigameControls/GameTimer/Label")
@onready var team_cash_ui = get_tree().current_scene.get_node("GameCanvas/MinigameControls/TeamCash")
@onready var team_cash_ui_text = get_tree().current_scene.get_node("GameCanvas/MinigameControls/TeamCash/Label")
@onready var team_target_hp_ui = get_tree().current_scene.get_node("GameCanvas/MinigameControls/TeamTargetHP")
@onready var team_target_hp_ui_text = get_tree().current_scene.get_node("GameCanvas/MinigameControls/TeamTargetHP/Label")
@onready var dm_leader_ui = get_tree().current_scene.get_node("GameCanvas/MinigameControls/DMLeader")
@onready var dm_leader_ui_text = get_tree().current_scene.get_node("GameCanvas/MinigameControls/DMLeader/Label")

@onready var world = get_parent()

@rpc("any_peer", "call_remote", "reliable")
func sync_properties_with_new_client(new_client_id) -> void:
	pass

@rpc("any_peer", "call_remote", "reliable")
func receive_properties_as_new_client(args : Array) -> void:
	pass

func play_intro_animation(camera):
	camera.get_parent().get_node("AnimationPlayer").play("intro")
	var map_name = Global.get_world().get_current_map().name
	get_tree().current_scene.get_node("GameCanvas").play_intro_animation(str("Minigame - ", map_name))

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
	game_over = false
	# in case coming from last minigame
	minigame_ui.visible = false
	# ready player
	var camera = get_viewport().get_camera_3d()
	var player = Global.get_player()
	while player == null:
		await get_tree().process_frame
		player = Global.get_player()
	player.go_to_spawn()
	UIHandler.hide_lobby_menu()
	camera.locked = true
	# play intro
	if !from_new_peer_connection:
		play_intro_animation(camera)
		await get_tree().create_timer(10).timeout
	camera.locked = false
	# after intro
	in_intro = false
	if camera is Camera:
		Global.get_player().set_camera(camera)
	player.change_state(RigidPlayer.IDLE)
	player.go_to_spawn()
	player.kills = 0
	player.deaths = 0
	player.update_info()
	my_team = player.team
	# ready ui
	get_tree().current_scene.get_node("GameCanvas").hide_pause_menu()
	# create game timer
	game_timer = Timer.new()
	game_timer.wait_time = game_time
	add_child(game_timer)
	game_timer.start()
	game_timer.connect("timeout", _on_game_timer_timeout)
	emit_signal("intro_completed")

func get_team_cash(team_name : String):
	return world.get_current_map().get_teams().get_team(team_name).cash

@rpc("any_peer", "call_local", "reliable")
func set_team_cash(team_name : String, new):
	world.get_current_map().get_teams().get_team(team_name).cash = get_team_cash(team_name) + new
	if get_team_cash(team_name) > 700:
		world.get_current_map().get_teams().get_team(team_name).cash = 700

func _on_player_list_update() -> void:
	pass

func _on_game_timer_timeout() -> void:
	print("Game timer timed out.")
	game_timer.queue_free()
	minigame_ui.visible = false
	end()

@rpc("any_peer", "call_local", "reliable")
func delete() -> void:
	# reset tools
	Global.get_player().get_tool_inventory().reset()
	Global.get_world().get_current_map().get_node("TeamConfines/collider").disabled = true
	Global.get_world().get_current_map().get_node("TeamConfines/caution").visible = false
	for team in playing_team_names:
		# reset team cash
		set_team_cash(team, 9999)
	
	Global.get_world().minigame = null
	call_deferred("queue_free")

@rpc("any_peer", "call_local", "reliable")
func end() -> void:
	game_over = true
	var camera = get_viewport().get_camera_3d()
	var player = Global.get_player()
	if multiplayer.is_server():
		Global.disconnect("player_list_information_update", _on_player_list_update)
	minigame_ui.visible = false
	# play outro
	var outro_spot = Global.get_world().get_current_map().get_node_or_null("OutroSpot")
	if outro_spot != null:
		camera.set_camera_mode(Camera.CameraMode.FREE)
		camera.fov = 55
		camera.locked = true
		play_outro_animation(camera)
		await get_tree().create_timer(10).timeout
		# exit outro
		camera.locked = false
	Global.get_world().minigame = null
	# remove all existing bricks
	Global.get_world().clear_bricks()
	Global.get_world().load_map(load("res://data/scene/Frozen Field/Frozen Field.tscn"))
	# refind node
	camera = get_viewport().get_camera_3d()
	if camera is Camera:
		Global.get_player().set_camera(camera)
	player.change_state(RigidPlayer.IDLE)
	player.kills = 0
	player.deaths = 0
	player.update_info()
	player.go_to_spawn()
	# reset toolsz
	player.get_tool_inventory().reset()
	
	UIHandler.show_alert("Game ended. World is now in Sandbox mode.", 8)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	delete()
