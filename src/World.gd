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
class_name World
signal map_loaded
signal map_deleted
signal tbw_loaded

var rigidplayer_list : Array = []
@onready var loading_canvas : CanvasLayer = get_tree().current_scene.get_node("LoadingCanvas")

# active minigame
var minigame : Minigame = null

func add_player_to_list(player : RigidPlayer) -> void:
	if !rigidplayer_list.has(player):
		rigidplayer_list.append(player)
	
func remove_player_from_list(player : RigidPlayer) -> void:
	if rigidplayer_list.has(player):
		rigidplayer_list.erase(player)

func teleport_player(player : RigidPlayer, pos : Vector3) -> void:
	await get_tree().process_frame
	player.global_position = Vector3(float(pos.x), float(pos.y), float(pos.z))

func teleport_all_players(pos : Vector3) -> void:
	await get_tree().process_frame
	for p : RigidPlayer in rigidplayer_list:
		p.global_position = Vector3(float(pos.x), float(pos.y), float(pos.z))

func _ready() -> void:
	Global.connect("graphics_preset_changed", _on_graphics_preset_changed)
	$MultiplayerMapSpawner.connect("spawned", _on_multiplayer_map_spawned)
	multiplayer.peer_connected.connect(_on_peer_connected)

func _on_peer_connected(id : int) -> void:
	if !multiplayer.is_server(): return
	
	print("peer connected on world: ", str(id))
	
	if minigame != null:
		var connected_win_cond : Lobby.GameWinCondition = Lobby.GameWinCondition.BASE_DEFENSE
		if minigame is MinigameDM:
			connected_win_cond = Lobby.GameWinCondition.DEATHMATCH
			if minigame.tdm:
				connected_win_cond = Lobby.GameWinCondition.TEAM_DEATHMATCH
		elif minigame is MinigameKing:
			connected_win_cond = Lobby.GameWinCondition.KINGS
		start_minigame.rpc_id(id, "", connected_win_cond, true)
	
	# sync tbw objects
	for obj : Node in get_children():
		if obj is TBWObject:
			var tbw : TBWObject = obj as TBWObject
			sync_tbw_obj_properties.rpc(tbw.get_path(), tbw.global_position, tbw.global_rotation, tbw.scale)

func _on_multiplayer_map_spawned(map : Map) -> void:
	emit_signal("map_loaded")

# Starts a new minigame with the scene's map name and a win condition.
@rpc("any_peer", "call_local", "reliable")
func start_minigame(map_name : String, win_condition : Lobby.GameWinCondition, from_new_peer_connection := false) -> void:
	minigame = null
	match (win_condition):
		Lobby.GameWinCondition.DEATHMATCH:
			minigame = MinigameDM.new(false)
		Lobby.GameWinCondition.TEAM_DEATHMATCH:
			minigame = MinigameDM.new(true)
		Lobby.GameWinCondition.KINGS:
			minigame = MinigameKing.new()
		_:
			minigame = MinigameBaseDefense.new()
	
	# load intended map
	clear_world()
	# only load if a name was actually given
	if map_name != "":
		load_map(load(str("res://data/scene/", map_name, "/", map_name, ".tscn")) as PackedScene)
	
	# create minigame
	var teams : Array = get_current_map().get_teams().get_team_list()
	minigame.playing_team_names = [teams[1].name, teams[2].name]
	minigame.name = "Minigame"
	# if a player has joined midway, sync some properties from server
	if from_new_peer_connection:
		minigame.from_new_peer_connection = true
	add_child(minigame)

func _on_graphics_preset_changed() -> void:
	match Global.get_graphics_preset():
		# COOL
		0:
			if $Map.get_children().size() > 0:
				var loaded_map : Map = $Map.get_child(0)
				if loaded_map.has_node("WorldEnvironment"):
					var env : WorldEnvironment = loaded_map.get_node("WorldEnvironment")
					env.environment.ssao_enabled = true
					env.environment.ssil_enabled = true
				var light : Node = loaded_map.get_node_or_null("DirectionalLight3D")
				if light:
					light.shadow_enabled = true
				var caff_light : Node = loaded_map.get_node_or_null("SpotLight3D")
				if caff_light:
					light.shadow_enabled = true
		# BAD
		1:
			if $Map.get_children().size() > 0:
				var loaded_map : Map = $Map.get_child(0)
				if loaded_map.has_node("WorldEnvironment"):
					var env : WorldEnvironment = loaded_map.get_node("WorldEnvironment")
					env.environment.ssao_enabled = false
					env.environment.ssil_enabled = false
				var light : Node = loaded_map.get_node_or_null("DirectionalLight3D")
				if light:
					light.shadow_enabled = true
				var caff_light : Node = loaded_map.get_node_or_null("SpotLight3D")
				if caff_light:
					light.shadow_enabled = true
		# AWFUL
		2:
			if $Map.get_children().size() > 0:
				var loaded_map : Map = $Map.get_child(0)
				if loaded_map.has_node("WorldEnvironment"):
					var env : WorldEnvironment = loaded_map.get_node("WorldEnvironment")
					env.environment.ssao_enabled = false
					env.environment.ssil_enabled = false
				# no shadows on awful graphics
				var light : Node = loaded_map.get_node_or_null("DirectionalLight3D")
				if light:
					light.shadow_enabled = false
				var caff_light : Node = loaded_map.get_node_or_null("SpotLight3D")
				if caff_light:
					light.shadow_enabled = false

