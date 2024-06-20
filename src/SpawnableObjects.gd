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

# This is an autoload script that can be accessed from anywhere.
# Any scene files that are instantiated in multiple different files
# should be put in here so that they don't have to be loaded multiple times.
# It also has the benefit of cleaning up other parts of the code and reducing
# redundancy.
# Use load here instead of preload, to avoid a cyclic dependency.

@onready var objects : Dictionary = {
	"Water": load("res://data/scene/editor_obj/WorldWater.tscn"),
	"PineTree": load("res://data/scene/editor_obj/PineTree.tscn"),
	"Cliff_0": load("res://data/scene/editor_obj/Cliff_0.tscn"),
	"Asteroid_0": load("res://data/scene/editor_obj/Asteroid_0.tscn"),
	"Mug": load("res://data/scene/editor_obj/Mug.tscn"),
	"Pickup": load("res://data/scene/pickup/Pickup.tscn"),
	"Lifter": load("res://data/scene/lifter/Lifter.tscn"),
	# ENVIRONMENTS
	"Sunny": load("res://data/scene/environments/Sunny.tscn"),
	"Sunset": load("res://data/scene/environments/Sunset.tscn"),
	"Molten": load("res://data/scene/environments/Molten.tscn"),
	"Warp": load("res://data/scene/environments/Warp.tscn"),
	# BRICKS
	"Brick": load("res://data/scene/brick/Brick.tscn"),
	"HalfBrick": load("res://data/scene/brick/HalfBrick.tscn"),
	"CylinderBrick": load("res://data/scene/brick/CylinderBrick.tscn"),
	"LargeCylinderBrick": load("res://data/scene/brick/LargeCylinderBrick.tscn"),
	"MotorSeat": load("res://data/scene/brick/MotorSeat.tscn")
}

# explosion
@onready var explosion = load("res://data/scene/explosion/Explosion.tscn")

# Automatically populate the MultiplayerWorldObjSpawner node with all tbw objects.
func _ready():
	var obj_spawner : MultiplayerSpawner = Global.get_world().get_node_or_null("MultiplayerObjSpawner")
	while obj_spawner == null:
		await get_tree().process_frame
		obj_spawner = Global.get_world().get_node_or_null("MultiplayerObjSpawner")
	
	for obj in objects:
		obj_spawner.add_spawnable_scene(objects[obj].resource_path)
