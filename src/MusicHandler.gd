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
signal master_setting_changed
signal music_setting_changed
signal sfx_setting_changed
signal ui_setting_changed

var master_setting := 0.8
var music_setting := 0.7
var sfx_setting := 1.0
var ui_setting := 1.0
var min_db : float = 30
var current_song_name := ""
var song_list : Array = [""]
const ALL_SONGS_LIST : Array = ["mus1", "mus2", "mus3", "mus4", "mus5", "mus6", "mus7", "mus8", "mus9", "mus10", "mus11", "mus12"]

@onready var music_player : AudioStreamPlayer = $AudioStreamPlayer
@onready var music_animator : AnimationPlayer = $AudioStreamPlayer/AnimationPlayer

func _ready() -> void:
	master_setting = MusicHandler.load_master_setting()
	music_setting = MusicHandler.load_music_setting()
	sfx_setting = MusicHandler.load_sfx_setting()
	ui_setting = MusicHandler.load_ui_setting()
	
	# debug no prefs file flag
	if OS.get_cmdline_args().has("--debug_mute"): master_setting = 0

func switch_song(new_song_names : Array, overwrite_song_list := true) -> void:
	if overwrite_song_list:
		song_list = new_song_names
	
	# don't actually try to play songs as dedicated server
	if Global.server_mode():
		return
	#print("Switching songs to: ", str(new_song_names), " ;;; Total song list: ", str(song_list))
	var new_song_name : String = ""
	if new_song_names.size() > 0:
		new_song_name = str(new_song_names.pick_random())
	# blank song name stops the music
	if new_song_name == "":
		current_song_name = new_song_name
		music_animator.play("song_fade_out")
		await get_tree().create_timer(3).timeout
		# don't stop the music if a new song has started since the 3s timeout
		if current_song_name == "":
			music_player.disconnect("finished", switch_song)
			music_player.stop()
	elif current_song_name != new_song_name:
		var new : AudioStream = load(str("res://data/audio/music/", new_song_name, ".ogg"))
		if new != null:
			# if we are switching from one song to another, fade (unless we're transitioning from no song)
			if music_player.playing && current_song_name != "":
				current_song_name = new_song_name
				music_animator.play("song_fade_out")
				await get_tree().create_timer(3).timeout
				# don't start old music if a new song has started since the 3s timeout
				if current_song_name == new_song_name:
					music_player.stream = new
					music_player.play()
					# keep songs playing from queue
					music_animator.play("RESET")
			# if there is no song currently playing, just play the new one
			else:
				current_song_name = new_song_name
				music_player.stream = new
				music_player.play()
				music_animator.play("RESET")

func _physics_process(delta : float) -> void:
	if !music_player.playing && song_list != [""] && !Global.server_mode() && music_setting > 0 && master_setting > 0:
		# don't play the same song again if there is more than one song
		var songs_minus_current : Array = song_list.duplicate()
		if song_list.size() > 1:
			if songs_minus_current.has(current_song_name):
				songs_minus_current.erase(current_song_name)
		current_song_name = "NULL"
		switch_song(songs_minus_current, false)

func get_master_setting() -> float:
	return master_setting

func set_master_setting(new : float) -> void:
	master_setting = new
	if new == 0:
		AudioServer.set_bus_mute(0, true)
	elif !Global.server_mode():
		AudioServer.set_bus_mute(0, false)
	AudioServer.set_bus_volume_db(0, (-min_db + (min_db * new)))
	emit_signal("master_setting_changed")

func load_master_setting() -> float:
	var loaded_preset : Variant = UserPreferences.load_pref("master_setting")
	if loaded_preset != null:
		set_master_setting(loaded_preset as float)
	return master_setting

func get_music_setting() -> float:
	return music_setting

func set_music_setting(new : float) -> void:
	music_setting = new
	if new == 0:
		AudioServer.set_bus_mute(1, true)
	else:
		AudioServer.set_bus_mute(1, false)
	AudioServer.set_bus_volume_db(1, (-min_db + (min_db * new)))
	emit_signal("music_setting_changed")

func load_music_setting() -> float:
	var loaded_preset : Variant = UserPreferences.load_pref("music_setting")
	if loaded_preset != null:
		set_music_setting(loaded_preset as float)
	return music_setting

func get_sfx_setting() -> float:
	return sfx_setting

func set_sfx_setting(new : float) -> void:
	sfx_setting = new
	if new == 0:
		AudioServer.set_bus_mute(2, true)
	else:
		AudioServer.set_bus_mute(2, false)
	AudioServer.set_bus_volume_db(2, (-min_db + (min_db * new)))
	emit_signal("sfx_setting_changed")

func load_sfx_setting() -> float:
	var loaded_preset : Variant = UserPreferences.load_pref("sfx_setting")
	if loaded_preset != null:
		set_sfx_setting(loaded_preset as float)
	return sfx_setting

func get_ui_setting() -> float:
	return ui_setting

func set_ui_setting(new : float) -> void:
	ui_setting = new
	if new == 0:
		AudioServer.set_bus_mute(3, true)
	else:
		AudioServer.set_bus_mute(3, false)
	AudioServer.set_bus_volume_db(3, (-min_db + (min_db * new)))
	emit_signal("ui_setting_changed")

func load_ui_setting() -> float:
	var loaded_preset : Variant = UserPreferences.load_pref("ui_vol_setting")
	if loaded_preset != null:
		set_ui_setting(loaded_preset as float)
	return ui_setting
