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

extends AnimatedList

@onready var selector : OptionButton = $GamemodeSelector
@onready var button : Button = $StartGamemode
@onready var end_button : Button = $EndGamemode

func _ready() -> void:
	super()
	# automatically populate gamemode list based on map
	Global.get_world().connect("tbw_loaded", _on_tbw_loaded)
	button.connect("pressed", _on_start_gamemode_pressed)
	end_button.connect("pressed", _on_end_gamemode_pressed)
	if !multiplayer.is_server():
		button.disabled = true

func _on_start_gamemode_pressed() -> void:
	var idx : int = selector.selected
	if Global.get_world().gamemode_list.size() > 0:
		Global.get_world().gamemode_list[idx].connect("gamemode_ended", _on_gamemode_ended.bind(idx))
		button.disabled = true
		end_button.disabled = false
		Global.get_world().gamemode_list[idx].start()
	else:
		UIHandler.show_alert("There are no gamemodes to start!")

func _on_end_gamemode_pressed() -> void:
	if !multiplayer.is_server(): return
	var e : Event = Event.new(Event.EventType.END_ACTIVE_GAMEMODE, [])
	e.start()

func _on_gamemode_ended(idx : int) -> void:
	if Global.get_world().gamemode_list[idx].is_connected("gamemode_ended", _on_gamemode_ended.bind(idx)):
		Global.get_world().gamemode_list[idx].disconnect("gamemode_ended", _on_gamemode_ended.bind(idx))
	if multiplayer.is_server():
		button.disabled = false
	end_button.disabled = true

func _on_tbw_loaded() -> void:
	# delete old list
	selector.clear()
	# add new gamemodes
	for gm : Gamemode in Global.get_world().gamemode_list:
		selector.add_item(gm.gamemode_name)
	# clear button disabled state
	if multiplayer.is_server():
		button.disabled = false
