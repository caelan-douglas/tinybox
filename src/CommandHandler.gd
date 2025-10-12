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
signal command_response(sender : String, text : String)

enum PermissionLevel {
	NONE,
	ADMIN,
	SERVER
}

class Command:
	var command_name : String
	var arg_size : int
	var permission_level : PermissionLevel
	var command_syntax : String
	
	func _init(_command_name : String, _arg_size : int, _permission_level: PermissionLevel, _command_syntax : String = "") -> void:
		command_name = _command_name
		arg_size = _arg_size
		permission_level = _permission_level
		command_syntax = _command_syntax

var admins : Array[int] = [1]
var valid_commands : Array[Command] = [
								Command.new("$stuck", 0, PermissionLevel.NONE), 
								Command.new("$speed", 2, PermissionLevel.ADMIN, "$speed NAME SPEED_AMOUNT"),
								Command.new("$size", 2, PermissionLevel.ADMIN, "$size NAME SIZE"),
								Command.new("$health", 2, PermissionLevel.ADMIN, "$health NAME HEALTH_AMOUNT"),
								Command.new("$tpall", 1, PermissionLevel.ADMIN, "$tpall TO_NAME"),
								Command.new("$promote", 1, PermissionLevel.SERVER, "$promote NAME"),
								Command.new("$demote", 1, PermissionLevel.SERVER, "$demote NAME"),
								Command.new("$ban", 1, PermissionLevel.ADMIN, "$ban NAME"),
								Command.new("$unban", 1, PermissionLevel.SERVER, "$unban IP_ADDRESS"),
								Command.new("$list", 0, PermissionLevel.NONE),
								Command.new("$admins", 0, PermissionLevel.NONE),
								Command.new("$loadmap", 1, PermissionLevel.ADMIN, "$loadmap MAP_FILENAME"),
								Command.new("$can_clients_load_worlds", 1, PermissionLevel.ADMIN, "$can_clients_load_worlds true/false"),
								Command.new("$quit", 0, PermissionLevel.SERVER)
								]

var cli_thread : Thread

func _ready() -> void:
	if Global.server_mode():
		cli_thread = Thread.new()
		cli_thread.start(_process_input)
		# close when cli thread closes, because that means that we quit
		while cli_thread.is_alive():
			await get_tree().process_frame
		print("\n\nQuitting server...")
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

func _exit_tree() -> void:
	if cli_thread != null:
		cli_thread.wait_to_finish()

func _process_input() -> void:
	var read : String = ""
	while read != "$quit":
		read = OS.read_string_from_stdin(1024).strip_edges()
		submit_cli_input.call_deferred(read)
	# quit when user types 'quit'
	return

func submit_cli_input(read : String) -> void:
	submit_command.rpc_id(1, "Server", read)

func command_is_valid(command : Command, id_from : int) -> bool:
	# only server handles commands
	if !multiplayer.is_server(): return false
	
	for valid_command : Command in valid_commands:
		if valid_command.command_name == command.command_name:
			# check correct number of arguments
			if valid_command.arg_size <= command.arg_size:
				# check permission levels
				match(valid_command.permission_level):
					PermissionLevel.NONE:
						return true
					PermissionLevel.ADMIN:
						if !admins.has(id_from):
							_send_response("Info", "You don't have permission to do that!", id_from)
							return false
						else:
							return true
					PermissionLevel.SERVER:
						if id_from != 1:
							_send_response("Info", "You don't have permission to do that!", id_from)
							return false
						else:
							return true
			else:
				_send_response("Info", "Invalid use of command. Correct syntax example: " + valid_command.command_syntax, id_from)
				return false
	# not in valid commands list, invalid command
	_send_response("Info", "Invalid command. Type '?' for help.", id_from)
	return false