# Get the current map.
func get_current_map() -> Map:
	return $Map.get_child(0)

func delete_old_map() -> void:
	# Remove old map (if it exists)
	var old_map : Node3D = $Map
	for c : Node in old_map.get_children():
		old_map.remove_child(c)
		c.queue_free()
	emit_signal("map_deleted")

# Call this function deferred and only on the main authority (server).
func load_map(map: PackedScene) -> void:
	delete_old_map()
	# Add new level.
	var current_map : Map = map.instantiate()
	$Map.add_child(current_map)
	emit_signal("map_loaded")

# Save the currently open world as a .tbw file.
func save_tbw(world_name : String) -> void:
	var dir : DirAccess = DirAccess.open("user://world")
	if !dir:
		DirAccess.make_dir_absolute("user://world")
	
	# save building to file
	dir = DirAccess.open("user://world")
	var count : int = 0
	if dir:
		dir.list_dir_begin()
		var file_name : String = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir():
				count += 1
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	var save_name : String = str(world_name)
	
	# get frame image and save it
	# hide everything
	if get_current_map() is Editor:
		# only hide editor ui
		get_tree().current_scene.get_node("EditorCanvas").visible = false
		# wait 1 frame so we can get screenshot
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.shrink_x2()
		var scrdir := DirAccess.open("user://world_scr")
		if !scrdir:
			DirAccess.make_dir_absolute("user://world_scr")
		img.save_jpg(str("user://world_scr/", save_name, ".jpg"))
		get_tree().current_scene.get_node("EditorCanvas").visible = true
	else:
		Global.get_player().visible = false
		get_tree().current_scene.get_node("GameCanvas").visible = false
		# wait 1 frame so we can get screenshot
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.shrink_x2()
		var scrdir := DirAccess.open("user://world_scr")
		if !scrdir:
			DirAccess.make_dir_absolute("user://world_scr")
		img.save_jpg(str("user://world_scr/", save_name, ".jpg"))
		# show everything again
		Global.get_player().visible = true
		get_tree().current_scene.get_node("GameCanvas").visible = true
	UIHandler.show_alert(str("Saved world as ", save_name, ".tbw."), 4, false, false, true)
	
	# Create tbw file.
	var file := FileAccess.open(str("user://world/", save_name, ".tbw"), FileAccess.WRITE)
	# Save objects before bricks
	for obj in get_children():
		if obj != null:
			if obj is TBWObject:
				var type : String = obj.tbw_object_type
				file.store_string(str(type))
				for p : String in obj.properties_to_save:
					file.store_string(str(" ; ", p , ":", obj.get(p)))
				file.store_line("")
			elif obj is TBWEnvironment:
				file.store_line(str("Environment ; ", obj.environment_name))
	# Store bricks in the same format as buildings.
	
	# Make sure there is actually a brick to save
	var found_brick := false
	for b : Node in get_children():
		if b != null:
			if b is Brick:
				if found_brick == false:
					file.store_line(str("[building]"))
					found_brick = true
				var type : String = b._brick_spawnable_type
				file.store_string(str(type))
				for p : String in b.properties_to_save:
					file.store_string(str(" ; ", p , ":", b.get(p)))
				file.store_line("")
	file.close()

