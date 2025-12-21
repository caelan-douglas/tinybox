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
var gamemode_list : Array[Gamemode] = []

@onready var loading_canvas : CanvasLayer = get_tree().current_scene.get_node("LoadingCanvas")
var tbw_loading : bool = false

var last_tbw_load_time : int = 0

func get_spawnpoint_for_team(team_name : String) -> Array[Vector3]:
	var spawns : Array[Vector3] = []
	for obj in get_children():
		if obj is SpawnPoint:
			if obj.team_name == team_name && !obj.checkpoint:
				spawns.append(obj.global_position)
	if spawns == []:
		# default spawn
		spawns.append(Vector3(0, 51, 0))
	return spawns

func change_player_team(who : RigidPlayer, what_team : Team) -> void:
	# broadcast updated team to peers
	who.update_team.rpc(what_team.name)
	# update info on player's client side
	who.update_info.rpc_id(who.get_multiplayer_authority())

func add_player_to_list(player : RigidPlayer) -> void:
	if !rigidplayer_list.has(player):
		rigidplayer_list.append(player)
	
func remove_player_from_list(player : RigidPlayer) -> void:
	if rigidplayer_list.has(player):
		rigidplayer_list.erase(player)

func teleport_all_players(pos : Vector3) -> void:
	await get_tree().process_frame
	for p : RigidPlayer in rigidplayer_list:
		p.teleport(Vector3(float(pos.x), float(pos.y), float(pos.z)))

func _ready() -> void:
	$MultiplayerMapSpawner.connect("spawned", _on_multiplayer_map_spawned)
	multiplayer.peer_connected.connect(_on_peer_connected)

func _on_peer_connected(id : int) -> void:
	if !multiplayer.is_server(): return
	
	print("peer connected on world: ", str(id))
	
	# sync tbw objects
	for obj : Node in get_children():
		if obj is TBWObject:
			var tbw : TBWObject = obj as TBWObject
			sync_tbw_obj_properties.rpc_id(id, tbw.get_path(), tbw.properties_as_dict())

func _on_multiplayer_map_spawned(map : Map) -> void:
	emit_signal("map_loaded")

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

