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

signal upnp_completed(error)

const Player = preload("res://data/scene/character/RigidPlayer.tscn")
const PORT = 30814
# thread for UPNP connection
var thread = null
var upnp = null
var host_public = true
var upnp_err = -1
var enet_peer = ENetMultiplayerPeer.new()
# For LAN servers
var lan_advertiser : ServerAdvertiser = null
var lan_listener : ServerListener = ServerListener.new()
var lan_entries = []

# Server version between client and server must match
# in order for client to join.
#
# Same as display version, but with leading zero for minor release
# to make room for double digit minor releases
# Last digit is 0 for pre-release and 1 for release
# ex. 9101 for 9.10; 10060 for 10.6pre; 12111 for 12.11
#     9 10 1         10 06 0            12 11 1
var server_version = 9100

# Displays on the title screen and game canvas
#
# major.minor
# add 'pre' at end for pre-release
var display_version = "beta 9.10pre"

@onready var host_button = $MultiplayerMenu/MainMenu/RightColumn/HostPanel/HostPanelContainer/Host
@onready var host_public_button = $MultiplayerMenu/MainMenu/RightColumn/HostPanel/HostPanelContainer/HostPublic
@onready var join_button = $MultiplayerMenu/MainMenu/RightColumn/JoinPanel/JoinPanelContainer/Join
@onready var display_name_field = $MultiplayerMenu/MainMenu/LeftColumn/MultiplayerSettings/MultiplayerSettingsContainer/DisplayName
@onready var join_address = $MultiplayerMenu/MainMenu/RightColumn/JoinPanel/JoinPanelContainer/Address
@onready var host_map_selector = $MultiplayerMenu/MainMenu/RightColumn/HostPanel/HostPanelContainer/MapSelection
@onready var editor_button = $MultiplayerMenu/MainMenu/LeftColumn/Editor

func _ready():
	# fullscreen if not in debug mode
	if !OS.has_feature("editor") && !OS.get_name() == "macOS":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	# if on macOS, go into fullscreen, not exclusive fullscreen (allows access to dock/status bar when hovering top/bottom)
	elif !OS.has_feature("editor") && OS.get_name() == "macOS":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	# Clear the graphics cache when entering the main menu.
	Global.graphics_cache = []
	
	host_button.connect("pressed", _on_host_pressed)
	host_public_button.connect("toggled", _on_host_public_toggled)
	host_public = host_public_button.button_pressed
	join_button.connect("pressed", _on_join_pressed)
	editor_button.connect("pressed", _on_editor_pressed)
	
	# Load display name from prefs.
	var display_pref = UserPreferences.load_pref("display_name")
	if display_pref != null:
		display_name_field.text = str(display_pref)
	
	# Load join address from prefs.
	var address = UserPreferences.load_pref("join_address")
	if address != null:
		join_address.text = str(address)
	
	# Scan for LAN servers.
	get_tree().current_scene.add_child(lan_listener)
	lan_listener.connect("new_server", _on_new_lan_server)
	lan_listener.connect("remove_server", _on_remove_lan_server)

func _on_new_lan_server(serverInfo):
	var multiplayer_menu = get_node_or_null("MultiplayerMenu")
	var lan_entry = load("res://data/scene/ui/LANEntry.tscn")
	if multiplayer_menu:
		var new_lan_entry = lan_entry.instantiate()
		get_node("MultiplayerMenu/MainMenu/RightColumn/LANPanel/LANPanelContainer/Label").text = "Join a server via LAN"
		multiplayer_menu.get_node("MainMenu/RightColumn/LANPanel/LANPanelContainer").add_child(new_lan_entry)
		new_lan_entry.get_node("Name").text = str(serverInfo.name)
		new_lan_entry.get_node("Join").connect("pressed", _on_join_pressed.bind(serverInfo.ip, true))
		new_lan_entry.entry_server_ip = serverInfo.ip
		lan_entries.append(new_lan_entry)

func _on_remove_lan_server(serverIp):
	for entry in lan_entries:
		if entry is LANEntry:
			if entry.entry_server_ip == serverIp:
				lan_entries.erase(entry)
				entry.queue_free()
				if lan_entries.size() < 1:
					get_node("MultiplayerMenu/MainMenu/RightColumn/LANPanel/LANPanelContainer/Label").text = "Searching for LAN servers..."

func verify_display_name(check_string):
	var regex = RegEx.new()
	regex.compile("^\\s+$")
	if regex.search(str(check_string)):
		return "has only whitespaces"
	return null