# Send the chat to all clients.
@rpc("any_peer", "call_local")
func submit_command(display_name : String, text : String, only_show_to_id : int = -1) -> void:
	# only server handles commands
	if !multiplayer.is_server(): return
	
	# get id who sent this request
	var id_from : int = multiplayer.get_remote_sender_id()
	var split_text : Array = text.split(" ", false, 1)
	var rsplit : Array = []
	if split_text.size() > 1:
		rsplit = split_text[1].rsplit(" ", false, 1)
	# commands
	if text == "?":
		_send_response("Commands", "", id_from)
		_send_response("$stuck", "Respawns you in case you are stuck.", id_from)
		_send_response("$speed", "ex. $speed Playername 12 - sets a given player's movement speed. Default is 5.", id_from)
		_send_response("$size", "ex. $size Playername 2 - sets the scale of a player's character. Default is 1.", id_from)
		_send_response("$health", "ex. $health Playername 15 - sets a given player's health. Standard range is 0 - 20; higher than 20 will not show on the health bar.", id_from)
		_send_response("$tpall", "ex. $tpall Playername - teleports all players to a given player.", id_from)
		_send_response("$promote", "ex. $promote Playername - promotes player to admin. Be careful, this allows them to use all commands except $end, $promote, and $demote.", id_from)
		_send_response("$demote", "ex. $demote Playername - demotes player from admin.", id_from)
		_send_response("$ban", "ex. $ban Playername - bans a player from the current session.", id_from)
		_send_response("$unban", "ex. $unban IP - unbans an IP of a user that had been previously banned.", id_from)
		_send_response("$list", "List of connected players.", id_from)
		_send_response("$admins", "List of server admins.", id_from)
		_send_response("$loadmap", "ex. $loadmap Steep Swamp - Load an internal or saved map. (Exclude the .tbw extension.)", id_from)
		_send_response("$can_clients_load_worlds", "ex. $can_clients_load_worlds false - Sets whether or not clients can load new worlds. True by default.", id_from)
		_send_response("$quit", "End the server (headless server mode only.)", id_from)
		return
	if text.begins_with("$"):
		# if running a command, first check it is valid
		if command_is_valid(Command.new(str(split_text[0]), rsplit.size(), PermissionLevel.NONE), id_from):
			if split_text[0] == "$speed":
				# Get this player and give them the speed.
				var player : RigidPlayer = Global.get_player_by_name(str(rsplit[0]))
				# change to x speed
				var x := str(rsplit[1]).to_int()
				if player != null:
					if x != 0:
						player.set_move_speed.rpc(x)
						_send_response("Info", str("Set ", rsplit[0], "'s move speed to ", x))
					else:
						_send_response("Info", "Speed cannot be zero", id_from)
				else:
					_send_response("Info", "Player not found", id_from)
				return
			
			elif split_text[0] == "$size":
				# Get this player and give them the size.
				var player : RigidPlayer = Global.get_player_by_name(str(rsplit[0]))
				# change to x size
				var x := clampf(str(rsplit[1]).to_float(), 1, 15)
				if player != null:
					if x >= 1:
						player.set_model_size.rpc(x)
						_send_response("Info", str("Set ", rsplit[0], "'s size to ", x))
					else:
						_send_response("Info", "Size must be greater than or equal to 1", id_from)
				else:
					_send_response("Info", "Player not found", id_from)
				return
			
			elif split_text[0] == "$health":
				# Get this player and give them the health.
				var player : RigidPlayer = Global.get_player_by_name(str(rsplit[0]))
				# change to x health
				var x := str(rsplit[1]).to_int()
				if player != null:
					player.set_health(x)
					_send_response("Info", str("Set ", rsplit[0], "'s health to ", x))
				else:
					_send_response("Info", "Player not found", id_from)
				return
			
			elif split_text[0] == "$stuck":
				var player : Node = Global.get_world().get_node_or_null(str(id_from))
				if player != null:
					player.reduce_health(9999)
				return
			
			elif split_text[0] == "$tpall":
				# Get the "to" player.
				var to_player : RigidPlayer = Global.get_player_by_name(str(split_text[1]))
				if to_player != null:
					for p : Node in Global.get_world().rigidplayer_list:
						if p is RigidPlayer:
							# add a bit of random to avoid sending people flying
							p.teleport.rpc(Vector3(to_player.global_position.x + randf() * 0.05, to_player.global_position.y + randf() * 0.05, to_player.global_position.z + randf() * 0.05))
					_send_response("Info", str("Teleporting all players to ", split_text[1], "."))
				else:
					_send_response("Info", "Player to teleport to not found", id_from)
				return
							
			elif split_text[0] == "$promote":
				var promote_player : RigidPlayer = Global.get_player_by_name(str(split_text[1]))
				if promote_player != null:
					if !admins.has(promote_player.get_multiplayer_authority()):
						admins.append(promote_player.get_multiplayer_authority())
						_send_response("Info", str("Promoted ", split_text[1], " to admin. They can now run all commands except $end, $promote, and $demote."))
				else:
					_send_response("Info", "Player to promote not found", id_from)
				return
					
			elif split_text[0] == "$demote":
				var demote_player : RigidPlayer = Global.get_player_by_name(str(split_text[1]))
				if demote_player != null:
					if (demote_player.get_multiplayer_authority() == 1):
						_send_response("Info", "Server cannot be demoted", id_from)
						return
					if admins.has(demote_player.get_multiplayer_authority()):
						admins.erase(demote_player.get_multiplayer_authority())
						_send_response("Info", str("Demoted ", split_text[1], "."))
				else:
					_send_response("Info", "Player to demote not found", id_from)
				return
			
			elif split_text[0] == "$list":
				var player_names : Array[String] = []
				for p : RigidPlayer in Global.get_world().rigidplayer_list:
					player_names.append(p.display_name)
				if player_names.size() > 0:
					_send_response("Info", str(player_names))
				else:
					_send_response("Info", "Nobody is here.")
				return
			
			elif split_text[0] == "$admins":
				if admins.size() > 0:
					_send_response("Info", str("Server admins: ", admins))
				else:
					_send_response("Info", "Nobody is admin.")
				return
			
			elif split_text[0] == "$loadmap":
				Global.get_world().load_tbw(str(split_text[1]), true)
				return
			
			elif split_text[0] == "$can_clients_load_worlds":
				var result := str(split_text[1])
				if result == "true":
					Global.server_can_clients_load_worlds = true
					_send_response("Info", "Clients are now able to load worlds.")
				else:
					Global.server_can_clients_load_worlds = false
					_send_response("Info", "Clients are no longer able to load worlds.")
				UserPreferences.save_server_pref("can_clients_load_worlds", Global.server_can_clients_load_worlds)
				return
				
			elif split_text[0] == "$ban":
				var ban_player : RigidPlayer = Global.get_player_by_name(str(split_text[1]))
				if ban_player != null:
					if ban_player.get_multiplayer_authority() == 1:
						_send_response("Info", "You cannot ban the server or host", id_from)
						return
					var main : Main = get_tree().current_scene
					var player_ip : String = main.enet_peer.get_peer(ban_player.get_multiplayer_authority()).get_remote_address()
					var player_id : int = ban_player.get_multiplayer_authority()
					main.enet_peer.disconnect_peer(player_id)
					# add to banned ip lists
					if !Global.server_banned_ips.has(player_ip):
						Global.server_banned_ips.append(player_ip)
					# save to server config file
					UserPreferences.save_server_pref("banned_ips", Global.server_banned_ips)
					_send_response("Info", str("Banned ", split_text[1]))
				else:
					_send_response("Info", "Player to ban not found", id_from)
				return
							
			elif split_text[0] == "$unban":
				var player_ip: String = split_text[1]
				if Global.server_banned_ips.has(player_ip):
					Global.server_banned_ips.erase(player_ip)
					# save to server config file
					UserPreferences.save_server_pref("banned_ips", Global.server_banned_ips)
					_send_response("Info", str("Unbanned IP ", player_ip))
				else:
					_send_response("Info", "Invalid IP or IP not currently banned", id_from)
				return
	else:
		# no command, just send the chat
		# Chats get display name from ID to help prevent spoofing
		var sender_display_name : String = "Unknown"
		var player : Variant = Global.get_world().get_node(str(multiplayer.get_remote_sender_id()))
		# Get name from ID
		if player != null:
			if player is RigidPlayer:
				sender_display_name = player.display_name
		_send_response(sender_display_name, str(text), only_show_to_id)

@rpc("call_local", "reliable")
func _response(sender : String, text : String) -> void:
	emit_signal("command_response", sender, text)
	if Global.server_mode() && multiplayer.is_server():
		print("(", Time.get_time_string_from_system(), ") ", sender, " >> ", text)

func _send_response(sender : String, text : String, only_to_id : int = -1) -> void:
	if only_to_id == -1:
		_response.rpc(sender, text)
	else:
		_response.rpc_id(only_to_id, sender, text)