# Save the currently open world as a .tbw file. Returns false if did not save.
func save_tbw(world_name : String, server : bool = false, selection : Array = [], temp : bool = false) -> bool:
	# don't save worlds that are currently loading
	if tbw_loading:
		UIHandler.show_alert("Please wait for the world to load before saving it!", 5, false, UIHandler.alert_colour_error)
		return false
	
	# check if there is a given selection
	var saving_entire_world : bool = false
	if selection.is_empty():
		saving_entire_world = true
		selection = get_children()
	
	if !temp && world_name == "temp":
		UIHandler.show_alert("That name is reserved for internal use! Please pick another.", 5, false, UIHandler.alert_colour_error)
	
	for map : String in Global.get_internal_tbw_names():
		var internal_name : String = map.split(".")[0]
		if internal_name == world_name:
			UIHandler.show_alert(str("That world name (", world_name, ") is\nalready used by a built-in map! Please pick another."), 5, false, UIHandler.alert_colour_error)
			return false
	
	var dir : DirAccess = DirAccess.open("user://world")
	if saving_entire_world:
		if !dir:
			DirAccess.make_dir_absolute("user://world")
		# save building to file
		dir = DirAccess.open("user://world")
	else:
		dir = DirAccess.open("user://building")
		if !dir:
			DirAccess.make_dir_absolute("user://building")
		# save building to file
		dir = DirAccess.open("user://building")
	
	if server:
		dir = DirAccess.open(UserPreferences.os_path)
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
	
	var img : Image = null
	# get frame image and save it as raw->base64 on first line
	# hide everything
	# servers don't save images
	if !server:
		if get_current_map() is Editor:
			# only hide editor ui
			get_tree().current_scene.get_node("EditorCanvas").visible = false
			get_tree().current_scene.get_node("/root/PersistentScene/AlertCanvas").visible = false
			var editor : Editor = get_current_map()
			# wait 1 frame so we can get screenshot
			await get_tree().process_frame
			await get_tree().process_frame
			img = get_viewport().get_texture().get_image()
			img.shrink_x2()
			get_tree().current_scene.get_node("EditorCanvas").visible = true
			get_tree().current_scene.get_node("/root/PersistentScene/AlertCanvas").visible = true
		else:
			Global.get_player().visible = false
			get_tree().current_scene.get_node("GameCanvas").visible = false
			get_tree().current_scene.get_node("/root/PersistentScene/AlertCanvas").visible = false
			# wait a bit so we can get screenshot
			await get_tree().process_frame
			await get_tree().process_frame
			img = get_viewport().get_texture().get_image()
			img.shrink_x2()
			# show everything again
			Global.get_player().visible = true
			get_tree().current_scene.get_node("GameCanvas").visible = true
			get_tree().current_scene.get_node("/root/PersistentScene/AlertCanvas").visible = true
	if !temp:
		UIHandler.show_alert(str("Saved as ", save_name, ".tbw."), 4, false, UIHandler.alert_colour_gold)
	
	# Create tbw file.
	var file : FileAccess
	if server:
		file = FileAccess.open(str(UserPreferences.os_path, save_name, ".tbw"), FileAccess.WRITE)
	else:
		if saving_entire_world:
			file = FileAccess.open(str("user://world/", save_name, ".tbw"), FileAccess.WRITE)
		else:
			file = FileAccess.open(str("user://building/", save_name, ".tbw"), FileAccess.WRITE)
	# Save image first
	file.store_line("[tbw]")
	# save version
	file.store_line(str("version ; ", (get_tree().current_scene as Main).server_version))
	# author tag
	file.store_line(str("author ; ", Global.display_name))
	# store image data as base64 inside file
	# servers don't save images
	if !server:
		file.store_line(str("image ; ", Marshalls.raw_to_base64(img.save_jpg_to_buffer())))
	
	if saving_entire_world:
		# Save song list (if not using all songs)
		if get_current_map().songs.size() != MusicHandler.ALL_SONGS_LIST.size():
			file.store_line(str("songs ; ", JSON.stringify(get_current_map().songs)))
		# Save map properties
		file.store_line(str("death_limit_low ; ", get_current_map().death_limit_low))
		file.store_line(str("death_limit_high ; ", get_current_map().death_limit_high))
		file.store_line(str("respawn_time ; ", get_current_map().respawn_time))
		file.store_line(str("gravity_scale ; ", get_current_map().gravity_scale))
	# TBW object list
	file.store_line("[objects]")
	# Save objects before bricks
	for obj : Node in selection:
		if obj != null:
			if obj is TBWObject:
				var type : String = obj.tbw_object_type
				file.store_string(str(type))
				for p : String in obj.properties_to_save:
					# make sure strings dont add line breaks, replace them
					# with \n
					var value : Variant = obj.get(p)
					if obj.get(p) is String:
						value = value.c_escape()
					# stringify some properties
					if p == "start_events" || p == "watchers" || p == "end_events":
						value = JSON.stringify(value)
					# store property inline
					file.store_string(str(" ; ", p , ":", value))
				file.store_line("")
			elif obj is TBWEnvironment:
				file.store_line(str("Environment ; ", obj.environment_name))
	# Store bricks in the same format as buildings.
	
	# Make sure there is actually a brick to save
	var found_brick := false
	for b : Node in selection:
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
	return true

func load_tbw(file_name : String, switching := false, reset_player_and_cameras := true, server : bool = false) -> void:
	print("Attempting to load ", file_name, ".tbw")
	# prevent loading multiple files at once
	if tbw_loading:
		await tbw_loaded
		await get_tree().create_timer(0.3).timeout
	# get lines of file
	var lines : Array = Global.get_tbw_lines(file_name, server)
	if lines.size() > 0:
		# if we are server
		if multiplayer.is_server():
			# switching from pause menu, show "map switching" alert to users
			if switching:
				show_tbw_switch_alert(Global.display_name, file_name)
			open_tbw(lines, reset_player_and_cameras)
		# if we are client
		else:
			ask_server_to_open_tbw.rpc_id(1, Global.display_name, file_name, lines)
	else:
		UIHandler.show_alert("World not found or corrupt!", 8, false, UIHandler.alert_colour_error)

