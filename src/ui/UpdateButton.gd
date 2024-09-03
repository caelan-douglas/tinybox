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

func _ready() -> void:
	super()
	var req : HTTPRequest = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(_on_request_completed)
	# Points to the latest official release.
	req.request("https://api.github.com/repos/caelan-douglas/tinybox/releases/latest")
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	# Points to the official repo.
	OS.shell_open("https://github.com/caelan-douglas/tinybox/releases/latest")

func _on_request_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	var json : Variant = JSON.parse_string(body.get_string_from_utf8())
	if json == null: return
	
	if json.has("name"):
		# if we are not running latest version
		if str(json["name"]) != get_tree().current_scene.display_version:
			visible = true
			self_modulate = Color(35.0, 6.0, 0.0, 1.0)
			text = str(JsonHandler.find_entry_in_file("ui/update_available"), json["name"])
			if json.has("body"):
				tooltip_text = str("Release notes:\n", json["body"])
