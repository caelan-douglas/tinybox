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

@onready var selector : OptionButton = $GamemodeSelector
@onready var button : Button = $StartGamemode

var gamemode_list : Array[Gamemode] = []

func _ready() -> void:
	# automatically populate gamemode list based on map
	Global.get_world().connect("tbw_loaded", _on_tbw_loaded)
	button.connect("pressed", _on_start_gamemode_pressed)

func _on_start_gamemode_pressed() -> void:
	var idx : int = selector.selected
	gamemode_list[idx].connect("gamemode_ended", _on_gamemode_ended.bind(idx))
	button.disabled = true
	gamemode_list[idx].start()

func _on_gamemode_ended(idx : int) -> void:
	if gamemode_list[idx].is_connected("gamemode_ended", _on_gamemode_ended.bind(idx)):
		gamemode_list[idx].disconnect("gamemode_ended", _on_gamemode_ended.bind(idx))
	button.disabled = false

func _on_tbw_loaded() -> void:
	gamemode_list = []
	# clear button disabled state
	button.disabled = false
	# clear old selector list
	selector.clear()
	for gamemode : Gamemode in Global.get_world().get_tbw_gamemodes():
		gamemode_list.append(gamemode)
		selector.add_item(gamemode.gamemode_name)
