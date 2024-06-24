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

extends DynamicButton

@export var editor_leave_text := false

func _ready() -> void:
	super()
	connect("pressed", ask_leave_server)

func ask_leave_server() -> void:
	var actions := []
	if !editor_leave_text:
		if multiplayer.is_server():
			actions = UIHandler.show_alert_with_actions("Are you sure you wish to leave? You are the host \nof the server, all players will be disconnected.", ["Close server", "Stay"], true)
		else:
			actions = UIHandler.show_alert_with_actions("Are you sure you wish to leave?", ["Leave server", "Stay"])
	else:
		actions = UIHandler.show_alert_with_actions("Are you sure? Any unsaved changes will be lost.", ["Leave editor", "Stay"], true)
	actions[0].connect("pressed", get_tree().current_scene.leave_server)
