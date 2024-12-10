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

extends Button
class_name MapList

@onready var built_in : VBoxContainer = $"TabContainer/Built-in"
@onready var your_maps : VBoxContainer = $"TabContainer/Your maps"
@onready var user_uploaded : VBoxContainer = $"TabContainer/World Browser"
@onready var all_lists : Array = [built_in, your_maps, user_uploaded]
@onready var window : Control = $TabContainer

@onready var map_list_entry : PackedScene = preload("res://data/scene/ui/MapListEntry.tscn")

var selected_name : String = ""
var selected_lines : Array = []

func add_map(file_name : String, list : Control, can_delete : bool = false, lines : Array = []) -> void:
	if lines.is_empty():
		lines = Global.get_tbw_lines(file_name)
	
	var image : Variant = Global.get_tbw_image_from_lines(lines)
	var tex : ImageTexture
	if image != null:
		image.resize(240, 162)
		tex = ImageTexture.create_from_image(image as Image)
	else:
		image = load("res://data/textures/tbw_placeholder.jpg")
		tex = ImageTexture.create_from_image(image as Image)
	
	var entry : Control = map_list_entry.instantiate()
	var entry_map_button : Button = entry.get_node("Map")
	var entry_img : TextureRect = entry.get_node("Map/Split/Image")
	var entry_title : Label = entry.get_node("Map/Split/Labels/Title")
	var entry_auth : Label = entry.get_node("Map/Split/Labels/Author")
	var entry_ver : Label = entry.get_node("Map/Split/Labels/Version")
	# set title
	entry_title.text = file_name
	# parse lines to set auth and version
	for l : String in lines:
		if l.contains("author ;"):
			entry_auth.text = str("by ", l.split(" ; ")[1])
		elif l.contains("version ;"):
			entry_ver.text = str("version: ", l.split(" ; ")[1])
	# set image
	entry_img.texture = tex
	if can_delete:
		var entry_delete_button : Button = entry.get_node("Delete")
		entry_delete_button.visible = true
		entry_delete_button.connect("pressed", _on_delete_pressed.bind(file_name))
	list.get_node("ScrollContainer/ItemList").add_child(entry)
	entry_map_button.connect("pressed", _on_map_selected.bind(file_name, lines, image))

func _on_delete_pressed(selected_map : String) -> void:
	if is_visible_in_tree():
		OS.move_to_trash(str(OS.get_user_data_dir(), "/world/", selected_map, ".tbw"))
		UIHandler.show_alert(str("The world '", selected_map, ".tbw' was moved to your device's trash bin."), 4)
	# refresh list
	refresh()

func _ready() -> void:
	connect("pressed", _on_pressed)
	window.connect("tab_changed", _on_tab_changed)
	refresh()
	
	var def_lines := Global.get_tbw_lines("Frozen Field")
	var def_image : Image = Global.get_tbw_image_from_lines(def_lines)
	_on_map_selected("Frozen Field", def_lines, def_image)

func _on_tab_changed(idx : int) -> void:
	if idx == 2:
		refresh_user_uploaded()

func _on_map_selected(file_name : String, lines : Array, image : Image) -> void:
	selected_name = file_name
	selected_lines = lines
	text = selected_name
	image.resize(80, 54)
	icon = ImageTexture.create_from_image(image as Image)
	window.visible = false
	disabled = false

func _on_pressed() -> void:
	window.visible = true
	disabled = true

func clear() -> void:
	for list : Control in all_lists:
		for c : Control in list.get_node("ScrollContainer/ItemList").get_children():
			c.queue_free()

var req_time : int = 0
func refresh_user_uploaded() -> void:
	for c : Control in user_uploaded.get_node("ScrollContainer/ItemList").get_children():
		c.queue_free()
	
	# add info about user uploaded maps
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = JsonHandler.find_entry_in_file("ui/user_maps_info")
	user_uploaded.get_node("ScrollContainer/ItemList").add_child(l)
	
	# loading tag
	var l2 := Label.new()
	l2.name = "_loading"
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.text = "\n\n\nFetching worlds..."
	l2.modulate = Color("#b973ff")
	user_uploaded.get_node("ScrollContainer/ItemList").add_child(l2)
	
	req_time = Time.get_ticks_msec()
	var req : HTTPRequest = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(self._user_maps_request_completed)

							# REST API on my website that hosts tinybox world files.
	var error := req.request("https://tinybox-worlds.caelan-douglas.workers.dev/")
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _user_maps_request_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	# remove loading text
	var loading_text : Control = user_uploaded.get_node("ScrollContainer/ItemList").get_node_or_null("_loading")
	if loading_text != null:
		loading_text.queue_free()
	
	# debug fetch time
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = str("\n\nWorld list fetch took ", Time.get_ticks_msec() - req_time, "ms.")
	user_uploaded.get_node("ScrollContainer/ItemList").add_child(l)
	
	var json := JSON.new()
	json.parse(body.get_string_from_utf8())
	var response : Variant = json.get_data()
	if response is Array:
		# sort by newest
		response.reverse()
		for r : Variant in response:
			if r is Dictionary:
				var map_name := "(no name)"
				var lines : Array = []
				if r.has("name"):
					map_name = r["name"]
				if r.has("tbw"):
					lines = str(r["tbw"]).split("\n")
				add_map(str(r["name"]), user_uploaded, false, lines)

func refresh() -> void:
	clear()
	# add built-in worlds
	add_map("Frozen Field", built_in)
	add_map("Acid House", built_in)
	add_map("Castle", built_in)
	add_map("Warp Spire", built_in)
	add_map("Quarry Quarrel", built_in)
	add_map("Perilous Platforms", built_in)
	add_map("Slapdash Central", built_in)
	add_map("Steep Swamp", built_in)
	add_map("Grasslands", built_in)
	# add user worlds to list
	for map : String in Global.get_user_tbw_names():
		add_map(map.split(".")[0], your_maps, true)
	# user-uploaded is handled seperately to help with bandwidth
