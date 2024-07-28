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

extends Object
class_name Gamemode

var name := "Gamemode"
var start_events : Dictionary = {
	0 : []
}
var watchers : Dictionary = {
	0 : []
}
var end_events : Dictionary = {
	0 : []
}

func _init(g_name : String, g_start_events : Dictionary, g_watchers : Dictionary, g_end_events : Dictionary) -> void:
	name = g_name
	watchers = g_watchers
	g_end_events = g_end_events

func start() -> void:
	pass
	# run start events
	# setup watchers
	# connect watchers to 'end' func

func end() -> void:
	pass
	# run end events
	# cleanup
