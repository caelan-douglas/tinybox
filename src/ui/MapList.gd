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
class_name MapList

@export var associated_button : Button
@export var report_button : Button

@onready var built_in : VBoxContainer = $"TabContainer/Built-in"
@onready var your_maps : VBoxContainer = $"TabContainer/Saved maps"
@onready var user_uploaded : VBoxContainer = $"TabContainer/World Browser (Online)"
@onready var user_uploaded_list : GridContainer = $"TabContainer/World Browser (Online)/ScrollContainer/ItemList"
@onready var all_lists : Array = [built_in, your_maps, user_uploaded]
@onready var window : Control = $TabContainer

@onready var search : LineEdit = $"TabContainer/World Browser (Online)/Header/FilterOptions/Search"

@onready var map_list_entry : PackedScene = preload("res://data/scene/ui/MapListEntry.tscn")

var selected_name : String = ""
var selected_lines : Array = []
var _map_downloaded : bool = false

func add_map(file_name : String, list : Control, can_delete : bool = false, lines : Array = [], id : int = -1) -> void:
	if lines.is_empty():
		lines = Global.get_tbw_lines(file_name)
	
	var image : Variant = Global.get_tbw_image_from_lines(lines)
	var tex : ImageTexture
	if image != null && !image.is_empty():
		image.resize(240, 162)
		tex = ImageTexture.create_from_image(image as Image)
	else:
		image = load("res://data/textures/tbw_placeholder.jpg")
		tex = ImageTexture.create_from_image(image as Image)
	
	var entry_is_featured : bool = false
	var entry : Control = map_list_entry.instantiate()
	var entry_map_button : Button = entry.get_node("Map")
	var entry_img : TextureRect = entry.get_node("Map/Split/Image")
	var entry_featured : Control = entry.get_node("Map/Split/Labels/FeaturedTag")
	var entry_new : Control = entry.get_node("Map/Split/Labels/NewTag")
	var entry_title : Label = entry.get_node("Map/Split/Labels/Title")
	var entry_auth : Label = entry.get_node("Map/Split/Labels/Author")
	var entry_date : Label = entry.get_node("Map/Split/Labels/Date")
	var entry_downloads : Label = entry.get_node("Map/Split/Labels/Downloads")
	var entry_ver : Label = entry.get_node("Map/Split/Labels/Version")
	# set title
	entry_title.text = file_name
	# parse lines to set auth and version
	for l : String in lines:
		if l.contains("author ;"):
			entry_auth.text = str("by ", l.split(" ; ")[1])
		elif l.contains("version ;"):
			entry_ver.text = str("version: ", Global.format_server_version(l.split(" ; ")[1]))
		elif l.contains("featured ;"):
			if str(int(l.split(" ; ")[1])) == "1":
				entry_featured.visible = true
				entry_is_featured = true
		elif l.contains("date ;"):
			entry_date.text = str("on ", l.split(" ; ")[1])
			# calculate if "new" (uploaded <2 weeks ago)
			var upload_date : int = Time.get_unix_time_from_datetime_string(str(l.split(" ; ")[1]))
			var current_date : int = Time.get_unix_time_from_system()
			# 2 weeks in seconds
			if (current_date - upload_date < 1209600):
				entry_new.visible = true
		elif l.contains("downloads ;"):
			entry_downloads.text = str("Downloads: ", int(l.split(" ; ")[1]))
	# set image
	entry_img.texture = tex
	if can_delete:
		var entry_delete_button : Button = entry.get_node("Delete")
		entry_delete_button.visible = true
		entry_delete_button.connect("pressed", _on_delete_pressed.bind(file_name))
	list.get_node("ScrollContainer/ItemList").add_child(entry)
	# move featured worlds to top
	if entry_is_featured:
		list.get_node("ScrollContainer/ItemList").move_child(entry, 1)
	entry_map_button.connect("pressed", _on_map_selected.bind(file_name, lines, image, id))

func _on_delete_pressed(selected_map : String) -> void:
	if is_visible_in_tree():
		OS.move_to_trash(str(OS.get_user_data_dir(), "/world/", selected_map, ".tbw"))
		UIHandler.show_alert(str("The world '", selected_map, ".tbw' was moved to your device's trash bin."), 4)
	# refresh list
	refresh()

func _on_report_pressed(id : int, map_name : String) -> void:
	var actions := UIHandler.show_alert_with_actions(str("Really report map:\n'", map_name, "'?"), ["Report map", "Cancel"], false)
	actions[0].connect("pressed", _send_report.bind(id))

func _send_report(id : int) -> void:
	var req : HTTPRequest = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(self._set_selected_user_map_tbw)
						# REST API on my website that hosts tinybox world files.
	var error := req.request(str(UserPreferences.database_repo, "?report=", id))
	if error != OK:
		push_error("An error occurred in the HTTP request.")
	UIHandler.show_alert("Thank you, your report has been sent.", 4, false)
	# disable once reported
	if report_button != null:
		report_button.disabled = true

func _ready() -> void:
	super()
	connect("pressed", _on_pressed)
	if !is_connected("visibility_changed", _on_visibility_changed):
		connect("visibility_changed", _on_visibility_changed)
	search.connect("text_changed", _on_search)
	window.connect("tab_changed", _on_tab_changed)
	refresh()
	
	var def_lines := Global.get_tbw_lines("Frozen Field")
	var def_image : Image = Global.get_tbw_image_from_lines(def_lines)
	_on_map_selected("Frozen Field", def_lines, def_image)

