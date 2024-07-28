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


# A group of bricks that form a premade asset, like a car, house, etc.
extends TBWObject
class_name Building

var place_on_spawn := true
@export var txt_name := "car"

func _init(_place_on_spawn := true) -> void:
	place_on_spawn = _place_on_spawn

func _ready() -> void:
	# only server spawns buildings
	if !multiplayer.is_server():
		# If not the server, delete self
		queue_free()
		return
	if place_on_spawn:
		print("Attempting to load ", txt_name, ".txt")
		var load_file := FileAccess.open(str("res://data/building/", txt_name, ".txt"), FileAccess.READ)
		if load_file != null:
			# load building
			var lines := []
			while not load_file.eof_reached():
				var line := load_file.get_line()
				lines.append(str(line))
			if multiplayer.is_server():
				Global.get_world()._server_load_building(lines, global_position)
