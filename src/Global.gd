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
signal graphics_preset_changed
signal keybinds_changed
signal appearance_changed
signal player_list_information_update
signal debug_toggled(mode : bool)

var display_name : String = ""
var connected_to_server := false
# server settings
var server_banned_ips : Array = []
var server_can_clients_load_worlds : bool = true

func server_mode() -> bool:
	return DisplayServer.get_name() == "headless"

var is_text_focused := false
var is_paused := false
var debug := false

enum GraphicsPresets {
	COOL,
	BAD,
	AWFUL
}

# A cache of already painted materials that can be re-used. Keeps draw call counts down.
var graphics_cache : Array[Material] = []
# Cache of ball colours.
var ball_colour_cache : Array[Material] = []
# Cache of capture colours.
var capture_colour_cache : Array[Material] = []
# Cache of already made meshes to avoid re-making meshes for bricks.
# 1: scale as vector3
# 2: brick type
# 3: mesh
var mesh_cache : Array = []

const GRAPHICS_CACHE_MAX = 256
const BALL_COLOUR_CACHE_MAX = 64
const CAPTURE_COLOUR_CACHE_MAX = 32
const MESH_CACHE_MAX = 128
func add_to_graphics_cache(what : Material) -> void:
	if graphics_cache.size() < GRAPHICS_CACHE_MAX:
		graphics_cache.append(what)
	else:
		graphics_cache.remove_at(0)
		graphics_cache.append(what)
func add_to_mesh_cache(what : Array) -> void:
	if mesh_cache.size() < MESH_CACHE_MAX:
		mesh_cache.append(what)
	else:
		mesh_cache.remove_at(0)
		mesh_cache.append(what)
func add_to_ball_colour_cache(what : Material) -> void:
	if ball_colour_cache.size() < BALL_COLOUR_CACHE_MAX:
		ball_colour_cache.append(what)
	else:
		ball_colour_cache.remove_at(0)
		ball_colour_cache.append(what)
func add_to_capture_colour_cache(what : Material) -> void:
	if capture_colour_cache.size() < CAPTURE_COLOUR_CACHE_MAX:
		capture_colour_cache.append(what)
	else:
		capture_colour_cache.remove_at(0)
		capture_colour_cache.append(what)

# The currently selected graphics preset.
var graphics_preset : GraphicsPresets = GraphicsPresets.COOL

# Appearance settings
var shirt : int = 0
var shirt_texture : String = ""
var hair : int = 0
var shirt_colour := Color("abababff")
var pants_colour := Color("#1a203d")
var hair_colour := Color("#a7606a")
var skin_colour := Color("d29185")

var kill : AudioStream = preload("res://data/audio/kill.ogg")
var doublekill : AudioStream = preload("res://data/audio/doublekill.ogg")
var triplekill : AudioStream = preload("res://data/audio/triplekill.ogg")
var multikill : AudioStream = preload("res://data/audio/multikill.ogg")

var last_gamemode_idx : int = 0;
var last_gamemode_params : Array = []
var last_gamemode_mods : Array = []

func reset_shirt_texture() -> void:
	var actions := UIHandler.show_alert_with_actions("Are you sure? You will lose your\ncurrent shirt.", ["Reset shirt", "Nevermind"], true)
	actions[0].connect("pressed", _reset_shirt_texture_pressed)

func _reset_shirt_texture_pressed() -> void:
	set_shirt_texture("")

func upload_shirt_texture() -> void:
	var picker := FileDialog.new()
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	picker.title = "Make a shirt"
	if OS.get_name() == "macOS":
		picker.use_native_dialog = true
	get_viewport().add_child(picker)
	picker.size = Vector2(800, 400)
	picker.popup_centered()
	picker.set_filters(["*.png, *.jpg, *.jpeg"])
	var path : String = await picker.file_selected
	var img : Image = Image.new()
	img.load(path)
	if img != null:
		if img.is_empty():
			show_shirt_texture_error()
		else:
			img.resize(128, 128)
			var new_base64 : String = Marshalls.raw_to_base64(img.save_jpg_to_buffer())
			if new_base64 != null:
				set_shirt_texture(new_base64)
	else:
		show_shirt_texture_error()

