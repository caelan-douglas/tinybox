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

extends Tool
class_name BuildTool

enum BuildMode {
	BUILD,
	DELETE,
	SAVE,
	LOAD
}

var _mode : BuildMode = BuildMode.BUILD
var building := false
var last_delete_hovered : Node3D = null
var switched_type := false
var brick_types := []
var brick_materials := []
var selected_brick_material : Brick.BrickMaterial = Brick.BrickMaterial.WOODEN
var selected_brick_type : int = 0
var brick_rotation_x : float = 0
var brick_rotation_y : float = 0
var mode_text : Label = null
var load_mode_name_text : Label = null
var load_mode_img : TextureRect = null
var load_mode_bg : ColorRect = null
@onready var brick_groups : BrickGroups = Global.get_world().get_node("BrickGroups")

@export var tool_name := "Build Tool"

# load not preload as buildings can also spawn bricks, and instantiated children cannot also preload
# and buildtool is spawned by inventory

@onready var load_arrow : PackedScene = preload("res://data/scene/ui/LoadArrow.tscn")

func _ready() -> void:
	# Create new tool.
	super.init("Build Tool", get_parent().get_parent() as RigidPlayer)
	# The types of bricks this can use.
	brick_types = [SpawnableObjects.objects["brick"], 
	SpawnableObjects.objects["brick_half"], 
	SpawnableObjects.objects["brick_cylinder"], 
	SpawnableObjects.objects["brick_cylinder_large"], 
	SpawnableObjects.objects["brick_motor_seat"],
	SpawnableObjects.objects["brick_lamp"]]
	# The materials of bricks this can use. Corresponds to the enums in
	# Brick.gd.
	brick_materials = [Brick.BrickMaterial.WOODEN, 
	Brick.BrickMaterial.METAL, 
	Brick.BrickMaterial.PLASTIC, 
	Brick.BrickMaterial.RUBBER]
	
	tool_overlay = get_tree().current_scene.get_node_or_null("GameCanvas/ToolOverlay/BuildTool")
	mode_text = tool_overlay.get_node_or_null("ModeLabel")
	load_mode_name_text = tool_overlay.get_node_or_null("LoadModeBg/LoadModeName")
	load_mode_bg = tool_overlay.get_node_or_null("LoadModeBg")
	load_mode_img = tool_overlay.get_node_or_null("LoadModeBg/LoadModeImg")

# Set whether or not this is in building mode.
func set_building(mode : bool) -> void:
	building = mode

# Spawn a new brick.
@rpc("call_local", "reliable")
func spawn_brick(id : int, brick_type : int, material : Brick.BrickMaterial) -> void:
	var b : Brick = brick_types[brick_type].instantiate()
	Global.get_world().add_child(b, true)
	b.spawn.rpc(id, material)

func set_tool_active(mode : bool, from_click : bool = false, free_camera_on_inactive : bool = true) -> void:
	# Exit delete mode if the tool is put away and brought back out.
	super(mode, from_click, free_camera_on_inactive)
	change_mode(BuildMode.BUILD)
	build_offset_y = 0
	# no longer building when inactive
	if mode == false:
		set_building(false)

func change_mode(new : BuildMode) -> void:
	if new == _mode: return
	_mode = new
	
	# delete arrow outside of load mode
	if new != BuildMode.LOAD:
		if spawned_load_arrow != null:
			spawned_load_arrow.queue_free()
			load_mode_bg.visible = false
	
	# enter mode
	match(_mode):
		BuildMode.BUILD:
			if mode_text:
				mode_text.text = "MODE: BUILD"
		BuildMode.DELETE:
			if mode_text:
				mode_text.text = "MODE: DELETE"
		BuildMode.SAVE:
			brick_groups = Global.get_world().get_node("BrickGroups")
			if mode_text:
				mode_text.text = "MODE: SAVE"
		BuildMode.LOAD:
			brick_groups = Global.get_world().get_node("BrickGroups")
			just_entered_load_mode = true
			load_mode_bg.visible = true
			if mode_text:
				mode_text.text = "MODE: LOAD"

var spawned_load_arrow : Node3D = null
var load_dir : DirAccess = null
var file_name := ""
var just_entered_load_mode := false
var can_load := true
var build_offset_y := 0

func _set_can_load(mode : bool) -> void:
	can_load = mode