func load_tbw(file_name := "test", internal := false) -> void:
	print("Attempting to load ", file_name, ".tbw")
	
	var load_file : FileAccess = null
	if internal:
		load_file = FileAccess.open(str("res://data/tbw/", file_name, ".tbw"), FileAccess.READ)
		# if file does not exist
		if load_file == null:
			# check user
			load_file = FileAccess.open(str("user://world/", file_name, ".tbw"), FileAccess.READ)
	else:
		load_file = FileAccess.open(str("user://world/", file_name, ".tbw"), FileAccess.READ)
		# if file does not exist
		if load_file == null:
			# check internal
			load_file = FileAccess.open(str("res://data/tbw/", file_name, ".tbw"), FileAccess.READ)
	if load_file != null:
		# load building
		var lines := []
		while not load_file.eof_reached():
			var line := load_file.get_line()
			lines.append(str(line))
		if multiplayer.is_server():
			_parse_and_open_tbw(lines)
		else:
			ask_server_to_open_tbw.rpc_id(1, Global.display_name, lines)
	else:
		UIHandler.show_alert("World not found or corrupt!", 8, false, true)

# server loads tbws
@rpc("any_peer", "call_local", "reliable")
func ask_server_to_open_tbw(name_from : String, lines : Array) -> void:
	if !multiplayer.is_server(): return
	_parse_and_open_tbw(lines)

# Only to be run as server
func _parse_and_open_tbw(lines : Array) -> void:
	if !multiplayer.is_server(): return
	
	clear_world()
	# Load default empty map, unless we are in the editor
	if !(Global.get_world().get_current_map() is Editor):
		load_map(load(str("res://data/scene/BaseWorld/BaseWorld.tscn")) as PackedScene)
	
	# BIG file, show loading visual
	var loading_text : Label = loading_canvas.get_node("Label")
	if lines.size() > 100:
		loading_canvas.visible = true
	
	var current_step := "none"
	var count : int = 0
	# amount of lines to read in a frame
	var max_proc := 32
	var cur_proc := 0
	# run through each line
	for line : String in lines:
		cur_proc += 1
		# wait a frame if we have read max lines for this frame
		if cur_proc > max_proc:
			await get_tree().process_frame
			cur_proc = 0
			if loading_canvas.visible:
				loading_text.text = str("Loading .tbw file...     Objects: ", count)
		if line != "":
			# final step, place building
			if str(line) == "[building]":
				# disable loading canvas if we used it
				loading_canvas.visible = false
				# load building portion, use global pos
				_server_load_building(lines.slice(count+1), Vector3.ZERO, true)
				break
			# Load other world elements, like environment, objects, etc.
			else:
				var line_split := line.split(" ; ")
				var inst : Node = null
				var props := true
				await get_tree().process_frame
				match line_split[0]:
					# World environments don't have pos or rotation
					"Environment":
						props = false
						if line_split.size() > 1:
							# name to spawnable object dict key
							if SpawnableObjects.objects.has(line_split[1]):
								var ret : PackedScene = SpawnableObjects.objects[line_split[1]]
								if ret != null:
									inst = ret.instantiate()
					_:
						# all other objects
						if SpawnableObjects.objects.has(line_split[0]):
							var ret : PackedScene = SpawnableObjects.objects[line_split[0]]
							if ret != null:
								inst = ret.instantiate()
				# ignore invalid items
				if inst != null:
					add_child(inst, true)
					# if this object has properties
					if props:
						var prop_list := line_split.slice(1)
						for p : String in prop_list:
							var property_split := p.split(":")
							# name is first half
							var property_name := property_split[0]
							# don't load scripts
							if property_name != "script":
								# determine type of second half
								var property : Variant = Global.property_string_to_property(property_name, property_split[1])
								# set the property
								inst.set(property_name, property)
						sync_tbw_obj_properties.rpc(inst.get_path(), inst.global_position, inst.global_rotation, inst.scale)
		count += 1
	# reset all player cameras once world is done loading
	reset_player_cameras.rpc()
	# announce we are done loading
	emit_signal("tbw_loaded")

@rpc("any_peer", "call_remote", "reliable")
func sync_tbw_obj_properties(obj_path : String, new_pos : Vector3, new_rot : Vector3, new_scale : Vector3) -> void:
	var node : Node3D = get_node_or_null(obj_path)
	if node:
		node.global_position = new_pos
		node.global_rotation = new_rot
		node.scale = new_scale

@rpc("any_peer", "call_local", "reliable")
func reset_player_cameras() -> void:
	# refind node
	var camera : Camera3D = get_viewport().get_camera_3d()
	if camera is Camera:
		Global.get_player().set_camera(camera)

@rpc("any_peer", "call_local", "reliable")
func clear_world() -> void:
	clear_bricks()
	for node in get_children():
		if node is TBWObject || node is TBWEnvironment:
			node.queue_free()