func _on_search(what : String) -> void:
	if user_uploaded_list == null:
		return
	
	if what != "":
		for c : Control in user_uploaded_list.get_children():
			c.visible = false
	else:
		for c : Control in user_uploaded_list.get_children():
			c.visible = true
		return
	
	for c : Control in user_uploaded_list.get_children():
		var name_label : Label = c.get_node_or_null("Map/Split/Labels/Title")
		var auth_label : Label = c.get_node_or_null("Map/Split/Labels/Author")
		if name_label != null:
			if name_label.text.to_lower().contains(what.to_lower()):
				c.visible = true
		if auth_label != null:
			if auth_label.text.to_lower().contains(what.to_lower()):
				c.visible = true

var first_open : bool = true
func _on_visibility_changed() -> void:
	if first_open:
		refresh_user_uploaded()
		first_open = false
	# hide menu when parent menu is hidden
	if is_visible_in_tree() == false:
		search.text = ""
		window.visible = false
		disabled = false
		if associated_button != null:
			associated_button.disabled = false

func _on_tab_changed(idx : int) -> void:
	if idx == 2:
		refresh_user_uploaded()
	else:
		for c : Node in get_children():
			if c is HTTPRequest:
				c.queue_free()

func _on_map_selected(file_name : String, lines : Array, image : Image, id : int = -1) -> void:
	selected_name = file_name
	# a browser map has been selected, get its world
	if id != -1:
		_map_downloaded = false
		var req : HTTPRequest = HTTPRequest.new()
		add_child(req)
		req.request_completed.connect(self._set_selected_user_map_tbw)
							# REST API on my website that hosts tinybox world files.
		var error := req.request(str(UserPreferences.database_repo, "?id=", id))
		if error != OK:
			push_error("An error occurred in the HTTP request.")
		
		window.visible = false
		if associated_button != null:
			associated_button.disabled = true
		icon = null
		text = "Downloading..."
		while(!_map_downloaded):
			await get_tree().create_timer(0.1).timeout
		
		# show report button for downloaded maps
		if report_button != null:
			if report_button.is_connected("pressed", _on_report_pressed):
				report_button.disconnect("pressed", _on_report_pressed)
			report_button.visible = true
			report_button.disabled = false
			report_button.connect("pressed", _on_report_pressed.bind(id, file_name))
	else:
		selected_lines = lines
		# hide report button for local maps
		if report_button != null:
			report_button.visible = false
	text = selected_name
	image.resize(80, 54)
	icon = ImageTexture.create_from_image(image as Image)
	window.visible = false
	disabled = false
	if associated_button != null:
		associated_button.disabled = false

func _set_selected_user_map_tbw(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	# get full map tbw now that map has been selected
	var json := JSON.new()
	json.parse(body.get_string_from_utf8())
	var response : Variant = json.get_data()
	if response is Array:
		if response[0] is Dictionary:
			if response[0].has("tbw"):
				selected_lines = str(response[0]["tbw"]).split("\n")
	_map_downloaded = true

func _on_pressed() -> void:
	window.visible = true
	disabled = true

func clear() -> void:
	for list : Control in all_lists:
		for c : Control in list.get_node("ScrollContainer/ItemList").get_children():
			c.queue_free()

var req_time : int = 0
func refresh_user_uploaded() -> void:
	if user_uploaded_list == null:
		return
	
	for c : Control in user_uploaded_list.get_children():
		c.queue_free()
	
	search.text = ""
	search.editable = false
	
	# loading tag
	var l2 := Label.new()
	l2.name = "_loading"
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l2.text = "\n\n\nFetching worlds from online database..."
	l2.modulate = Color("#b973ff")
	user_uploaded_list.add_child(l2)
	
	req_time = Time.get_ticks_msec()
	var req : HTTPRequest = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(self._user_maps_request_completed)

							# REST API on my website that hosts tinybox world files.
	var error := req.request(str(UserPreferences.database_repo))
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func _user_maps_request_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	if user_uploaded_list == null:
		return
	# remove loading text
	var loading_text : Control = user_uploaded_list.get_node_or_null("_loading")
	if loading_text != null:
		loading_text.queue_free()
	
	if (response_code != 200):
		var lerr := Label.new()
		lerr.name = "_error"
		lerr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lerr.text = "\n\n\nUnable to fetch worlds. Do you have an internet connection?\n(If you changed the Database Repository setting, it may be incorrectly typed.)"
		lerr.modulate = Color("#d65656")
		user_uploaded_list.add_child(lerr)
		return
	
	search.editable = true
	
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
				var id : int = -1
				if r.has("name"):
					map_name = r["name"]
				if r.has("image"):
					lines = [\
						str("image ; ", r["image"]),\
						str("author ; ", r["author"]),\
						str("version ; ", r["version"]),\
						str("featured ; ", r["featured"]),\
						str("date ; ", r["date"]),\
						str("downloads ; ", r["downloads"])\
						]
				if r.has("id"):
					id = r["id"] as int
				add_map(str(r["name"]), user_uploaded, false, lines, id)
	
	# debug fetch time @ bottom
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text = str("\n\nEnd of list. World list fetch took ", Time.get_ticks_msec() - req_time, "ms (from repo ", UserPreferences.database_repo, ").")
	user_uploaded_list.add_child(l)

func refresh() -> void:
	clear()
	# add built-in worlds
	add_map("Frozen Field", built_in)
	add_map("Empty Room", built_in)
	add_map("Icy Inclines", built_in)
	add_map("Tunnel Tussle", built_in)
	add_map("Acid House", built_in)
	add_map("Warp Spire", built_in)
	add_map("Quarry Quarrel", built_in)
	add_map("Perilous Platforms", built_in)
	add_map("Slapdash Central", built_in)
	add_map("Grasslands", built_in)
	# add user worlds to list
	for map : String in Global.get_user_tbw_names():
		# don't show temp clipboard map
		if map == "temp.tbw":
			continue
		add_map(map.split(".")[0], your_maps, true)
	# user-uploaded is handled seperately to help with bandwidth
