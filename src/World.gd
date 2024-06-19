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

var rigidplayer_list = []

# active minigame
var minigame = null

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
	for p in rigidplayer_list:
		p.global_position = Vector3(float(pos.x), float(pos.y), float(pos.z))

func _ready():
	Global.connect("graphics_preset_changed", _on_graphics_preset_changed)
	$MultiplayerMapSpawner.connect("spawned", _on_multiplayer_map_spawned)
	multiplayer.peer_connected.connect(_on_peer_connected)

func _on_peer_connected(id) -> void:
	if !multiplayer.is_server(): return
	
	print("peer connected on world: ", str(id))
	
	if minigame != null:
		var connected_win_cond = Lobby.GameWinCondition.BASE_DEFENSE
		if minigame is MinigameDM:
			connected_win_cond = Lobby.GameWinCondition.DEATHMATCH
			if minigame.tdm:
				connected_win_cond = Lobby.GameWinCondition.TEAM_DEATHMATCH
		elif minigame is MinigameKing:
			connected_win_cond = Lobby.GameWinCondition.KINGS
		start_minigame.rpc_id(id, "", connected_win_cond, true)

func _on_multiplayer_map_spawned(map) -> void:
	emit_signal("map_loaded")

# Starts a new minigame with the scene's map name and a win condition.
@rpc("any_peer", "call_local", "reliable")
func start_minigame(map_name, win_condition, from_new_peer_connection = false) -> void:
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
		load_map(load(str("res://data/scene/", map_name, "/", map_name, ".tscn")))
	
	# create minigame
	var teams = get_current_map().get_teams().get_team_list()
	minigame.playing_team_names = [teams[1].name, teams[2].name]
	minigame.name = "Minigame"
	# if a player has joined midway, sync some properties from server
	if from_new_peer_connection:
		minigame.from_new_peer_connection = true
	add_child(minigame)

func _on_graphics_preset_changed():
	match Global.get_graphics_preset():
		# COOL
		0:
			if $Map.get_children().size() > 0:
				var loaded_map = $Map.get_child(0)
				if loaded_map.has_node("WorldEnvironment"):
					var env = loaded_map.get_node("WorldEnvironment")
					env.environment.ssao_enabled = true
					env.environment.ssil_enabled = true
				var light = loaded_map.get_node_or_null("DirectionalLight3D")
				if light:
					light.shadow_enabled = true
				var caff_light = loaded_map.get_node_or_null("SpotLight3D")
				if caff_light:
					light.shadow_enabled = true
		# BAD
		1:
			if $Map.get_children().size() > 0:
				var loaded_map = $Map.get_child(0)
				if loaded_map.has_node("WorldEnvironment"):
					var env = loaded_map.get_node("WorldEnvironment")
					env.environment.ssao_enabled = false
					env.environment.ssil_enabled = false
				var light = loaded_map.get_node_or_null("DirectionalLight3D")
				if light:
					light.shadow_enabled = true
				var caff_light = loaded_map.get_node_or_null("SpotLight3D")
				if caff_light:
					light.shadow_enabled = true
		# AWFUL
		2:
			if $Map.get_children().size() > 0:
				var loaded_map = $Map.get_child(0)
				if loaded_map.has_node("WorldEnvironment"):
					var env = loaded_map.get_node("WorldEnvironment")
					env.environment.ssao_enabled = false
					env.environment.ssil_enabled = false
				# no shadows on awful graphics
				var light = loaded_map.get_node_or_null("DirectionalLight3D")
				if light:
					light.shadow_enabled = false
				var caff_light = loaded_map.get_node_or_null("SpotLight3D")
				if caff_light:
					light.shadow_enabled = false

# Get the current map.
func get_current_map():
	return $Map.get_child(0)

func delete_old_map() -> void:
	# Remove old map (if it exists)
	var old_map = $Map
	for c in old_map.get_children():
		old_map.remove_child(c)
		c.queue_free()
	emit_signal("map_deleted")

# Call this function deferred and only on the main authority (server).
func load_map(map: PackedScene) -> void:
	delete_old_map()
	# Add new level.
	var current_map = map.instantiate()
	$Map.add_child(current_map)
	emit_signal("map_loaded")

