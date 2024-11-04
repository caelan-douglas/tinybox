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

func _ready() -> void:
	var add_button : Button = Button.new()
	add_button.text = "Add fake health (pretend to be server as client)"
	add_button.connect("pressed", _on_add_fake_health)
	add_child(add_button)
	
	add_button = Button.new()
	add_button.text = "Add fake spawn protection (pretend to be server as client)"
	add_button.connect("pressed", _on_add_fake_spawnprot)
	add_child(add_button)
	
	add_button = Button.new()
	add_button.text = "Add fake kills"
	add_button.connect("pressed", _on_add_fake_kills)
	add_child(add_button)
	
	Global.connect("debug_toggled", _on_debug_toggled)

func _on_debug_toggled(mode : bool) -> void:
	visible = mode

func _on_add_fake_spawnprot() -> void:
	if !multiplayer.is_server():
		Global.get_player()._receive_server_protect_spawn()

func _on_add_fake_health() -> void:
	if !multiplayer.is_server():
		Global.get_player()._receive_server_health(Global.get_player().health + 10)

func _on_add_fake_kills() -> void:
	Global.get_player().increment_kills()
	Global.play_kill_sound()
		
func _physics_process(delta : float) -> void:
	if visible:
		var brick_count : int = 0
		var bricks : Array = Global.get_world().get_children()
		for b : Node in bricks:
			if b is Brick:
				brick_count += 1
		debug_text.text = str("bricks in world: ", str(brick_count),
		"\nactive physics objects: ", Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"\ndraw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"\nmaterial cache size: ", str(Global.graphics_cache.size()), " / 256",
		"\nball colour cache size: ", str(Global.ball_colour_cache.size()), " / 64",
		"\nmesh cache size: ", str(Global.mesh_cache.size()), " / 128")
		var player : RigidPlayer = Global.get_player()
		if player != null:
			debug_text.text += str("\nPlayer linear velocity total:", round(player.linear_velocity.length()), 
			"\nPlayer position (global): ", round(player.global_position), 
			"\nPlayer friction: ", player.physics_material_override.friction,
			"\nPlayer linear damp: ", player.linear_damp,
			"\nPlayer last hit by: ", player.last_hit_by_id,
			"\nPlayer occupying seat: ", player.seat_occupying)
		if Global.get_world().get_current_map() and Global.get_world().get_current_map().get_teams():
			var teams : Teams = Global.get_world().get_current_map().get_teams()
			debug_text.text += str("\n------------PLAYER TEAMS INFO ------------\n")
			for t : Team in teams.get_team_list():
				var team_name : String = t.name
				debug_text.text += str("\n----- ", team_name, " -----\n")
				debug_text.text += str(teams.get_players_in_team(team_name))
