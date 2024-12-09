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
class_name Main

signal upnp_completed(error : Object)

const PLAYER : PackedScene = preload("res://data/scene/character/RigidPlayer.tscn")
const CAMERA : PackedScene = preload("res://data/scene/camera/Camera.tscn")
const PORT = 30815
const SERVER_INFO_PORT = 30816
# for server info
var udp_server : UDPServer = UDPServer.new()
# thread for UPNP connection
var thread : Thread = null
var upnp : UPNP = null
var host_public := true
var upnp_err : int = -1
var enet_peer := ENetMultiplayerPeer.new()
# For LAN servers
var lan_advertiser : ServerAdvertiser = null
var lan_listener : ServerListener = ServerListener.new()
var lan_entries := []

# Server version between client and server must match
# in order for client to join.
#
# Same as display version, but with leading zero for minor release
# to make room for double digit minor releases
# Last digit is 0 for pre-release and 1 for release
# ex. 9101 for 9.10; 10060 for 10.6pre; 12111 for 12.11
#     9 10 1         10 06 0            12 11 1
var server_version : int = 12020

# Displays on the title screen and game canvas
#
# major.minor
# add 'pre' at end for pre-release
var display_version := "beta 12.2pre"

@onready var host_button : Button = $MultiplayerMenu/PlayMenu/HostHbox/Host
@onready var host_public_button : Button = $MultiplayerMenu/HostSettingsMenu/HostPublic
@onready var join_button : Button = $MultiplayerMenu/PlayMenu/JoinHbox/Join
@onready var display_name_field : LineEdit = $MultiplayerMenu/DisplayName
@onready var join_address : LineEdit = $MultiplayerMenu/PlayMenu/JoinHbox/Address
@onready var host_map_selector : MapList = $MultiplayerMenu/HostSettingsMenu/MapList
@onready var editor_button : Button = $MultiplayerMenu/MainMenu/Editor
@onready var tutorial_button : Button = $MultiplayerMenu/MainMenu/Tutorial

func _ready() -> void:
	# reset paused state
	Global.is_paused = false
	# Clear the graphics cache when entering the main menu.
	Global.graphics_cache = []
	# Update the spawnable scenes in case the player left a server.
	# (re-adds all spawnable objs to the multiplayerspawner)
	SpawnableObjects.update_spawnable_scenes()
	
	# ask user before quitting (command and Q are buttons that may both
	# be used at the same time)
	get_tree().set_auto_accept_quit(false)
	
	host_button.connect("pressed", _on_host_pressed)
	host_public_button.connect("toggled", _on_host_public_toggled)
	host_public = host_public_button.button_pressed
	join_button.connect("pressed", _on_join_pressed)
	editor_button.connect("pressed", _on_editor_pressed)
	tutorial_button.connect("pressed", _on_tutorial_pressed)
	
	# Scan for LAN servers.
	get_tree().current_scene.add_child(lan_listener)
	lan_listener.connect("new_server", _on_new_lan_server)
	lan_listener.connect("remove_server", _on_remove_lan_server)
	
	# Load display name from prefs.
	var display_pref : Variant = UserPreferences.load_pref("display_name")
	if display_pref != null:
		display_name_field.text = str(display_pref)
	
	# Load join address from prefs.
	var address : Variant = UserPreferences.load_pref("join_address")
	if address != null:
		join_address.text = str(address)
	
	# check if running in server mode
	if Global.server_mode():
		_on_host_pressed()
	
	if display_version.contains("pre"):
		UIHandler.show_alert("You are using a pre-release build, you may encounter unexpected issues when joining incompatible servers", 8, false, UIHandler.alert_colour_error)

