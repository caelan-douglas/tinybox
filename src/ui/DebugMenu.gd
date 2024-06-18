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

@onready var debug_text = $DebugText

func _ready():
	$FakePoint.connect("pressed", _on_fake_point_pressed)
	$LockPlayer.connect("pressed", _on_lock_player_pressed)
	$ResetTools.connect("pressed", _on_reset_tools_pressed)
	$ChangeTeam.connect("pressed", _on_change_team_pressed)
	$LoadTestWorld.connect("pressed", _on_load_test_world_pressed)
	$SaveTestWorld.connect("pressed", _on_save_test_world_pressed)

func _on_change_team_pressed() -> void:
	var player = Global.get_player()
	var teams = Global.get_world().get_current_map().get_teams()
	var team_idx = teams.get_team_index(player.team)
	team_idx += 1
	if team_idx >= teams.get_team_list().size():
		team_idx = 0
	# broadcast updated team to peers
	player.update_team.rpc(teams.get_team_list()[team_idx].name)
	player.update_info()

func _on_load_test_world_pressed() -> void:
	Global.get_world().load_tbw("test")

func _on_save_test_world_pressed() -> void:
	Global.get_world().save_tbw("test")

func _on_fake_point_pressed() -> void:
	if multiplayer.is_server():
		Global.get_player().increment_kills()

func _on_lock_player_pressed() -> void:
	if multiplayer.is_server():
		if Global.get_player().locked:
			Global.get_player().unlock()
		else:
			Global.get_player().lock()

func _on_reset_tools_pressed() -> void:
	if Global.get_player() != null:
		Global.get_player().get_tool_inventory().reset()

func _physics_process(delta):
	if Input.is_action_just_pressed("debug_menu"):
		# game canvas should be visible
		if get_parent().visible:
			visible = !visible
	if visible:
		debug_text.text = str("active physics objects: ", Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), "\nvideo memory: ", round(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) * 0.000001), "mb\ndraw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "\ngraphics cache contents: ", str(Global.graphics_cache))
		var player = Global.get_player()
		if player != null:
			debug_text.text += str("\nPlayer linear velocity total:", round(player.linear_velocity.length()), "\nPlayer position (global): ", round(player.global_position), "\nPlayer state: ", player.states_as_names[player._state], "\nPlayer fire?: ", player.on_fire, "\nPlayer occupying seat: ", player.seat_occupying)
		debug_text.text += str("\n---------- WORLD TEAMS INFO -------------\n")
		debug_text.text += str("World Teams Node list:\n")
		if Global.get_world().get_current_map() and Global.get_world().get_current_map().get_teams():
			var teams = Global.get_world().get_current_map().get_teams()
			debug_text.text += str(teams.get_team_list())
			debug_text.text += str("\n------------PLAYER TEAMS INFO ------------\n")
			for t in teams.get_team_list():
				var team_name = t.name
				debug_text.text += str("\n----- ", team_name, " -----\n")
				debug_text.text += str(teams.get_players_in_team(team_name))