func show_shirt_texture_error() -> void:
	UIHandler.show_alert("File unsupported. Please upload a .png,\n.jpeg, or .jpg file (preferably square)!", 8, false, UIHandler.alert_colour_error)

func set_shirt(new : int) -> void:
	shirt = new
	emit_signal("appearance_changed")
func set_shirt_texture(new_base64 : String = "") -> void:
	shirt_texture = new_base64
	emit_signal("appearance_changed")
func set_hair(new : int) -> void:
	hair = new
	emit_signal("appearance_changed")
func set_shirt_colour(new : Color) -> void:
	shirt_colour = new
	emit_signal("appearance_changed")
func set_pants_colour(new : Color) -> void:
	pants_colour = new
	emit_signal("appearance_changed")
func set_hair_colour(new : Color) -> void:
	hair_colour = new
	emit_signal("appearance_changed")
func set_skin_colour(new : Color) -> void:
	skin_colour = new
	emit_signal("appearance_changed")

func _ready() -> void:
	load_appearance()
	get_viewport().connect("gui_focus_changed", _on_gui_focus_changed)
	# save version once on launch, in case we want to compare against it in a newer version
	UserPreferences.save_pref("version", get_tree().current_scene.server_version)
	# fullscreen if not in debug mode
	if !OS.has_feature("editor") && !OS.get_name() == "macOS" && !Global.server_mode():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	# if on macOS, go into fullscreen, not exclusive fullscreen (allows access to dock/status bar when hovering top/bottom)
	elif !OS.has_feature("editor") && OS.get_name() == "macOS" && !Global.server_mode():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func save_appearance() -> void:
	UserPreferences.save_pref("shirt", shirt)
	UserPreferences.save_pref("shirt_texture", shirt_texture)
	UserPreferences.save_pref("hair", hair)
	UserPreferences.save_pref("shirt_colour", shirt_colour)
	UserPreferences.save_pref("pants_colour", pants_colour)
	UserPreferences.save_pref("hair_colour", hair_colour)
	UserPreferences.save_pref("skin_colour", skin_colour)

func load_appearance() -> void:
	var loaded_shirt : Variant = UserPreferences.load_pref("shirt")
	if loaded_shirt != null:
		set_shirt(loaded_shirt as int)
	var loaded_shirt_texture : Variant = UserPreferences.load_pref("shirt_texture")
	if loaded_shirt_texture != null:
		set_shirt_texture(str(loaded_shirt_texture))
	var loaded_hair : Variant = UserPreferences.load_pref("hair")
	if loaded_hair != null:
		set_hair(loaded_hair as int)
	
	var loaded_shirt_colour : Variant = UserPreferences.load_pref("shirt_colour")
	if loaded_shirt_colour != null:
		set_shirt_colour(loaded_shirt_colour as Color)
	var loaded_pants_colour : Variant = UserPreferences.load_pref("pants_colour")
	if loaded_pants_colour != null:
		set_pants_colour(loaded_pants_colour as Color)
	var loaded_hair_colour : Variant = UserPreferences.load_pref("hair_colour")
	if loaded_hair_colour != null:
		set_hair_colour(loaded_hair_colour as Color)
	var loaded_skin_colour : Variant = UserPreferences.load_pref("skin_colour")
	if loaded_skin_colour != null:
		set_skin_colour(loaded_skin_colour as Color)

# Returns the World.
func get_world() -> World:
	return get_tree().current_scene.get_node("World")

# Returns this authority's Player.
func get_player() -> RigidPlayer:
	if connected_to_server:
		return get_world().get_node_or_null(str(multiplayer.get_unique_id()))
	else: return null

# Returns player by name.
func get_player_by_name(what : String) -> RigidPlayer:
	if connected_to_server:
		for p : RigidPlayer in get_world().rigidplayer_list:
			if str(p.display_name).to_lower() == str(what).to_lower():
				return p
	return null

# Gets the current graphics
func get_graphics_preset() -> GraphicsPresets:
	return graphics_preset

# Sets the current graphics
func set_graphics_preset(new : GraphicsPresets) -> void:
	graphics_preset = new
	emit_signal("graphics_preset_changed")

