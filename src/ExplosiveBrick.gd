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

extends Brick
class_name ExplosiveBrick

@onready var explosion : PackedScene = SpawnableObjects.explosion

# Set a custom property
func set_property(property : StringName, value : Variant) -> void:
	super(property, value)
	# set mass after determing mass mult from size
	mass = 10 * mass_mult

# Set the material of this brick to a different one, 
# and update any related properties.
@rpc("call_local")
func set_material(new : Brick.BrickMaterial) -> void:
	# don't change material on explosive bricks
	pass

@rpc("any_peer", "call_local", "reliable")
func set_colour(new : Color) -> void:
	# don't change colour
	pass

var fuse_lit : bool = false
@rpc("any_peer", "call_local")
func explode(explosion_position : Vector3, from_whom : int = -1, _explosion_force : float = 4) -> void:
	if multiplayer.is_server():
		if !fuse_lit:
			super(explosion_position, from_whom)
		fuse_lit = true
	await get_tree().create_timer((randf() * 0.4) + 0.6).timeout
	var explosion_i : Explosion = explosion.instantiate()
	get_tree().current_scene.add_child(explosion_i)
	explosion_i.set_explosion_size(clamp(mass_mult * 4, 1, 150) as float) # base is 4
	# player_from id is later used in death messages
	explosion_i.set_explosion_owner(from_whom)
	explosion_i.global_position = global_position
	explosion_i.play_sound()
	despawn.rpc()

func _init() -> void:
	properties_to_save = ["global_position", "global_rotation", "brick_scale", "immovable", "joinable"]

func _ready() -> void:
	super()