func _process(delta : float) -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	
	# If the tool is active (ui partner selected)
	if get_tool_active():
		# Switch material.
		if Input.is_action_just_pressed("debug_action_m"):
			# move through each brick type
			if ((selected_brick_material + 1) >= brick_materials.size()):
				selected_brick_material = 0
			else: selected_brick_material += 1
			switched_type = true
		
		# Switch type.
		if Input.is_action_just_pressed("debug_action_t"):
			# move through each brick type
			if ((selected_brick_type + 1) >= brick_types.size()):
				selected_brick_type = 0
			else: selected_brick_type += 1
			switched_type = true
		
		if Input.is_action_just_pressed("shift"):
			build_offset_y += 1
		elif Input.is_action_just_pressed("control"):
			build_offset_y -= 1
		build_offset_y = clamp(build_offset_y, 0, 3)
		
		# Switch delete/build/save/load mode.
		if Input.is_action_just_pressed("build_tool_mode"):
			match(_mode):
				BuildMode.BUILD:
					change_mode(BuildMode.DELETE)
				BuildMode.DELETE:
					change_mode(BuildMode.SAVE)
				BuildMode.SAVE:
					change_mode(BuildMode.LOAD)
				BuildMode.LOAD:
					change_mode(BuildMode.BUILD)
		
		# If we are not building, and we select the build tool, set it to
		# building and spawn a new brick.
		if !building && _mode == BuildMode.BUILD:
			set_building(true)
			# if we are NOT the server,
			# make server spawn brick so it is synced by MultiplayerSpawner
			if !multiplayer.is_server():
				spawn_brick.rpc_id(1, multiplayer.get_unique_id(), selected_brick_type, brick_materials[selected_brick_material])
			else:
				spawn_brick(multiplayer.get_unique_id(), selected_brick_type, brick_materials[selected_brick_material] as Brick.BrickMaterial)
		
		# Delete mode
		if _mode == BuildMode.DELETE:
			# get mouse position in 3d space
			var m_3d : Dictionary = get_viewport().get_camera_3d().get_mouse_pos_3d()
			var m_pos_3d := Vector3()
			# we must check if the mouse's ray is not hitting anything
			if m_3d:
				# if it is hitting something
				m_pos_3d = m_3d["position"] as Vector3
			if m_3d:
				# if we are hovering a brick
				if m_3d["collider"].owner is Brick:
					var brick : Brick = m_3d["collider"].owner
					if brick.player_from != null:
						# can't delete another team's brick
						if brick.player_from.team != tool_player_owner.team:
							UIHandler.show_alert("Can't delete! Brick belongs to another team", 2, false, UIHandler.alert_colour_error)
							return
					brick.show_delete_overlay()
					if Input.is_action_just_pressed("click"):
						var minigame : Object = Global.get_world().minigame
						if minigame != null:
							# only base defense has costs
							if minigame is MinigameBaseDefense:
								if minigame.playing_team_names.has(tool_player_owner.team):
									# refund brick
									var cost : int = 2
									# minigame costs
									if brick._material == Brick.BrickMaterial.METAL:
										cost = 8
									elif brick._material == Brick.BrickMaterial.RUBBER:
										cost = 7
									minigame.set_team_cash(tool_player_owner.team, cost)
						# despawn brick
						brick.despawn.rpc()
		
		# Save mode
		if _mode == BuildMode.SAVE:
			# get mouse position in 3d space
			var m_3d : Dictionary = get_viewport().get_camera_3d().get_mouse_pos_3d()
			var m_pos_3d := Vector3()
			# we must check if the mouse's ray is not hitting anything
			if m_3d:
				# if it is hitting something
				m_pos_3d = m_3d["position"] as Vector3
			if m_3d:
				var hovered_group := []
				# if we are hovering a brick and we are NOT auth
				if (m_3d["collider"] is Brick && (m_3d["collider"].get_multiplayer_authority() != get_multiplayer_authority())) || (m_3d["collider"].get_parent() is Brick && (m_3d["collider"].get_parent().get_multiplayer_authority() != get_multiplayer_authority())):
					var hov_brick := m_3d["collider"] as Brick
					if m_3d["collider"].get_parent() is Brick:
						hov_brick = m_3d["collider"].get_parent()
					if !brick_groups.non_auth_group.has(hov_brick.name) && brick_groups.receive_timeout < 1:
						brick_groups.non_auth_group = []
						hov_brick.request_group_from_authority.rpc_id(hov_brick.get_multiplayer_authority(), multiplayer.get_unique_id())
					for b : String in brick_groups.non_auth_group:
						var found_brick : Brick = Global.get_world().get_node_or_null(NodePath(str(b))) as Brick
						if found_brick != null:
							if !Input.is_action_just_pressed("click"):
								found_brick.show_save_overlay()
							if !hovered_group.has(found_brick):
								hovered_group.append(found_brick)
				# if we ARE auth
				elif m_3d["collider"].owner is Brick && (m_3d["collider"].owner.get_multiplayer_authority() == get_multiplayer_authority()):
					var brick : Brick = m_3d["collider"].owner
					var group : String = brick.group
					# show save appearance on all bricks
					for b : Variant in brick_groups.groups[str(group)]:
						if b != null:
							b = b as Brick
							if !Input.is_action_just_pressed("click"):
								b.show_save_overlay()
							if !hovered_group.has(b):
								hovered_group.append(b)
				
				if Input.is_action_just_pressed("click") && hovered_group.size() > 0:
					var dir := DirAccess.open("user://building")
					if !dir:
						DirAccess.make_dir_absolute("user://building")
					
					# save building to file
					dir = DirAccess.open("user://building")
					var count : int = 0
					if dir:
						dir.list_dir_begin()
						var file_name := dir.get_next()
						while file_name != "":
							if !dir.current_is_dir():
								count += 1
							file_name = dir.get_next()
					else:
						print("An error occurred when trying to access the path.")
					var save_name : String = str("Building", ("%X" % Time.get_unix_time_from_system()))
					
					# get frame image and save it
					# hide everything
					Global.get_player().visible = false
					get_tree().current_scene.get_node("GameCanvas").visible = false
					# wait 1 frame so we can get screenshot
					await get_tree().process_frame
					var img := get_viewport().get_texture().get_image()
					img.shrink_x2()
					var scrdir := DirAccess.open("user://building_scr")
					if !scrdir:
						DirAccess.make_dir_absolute("user://building_scr")
					img.save_jpg(str("user://building_scr/", save_name, ".jpg"))
					# show everything again
					Global.get_player().visible = true
					get_tree().current_scene.get_node("GameCanvas").visible = true
					UIHandler.show_alert(str("Saved as ", save_name), 4, false, UIHandler.alert_colour_gold)
					
					var file := FileAccess.open(str("user://building/", save_name, ".txt"), FileAccess.WRITE)
					for b : Node3D in hovered_group:
						if b != null:
							if b is Brick:
								var type : String = b._brick_spawnable_type
								file.store_string(str(type))
								for p : String in b.properties_to_save:
									file.store_string(str(" ; ", p , ":", b.get(p)))
								file.store_line("")
					file.close()
		# Load mode
		if _mode == BuildMode.LOAD:
			# get mouse position in 3d space
			var m_3d : Dictionary = get_viewport().get_camera_3d().get_mouse_pos_3d()
			var m_pos_3d := Vector3()
			# we must check if the mouse's ray is not hitting anything
			if m_3d:
				# if it is hitting something
				m_pos_3d = m_3d["position"] as Vector3
				# load arrow visual
				if spawned_load_arrow == null:
					spawned_load_arrow = load_arrow.instantiate()
					Global.get_world().add_child(spawned_load_arrow)
				spawned_load_arrow.global_position = m_pos_3d
				# avoid loading buildings in the ground
				m_pos_3d.y += 0.5
			if m_3d:
				if Input.is_action_just_pressed("load_next_building") || just_entered_load_mode:
					if !load_dir:
						load_dir = DirAccess.open("user://building")
					if load_dir:
						if just_entered_load_mode:
							load_dir.list_dir_begin()
						file_name = load_dir.get_next()
						# if we reach end, go back to start
						if file_name == "":
							load_dir.list_dir_begin()
							file_name = load_dir.get_next()
							# if there is still nothing, the folder is empty
							if file_name == "":
								UIHandler.show_alert("You have no saved buildings! Save something first.", 8, false, UIHandler.alert_colour_error)
						load_mode_name_text.text = str("Selected:\n", file_name.split(".")[0], "\n([ C ] for next)")
					else:
						UIHandler.show_alert("You have no saved buildings! Save something first.", 8, false, UIHandler.alert_colour_error)
					just_entered_load_mode = false
					
					# load image
					var scrdir := DirAccess.open("user://building_scr")
					if scrdir:
						var image := Image.load_from_file(str("user://building_scr/", file_name.split(".")[0], ".jpg"))
						var texture := ImageTexture.create_from_image(image)
						load_mode_img.texture = texture
				elif Input.is_action_just_pressed("click"):
					if can_load:
						var load_file := FileAccess.open(str("user://building/", file_name), FileAccess.READ)
						if load_file != null:
							# start delay timer
							can_load = false
							get_tree().create_timer(7).connect("timeout", _set_can_load.bind(true))
							# load building
							var lines := []
							while not load_file.eof_reached():
								var line := load_file.get_line()
								lines.append(str(line))
							if multiplayer.is_server():
								Global.get_world()._server_load_building(lines, m_pos_3d)
							else:
								Global.get_world().ask_server_to_load_building.rpc_id(1, Global.display_name, lines, m_pos_3d)
						else:
							UIHandler.show_alert("Building not found or corrupt!", 8, false, UIHandler.alert_colour_error)
					else:
						UIHandler.show_alert("Wait a bit before trying to load another building!", 5, false, UIHandler.alert_colour_error)
				elif Input.is_action_just_pressed("delete"):
					DirAccess.remove_absolute(str("user://building/", file_name))
					DirAccess.remove_absolute(str("user://building_scr/", file_name.split(".")[0], ".jpg"))
					UIHandler.show_alert("Building deleted.", 4, false, UIHandler.alert_colour_error)
					# load next building
					just_entered_load_mode = true