# Save the currently open world as a .tbw file.
func save_tbw(world_name) -> void:
	var dir = DirAccess.open("user://world")
	if !dir:
		DirAccess.make_dir_absolute("user://world")
	
	# save building to file
	dir = DirAccess.open("user://world")
	var count = 0
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir():
				count += 1
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	var save_name = str(world_name)
	
	# get frame image and save it
	# hide everything
	if get_current_map() is Editor:
		# only hide editor ui
		get_tree().current_scene.get_node("EditorCanvas").visible = false
		# wait 1 frame so we can get screenshot
		await get_tree().process_frame
		var img = get_viewport().get_texture().get_image()
		img.shrink_x2()
		var scrdir = DirAccess.open("user://world_scr")
		if !scrdir:
			DirAccess.make_dir_absolute("user://world_scr")
		img.save_jpg(str("user://world_scr/", save_name, ".jpg"))
		get_tree().current_scene.get_node("EditorCanvas").visible = true
	else:
		Global.get_player().visible = false
		get_tree().current_scene.get_node("GameCanvas").visible = false
		# wait 1 frame so we can get screenshot
		await get_tree().process_frame
		var img = get_viewport().get_texture().get_image()
		img.shrink_x2()
		var scrdir = DirAccess.open("user://world_scr")
		if !scrdir:
			DirAccess.make_dir_absolute("user://world_scr")
		img.save_jpg(str("user://world_scr/", save_name, ".jpg"))
		# show everything again
		Global.get_player().visible = true
		get_tree().current_scene.get_node("GameCanvas").visible = true
	UIHandler.show_alert(str("Saved world as ", save_name, ".tbw."), 4, false, false, true)
	
	# Create tbw file.
	var file = FileAccess.open(str("user://world/", save_name, ".tbw"), FileAccess.WRITE)
	# Save objects before bricks
	for obj in get_children():
		if obj != null:
			if obj is TBWObject:
				var type = obj.tbw_object_type
				file.store_line(str(type, ";", obj.global_position.x, ",", obj.global_position.y, ",", obj.global_position.z, ";", obj.global_rotation.x, ",", obj.global_rotation.y, ",", obj.global_rotation.z))
			elif obj is TBWEnvironment:
				file.store_line(str("Environment;", obj.environment_name))
	# Store bricks in the same format as buildings.
	
	# Make sure there is actually a brick to save
	var found_brick = false
	for b in get_children():
		if b != null:
			if b is Brick:
				if found_brick == false:
					file.store_line(str("[building]"))
					found_brick = true
				var type = b._brick_type
				file.store_line(str(type, ";", b.global_position.x, ",", b.global_position.y, ",", b.global_position.z, ";", b.global_rotation.x, ",", b.global_rotation.y, ",", b.global_rotation.z, ";", b._material, ";", b._state, ";", b._colour.to_html(false)))
	file.close()

func load_tbw(file_name = "test", internal = false):
	print("Attempting to load ", file_name, ".tbw")
	
	var load_file = null
	if internal:
		load_file = FileAccess.open(str("res://data/tbw/", file_name, ".tbw"), FileAccess.READ)
	else:
		load_file = FileAccess.open(str("user://world/", file_name, ".tbw"), FileAccess.READ)
	if load_file != null:
		# load building
		var lines = []
		while not load_file.eof_reached():
			var line = load_file.get_line()
			lines.append(str(line))
		if multiplayer.is_server():
			_parse_and_open_tbw(lines)
		else:
			ask_server_to_open_tbw.rpc_id(1, Global.display_name, lines)
	else:
		UIHandler.show_alert("World not found or corrupt!", 8, false, true)

# server loads tbws
@rpc("any_peer", "call_local", "reliable")
func ask_server_to_open_tbw(name_from, lines):
	if !multiplayer.is_server(): return
	_parse_and_open_tbw(lines)