func get_display_name_from_field():
	var t_display_name = display_name_field.text
	# User must have a display name.
	if t_display_name == "" || t_display_name == null:
		UIHandler.show_alert("Please enter a display name", 4)
		display_name_field.text = ""
		return null
	# Users can't have a display name that's only whitespace.
	var check_result = verify_display_name(t_display_name)
	if check_result != null:
		UIHandler.show_alert(str("Display name invalid (", check_result, ")"), 4)
		display_name_field.text = ""
		return null
	# Save the successful name.
	UserPreferences.save_pref("display_name", t_display_name)
	return t_display_name

# UPnP setup thread
func _upnp_setup(server_port):
	upnp = UPNP.new()
	host_button.call_deferred("set", "text", "Finding gateway...")
	# timeout 2500ms
	var err = upnp.discover(2500)
	
	if err != OK:
		push_error(str(err))
		upnp_err = err
		UIHandler.call_deferred("show_alert", str("Failed to start server because: ", str(err)), 15, false, true)
		call_deferred("emit_signal", "upnp_completed", err)
		return
	
	if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
		host_button.call_deferred("set", "text", "Configuring...")
		upnp.add_port_mapping(server_port, server_port, ProjectSettings.get_setting("application/config/name"), "UDP")
		upnp.add_port_mapping(server_port, server_port, ProjectSettings.get_setting("application/config/name"), "TCP")
		call_deferred("emit_signal", "upnp_completed", OK)
	elif upnp.get_device_count() < 1:
		UIHandler.call_deferred("show_alert", "Failed to start server because: No devices", 15, false, true)
		call_deferred("emit_signal", "upnp_completed", 27)
	else:
		# unknown error
		UIHandler.call_deferred("show_alert", "Failed to start server because: Unknown\n(UPnP is probably disabled on your router)", 15, false, true)
		call_deferred("emit_signal", "upnp_completed", 28)

func _exit_tree():
	# Wait for thread finish here to handle game exit while the thread is running.
	if thread != null:
		thread.wait_to_finish()
	# Delete the port opened by upnp.
	if upnp != null:
		upnp.delete_port_mapping(PORT, "UDP")
		upnp.delete_port_mapping(PORT, "TCP")

func _on_host_public_toggled(mode) -> void:
	host_public = mode
	if mode:
		host_public_button.set_text_to_json("ui/host_public_settings/on")
	else:
		host_public_button.set_text_to_json("ui/host_public_settings/off")

func _on_host_pressed() -> void:
	Global.display_name = get_display_name_from_field()
	if Global.display_name == null:
		return
	
	# Change button text to notify user server is starting.
	host_button.text = "Starting server..."
	host_button.disabled = true
	
	# only port forward public servers
	if host_public:
		thread = Thread.new()
		thread.start(_upnp_setup.bind(PORT))
		
		await Signal(self, "upnp_completed")
		
		if upnp_err != -1:
			host_button.text = "Host server"
			host_button.disabled = false
			return
	
	get_tree().current_scene.get_node("MultiplayerMenu").visible = false
	get_tree().current_scene.get_node("GameCanvas").visible = true
	# Get the host's selected map from the dropdown.
	var selected_map = host_map_selector.get_item_text(host_map_selector.selected)
	
	# Create the server.
	enet_peer.create_server(PORT)
	# Set the current multiplayer peer to the server.
	multiplayer.multiplayer_peer = enet_peer
	# When a new player connects, add them with their id.
	multiplayer.peer_connected.connect(add_peer)
	multiplayer.peer_disconnected.connect(remove_player)
	# Load the world using the multiplayerspawner spawn method.
	var world = $World
	world.load_map.call_deferred(load(str("res://data/scene/", selected_map, "/", selected_map, ".tscn")))
	await Signal(world, "map_loaded")
	add_peer(multiplayer.get_unique_id())
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Create the LAN advertiser.
	lan_advertiser = ServerAdvertiser.new()
	get_tree().current_scene.add_child(lan_advertiser)
	lan_advertiser.serverInfo["name"] = str(display_name_field.text, "'s Server")
	lan_advertiser.broadcast_interval = 3

# Only runs for client
func _on_join_pressed(address = null, is_lan = false) -> void:
	if address == null:
		address = join_address.text
	# Save address for join (only if not LAN.)
	if !is_lan:
		UserPreferences.save_pref("join_address", address)
	
	# debug name
	if display_name_field.text == "Merle":
		var names = ["Test1", "Test2", "Dog man", "Dog", "Extra Long Name Very Long"]
		Global.display_name = names.pick_random()
	else:
		Global.display_name = get_display_name_from_field()
		if Global.display_name == null:
			return
		
	# Change button text to notify user we are joining.
	join_button.text = "Trying to join..."
	
	# Create the client.
	enet_peer.create_client(address, PORT)
	# Set the current multiplayer peer to the client.
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.connection_failed.connect(kick_client.bind("Server timeout or couldn't find server."))
	multiplayer.peer_disconnected.connect(remove_player)
	multiplayer.server_disconnected.connect(_on_host_disconnect_as_client)
	$World.delete_old_map()
	await Signal($World, "map_loaded")
	get_tree().current_scene.get_node("MultiplayerMenu").visible = false
	get_tree().current_scene.get_node("GameCanvas").visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Entering the world editor.