# server loads tbws
@rpc("any_peer", "call_local", "reliable")
func ask_server_to_open_tbw(name_from : String, world_name : String, lines : Array) -> void:
	if !multiplayer.is_server(): return
	if lines.is_empty():
		UIHandler.show_alert("World not found or corrupt!", 8, false, UIHandler.alert_colour_error)
		return
	if !Global.server_can_clients_load_worlds:
		UIHandler.show_alert.rpc_id(multiplayer.get_remote_sender_id(), "Sorry, clients are not permitted to change worlds in this server", 7, false, UIHandler.alert_colour_error)
		return
	# 10 seconds between loading buildings/maps
	elif Time.get_ticks_msec() - last_tbw_load_time < 10000:
		UIHandler.show_alert.rpc_id(multiplayer.get_remote_sender_id(), "Please wait before trying to load another building or world", 5, false, UIHandler.alert_colour_error)
		return
	else:
		last_tbw_load_time = Time.get_ticks_msec()
		_world_accepted(name_from, world_name, lines)
		#TODO: map voting system?
		#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		#var actions := UIHandler.show_alert_with_actions(str(name_from, " wishes to load the world \"", world_name, ".tbw\".\nAll bricks will be destroyed. Is this OK?"), ["Load world", "Do not load"], true)
		#actions[0].connect("pressed", _world_accepted.bind(name_from, world_name, lines))
		#actions[1].connect("pressed", _world_denied.bind(name_from, world_name))

func _world_denied(name_from : String, world_name : String) -> void:
	# if the alert showed when the game wasn't paused, go back to captured
	if !Global.is_paused && !Global.server_mode():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# show alert to all users that map was denied
	UIHandler.show_alert.rpc(str("Server denied loading world \"", world_name, ".tbw\"\ncreated by ", name_from), 7, false, UIHandler.alert_colour_error)

func _world_accepted(name_from : String, world_name : String, lines : Array) -> void:
	# if the alert showed when the game wasn't paused, go back to captured
	if !Global.is_paused && !Global.server_mode():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	open_tbw(lines)
	# show alert to all users that map was switched
	show_tbw_switch_alert(name_from, world_name)

func show_tbw_switch_alert(name_from : String, world_name : String) -> void:
	UIHandler.show_alert.rpc(str("Switched to world \"", world_name, "\"\nrequested by ", name_from), 7)

@rpc("authority", "call_local", "reliable")
func set_loading_canvas_visiblity(mode : bool) -> void:
	loading_canvas.visible = mode

@rpc("authority", "call_local", "reliable")
func set_loading_canvas_text(text : String) -> void:
	var loading_text : Label = loading_canvas.get_node("Panel/Label")
	loading_text.text = str(text)


func open_tbw(lines : Array, reset_camera_and_player : bool = true) -> void:
	if !multiplayer.is_server(): return
	# End the active gamemode if a new world is requested.
	var e : Event = Event.new(Event.EventType.END_ACTIVE_GAMEMODE, [])
	e.start()
	
	for p : RigidPlayer in rigidplayer_list:
		p.protect_spawn(3.5, false)
	await get_tree().physics_frame
	tbw_loading = true
	clear_world()
	# Load default empty map, unless we are in the editor
	if !(Global.get_world().get_current_map() is Editor):
		load_map(load(str("res://data/scene/BaseWorld/BaseWorld.tscn")) as PackedScene)
	
	# set fallback values
	Global.get_world().get_current_map().reset_map_properties()
	
	# BIG file, show loading visual
	if lines.size() > 100:
		set_loading_canvas_visiblity.rpc(true)
	
	var contained_world := await parse_tbw(lines)
	
	# reset all player cameras once world is done loading
	if reset_camera_and_player:
		reset_player_cameras.rpc()
		reset_player_positions.rpc()
	# add basic gamemodes
	_clear_gamemodes()
	add_all_gamemodes()
	print(gamemode_list)
	# announce we are done loading
	tbw_loading = false
	await get_tree().process_frame
	emit_signal("tbw_loaded")


