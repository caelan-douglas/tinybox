extends Node
signal command_response(sender : String, text : String)

var admins : Array[int] = [1]

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
		_send_response("$speed", "ex. $speed Playername 12 - sets a given player's movement speed. Default is 5.", id_from)
		_send_response("$stuck", "Respawns you in case you are stuck.", id_from)
		_send_response("$health", "ex. $health Playername 15 - sets a given player's health. Standard range is 0 - 20; higher than 20 will not show on the health bar.", id_from)
		_send_response("$tpall", "ex. $tpall Playername - teleports all players to a given player.", id_from)
		_send_response("$promote", "ex. $promote Playername - promotes player to admin. Be careful, this allows them to use all commands except $end, $promote, and $demote.", id_from)
		_send_response("$demote", "ex. $demote Playername - demotes player from admin.", id_from)
		_send_response("$list", "List of connected players.", id_from)
		_send_response("$loadmap", "ex. $loadmap Steep Swamp - Load an internal or saved map. (Exclude the .tbw extension.)", id_from)
		_send_response("$end", "End the server as host.", id_from)
		return
	if text.begins_with("$"):
		if split_text[0] == "$speed":
			# only admins can do speed command
			if admins.has(id_from):
				if rsplit.size() == 2:
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
				else:
					_send_response("Info", "Invalid use of $speed. Correct syntax example: $speed NAME SPEED_AMOUNT", id_from)
					return
			else:
				_send_response("Info", "You don't have permission to do that!", id_from)
				return
		elif split_text[0] == "$health":
			# only admins can do health command
			if admins.has(id_from):
				if rsplit.size() == 2:
					# Get this player and give them the speed.
					var player : RigidPlayer = Global.get_player_by_name(str(rsplit[0]))
					# change to x speed
					var x := str(rsplit[1]).to_int()
					if player != null:
						player.set_health(x)
						_send_response("Info", str("Set ", rsplit[0], "'s health to ", x))
					else:
						_send_response("Info", "Player not found", id_from)
					return
				else:
					_send_response("Info", "Invalid use of $health. Correct syntax example: $health NAME AMOUNT", id_from)
					return
			else:
				_send_response("Info", "You don't have permission to do that!", id_from)
				return
		elif split_text[0] == "$stuck":
			var player : Node = Global.get_world().get_node_or_null(str(id_from))
			if player != null:
				player.reduce_health(9999)
		elif split_text[0] == "$tpall":
			# only admins can do tp command
			if admins.has(id_from):
				if split_text.size() > 1:
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
				else:
					_send_response("Info", "Invalid use of $tpall. Correct syntax example: $tpall TO_PLAYER_NAME", id_from)
					return
			else:
				_send_response("Info", "You don't have permission to do that!", id_from)
		elif split_text[0] == "$promote":
			if id_from == 1:
				if split_text.size() > 1:
					var promote_player : RigidPlayer = Global.get_player_by_name(str(split_text[1]))
					if promote_player != null:
						if !admins.has(promote_player.get_multiplayer_authority()):
							admins.append(promote_player.get_multiplayer_authority())
							_send_response("Info", str("Promoted ", split_text[1], " to admin. They can now run all commands except $end, $promote, and $demote."))
					else:
						_send_response("Info", "Player to promote not found", id_from)
				else:
					_send_response("Info", "Invalid use of $promote. Correct syntax example: $promote PLAYERNAME", id_from)
					return
			else:
				_send_response("Info", "You don't have permission to do that!", id_from)
		elif split_text[0] == "$demote":
			if id_from == 1:
				if split_text.size() > 1:
					var demote_player : RigidPlayer = Global.get_player_by_name(str(split_text[1]))
					if demote_player != null:
						if admins.has(demote_player.get_multiplayer_authority()):
							admins.erase(demote_player.get_multiplayer_authority())
							_send_response("Info", str("Demoted ", split_text[1], "."))
					else:
						_send_response("Info", "Player to promote not found", id_from)
				else:
					_send_response("Info", "Invalid use of $demote. Correct syntax example: $demote PLAYERNAME", id_from)
					return
			else:
				_send_response("Info", "You don't have permission to do that!", id_from)
		elif split_text[0] == "$list":
			var player_names : Array[String] = []
			for p : RigidPlayer in Global.get_world().rigidplayer_list:
				player_names.append(p.display_name)
			if player_names.size() > 0:
				_send_response("Info", str(player_names))
			else:
				_send_response("Info", "Nobody is here.")
		elif split_text[0] == "$loadmap":
			if admins.has(id_from):
				if split_text.size() > 1:
					Global.get_world().load_tbw(str(split_text[1]), true)
				else:
					_send_response("Info", "Invalid use of $loadmap. Correct syntax example: $loadmap MAPNAME", id_from)
					return
			else:
				_send_response("Info", "You don't have permission to do that!", id_from)
		elif split_text[0] == "$end":
			if id_from == 1:
				var actions := UIHandler.show_alert_with_actions("Are you sure you wish to close the server?\nEveryone will be disconnected.", ["Close server", "Cancel"], true)
				actions[1].grab_focus()
				actions[0].connect("pressed", get_tree().quit)
			else:
				_send_response("Info", "You don't have permission to do that!", id_from)
		else:
			_send_response("Info", "Unknown command, type '?' for help.", id_from)
	else:
		# no command, just send the chat
		_send_response(str(display_name), str(text), only_show_to_id)

@rpc("call_local", "reliable")
func _response(sender : String, text : String) -> void:
	emit_signal("command_response", sender, text)

func _send_response(sender : String, text : String, only_to_id : int = -1) -> void:
	if only_to_id == -1:
		_response.rpc(sender, text)
	else:
		_response.rpc_id(only_to_id, sender, text)
