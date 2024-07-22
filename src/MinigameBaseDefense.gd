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
class_name MinigameBaseDefense

# Base Defense

var team_targets : Array[MinigameTarget] = []
# normally 180
var build_time := 180
var build_period := true
var build_timer : Timer = null

var target_dog : PackedScene = preload("res://data/scene/minigame/targets/Dog.tscn")

@rpc("any_peer", "call_remote", "reliable")
func sync_properties_with_new_client(new_client_id : int) -> void:
	# RUNS ON SERVER, SENDS PROPS TO CLIENT
	receive_properties_as_new_client.rpc_id(new_client_id, [game_timer.time_left, current_leader_id, winner_name, build_timer.time_left, build_period])

@rpc("any_peer", "call_remote", "reliable")
func receive_properties_as_new_client(args : Array) -> void:
	game_timer.wait_time = args[0] as float
	current_leader_id = args[1] as int
	winner_name = args[2] as String
	build_timer.wait_time = args[3] as float
	build_period = args[4] as bool

func play_intro_animation(camera : Camera3D) -> void:
	var map_name : String = Global.get_world().get_current_map().name
	if map_name == "Warp":
		camera.get_parent().get_node("AnimationPlayer").play("intro")
	else:
		camera.get_parent().get_node("AnimationPlayer").play("intro_alt")
	get_tree().current_scene.get_node("GameCanvas").play_intro_animation(str("Base Defense - ", map_name))

func _ready() -> void:
	super._ready()
	await Signal(self, "intro_completed")
	var map_name : String = Global.get_world().get_current_map().name
	# floaty has shorter build period
	match(map_name):
		"Floaty":
			game_time = 780
			build_time = 120
	UIHandler.show_alert("Build period started! Defend your target\nwith a base or vehicles!", 14, false, UIHandler.alert_colour_error)
	
	# adjust ui
	team_target_hp_ui.visible = true
	team_cash_ui.visible = true
	dm_leader_ui.visible = false
	
	# create build timer
	build_timer = Timer.new()
	build_timer.wait_time = build_time
	build_timer.one_shot = true
	add_child(build_timer)
	build_timer.start()
	build_timer.connect("timeout", _on_build_timer_timeout)
	game_timer_ui.max_value = build_timer.time_left
	minigame_ui.visible = true
	minigame_ui.get_node("AnimationPlayer").play("flash_controls")
	
	# team confines
	Global.get_world().get_current_map().get_node("TeamConfines/collider").disabled = false
	Global.get_world().get_current_map().get_node("TeamConfines/caution").visible = true
	
	# only run on server
	if multiplayer.is_server():
		# team sizes, in order of playing_team_names
		var team_sizes := []
		# first check if inbalanced
		for team : String in playing_team_names:
			var team_players : Array = Global.get_world().get_current_map().get_teams().get_players_in_team(team)
			team_sizes.append(team_players.size())
		var greatest_team_size := 0
		# determine greatest team size
		for size : int in team_sizes:
			if size > greatest_team_size:
				greatest_team_size = size
		# now spawn targets
		var team_idx := 0
		for t : String in playing_team_names:
			# determine team target health by comparing against greatest team size
			var target_health : int = (1 + greatest_team_size) * 750 / (1 + team_sizes[team_idx])
			var target : Node3D = create_team_target(t, target_health)
			team_targets.append(target)
			# append team targets for clients too
			append_team_targets_client.rpc(target.get_path(), t)
			team_idx += 1
	
	# sync with server
	if from_new_peer_connection:
		sync_properties_with_new_client.rpc_id(1, multiplayer.get_unique_id())

@rpc("call_remote", "reliable")
func append_team_targets_client(t_as_path : NodePath, team_name : String) -> void:
	var target_node : Node3D = get_node(t_as_path)
	team_targets.append(target_node)
	# set colour for clients too
	target_node.get_node("Label3D").modulate = Global.get_world().get_current_map().get_teams().get_team(team_name).colour

func create_team_target(team_name : String, health := 750) -> Node:
	var target_i : MinigameTarget = target_dog.instantiate()
	target_i.name = str("Target", team_name)
	world.add_child(target_i)
	target_i.team = team_name
	target_i.health = health
	target_i.minigame = self
	target_i.get_node("Label3D").modulate = Global.get_world().get_current_map().get_teams().get_team(team_name).colour
	var team_spawn : Node3D = Global.get_world().get_current_map().get_teams().get_team_target_spawn(team_name)
	if team_spawn != null:
		target_i.global_position = team_spawn.global_position
	return target_i

var passive_income_interval := 400
var interval := 0
func _physics_process(delta : float) -> void:
	# only run on server
	if multiplayer.is_server() && !in_intro:
		for t : String in playing_team_names:
			for target : MinigameTarget in team_targets:
				if target.team == t:
					if target.health <= 0:
						UIHandler.show_alert.rpc(str(t, " lost!!!"), 8)
						end.rpc()
					# reset targets that fall off map
					if target.global_position.y < 40:
						var team_spawn : Node3D = Global.get_world().get_current_map().get_teams().get_team_target_spawn(t)
						if team_spawn != null:
							target.global_position = team_spawn.global_position
							target.linear_velocity = Vector3.ZERO
		# passive income outside build mode
		if !build_period:
			interval += 1
			if interval > passive_income_interval:
				interval = 0
				for t : String in playing_team_names:
					set_team_cash.rpc(t, 6)

@rpc("call_local", "reliable")
func _on_build_timer_timeout() -> void:
	UIHandler.show_alert("Build period is over! The game starts.", 8, false, UIHandler.alert_colour_error)
	build_period = false
	game_timer_ui.max_value = game_timer.time_left
	Global.get_world().get_current_map().get_node("TeamConfines/collider").disabled = true
	Global.get_world().get_current_map().get_node("TeamConfines/caution").visible = false
	build_timer.queue_free()

@rpc("any_peer", "call_local", "reliable")
func delete() -> void:
	for target in team_targets:
		target.queue_free()
	super()

func _process(delta : float) -> void:
	# wait for intro
	if in_intro:
		return
	if build_period && build_timer != null:
		game_timer_ui.value = build_timer.time_left
		var mins := str(int((build_timer.time_left) / 60))
		var seconds := str('%02d' % (int(build_timer.time_left) % 60))
		game_timer_ui_text.text = str("Build period: ", mins, ":", seconds, "!")
	# game period
	else:
		game_timer_ui.value = game_timer.time_left
		var mins := str(int(game_timer.time_left as int / 60))
		var seconds := str('%02d' % (int(game_timer.time_left as int) % 60))
		game_timer_ui_text.text = str(mins, ":", seconds, " left in game!")
	# team target ui
	for target in team_targets:
		if target.team == my_team:
			team_target_hp_ui.value = target.get_health()
			team_target_hp_ui_text.text = str("Your team's target HP: ", target.get_health())
	# team cash ui
	team_cash_ui.value = get_team_cash(str(my_team))
	team_cash_ui_text.text = str("Team cash remaining: ", get_team_cash(str(my_team)))