# Only to be run as server or local client
func parse_tbw(lines : Array, return_as_container : bool = false) -> Node3D:
	var container := Node3D.new()
	if return_as_container:
		add_child(container)
	
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
				set_loading_canvas_text.rpc(str("Loading .tbw file...     Objects: ", count))
		if line != "":
			if !return_as_container:
				# songs
				if str(line).begins_with("songs ;"):
					get_current_map().set_songs.rpc(line)
				if str(line).begins_with("death_limit_low ; "):
					get_current_map().death_limit_low = str(line).split(" ; ")[1] as int
				if str(line).begins_with("death_limit_high ; "):
					get_current_map().death_limit_high = str(line).split(" ; ")[1] as int
				if str(line).begins_with("respawn_time ; "):
					var respawn_time : int = str(line).split(" ; ")[1] as int
					get_current_map().respawn_time = respawn_time
					get_current_map().set_respawn_time.rpc(respawn_time)
				if str(line).begins_with("gravity_scale ; "):
					var gravity_scale : float = str(line).split(" ; ")[1] as float
					# Modify default gravity
					get_current_map().set_gravity_scale.rpc(gravity_scale)
					get_current_map().set_gravity.rpc(false)
			# final step, place building
			if str(line) == "[building]":
				# disable loading canvas if we used it
				set_loading_canvas_visiblity.rpc(false)
				# load building portion, use global pos
				# pass container if returning as container
				if return_as_container:
					await _server_load_building(lines.slice(count+1), Vector3.ZERO, false, container)
				else:
					await _server_load_building(lines.slice(count+1), Vector3.ZERO, true)
				break
			# Load other world elements, like environment, objects, etc.
			elif !return_as_container:
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
					if return_as_container:
						container.add_child(inst, true)
					else:
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
								inst.set_property(property_name, property)
						sync_tbw_obj_properties.rpc(inst.get_path(), inst.properties_as_dict())
		count += 1
	return container

# add gamemodes based on their requirements
func add_all_gamemodes() -> void:
	# add FFA & Home Run, always available
	add_gamemode(GamemodeDeathmatch.new(true))
	add_gamemode(GamemodeHomeRun.new(true))
	add_gamemode(GamemodeBalls.new(true))
	
	var has_capture_point : bool = false
	# check capture ffa
	for obj in get_children():
		if obj is CapturePoint:
			add_gamemode(GamemodeKOTH.new(true))
			has_capture_point = true
			break
	
	var has_finish_line : bool = false
	# check finishline
	for obj in get_children():
		if obj is SpawnPoint:
			if obj.checkpoint == SpawnPoint.CheckpointType.FINISH_LINE:
				add_gamemode(GamemodeRace.new(true))
				has_finish_line = true
				break
	
	# check tdm spawns
	var first_team_spawn_name := ""
	for obj in get_children():
		if obj is SpawnPoint:
			if obj.team_name != "Default":
				# don't replace first found
				if first_team_spawn_name != "":
					first_team_spawn_name = obj.team_name
				# at least two different team spawns
				if obj.team_name != first_team_spawn_name:
					# both tdm and hide and seek can be added
					add_gamemode(GamemodeDeathmatch.new(false))
					add_gamemode(GamemodeHomeRun.new(false))
					add_gamemode(GamemodeBalls.new(false))
					add_gamemode(GamemodeOneVersusAll.new())
					add_gamemode(GamemodeHideSeek.new())
					if has_capture_point:
						# team capture
						add_gamemode(GamemodeKOTH.new(false))
					if has_finish_line:
						add_gamemode(GamemodeRace.new(false))
					# break out of loop once added
					break

func add_gamemode(new : Gamemode) -> void:
	if !gamemode_list.has(new):
		gamemode_list.append(new)
		# add gm to world so it can access world properties
		add_child(new)

func remove_gamemode(what : Gamemode) -> void:
	if gamemode_list.has(what):
		gamemode_list.erase(what)
		what.queue_free()

func _clear_gamemodes() -> void:
	for gm : Gamemode in gamemode_list:
		gm.queue_free()
	gamemode_list = []

@rpc("any_peer", "call_remote", "reliable")
func sync_tbw_obj_properties(obj_path : String, props : Dictionary) -> void:
	var node : TBWObject = get_node_or_null(obj_path)
	if node:
		for prop : String in props.keys():
			if prop != "script":
				node.set_property(prop, props[prop])

