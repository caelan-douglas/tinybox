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

extends HSlider

enum AudioBus {
	MASTER,
	MUSIC,
	SFX,
	UI
}

@export var bus : AudioBus = AudioBus.MASTER

func _ready() -> void:
	connect("value_changed", set_volume)
	await get_tree().process_frame
	load_settings()
	# when the gamecanvas is shown or hidden
	connect("visibility_changed", load_settings)
	# don't change value with scrollwheel
	scrollable = false

func load_settings() -> void:
	match(bus):
		AudioBus.MASTER:
			var current := MusicHandler.load_master_setting()
			if current != null:
				value = current
		AudioBus.MUSIC:
			var current := MusicHandler.load_music_setting()
			if current != null:
				value = current
		AudioBus.SFX:
			var current := MusicHandler.load_sfx_setting()
			if current != null:
				value = current
		AudioBus.UI:
			var current := MusicHandler.load_ui_setting()
			if current != null:
				value = current

# Toggle music on/off and save the setting.
func set_volume(new : float) -> void:
	match(bus):
		AudioBus.MASTER:
			MusicHandler.set_master_setting(new)
			UserPreferences.save_pref("master_setting", MusicHandler.get_master_setting())
		AudioBus.MUSIC:
			MusicHandler.set_music_setting(new)
			UserPreferences.save_pref("music_setting", MusicHandler.get_music_setting())
		AudioBus.SFX:
			MusicHandler.set_sfx_setting(new)
			UserPreferences.save_pref("sfx_setting", MusicHandler.get_sfx_setting())
		AudioBus.UI:
			MusicHandler.set_ui_setting(new)
			UserPreferences.save_pref("ui_vol_setting", MusicHandler.get_ui_setting())