# Only to be run as server
func _parse_and_open_tbw(lines : Array) -> void:
	if !multiplayer.is_server(): return
	
	clear_world()
	# Load default empty map, unless we are in the editor
	if !(Global.get_world().get_current_map() is Editor):
		load_map(load(str("res://data/scene/BaseWorld/BaseWorld.tscn")))
	
	var current_step = "none"
	var count = 0
	# run through each line
	for line in lines:
		if line != "":
			# final step, place building
			if str(line) == "[building]":
				# load building portion, use global pos
				_server_load_building(lines.slice(count+1), Vector3.ZERO, true)
				break
			# Load other world elements, like environment, objects, etc.
			else:
				var line_split = line.split(";")
				var inst = null
				var posrot = true
				await get_tree().process_frame
				match line_split[0]:
					# World environments don't have pos or rotation
					"Environment":
						posrot = false
						if line_split.size() > 1:
							match line_split[1]:
								"Sunset":
									inst = SpawnableObjects.tbw_env_sunset.instantiate()
								"Molten":
									inst = SpawnableObjects.tbw_env_molten.instantiate()
								"Warp":
									inst = SpawnableObjects.tbw_env_warp.instantiate()
								_:
									inst = SpawnableObjects.tbw_env_sunny.instantiate()
					_:
						# all other objects
						var ret = SpawnableObjects.tbw_obj_from_string(line_split[0])
						if ret != null:
							inst = ret.instantiate()
				# ignore invalid items
				if inst != null:
					add_child(inst, true)
					# if this object has position and rotation
					if posrot:
						# object position
						if line_split.size() > 1:
							var pos = line_split[1].split(",")
							inst.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
						# object rotation
						if line_split.size() > 2:
							var rot = line_split[2].split(",")
							inst.global_rotation = Vector3(float(rot[0]), float(rot[1]), float(rot[2]))
						sync_tbw_obj_properties.rpc(inst.get_path(), inst.global_position, inst.global_rotation)
		count += 1
	# reset all player cameras once world is done loading
	reset_player_cameras.rpc()
	# announce we are done loading
	emit_signal("tbw_loaded")

@rpc("any_peer", "call_remote", "reliable")
func sync_tbw_obj_properties(obj_path, new_pos, new_rot) -> void:
	var node = get_node_or_null(obj_path)
	if node:
		node.global_position = new_pos
		node.global_rotation = new_rot

@rpc("any_peer", "call_local", "reliable")
func reset_player_cameras():
	# refind node
	var camera = get_viewport().get_camera_3d()
	if camera is Camera:
		Global.get_player().set_camera(camera)

# Load a building into the existing map.
# Arg 1: The path to the building scene file.
func load_building_into_map(path_to_building : String) -> void:
	var building = load(path_to_building)
	var b_i = building.instantiate()

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
	load_map(load("res://data/scene/Lobby/Lobby.tscn"))

# server places bricks
@rpc("any_peer", "call_local", "reliable")
func ask_server_to_load_building(name_from, lines, b_position):
	if !multiplayer.is_server(): return
	_server_load_building(lines, b_position)

# TODO: should do this in a thread
func _server_load_building(lines, b_position, use_global_position = false):
	if !multiplayer.is_server(): return
	
	var building = Building.new(false)
	add_child(building)
	
	var line_split_init = lines[0].split(";")
	var offset_pos = Vector3.ZERO
	# convert global position into 'local' with offset of first brick
	if !use_global_position:
		var building_pos = line_split_init[1].split(",")
		offset_pos = Vector3(float(building_pos[0]), float(building_pos[1]), float(building_pos[2]))
	
	for line in lines:
		if line != "":
			var line_split = line.split(";")
			var b = null
			match line_split[0]:
				"Brick":
					b = SpawnableObjects.brick.instantiate()
				"HalfBrick":
					b = SpawnableObjects.half_brick.instantiate()
				"CylinderBrick":
					b = SpawnableObjects.cylinder_brick.instantiate()
				"LargeCylinderBrick":
					b = SpawnableObjects.large_cylinder_brick.instantiate()
				"MotorSeat":
					b = SpawnableObjects.motor_seat.instantiate()
			building.add_child(b, true)
			# position
			if line_split.size() > 1:
				var pos = line_split[1].split(",")
				b.global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2])) - offset_pos + b_position
			# rotation
			if line_split.size() > 2:
				var rot = line_split[2].split(",")
				b.global_rotation = Vector3(float(rot[0]), float(rot[1]), float(rot[2]))
			# colour
			if line_split.size() > 5:
				b._colour = Color.from_string(line_split[5], Color.WHITE)
			# material
			if line_split.size() > 3:
				var mat = line_split[3]
				b.set_material.rpc(int(mat))
	building.place()