# quit request
func _notification(what : int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if !Global.server_mode():
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			var question : String = "Are you sure you want to quit?"
			if Global.get_world().get_current_map() is Editor:
				question = "Are you sure you want to quit? All unsaved\nchanges will be lost!"
			var actions := UIHandler.show_alert_with_actions(question, ["Quit game", "Cancel"], true)
			actions[0].connect("pressed", get_tree().quit)
		# server quit
		else:
			print("\nSaving world...")
			var ok : Variant = await Global.get_world().save_tbw("server_world", true)
			if ok == false:
				print("\nFailed to save world!")
			get_tree().quit()

func _on_new_lan_server(serverInfo : Dictionary) -> void:
	var multiplayer_menu : CanvasLayer = get_node_or_null("MultiplayerMenu")
	var lan_entry : PackedScene = load("res://data/scene/ui/LANEntry.tscn")
	if multiplayer_menu:
		var new_lan_entry : Control = lan_entry.instantiate()
		get_node("MultiplayerMenu/PlayMenu/LANPanelContainer/Label").text = "Join a server via LAN"
		multiplayer_menu.get_node("PlayMenu/LANPanelContainer").add_child(new_lan_entry)
		new_lan_entry.get_node("Name").text = str(serverInfo.name)
		new_lan_entry.get_node("Join").connect("pressed", _on_join_pressed.bind(serverInfo.ip, true))
		new_lan_entry.entry_server_ip = serverInfo.ip
		lan_entries.append(new_lan_entry)

func _on_remove_lan_server(serverIp : String) -> void:
	for entry : Control in lan_entries:
		if entry is LANEntry:
			if entry.entry_server_ip == serverIp:
				lan_entries.erase(entry)
				entry.queue_free()
				if lan_entries.size() < 1:
					get_node("MultiplayerMenu/PlayMenu/LANPanelContainer/Label").text = "Searching for LAN servers..."

func verify_display_name(check_string : String) -> Variant:
	var regex := RegEx.new()
	regex.compile("^\\s+$")
	if regex.search(str(check_string)):
		return "has only whitespaces"
	return null

func get_display_name_from_field() -> Variant:
	var t_display_name : String = display_name_field.text
	# User must have a display name.
	if t_display_name == "" || t_display_name == null:
		UIHandler.show_alert("Please enter a display name on the left.", 4, false, UIHandler.alert_colour_error)
		display_name_field.text = ""
		return null
	# Users can't have a display name that's only whitespace.
	var check_result : Variant = verify_display_name(t_display_name)
	if check_result != null:
		UIHandler.show_alert(str("Display name invalid (", check_result, ")"), 4)
		display_name_field.text = ""
		return null
	# Save the successful name.
	UserPreferences.save_pref("display_name", t_display_name)
	return t_display_name

# UPnP setup thread
func _upnp_setup(server_port : int) -> void:
	upnp = UPNP.new()
	host_button.call_deferred("set", "text", "Finding gateway...")
	# timeout 2500ms
	var err := upnp.discover(2500)
	
	if err != OK:
		push_error(str(err))
		upnp_err = err
		UIHandler.call_deferred("show_alert", str("Failed to start server because: ", str(err)), 15, false, true)
		call_deferred("emit_signal", "upnp_completed", err)
		return
	
	if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
		host_button.call_deferred("set", "text", "Configuring...")
		upnp.add_port_mapping(server_port, server_port, str(ProjectSettings.get_setting("application/config/name")), "UDP")
		upnp.add_port_mapping(server_port, server_port, str(ProjectSettings.get_setting("application/config/name")), "TCP")
		call_deferred("emit_signal", "upnp_completed", OK)
	elif upnp.get_device_count() < 1:
		UIHandler.call_deferred("show_alert", "Failed to start server because: No devices", 15, false, true)
		call_deferred("emit_signal", "upnp_completed", 27)
	else:
		# unknown error
		UIHandler.call_deferred("show_alert", "Failed to start server because: Unknown\n(UPnP is probably disabled on your router)", 15, false, true)
		call_deferred("emit_signal", "upnp_completed", 28)

func _exit_tree() -> void:
	# Wait for thread finish here to handle game exit while the thread is running.
	if thread != null:
		thread.wait_to_finish()
	# Delete the port opened by upnp.
	if upnp != null:
		upnp.delete_port_mapping(PORT, "UDP")
		upnp.delete_port_mapping(PORT, "TCP")

func _on_host_public_toggled(mode : bool) -> void:
	host_public = mode
	if mode:
		host_public_button.set_text_to_json("ui/host_public_settings/on")
	else:
		host_public_button.set_text_to_json("ui/host_public_settings/off")

func _on_host_pressed() -> void:
	var no_display_name : bool = false
	if get_display_name_from_field() == null:
		if !Global.server_mode():
			return
		else:
			# Just use "Server" as default if display name is invalid
			Global.display_name = "Server"
			no_display_name = true
	else:
		Global.display_name = get_display_name_from_field()
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
	# Get the host's selected map from the dropdown.
	# Create the server.
	enet_peer.create_server(PORT)
	# Set the current multiplayer peer to the server.
	multiplayer.multiplayer_peer = enet_peer
	# When a new player connects, add them with their id.
	multiplayer.peer_connected.connect(add_peer)
	multiplayer.peer_disconnected.connect(remove_player)
	# Server info ping listener
	start_udp_listener()
	# Load the world using the multiplayerspawner spawn method.
	var world : World = $World
	
	if Global.server_mode():
		# load server preferences
		Global.server_banned_ips = UserPreferences.load_server_pref("banned_ips")
		Global.server_can_clients_load_worlds = UserPreferences.load_server_pref("can_clients_load_worlds")
		# Set 'low processor mode', so that the screen does not redraw if
		# nothing changes
		OS.low_processor_usage_mode = true
		# Disable audio and no camera for dedicated servers
		AudioServer.set_bus_mute(0, true)
		UIHandler.show_alert(str("Started with arguments: ", OS.get_cmdline_args()))
		await get_tree().create_timer(0.3).timeout
		CommandHandler.submit_command.rpc("Info", "Your dedicated server has started! Type '?' in the command box for a list of commands. Alerts will show in this chat list. Player's chats will also appear here.")
		await get_tree().create_timer(0.3).timeout
		CommandHandler.submit_command.rpc("Info", "To stop the server and quit the app type '$end'.")
		if no_display_name:
			await get_tree().create_timer(0.3).timeout
			CommandHandler.submit_command.rpc("Alert", "You have no saved display name so the default name 'Server' was used.")
		# load server world, first check if world exists
		var lines : Array = Global.get_tbw_lines("server_world", true)
		if lines.size() > 0:
			world.load_tbw.call_deferred("server_world", false, true, true)
		else:
			# load default world
			world.load_tbw.call_deferred("Grasslands", false, true, false)
	else:
		get_tree().current_scene.get_node("GameCanvas").visible = true
		# remove ".tbw"
		world.load_tbw.call_deferred("Frozen Field")
	# add camera
	var camera_inst : Node3D = CAMERA.instantiate()
	world.add_child(camera_inst, true)
	if !Global.server_mode():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	await Signal(world, "map_loaded")
	add_peer(multiplayer.get_unique_id())
	# Create the LAN advertiser.
	lan_advertiser = ServerAdvertiser.new()
	get_tree().current_scene.add_child(lan_advertiser)
	lan_advertiser.serverInfo["name"] = str(display_name_field.text, "'s Server")
	lan_advertiser.broadcast_interval = 3
	get_tree().current_scene.get_node("MultiplayerMenu").visible = false

func start_udp_listener() -> void:
	udp_server.listen(SERVER_INFO_PORT)

# Listen on the udp server.
func _process(delta : float) -> void:
	udp_server.poll()
	if udp_server.is_connection_available():
		var peer : PacketPeerUDP = udp_server.take_connection()
		# Reply w/ player count
		peer.put_packet(str(Global.get_world().rigidplayer_list.size(), ";", display_version).to_utf8_buffer())

# Only runs for client
func _on_join_pressed(address : Variant = null, is_from_list := false) -> void:
	if address == null:
		address = join_address.text
		if join_address.text == "" && !is_from_list:
			UIHandler.show_alert("Enter an IP or domain to join in the '+' section\nto the right of the Join button.", 8, false, UIHandler.alert_colour_error)
			return
	# Save address for join (only if not LAN or server browser.)
	if !is_from_list:
		UserPreferences.save_pref("join_address", str(address))
	
	# editor debug names
	if OS.has_feature("editor"):
		Global.display_name = str("Editor Client ", randi_range(0, 99))
	else:
		if get_display_name_from_field() == null:
			return
		Global.display_name = get_display_name_from_field()
	
	# Change button text to notify user we are joining.
	join_button.text = JsonHandler.find_entry_in_file("ui/join_clicked")
	
	# Create the client.
	enet_peer.create_client(str(address), PORT)
	# Set the current multiplayer peer to the client.
	multiplayer.multiplayer_peer = enet_peer
	multiplayer.connection_failed.connect(kick_client.bind("Server timeout or couldn't find server."))
	multiplayer.peer_disconnected.connect(remove_player)
	multiplayer.server_disconnected.connect(_on_host_disconnect_as_client)
	$World.delete_old_map()
	await Signal($World, "map_loaded")
	
	# add camera
	var camera_inst : Node3D = CAMERA.instantiate()
	$World.add_child(camera_inst, true)
	
	get_tree().current_scene.get_node("MultiplayerMenu").visible = false
	get_tree().current_scene.get_node("GameCanvas").visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Entering the world editor.
func _on_editor_pressed() -> void:
	if get_display_name_from_field() == null:
		return
	Global.display_name = get_display_name_from_field()
	
	# Change button text to notify user server is starting.
	editor_button.text = "Loading editor..."
	editor_button.disabled = true
	
	get_tree().current_scene.get_node("MultiplayerMenu").visible = false
	get_tree().current_scene.get_node("EditorCanvas").visible = true
	
	# Editor is single player.
	var world : World = $World
	world.load_map.call_deferred(load(str("res://data/scene/EditorWorld/EditorWorld.tscn")))
	await Signal(world, "map_loaded")
	# add camera
	var camera_inst : Node3D = CAMERA.instantiate()
	world.add_child(camera_inst, true)
	
	add_peer(multiplayer.get_unique_id())
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Entering the tutorial.
func _on_tutorial_pressed() -> void:
	if get_display_name_from_field() == null:
		return
	Global.display_name = get_display_name_from_field()
	
	# Change button text to notify user server is starting.
	tutorial_button.text = "Loading tutorial..."
	tutorial_button.disabled = true
	
	get_tree().current_scene.get_node("MultiplayerMenu").visible = false
	get_tree().current_scene.get_node("GameCanvas").visible = true
	
	# Editor is single player.
	var world : World = $World
	world.load_tbw.call_deferred("tutorial")
	await Signal(world, "map_loaded")
	# add camera
	var camera_inst : Node3D = CAMERA.instantiate()
	world.add_child(camera_inst, true)
	
	add_peer(multiplayer.get_unique_id())
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Notify clients if the host disconnects.
func _on_host_disconnect_as_client() -> void:
	# in case host disconnects while mouse is captured
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	UIHandler.show_alert("Connection lost :(", 12, false, UIHandler.alert_colour_error)
	leave_server()

func leave_server() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	enet_peer.close()
	udp_server.stop()
	Global.connected_to_server = false
	get_tree().change_scene_to_file("res://data/scene/MainScene.tscn")

# Kick or disconnect from the server with a reason.
func kick_client(reason : String) -> void:
	UIHandler.show_alert(str("Connection failure: ", reason), 8, false, UIHandler.alert_colour_error)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	leave_server()
	
@rpc("any_peer", "call_remote", "reliable")
func announce_player_joined(p_display_name : String) -> void:
	UIHandler.show_alert(str(p_display_name, " joined."), 4, false, UIHandler.alert_colour_player)
	if multiplayer.is_server():
		print("Server info: IP of player ", p_display_name, ": ", enet_peer.get_peer(multiplayer.get_remote_sender_id()).get_remote_address())

# Adds a player to the server with id & name.
func add_peer(peer_id : int) -> void:
	if multiplayer.is_server():
		# for connecting clients, do prejoin before adding player
		if peer_id != 1:
			rpc_id(peer_id, "client_info_request_from_server")
		# for the server just add them
		else:
			# if joining as a player
			if !Global.server_mode():
				var player : RigidPlayer = PLAYER.instantiate()
				player.name = str(peer_id)
				$World.add_child(player, true)
			Global.connected_to_server = true

# first request sent out to the joining client from the server
@rpc("call_local", "reliable")
func client_info_request_from_server() -> void:
	info_response_from_client.rpc_id(1, multiplayer.get_unique_id(), server_version, Global.display_name)

# first response from the joining client; check validity here
@rpc("any_peer", "call_remote", "reliable")
func info_response_from_client(id : int, client_server_version : int, client_name : String) -> void:
	# check if ip banned
	var remote_ip := enet_peer.get_peer(multiplayer.get_remote_sender_id()).get_remote_address()
	if Global.server_banned_ips.has(remote_ip):
		# kick new client with code 3 (banned)
		response_from_server_joined.rpc_id(multiplayer.get_remote_sender_id(), 3)
		await get_tree().create_timer(0.35).timeout
		enet_peer.disconnect_peer(multiplayer.get_remote_sender_id())
		return
	
	if client_server_version != server_version:
		# kick new client with code 1 (mismatch version)
		response_from_server_joined.rpc_id(multiplayer.get_remote_sender_id(), 1)
		# wait for a bit before kicking to get message to client sent
		await get_tree().create_timer(0.35).timeout
		enet_peer.disconnect_peer(multiplayer.get_remote_sender_id())
		return
	for i in Global.get_world().get_children():
		if i is RigidPlayer:
			# case insensitive
			if i.display_name.to_lower() == client_name.to_lower():
				# kick new client with code 2 (name taken)
				response_from_server_joined.rpc_id(multiplayer.get_remote_sender_id(), 2)
				# wait for a bit before kicking to get message to client sent
				await get_tree().create_timer(0.35).timeout
				enet_peer.disconnect_peer(multiplayer.get_remote_sender_id())
				return
	# nothing wrong
	response_from_server_joined.rpc_id(multiplayer.get_remote_sender_id(), 0)
	var player : RigidPlayer = PLAYER.instantiate()
	player.name = str(multiplayer.get_remote_sender_id())
	$World.add_child(player)

# second response from server to client
@rpc("call_local", "reliable")
func response_from_server_joined(response_code : int) -> void:
	if response_code == 1:
		kick_client("Version mismatch (your version does not match host version)")
	elif response_code == 2:
		kick_client("Display name already in use")
	elif response_code == 3:
		kick_client("You are banned from this server")
	elif response_code == 0:
		# announce to other clients, from the joined client
		announce_player_joined.rpc(Global.display_name)
		Global.connected_to_server = true

# Removes a player from the server given an id.
func remove_player(peer_id : int) -> void:
	var player : RigidPlayer = $World.get_node_or_null(str(peer_id))
	if player:
		# don't tell clients that the host disconnected
		if peer_id != 1:
			# Tell others that someone left
			UIHandler.show_alert(str(player.display_name, " left."), 4, false, UIHandler.alert_colour_player)
		# Remove player from World player list.
		Global.get_world().remove_player_from_list(player)
		# if server, demote player
		if multiplayer.is_server():
			if CommandHandler.admins.has(peer_id):
				CommandHandler.admins.erase(peer_id)
				CommandHandler._send_response("Info", str("Demoted ", player.display_name, " because they left."))
		
		player.queue_free()
