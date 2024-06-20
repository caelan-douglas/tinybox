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

var display_name
var connected_to_server = false

enum GraphicsPresets {
	COOL,
	BAD,
	AWFUL
}

# A cache of already painted materials that can be re-used. Keeps draw call counts down.
var graphics_cache = []

# The currently selected graphics preset.
var graphics_preset : GraphicsPresets = GraphicsPresets.COOL

# Appearance settings
var shirt = 0
var shirt_texture = 0
var hair = 0
var shirt_colour = Color("#ffffff")
var pants_colour = Color("#1a203d")
var hair_colour = Color("#a7606a")
var skin_colour = Color("d29185")

var beep_low = preload("res://data/audio/beep/beep_low.ogg")
var beep_fifths = preload("res://data/audio/beep/beep_fifths.ogg")

func set_shirt(new) -> void:
	shirt = new
	emit_signal("appearance_changed")
func set_shirt_texture(new) -> void:
	shirt_texture = new
	# TODO: better way to handle this
	if shirt_texture == 2 && get_tree().current_scene.get_node("MultiplayerMenu/AppearanceMenu").visible == true:
		UIHandler.show_alert("This shirt design is best used with a white shirt.", 5)
	emit_signal("appearance_changed")
func set_hair(new) -> void:
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

func _ready():
	load_appearance()

func save_appearance() -> void:
	UserPreferences.save_pref("shirt", shirt)
	UserPreferences.save_pref("shirt_texture", shirt_texture)
	UserPreferences.save_pref("hair", hair)
	UserPreferences.save_pref("shirt_colour", shirt_colour)
	UserPreferences.save_pref("pants_colour", pants_colour)
	UserPreferences.save_pref("hair_colour", hair_colour)
	UserPreferences.save_pref("skin_colour", skin_colour)

func load_appearance() -> void:
	var loaded_shirt = UserPreferences.load_pref("shirt")
	if loaded_shirt != null:
		set_shirt(loaded_shirt)
	var loaded_shirt_texture = UserPreferences.load_pref("shirt_texture")
	if loaded_shirt_texture != null:
		set_shirt_texture(loaded_shirt_texture)
	var loaded_hair = UserPreferences.load_pref("hair")
	if loaded_hair != null:
		set_hair(loaded_hair)
	
	var loaded_shirt_colour = UserPreferences.load_pref("shirt_colour")
	if loaded_shirt_colour != null:
		set_shirt_colour(loaded_shirt_colour)
	var loaded_pants_colour = UserPreferences.load_pref("pants_colour")
	if loaded_pants_colour != null:
		set_pants_colour(loaded_pants_colour)
	var loaded_hair_colour = UserPreferences.load_pref("hair_colour")
	if loaded_hair_colour != null:
		set_hair_colour(loaded_hair_colour)
	var loaded_skin_colour = UserPreferences.load_pref("skin_colour")
	if loaded_skin_colour != null:
		set_skin_colour(loaded_skin_colour)

# Returns the World.
func get_world() -> World:
	return get_tree().current_scene.get_node("World")

# Returns this authority's Player.
func get_player() -> RigidPlayer:
	if connected_to_server:
		return get_world().get_node_or_null(str(multiplayer.get_unique_id()))
	else: return null

# Gets the current graphics
func get_graphics_preset() -> GraphicsPresets:
	return graphics_preset

# Sets the current graphics
func set_graphics_preset(new : GraphicsPresets) -> void:
	graphics_preset = new
	emit_signal("graphics_preset_changed")

# Loads the saved graphics preset from disk.
func load_graphics_preset() -> GraphicsPresets:
	var loaded_preset = UserPreferences.load_pref("graphics_preset")
	if loaded_preset != null:
		set_graphics_preset(loaded_preset)
	return graphics_preset

# When the PlayerList gets updated, this is called.
func update_player_list_information() -> void:
	emit_signal("player_list_information_update")

# TODO: Maybe this should move to MusicHandler? + MusicHandler could be called AudioHandler?
var last_kill_time = 0
@rpc("any_peer", "call_remote", "reliable")
func play_kill_sound() -> void:
	var audio = AudioStreamPlayer.new()
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

func get_user_tbw_names() -> Array:
	var dir = DirAccess.open("user://world")
	if dir:
		return dir.get_files()
	else:
		return []
