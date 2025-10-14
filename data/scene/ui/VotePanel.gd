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

extends AnimatedPanelContainer
class_name VotePanel
signal voting_ended

@onready var grid : GridContainer = get_node("VBoxContainer/GridContainer")
var buttons : Array = []
var maps : Array = []
var player_votes : Dictionary = {}
var vote_timer : Timer

func _ready() -> void:
	super()
	buttons.append(get_node("VBoxContainer/GridContainer/Opt1"))
	buttons.append(get_node("VBoxContainer/GridContainer/Opt2"))
	buttons.append(get_node("VBoxContainer/GridContainer/Opt3"))
	buttons.append(get_node("VBoxContainer/GridContainer/Opt4"))
	buttons.append(get_node("VBoxContainer/GridContainer/Replay"))
	buttons.append(get_node("VBoxContainer/GridContainer/Sandbox"))
	
	vote_timer = Timer.new()
	vote_timer.wait_time = 20
	vote_timer.one_shot = true
	vote_timer.connect("timeout", _on_vote_timeout)
	add_child(vote_timer)

# only runs as server
func start_voting() -> void:
	if !multiplayer.is_server():
		return
	maps = []
	player_votes = {}
	# populate list with random maps
	var req : HTTPRequest = HTTPRequest.new()
	add_child(req)
	req.request_completed.connect(self._maps_request_completed)
							# REST API on my website that hosts tinybox world files.
	var error := req.request(str(UserPreferences.database_repo))
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func update_timer() -> void:
	if player_votes.size() >= Global.get_world().rigidplayer_list.size():
		vote_timer.stop()
		_on_vote_timeout()
	if !vote_timer.is_stopped():
		update_timer_rpc.rpc(vote_timer.time_left)
		await get_tree().create_timer(1).timeout
		update_timer()

# Send timer update to peers
@rpc("any_peer", "call_local", "reliable")
func update_timer_rpc(time : int) -> void:
	get_node("VBoxContainer/HBoxContainer/Timer").text = str(time, "s") 

@rpc("any_peer", "call_local", "reliable")
func on_voting_ended_rpc() -> void:
	emit_signal("voting_ended")

# runs as server
func _on_vote_timeout() -> void:
	on_voting_ended_rpc.rpc()
	var votes : Array = [0, 0, 0, 0, 0, 0]
	for vote : int in player_votes.values():
		votes[vote] += 1
	var highest_vote : int = 5
	# in this case, highest_vote is idx 0-5
	for i in 6:
		if votes[i] > votes[highest_vote]:
			highest_vote = i
	# for 1-4, choose map
	# for 5, reload map and restart last gamemode
	# for 6, enter sandbox (do nothing)
	match (highest_vote):
		4:
			# replay
			Global.server_start_gamemode.rpc_id(1, Global.last_gamemode_idx, Global.last_gamemode_params, Global.last_gamemode_mods)
		5:
			# sandbox
			for player : RigidPlayer in Global.get_world().rigidplayer_list:
				player.change_state.rpc_id(player.get_multiplayer_authority(), RigidPlayer.IDLE)
				player.go_to_spawn()
				player.protect_spawn()
		_:
			for player : RigidPlayer in Global.get_world().rigidplayer_list:
				player.change_state.rpc_id(player.get_multiplayer_authority(), RigidPlayer.IDLE)
				player.protect_spawn()
			# get map based on ID
			var map_id : int = maps[highest_vote]["id"]
			
			# built-in
			if map_id == -1:
				Global.get_world().open_tbw(Global.get_tbw_lines(str(maps[highest_vote]["name"])))
			else:
				# browser
				var req : HTTPRequest = HTTPRequest.new()
				add_child(req)
				req.request_completed.connect(self._switch_map)
									# REST API on my website that hosts tinybox world files.
				var error := req.request(str(UserPreferences.database_repo, "?id=", map_id))
				if error != OK:
					push_error("An error occurred in the HTTP request.")
	hide_panel.rpc()

