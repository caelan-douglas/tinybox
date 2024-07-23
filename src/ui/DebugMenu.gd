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

@onready var debug_text : Label = $DebugText

func _physics_process(delta : float) -> void:
	if Input.is_action_just_pressed("debug_menu"):
		# game canvas should be visible
		if get_parent().visible:
			visible = !visible
	if visible:
		var brick_count : int = 0
		var bricks : Array = Global.get_world().get_children()
		for b : Node in bricks:
			if b is Brick:
				brick_count += 1
		debug_text.text = str("bricks in world: ", str(brick_count), "\nactive physics objects: ", Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS), "\nvideo memory: ", round(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) * 0.000001), "mb\ndraw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "\nmaterial cache size: ", str(Global.graphics_cache.size()))
		var player : RigidPlayer = Global.get_player()
		if player != null:
			debug_text.text += str("\nPlayer linear velocity total:", round(player.linear_velocity.length()), 
			"\nPlayer position (global): ", round(player.global_position), 
			"\nPlayer state: ", player.states_as_names[player._state], 
			"\nPlayer air from jump?: ", player.air_from_jump, 
			"\nPlayer air duration: ", player.air_duration, 
			"\nPlayer occupying seat: ", player.seat_occupying)
		debug_text.text += str("\n---------- WORLD TEAMS INFO -------------\n")
		debug_text.text += str("World Teams Node list:\n")
		if Global.get_world().get_current_map() and Global.get_world().get_current_map().get_teams():
			var teams : Teams = Global.get_world().get_current_map().get_teams()
			debug_text.text += str(teams.get_team_list())
			debug_text.text += str("\n------------PLAYER TEAMS INFO ------------\n")
			for t : Team in teams.get_team_list():
				var team_name : String = t.name
				debug_text.text += str("\n----- ", team_name, " -----\n")
				debug_text.text += str(teams.get_players_in_team(team_name))
