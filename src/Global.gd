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
signal appearance_changed
signal player_list_information_update

var display_name : String = ""
var connected_to_server := false
var dedicated_server := false
var is_text_focused := false
var is_paused := false

enum GraphicsPresets {
	COOL,
	BAD,
	AWFUL
}

# A cache of already painted materials that can be re-used. Keeps draw call counts down.
var graphics_cache : Array[Material] = []

const GRAPHICS_CACHE_MAX = 256
func add_to_graphics_cache(what : Material) -> void:
	if graphics_cache.size() < GRAPHICS_CACHE_MAX:
		graphics_cache.append(what)
	else:
		graphics_cache.remove_at(0)
		graphics_cache.append(what)

# The currently selected graphics preset.
var graphics_preset : GraphicsPresets = GraphicsPresets.COOL

var brick_materials_as_names : Array[String] = ["Wooden", "Wooden (charred)", "Metal", "Plastic", "Rubber", "Immovable"]

# Appearance settings
var shirt : int = 0
var shirt_texture : int = 0
var hair : int = 0
var shirt_colour := Color("#ffffff")
var pants_colour := Color("#1a203d")
var hair_colour := Color("#a7606a")
var skin_colour := Color("d29185")

var beep_low : AudioStream = preload("res://data/audio/beep/beep_low.ogg")
var beep_fifths : AudioStream = preload("res://data/audio/beep/beep_fifths.ogg")

func set_shirt(new : int) -> void:
	shirt = new
	emit_signal("appearance_changed")
func set_shirt_texture(new : int) -> void:
	shirt_texture = new
	# TODO: better way to handle this
	if shirt_texture == 2 && get_tree().current_scene.get_node("MultiplayerMenu/AppearanceMenu").visible == true:
		UIHandler.show_alert("This shirt design is best used with a white shirt.", 5)
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
		set_shirt_texture(loaded_shirt_texture as int)
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
@rpc("any_peer", "call_local", "reliable")
func play_kill_sound() -> void:
	var audio := AudioStreamPlayer.new()
	audio.volume_db = 1
	get_world().add_child(audio)
	if Time.get_unix_time_from_system() - last_kill_time < 4:
		# double kill
		audio.stream = beep_fifths
	else:
		# normal kill
		audio.stream = beep_low
	last_kill_time = Time.get_unix_time_from_system()
	# delay for sound (avoid getting muffled by explosions etc)
	await get_tree().create_timer(0.3).timeout
	audio.play()
	audio.connect("finished", audio.queue_free)

# Get an array of all the names of TBW files the user has made.
func get_user_tbw_names() -> Array:
	var dir : DirAccess = DirAccess.open("user://world")
	if dir:
		return dir.get_files()
	else:
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
		"global_position", "global_rotation", "scale":
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
		# for gamemodes
		"start_events", "watchers", "end_events":
			var arrays : Array = JSON.parse_string(property)
			return arrays
		_:
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
