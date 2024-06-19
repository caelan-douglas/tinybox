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

@onready var objects = {
	"water": load("res://data/scene/editor_obj/WorldWater.tscn"),
	"pine_tree": load("res://data/scene/editor_obj/WorldWater.tscn"),
	"cliff_0": load("res://data/scene/editor_obj/Cliff_0.tscn"),
	"asteroid_0": load("res://data/scene/editor_obj/Asteroid_0.tscn"),
	"mug": load("res://data/scene/editor_obj/Mug.tscn"),
	"pickup": load("res://data/scene/pickup/Pickup.tscn"),
	"lifter": load("res://data/scene/lifter/Lifter.tscn"),
	# ENVIRONMENTS
	"environment_sunny": load("res://data/scene/environments/Sunny.tscn"),
	"environment_sunset": load("res://data/scene/environments/Sunset.tscn"),
	"environment_molten": load("res://data/scene/environments/Molten.tscn"),
	"environment_warp": load("res://data/scene/environments/Warp.tscn"),
	# BRICKS
	"brick": load("res://data/scene/brick/Brick.tscn"),
	"half_brick": load("res://data/scene/brick/HalfBrick.tscn"),
	"cylinder_brick": load("res://data/scene/brick/CylinderBrick.tscn"),
	"large_cylinder_brick": load("res://data/scene/brick/LargeCylinderBrick.tscn"),
	"motor_seat": load("res://data/scene/brick/MotorSeat.tscn")
}

# explosion
@onready var explosion = load("res://data/scene/explosion/Explosion.tscn")

# Automatically populate the MultiplayerWorldObjSpawner node with all tbw objects.
func _ready():
	var obj_spawner : MultiplayerSpawner = get_tree().current_scene.get_node_or_null("MultiplayerWorldObjSpawner")
	if obj_spawner == null: return
	
	for obj in objects:
		obj_spawner.add_spawnable_scene(objects[obj].resource_path)
