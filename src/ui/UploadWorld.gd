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

@export var world_name : LineEdit

func _ready() -> void:
	super()
	connect("pressed", _on_upload_world_pressed)

func _on_upload_world_pressed() -> void:
	if world_name.text == "":
		UIHandler.show_alert("Please enter a world name above!", 4, false, UIHandler.alert_colour_error)
	else:
		var actions := UIHandler.show_alert_with_actions("Upload world to World Browser?\nIt will be made public and available to download for other players.\nOnce uploaded, it can't be changed.\n\nThe preview image will be taken from the current camera angle.", ["Upload world", "Cancel"], false)
		actions[0].connect("pressed", _upload_world)

func _upload_world() -> void:
	var ok : bool = await Global.get_world().save_tbw(str(world_name.text))
	if ok:
		var map_name : String = world_name.text
		var tbw : String = "" 
		var lines : Array = Global.get_tbw_lines(str(world_name.text))
		for l : String in lines:
			tbw += str(l, "\n")
		
		var req : HTTPRequest = HTTPRequest.new()
		add_child(req)
		req.request_completed.connect(self._user_maps_upload_request_completed)
		var body := JSON.new().stringify({"name": map_name, "tbw": tbw})
								# default REST API for worlds, hosted on my website
		var error := req.request(str(UserPreferences.database_repo), ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)
		if error != OK:
			push_error("An error occurred in the HTTP request.")
	else:
		UIHandler.show_alert("Sorry, there was an error saving the world.", 4, false, UIHandler.alert_colour_error)

func _user_maps_upload_request_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	if str(body.get_string_from_utf8()) == "OK":
		UIHandler.show_alert("Your world has been uploaded.", 4, false)
	else:
		UIHandler.show_alert(str("Sorry, issue uploading your world: ", body.get_string_from_utf8()), 4, false, UIHandler.alert_colour_error)