@rpc("any_peer", "call_local", "reliable")
func reset_player_cameras() -> void:
	# refind node
	var camera : Camera3D = get_viewport().get_camera_3d()
	if camera is Camera:
		var player : RigidPlayer = Global.get_player()
		if player != null:
			player.set_camera(camera)

@rpc("any_peer", "call_local", "reliable")
func reset_player_positions() -> void:
	var player : RigidPlayer = Global.get_player()
	if player != null:
		player.change_state(RigidPlayer.IDLE)
		player.go_to_spawn()

func clear_world() -> void:
	clear_bricks()
	for node in get_children():
		if node is TBWObject || node is TBWEnvironment:
			node.queue_free()

func clear_bricks() -> void:
	# remove all existing bricks
	for b in get_children():
		if b is Brick:
			# despawn and don't check world groups
			b.despawn(false)

# server places bricks
@rpc("any_peer", "call_local", "reliable")
func ask_server_to_load_building(name_from : String, lines : Array, b_position : Vector3, use_global_position := false, placement_rotation : Vector3 = Vector3.ZERO) -> void:
	if !multiplayer.is_server(): return
	# buildings are 3 lines or greater
	if lines.size() > 2:
		if Time.get_ticks_msec() - last_tbw_load_time < 5000 && Global.get_world().get_current_map() is not Editor:
			UIHandler.show_alert.rpc_id(multiplayer.get_remote_sender_id(), "Please wait before trying to load another building or world", 5, false, UIHandler.alert_colour_error)
			return
	last_tbw_load_time = Time.get_ticks_msec()
	if Global.server_mode():
		CommandHandler.submit_command.rpc("Alert", str(name_from, " placed building at: ", b_position, ". Number of objects: ", lines.size()), 1)
	_server_load_building(lines, b_position, use_global_position, null, placement_rotation)

