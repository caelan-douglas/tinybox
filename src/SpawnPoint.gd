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

extends TBWObject
class_name SpawnPoint

@onready var area : Area3D = $Area3D
@onready var audio : AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_checkpoint : AudioStreamOggVorbis = preload("res://data/audio/checkpoint.ogg")
@onready var audio_checkpoint_finish : AudioStreamOggVorbis = preload("res://data/audio/checkpoint_final.ogg")

var team_name : String = "Default"
var checkpoint : CheckpointType = CheckpointType.NONE

enum CheckpointType {
	NONE,
	CHECKPOINT,
	FINISH_LINE
}
const CHECKPOINT_TYPES_AS_STRINGS : Array[String] = ["None", "Checkpoint", "Finish Line"]

func _init() -> void:
	properties_to_save = ["global_position", "global_rotation", "scale", "team_name", "checkpoint"]

func _ready() -> void:
	area.connect("body_entered", _on_area_entered)

# set colour of spawns to team colour
func set_property(property : StringName, value : Variant) -> void:
	match(property):
		"team_name":
			team_name = str(value)
			var mat := StandardMaterial3D.new()
			var team : Team = Global.get_world().get_current_map().get_teams().get_team(team_name)
			mat.albedo_color = team.colour
			
			var add_material_to_cache := true
			# Check over the graphics cache to make sure we don't already have the same material created.
			for cached_material : Material in Global.graphics_cache:
				# If the material texture and colour matches (that's all that really matters):
				if (cached_material.albedo_color == team.colour):
					# Instead of using the duplicate material we created, use the cached material.
					mat = cached_material
					# Don't add this material to cache, since we're pulling it from the cache already.
					add_material_to_cache = false
			# Add the material to the graphics cache if we need to.
			if add_material_to_cache:
				Global.add_to_graphics_cache(mat)
			$MeshInstance3D.set_surface_override_material(0, mat)
		"checkpoint":
			# support old checkpoint format
			if str(value) == "false": value = 0
			if str(value) == "true": value = 1
			
			if value == 0:
				$Flag.visible = false
				$FinishFlag.visible = false
			elif value == 1:
				$Flag.visible = true
				$FinishFlag.visible = false
			elif value == 2:
				$Flag.visible = false
				$FinishFlag.visible = true
			checkpoint = value
		_:
			set(property, value)

# set player checkpoint as server
func _on_area_entered(body : PhysicsBody3D) -> void:
	if !multiplayer.is_server(): return
	
	# if the player enters a checkpoint, set their spawn there
	if body is RigidPlayer && checkpoint != CheckpointType.NONE:
		var player : RigidPlayer = body as RigidPlayer
		if player != null:
			player.set_spawns.rpc([global_position])
			print(str(player.display_name, " got checkpoint."))
			UIHandler.show_alert.rpc_id(player.get_multiplayer_authority(), "Checkpoint spawn set!", 3, false, UIHandler.alert_colour_gold)
			play_sound.rpc_id(player.get_multiplayer_authority())
			# finish line sets player checkpoint prop to 1
			if checkpoint == CheckpointType.FINISH_LINE:
				player.update_checkpoint(1)

@rpc("any_peer", "call_local", "reliable")
func play_sound() -> void:
	# if this go to spawn request is not from the server or run locally, return
	if multiplayer.get_remote_sender_id() != 1 && multiplayer.get_remote_sender_id() != get_multiplayer_authority() && multiplayer.get_remote_sender_id() != 0:
		return
	match (checkpoint):
		CheckpointType.FINISH_LINE:
			audio.stream = audio_checkpoint_finish
		_:
			audio.stream = audio_checkpoint
	audio.play()

func occupied() -> bool:
	for b in area.get_overlapping_bodies():
		if b is RigidPlayer:
			return true
	return false