# Loads the saved graphics preset from disk.
func load_graphics_preset() -> GraphicsPresets:
	var loaded_preset : Variant = UserPreferences.load_pref("graphics_preset")
	if loaded_preset != null:
		set_graphics_preset(loaded_preset as int)
	return graphics_preset

# When the PlayerList gets updated, this is called.
func update_player_list_information() -> void:
	emit_signal("player_list_information_update")

# TODO: Maybe this should move to MusicHandler? + MusicHandler could be called AudioHandler?
var last_kill_time := 0
var combo := 0
@rpc("any_peer", "call_local", "reliable")
func play_kill_sound() -> void:
	var audio := AudioStreamPlayer.new()
	audio.volume_db = 1
	get_world().add_child(audio)
	# combo kill
	if Time.get_unix_time_from_system() - last_kill_time < 8:
		match (combo):
			0:
				# double kill
				audio.stream = doublekill
			1:
				# triple kill
				audio.stream = triplekill
			_:
				# multi kill
				audio.stream = multikill
		combo += 1
	else:
		# normal kill
		audio.stream = kill
		combo = 0
	last_kill_time = Time.get_unix_time_from_system()
	# delay for sound (avoid getting muffled by explosions etc)
	await get_tree().create_timer(0.3).timeout
	audio.play()
	audio.connect("finished", audio.queue_free)

# Get an array of all the names of TBW files the user has made, with extension.
func get_user_tbw_names() -> Array:
	var dir : DirAccess = DirAccess.open("user://world")
	if dir:
		var files : Array[String] = []
		for f : String in dir.get_files():
			files.append("user://world/" + f)
		files.sort_custom(sort_local_tbw_by_modified_date)
		var ret : Array[String] = []
		for f : String in files:
			ret.append(f.replace("user://world/", ""))
		return ret
	else:
		return []

func sort_local_tbw_by_modified_date(a : String, b : String) -> bool:
	return FileAccess.get_modified_time(a) > FileAccess.get_modified_time(b)

func get_internal_tbw_names() -> Array:
	var dir : DirAccess = DirAccess.open("res://data/tbw")
	if dir:
		return dir.get_files()
	else:
		return []

func get_tbw_image(file_name : String) -> Image:
	var lines := get_tbw_lines(file_name)
	return get_tbw_image_from_lines(lines)

func get_tbw_image_from_lines(lines : Array) -> Image:
	var image_base64 : String = ""
	for line : String in lines:
		if line.begins_with("image ; "):
			image_base64 = line.split(" ; ")[1]
	if image_base64 != "":
		var image : Image = Image.new()
		image.load_jpg_from_buffer(Marshalls.base64_to_raw(image_base64))
		return image
	return null

func get_tbw_lines(file_name : String, server : bool = false) -> Array:
	var load_file : FileAccess = null
	# non-server worlds
	if !server:
		load_file = FileAccess.open(str("user://world/", file_name, ".tbw"), FileAccess.READ)
		# if file does not exist, check internal
		if load_file == null:
			# check internal
			load_file = FileAccess.open(str("res://data/tbw/", file_name, ".tbw"), FileAccess.READ)
		if load_file == null:
			# check building
			load_file = FileAccess.open(str("user://building/", file_name), FileAccess.READ)
		if file_name == "temp":
			load_file = FileAccess.open(str("user://building/temp.tbw"), FileAccess.READ)
	else:
		# server world as load file
		load_file = FileAccess.open(str(UserPreferences.os_path, file_name, ".tbw"), FileAccess.READ)
	if load_file != null:
		# load building
		var lines := []
		while not load_file.eof_reached():
			var line := load_file.get_line()
			lines.append(str(line))
		return lines
	return []

# gets children recursively
func get_all_children(in_what : Node) -> Array:
	var all_children := []
	for child in in_what.get_children():
		if child.get_child_count() > 0:
			all_children.append(get_all_children(child))
		all_children.append(child)
	return all_children