func _server_load_building(lines : PackedStringArray, b_position : Vector3, use_global_position := false, container : Node3D = null, placement_rotation : Vector3 = Vector3.ZERO) -> void:
	var count_start : int = 0
	# if loading a tbw as a building, remove extra data like image and author
	for line : String in lines:
		count_start += 1
		if str(line) == "[building]":
			lines = lines.slice(count_start)
	
	var building_group := []
	building_group.resize(lines.size())
	var line_split_init : PackedStringArray = lines[0].split(" ; ")
	if line_split_init.size() < 2:
		UIHandler.show_alert.rpc("A corrupt or empty building could not be loaded.", 5, false, UIHandler.alert_colour_error)
		return
	var offset_pos := Vector3.ZERO
	# convert global position into 'local' with offset of first brick
	if !use_global_position:
		var lowest_pos : Vector3 = Vector3(0, 131072, 0)
		# find lowest brick as spawn point
		for line : String in lines:
			if line != "":
				var line_split := line.split(" ; ")
				var prop_list := line_split.slice(1)
				var this_pos : Vector3 = Vector3.ZERO
				for p : String in prop_list:
					var property_split := p.split(":")
					# name is first half
					var property_name := property_split[0]
					# don't use state yet
					if property_name == "global_position":
						var property : Variant = Global.property_string_to_property(property_name, property_split[1])
						this_pos = property as Vector3
						if this_pos.y < lowest_pos.y:
							lowest_pos = this_pos
					# Account for scale in lowest point to avoid
					# spawning large bricks in the ground.
					if property_name == "brick_scale":
						var property : Variant = Global.property_string_to_property(property_name, property_split[1])
						var this_scale : Vector3 = property as Vector3
						this_pos.y -= (this_scale.y * 0.5) - 0.5
						if this_pos.y < lowest_pos.y:
							lowest_pos = this_pos
		var building_pos : Vector3 = Global.property_string_to_property("global_position", line_split_init[1].split(":")[1])
		offset_pos = Vector3(roundf(building_pos.x), roundf(lowest_pos.y), roundf(building_pos.z))
	
	# BIG file, show loading visual
	if lines.size() > 100:
		set_loading_canvas_visiblity.rpc(true)
	
	### Reading file
	# amount of lines to read in a frame
	var max_proc := 32
	var cur_proc := 0
	var total_proc := 0
	var bg_actual_size := 0
	print(str("Building: reading lines... ", Time.get_ticks_msec()))
	for line : String in lines:
		cur_proc += 1
		total_proc += 1
		# wait a frame if we have read max lines for this frame
		if cur_proc > max_proc:
			await get_tree().process_frame
			cur_proc = 0
			if loading_canvas.visible:
				set_loading_canvas_text.rpc(str("Loading file...     Bricks: ", total_proc))
		if line != "":
			var line_split := line.split(" ; ")
			if SpawnableObjects.objects.has(line_split[0]):
				var b : Brick = SpawnableObjects.objects[line_split[0]].instantiate()
				# for parsing return as container
				if container != null:
					container.add_child(b, true)
				else:
					add_child(b, true)
				building_group[total_proc - 1] = b
				bg_actual_size += 1
				var prop_list := line_split.slice(1)
				for p : String in prop_list:
					var property_split := p.split(":")
					# name is first half
					var property_name := property_split[0]
					# don't use state yet
					if property_name != "_state":
						# determine type of second half
						var property : Variant = Global.property_string_to_property(property_name, property_split[1])
						if property_name == "global_position":
							property = property as Vector3
							property = property - offset_pos + b_position
						# set the property
						b.set_property(property_name, property)
	building_group.resize(bg_actual_size)
	
	# placing directly in world
	if container == null:
		if placement_rotation != Vector3.ZERO:
			await get_tree().physics_frame
			### Offset by rotation
			print("Placement rotation:", placement_rotation)
			var pivot_obj : Node3D = Node3D.new()
			add_child(pivot_obj)
			pivot_obj.global_position = b_position
			pivot_obj.global_rotation = Vector3.ZERO
			var pivot : Transform3D = pivot_obj.global_transform
			# pivot origin to placement position, as it works with the preview
			# TODO: clean this up
			var quat_left := Quaternion(Vector3(1, 0, 0), placement_rotation.x)
			var quat_up := Quaternion(Vector3(0, 1, 0), placement_rotation.y)
			var quat_forward := Quaternion(Vector3(0, 0, 1), placement_rotation.z)
			var target_quat := quat_up * quat_left * quat_forward
			var target_basis := Basis(target_quat)

			var new_pivot := Transform3D(target_basis, pivot.origin)
			for b : Brick in building_group:
				#var last_rot := b.global_rotation
				var local_trans := pivot.affine_inverse() * b.global_transform
				b.global_transform = new_pivot * local_trans
			pivot_obj.queue_free()
		
		### Joining bricks
		# don't place nothing
		if building_group.size() < 1:
			printerr("Building: Tried to load building with nothing in it.")
			UIHandler.show_alert.rpc("A corrupt or empty building could not be loaded.", 7, false, UIHandler.alert_colour_error)
			return
		# change ownership first
		# wait a bit before checking joints
		await get_tree().create_timer(0.1).timeout
		if building_group[0] == null:
			return
		# update first brick pos for sorter
		first_brick_pos = building_group[0].global_position
		var building_group_extras := []
		# sort array by position
		building_group.sort_custom(_pos_sort)
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
			b.change_state.rpc(Brick.States.PLACED)
			if count == 1:
				# recheck first brick in array on second brick check
				# (never gets chance to join)
				building_group[0].check_joints()
			count += 1
			b.sync_properties.rpc(b.properties_as_dict())
		# now for each extra brick:
		# 1. enable its collider
		# 2. check neighbours
		await get_tree().process_frame
		count = 0
		for b : Brick in building_group_extras:
			b.change_state.rpc(Brick.States.PLACED)
			count += 1
			b.sync_properties.rpc(b.properties_as_dict())
		
		print(str("Done loading building, checking groups. ", Time.get_ticks_msec()))
		# Update the brick groups.
		get_node("BrickGroups").check_world_groups(true)
	set_loading_canvas_visiblity.rpc(false)

var first_brick_pos : Vector3 = Vector3.ZERO
func _pos_sort(a : Node3D, b : Node3D) -> bool:
	return a.global_position.distance_to(first_brick_pos) < b.global_position.distance_to(first_brick_pos)