func _switch_map(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	# get full map tbw now that map has been selected
	var json := JSON.new()
	json.parse(body.get_string_from_utf8())
	var response : Variant = json.get_data()
	if response is Array:
		if response[0] is Dictionary:
			if response[0].has("tbw"):
				var lines : PackedStringArray = str(response[0]["tbw"]).split("\n")
				Global.get_world().open_tbw(lines)

func _maps_request_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	if (response_code != 200):
		return
	
	vote_timer.wait_time = 20
	vote_timer.one_shot = true
	vote_timer.start()
	update_timer()
	
	var json := JSON.new()
	json.parse(body.get_string_from_utf8())
	var response : Variant = json.get_data()
	# Add 4 votable maps; 2 from browser, 2 from built-in.
	# Selection of good built in gamemode maps.
	var built_in_maps : Array = [\
		"Icy Inclines",
		"Tunnel Tussle",
		"Acid House",
		"Warp Spire",
		"Quarry Quarrel",
		"Perilous Platforms",
		"Slapdash Central"]
	
	for i in 2:
		var map_name : String = built_in_maps.pick_random()
		maps.append({"name": map_name, "id": -1, "image": "-1", "author": "Tinybox"})
		# pop from array pool
		built_in_maps.pop_at(built_in_maps.find(map_name))
	if response is Array:
		for i in 2:
			var r : Variant = response.pick_random()
			if r is Dictionary:
				var map_name := "(no name)"
				var id : int = -1
				var image : String = ""
				var author : String = ""
				if r.has("name"):
					map_name = r["name"]
				if r.has("image"):
					image = r["image"]
					author = r["author"]
				if r.has("id"):
					id = r["id"] as int
				maps.append({"name": map_name, "id": id, "image": image, "author": author})
			# pop from array pool
			response.pop_at(response.find(r))
	show_panel.rpc(maps)

@rpc("any_peer", "call_local", "reliable")
func show_panel(maps : Array) -> void:
	player_votes = {}
	update_player_votes.rpc(player_votes)
	
	visible = true
	for i in 4:
		buttons[i].get_node("Split/Labels/Title").text = maps[i]["name"]
		buttons[i].get_node("Split/Labels/Author").text = str("by ", maps[i]["author"])
		buttons[i].connect("pressed", _on_vote.bind(i))
		var image : Variant
		# built-in
		if (maps[i]["id"] == -1):
			image = Global.get_tbw_image_from_lines(Global.get_tbw_lines(str(maps[i]["name"])))
		# from browser
		else:
			image = Global.get_tbw_image_from_lines([str("image ; ", maps[i]["image"])])
		var tex : ImageTexture
		if image != null:
			image.resize(240, 162)
			tex = ImageTexture.create_from_image(image as Image)
			buttons[i].get_node("Split/Image").texture = tex
	buttons[4].connect("pressed", _on_vote.bind(4))
	buttons[5].connect("pressed", _on_vote.bind(5))
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_vote(idx : int) -> void:
	send_vote_to_server.rpc_id(1, idx)

@rpc("any_peer", "call_local", "reliable")
func send_vote_to_server(idx : int) -> void:
	player_votes[str(multiplayer.get_remote_sender_id())] = idx
	update_player_votes.rpc(player_votes)

@rpc("any_peer", "call_local", "reliable")
func update_player_votes(_player_votes : Dictionary) -> void:
	for i in 6:
		var this_map_votes : int = 0
		for vote : Variant in _player_votes.values():
			if str(vote) == str(i):
				this_map_votes += 1
		if this_map_votes == 0:
			# no text for no votes
			buttons[i].get_node("Split/Labels/VoteCount").text = ""
		else:
			buttons[i].get_node("Split/Labels/VoteCount").text = str(this_map_votes, " votes")

@rpc("any_peer", "call_local", "reliable")
func hide_panel() -> void:
	visible = false
	if !Global.is_paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