# returns the appropriate data type based on a tbw property name.
func property_string_to_property(property_name : String, property : String) -> Variant:
	match(property_name):
		"global_position", "global_rotation", "scale", "brick_scale":
			return Global.string_to_vec3(property)
		"_material", "_state":
			return int(property)
		"_colour":
			property = property.erase(0)
			property = property.erase(property.length())
			var property_split := property.split(", ")
			return Color(float(property_split[0]), float(property_split[1]), float(property_split[2]), float(property_split[3]))
		"text", "team_name", "connection", "gamemode_name":
			# unescape strings because strings are stored inline with \n
			return str(property.c_unescape())
		_:
			var parse_attempt : Variant = JSON.parse_string(property)
			if parse_attempt != null:
				return parse_attempt
			else: 
				print("JSON parse for unknown property ", property_name, " failed, returning property as int.")
				return int(property)

# sets text focused bool for making sure that input keys don't get pressed
# when typing
func _on_gui_focus_changed(control : Control) -> void:
	if control is LineEdit || control is TextEdit:
		is_text_focused = true
	else:
		is_text_focused = false

# helper func
func string_to_vec3(what : String) -> Vector3:
	what = what.erase(0)
	what = what.erase(what.length())
	var what_split := what.split(", ")
	if what_split.size() > 2:
		return Vector3(float(what_split[0]), float(what_split[1]), float(what_split[2]))
	else:
		# default spawn point
		return Vector3(0, 51, 0)

func _unhandled_input(event : InputEvent) -> void:
	if (event is InputEventKey):
		if event.pressed and event.keycode == KEY_QUOTELEFT:
			debug = !debug
			# Show/hide debug collision shapes.
			# https://github.com/godotengine/godot-proposals/issues/2072
			var tree := get_tree()
			tree.debug_collisions_hint = debug
			var node_stack: Array[Node] = [tree.get_root()]
			while not node_stack.is_empty():
				var node: Node = node_stack.pop_back()
				if is_instance_valid(node):
					if node is CollisionShape3D or node is CollisionPolygon3D:
						var parent: Node = node.get_parent()
						if parent:
							# "redraw"
							parent.remove_child(node)
							parent.add_child(node)
					node_stack.append_array(node.get_children())
			# let other debug scripts know that debug has changed
			emit_signal("debug_toggled", debug)

# here because cameras are not synced between multiplayer clients
@rpc("any_peer", "call_local", "reliable")
func set_camera_max_dist(new : float = 40) -> void:
	if multiplayer.get_remote_sender_id() != 1 && multiplayer.get_remote_sender_id() != get_multiplayer_authority() && multiplayer.get_remote_sender_id() != 0:
		return
	var camera : Camera3D = get_viewport().get_camera_3d()
	if camera is Camera:
		camera.set_max_dist(new)

@rpc("any_peer", "call_local", "reliable")
func server_start_gamemode(idx : int, params : Array, mods : Array) -> void:
	for gm : Gamemode in get_world().gamemode_list:
		if gm.running:
			UIHandler.show_alert.rpc_id(multiplayer.get_remote_sender_id(), "Can't start a new gamemode while one is currently running!", 6, false, UIHandler.alert_colour_error)
			return
		
	if get_world().gamemode_list.size() > 0:
		get_world().gamemode_list[idx].connect("gamemode_ended", _on_gamemode_ended.bind(idx))
		get_world().gamemode_list[idx].start(params, mods)
		
		last_gamemode_idx = idx
		last_gamemode_params = params
		last_gamemode_mods = mods
	else:
		UIHandler.show_alert.rpc_id(multiplayer.get_remote_sender_id(), "There are no gamemodes to start!")

func _on_gamemode_ended(idx : int) -> void:
	if get_world().gamemode_list[idx].is_connected("gamemode_ended", _on_gamemode_ended.bind(idx)):
		get_world().gamemode_list[idx].disconnect("gamemode_ended", _on_gamemode_ended.bind(idx))

# String formatting helpers
# TODO: If this gets large enough might be worth seperating into StringEx or something

func format_server_version(what : String) -> String:
	var first : String = what.substr(0, 2)
	var second : String = what.substr(2, 2)
	var last : String = what.right(1)
	
	var suffix : String = ""
	if last == "0":
		suffix = "pre"
	return str("beta ", first, ".", str(int(second)), suffix)