func _on_editor_pressed() -> void:
	Global.display_name = get_display_name_from_field()
	if Global.display_name == null:
		return
	
	# Change button text to notify user server is starting.
	editor_button.text = "Loading editor..."
	editor_button.disabled = true
	
	get_tree().current_scene.get_node("MultiplayerMenu").visible = false
	get_tree().current_scene.get_node("EditorCanvas").visible = true
	
	# Create the server.
	enet_peer.create_server(PORT)
	# Set the current multiplayer peer to the server.
	multiplayer.multiplayer_peer = enet_peer
	# When a new player connects, add them with their id.
	multiplayer.peer_connected.connect(add_peer)
	multiplayer.peer_disconnected.connect(remove_player)
	# Load the world using the multiplayerspawner spawn method.
	var world = $World
	world.load_map.call_deferred(load(str("res://data/scene/EditorWorld/EditorWorld.tscn")))
	await Signal(world, "map_loaded")
	add_peer(multiplayer.get_unique_id())
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Create the LAN advertiser.
	lan_advertiser = ServerAdvertiser.new()
	get_tree().current_scene.add_child(lan_advertiser)
	lan_advertiser.serverInfo["name"] = str(display_name_field.text, "'s Editor")
	lan_advertiser.broadcast_interval = 3

# Notify clients if the host disconnects.
func _on_host_disconnect_as_client() -> void:
	# in case host disconnects while mouse is captured
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	UIHandler.show_alert("Host disconnected :(", -1, true, true)

func leave_server() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	enet_peer.close()
	Global.connected_to_server = false
	get_tree().change_scene_to_file("res://data/scene/MainScene.tscn")

# Kick or disconnect from the server with a reason.
func kick_client(reason : String) -> void:
	UIHandler.show_alert(str("Connection failure: ", reason), 8, false, true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	leave_server()
	
@rpc("any_peer", "call_remote", "reliable")
func announce_player_joined(p_display_name : String) -> void:
	UIHandler.show_alert(str(p_display_name, " joined."), 4)

# Adds a player to the server with id & name.
func add_peer(peer_id : int) -> void:
	if multiplayer.is_server():
		# for connecting clients, do prejoin before adding player
		if peer_id != 1:
			rpc_id(peer_id, "client_info_request_from_server")
		# for the server just add them
		else:
			var player = Player.instantiate()
			player.name = str(peer_id)
			$World.add_child(player)
			Global.connected_to_server = true

# first request sent out to the joining client from the server
@rpc("call_local", "reliable")
func client_info_request_from_server() -> void:
	info_response_from_client.rpc_id(1, multiplayer.get_unique_id(), server_version, Global.display_name)

# first response from the joining client; check validity here
@rpc("any_peer", "call_remote", "reliable")
func info_response_from_client(id : int, client_server_version : int, client_name : String) -> void:
	if client_server_version != server_version:
		# kick new client with code 1 (mismatch version)
		response_from_server_joined.rpc_id(id, 1)
		# wait for a bit before kicking to get message to client sent
		await get_tree().create_timer(0.35).timeout
		enet_peer.disconnect_peer(id)
		return
	for i in Global.get_world().get_children():
		if i is RigidPlayer:
			if i.display_name == client_name:
				# kick new client with code 2 (name taken)
				response_from_server_joined.rpc_id(id, 2)
				# wait for a bit before kicking to get message to client sent
				await get_tree().create_timer(0.35).timeout
				enet_peer.disconnect_peer(id)
				return
	# nothing wrong
	response_from_server_joined.rpc_id(id, 0)
	var player = Player.instantiate()
	player.name = str(id)
	$World.add_child(player)

# second response from server to client
@rpc("call_local", "reliable")
func response_from_server_joined(response_code : int) -> void:
	if response_code == 1:
		kick_client("Version mismatch (your version does not match host version)")
	elif response_code == 2:
		kick_client("Display name already in use")
	elif response_code == 0:
		# announce to other clients, from the joined client
		announce_player_joined.rpc(Global.display_name)
		Global.connected_to_server = true

# Removes a player from the server given an id.
func remove_player(peer_id : int) -> void:
	var player = $World.get_node_or_null(str(peer_id))
	if player:
		# don't tell clients that the host disconnected
		if peer_id != 1:
			# Tell others that someone left
			UIHandler.show_alert(str(player.display_name, " left."), 4)
		# Remove player from World player list.
		Global.get_world().remove_player_from_list(player)
		
		player.queue_free()