@rpc("any_peer", "call_local", "reliable")
func clear_bricks() -> void:
	# remove all existing bricks
	for b in get_children():
		if b is Brick:
			b.despawn()

func send_start_lobby() -> void:
	if has_node("Minigame"):
		$Minigame.delete.rpc()
	start_lobby.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func start_lobby() -> void:
	load_map(load("res://data/scene/Lobby/Lobby.tscn") as PackedScene)

# server places bricks
@rpc("any_peer", "call_local", "reliable")
func ask_server_to_load_building(name_from : String, lines : Array, b_position : Vector3) -> void:
	if !multiplayer.is_server(): return
	_server_load_building(lines, b_position)

# TODO: should do this in a thread
func _server_load_building(lines : PackedStringArray, b_position : Vector3, use_global_position := false) -> void:
	if !multiplayer.is_server(): return
	
	var building_group := []
	var first_brick_pos := Vector3.ZERO
	
	var line_split_init : PackedStringArray = lines[0].split(";")
	var offset_pos := Vector3.ZERO
	# convert global position into 'local' with offset of first brick
	if !use_global_position:
		var building_pos : PackedStringArray = line_split_init[1].split(",")
		offset_pos = Vector3(float(building_pos[0]), float(building_pos[1]), float(building_pos[2]))
	
	# BIG file, show loading visual
	var loading_text : Label = loading_canvas.get_node("Label")
	if lines.size() > 100:
		loading_canvas.visible = true
	
	### Reading file
	# amount of lines to read in a frame
	var max_proc := 32
	var cur_proc := 0
	var total_proc := 0
	print(str("Building: reading lines... ", Time.get_ticks_msec()))
	for line : String in lines:
		cur_proc += 1
		total_proc += 1
		# wait a frame if we have read max lines for this frame
		if cur_proc > max_proc:
			await get_tree().process_frame
			cur_proc = 0
			if loading_canvas.visible:
				loading_text.text = str("Loading file...     Bricks: ", total_proc)
		if line != "":
			var line_split := line.split(" ; ")
			if SpawnableObjects.objects.has(line_split[0]):
				var b : Brick = SpawnableObjects.objects[line_split[0]].instantiate()
				add_child(b, true)
				building_group.append(b)
				b.change_state.rpc(Brick.States.PLACED)
				var prop_list := line_split.slice(1)
				for p : String in prop_list:
					var property_split := p.split(":")
					# name is first half
					var property_name := property_split[0]
					# determine type of second half
					var property : Variant = Global.property_string_to_property(property_name, property_split[1])
					# set the property
					b.set(property_name, property)
	
	### Placing bricks
	
	# don't place nothing
	if building_group.size() < 1:
		printerr("Building: Tried to load building with nothing in it.")
		UIHandler.show_alert.rpc("A corrupt or empty building could not be loaded.", 7, false, true, false)
		return
	# change ownership first
	# wait a bit before checking joints
	await get_tree().create_timer(0.1).timeout
	# update first brick pos for sorter
	first_brick_pos = building_group[0].global_position
	var building_group_extras := []
	# sort array by position
	building_group.sort_custom(_pos_sort)
	# first make all basic brick colliders disabled
	for b : Brick in building_group:
		b.joinable = false
		b.model_mesh.visible = false
	# now move all extra bricks (motorseat, motorbrick) to building_group_extras
	for b : Brick in building_group:
		if b is MotorBrick || b is MotorSeat:
			building_group_extras.append(b)
			building_group.erase(b)
	# resort basic bricks
	building_group.sort_custom(_pos_sort)
	# now for each basic brick:
	# 1. enable its collider
	# 2. check neighbours
	var count : int = 0
	for b : Brick in building_group:
		b.joinable = true
		b.model_mesh.visible = true
		b.check_joints()
		if count == 1:
			# recheck first brick in array on second brick check
			# (never gets chance to join)
			building_group[0].check_joints()
		count += 1
	# now for each extra brick:
	# 1. enable its collider
	# 2. check neighbours
	await get_tree().process_frame
	count = 0
	for b : Brick in building_group_extras:
		b.joinable = true
		b.model_mesh.visible = true
		b.check_joints()
		count += 1
	
	print(str("Done loading building", Time.get_ticks_msec()))
	loading_canvas.visible = false

var first_brick_pos : Vector3 = Vector3.ZERO
func _pos_sort(a : Node3D, b : Node3D) -> bool:
	return a.global_position.distance_to(first_brick_pos) < b.global_position.distance_to(first_brick_pos)
