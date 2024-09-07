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
class_name Event

enum EventType {
	# 1 additonal arg
	TELEPORT_ALL_PLAYERS,
	LOCK_PLAYER_STATES,
	WAIT_FOR_SECONDS,
	# base
	MOVE_ALL_PLAYERS_TO_SPAWN,
	BALANCE_TEAMS,
	CLEAR_LEADERBOARD,
	SHOW_PODIUM,
	SHOW_WORLD_PREVIEW,
	END_ACTIVE_GAMEMODE
}

# Event types that cannot be used in the editor gamemode creation tool.
const EDITOR_DISALLOWED_TYPES : Array[String] = ["SHOW_WORLD_PREVIEW"]
# Event types that can only be run as event events of watchers.
const WATCHER_END_ONLY_TYPES : Array[String] = ["SHOW_PODIUM", "END_ACTIVE_GAMEMODE"]
var event_type : EventType = EventType.TELEPORT_ALL_PLAYERS
var args : Array = []

func _init(e_event_type : EventType, e_args : Array) -> void:
	event_type = e_event_type
	args = e_args

func start() -> int:
	# add self to tree
	Global.get_world().add_child(self)
	# only server runs events
	if !multiplayer.is_server():
		queue_free()
		return -1
	
	match (event_type):
		EventType.TELEPORT_ALL_PLAYERS:
			var players : Array = Global.get_world().rigidplayer_list
			for player : RigidPlayer in players:
				# assuming vec3 may be string formatted
				player.teleport.rpc(Global.string_to_vec3(str(args[0])))
		EventType.MOVE_ALL_PLAYERS_TO_SPAWN:
			var players : Array = Global.get_world().rigidplayer_list
			for player : RigidPlayer in players:
				player.go_to_spawn.rpc()
		EventType.BALANCE_TEAMS:
			var teams : Teams = Global.get_world().get_current_map().get_teams()
			var participants : Array = Global.get_world().rigidplayer_list
			for i in range(participants.size()):
				if (i % 2) == 0:
					participants[i].update_team.rpc(teams.get_team_list()[1].name)
				else:
					participants[i].update_team.rpc(teams.get_team_list()[2].name)
				# update info on player's client side
				participants[i].update_info.rpc_id(participants[i].get_multiplayer_authority(), participants[i].get_multiplayer_authority())
		EventType.CLEAR_LEADERBOARD:
			for player : RigidPlayer in Global.get_world().rigidplayer_list:
				player.update_kills.rpc(0)
				player.update_deaths.rpc(0)
		EventType.END_ACTIVE_GAMEMODE:
			for gamemode : Gamemode in Global.get_world().get_tbw_gamemodes():
				if gamemode.running:
					gamemode.end([])
		EventType.SHOW_PODIUM:
			if args.size() > 0:
				# arg 0: player 1 id
				var players : Array = Global.get_world().rigidplayer_list
				for player : RigidPlayer in players:
					if player.name == str(args[0]):
						player.change_state.rpc_id(player.get_multiplayer_authority(), RigidPlayer.DUMMY)
						player.teleport.rpc_id(player.get_multiplayer_authority(), Vector3(0, 350, 0))
						# show animation
						var camera : Camera = get_viewport().get_camera_3d()
						if camera is Camera:
							camera.play_podium_animation.rpc(str(args[0]).to_int())
							UIHandler.show_alert.rpc(str(player.display_name, " wins!"), 8, false, UIHandler.alert_colour_gold)
						
						# show podium for 8s
						await get_tree().create_timer(8).timeout
						player.change_state.rpc_id(player.get_multiplayer_authority(), RigidPlayer.IDLE)
		EventType.WAIT_FOR_SECONDS:
			# arg 0: seconds to wait
			# arg 1: whether or not to show countdown
			if args.size() > 0:
				for i : int in range(args[0]):
					# if showing countdown
					if args[1] as bool:
						UIHandler.show_toast.rpc(str(args[0] as int - i), 1, Color.DARK_ORANGE, 72)
					await get_tree().create_timer(1).timeout
			UIHandler.show_toast.rpc("GO!", 1, Color.LIME_GREEN, 72)
		EventType.SHOW_WORLD_PREVIEW:
			# arg 0: gamemode name
			# show animation
			var has_previews : bool = false
			for obj in Global.get_world().get_children():
				if obj is CameraPreviewPoint:
					has_previews = true
			if has_previews:
				var camera : Camera = get_viewport().get_camera_3d()
				if camera is Camera:
					# camera movements
					camera.play_preview_animation.rpc()
					# play preview overlay
					if args.size() < 1:
						# don't show name if there is none
						args[0] = ""
					UIHandler.play_preview_animation_overlay.rpc(str(args[0]))
					# wait for animation to finish before running next events
					await get_tree().create_timer(10).timeout
		_:
			printerr("Failed to run event because the event type is not valid.")
	
	queue_free()
	return 0
