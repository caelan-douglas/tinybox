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

@onready var col1 : RichTextLabel = $HBoxContainer/DebugCol1
@onready var col2 : RichTextLabel = $HBoxContainer/DebugCol2

var raycast : RayCast3D

func _ready() -> void:
	Global.connect("debug_toggled", _on_debug_toggled)
	raycast = RayCast3D.new()
	add_child(raycast)

func _on_debug_toggled(mode : bool) -> void:
	visible = mode

func _physics_process(delta : float) -> void:
	if visible:
		# slow but only if debug menu is visible
		var brick_count : int = 0
		var bricks : Array = Global.get_world().get_children()
		for b : Node in bricks:
			if b is Brick:
				brick_count += 1
		col1.text = str("[b]Compute				(", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS), "s)[/b]",
		"\n[b]	Bricks[/b]				", str(brick_count),
		"\n[b]	Physics[/b]			", Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"\n[b]	Objects[/b]			", str(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"\n[b]	Orphans[/b]			", str(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"\n[b]	Collisions[/b]		", str(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)),
		"\n[b]	Memory[/b]			", round(OS.get_static_memory_usage() * 0.000001), "mb",
		"\n\n[b]Draw					(", Performance.get_monitor(Performance.TIME_PROCESS), "s)[/b]",
		"\n[b]	Drawcalls[/b]		", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"\n[b]	Mat. Cache[/b]		", str(Global.graphics_cache.size()), " / 256",
		"\n[b]	Ball Cache[/b]		", str(Global.ball_colour_cache.size()), " / 64",
		"\n[b]	Mesh Cache[/b]	", str(Global.mesh_cache.size()), " / 128",
		"\n[b]	Video Mem[/b]	", str(round(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) * 0.000001), "mb"),
		"\n\n[b]System[/b]",
		"\n[b]	Platform[/b]		", OS.get_name(), " ", OS.get_version(),
		"\n[b]	Processor[/b]		", OS.get_processor_name(),
		"\n[b]	Graphics[/b]			", RenderingServer.get_rendering_device().get_device_name(),
		"\n[b]	Gfx API[/b]			", RenderingServer.get_current_rendering_driver_name().capitalize())
		var player : RigidPlayer = Global.get_player()
		if player != null:
			col2.text = str("\n[b]Player[/b]", 
			"\n[b]	Velocity[/b]				", round(player.linear_velocity.length()), 
			"\n[b]	Position[/b]				", round(player.global_position), 
			"\n[b]	Friction[/b]				", player.physics_material_override.friction, 
			"\n[b]	Last hit by[/b]			", player.last_hit_by_id, 
			"\n[b]	Seat[/b]					", player.seat_occupying,
			"\n[b]	On object[/b]			", player.standing_on_object)
		else:
			col2.text = str("\n[b]No player info available.[/b]")
		
		# facing obj data from raycast
		if raycast:
			var cam : Camera3D = get_viewport().get_camera_3d()
			raycast.global_position = cam.global_position
			raycast.target_position = cam.global_position + (cam.basis.z * -1000)
			
			if raycast.is_colliding():
				col2.text += str("\n\n[b]Facing[/b]")
				if raycast.get_collider() is Brick:
					var b : Brick = raycast.get_collider() as Brick
					col2.text += str("\n\n[b]Brick[/b]",
					"\n[b]	Name[/b]			", b.name,
					"\n[b]	Glued?[/b]		", b.glued,
					"\n[b]	Frozen?[/b]		", b.freeze)
					if b is MotorBrick:
						col2.text += str("\n[b]	Last input[/b]		", b.last_input_time)
					for j : Node in b.get_children():
						if j is Generic6DOFJoint3D:
							col2.text += str("\n[b]	Joint[/b]		", j.name)
			
		#if Global.get_world().get_current_map() and Global.get_world().get_current_map().get_teams():
		#	var teams : Teams = Global.get_world().get_current_map().get_teams()
		#	col2.text += str("\n\n[b]Teams[/b]")
		#	for t : Team in teams.get_team_list():
		#		var team_name : String = t.name
		#		col2.text += str("\n[b]	", team_name, "[/b]")
		#		col2.text += str("\n		", teams.get_players_in_team(team_name))
