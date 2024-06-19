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

# .tbw objects
@onready var obj_water = load("res://data/scene/editor_obj/WorldWater.tscn")
@onready var obj_pine_tree = load("res://data/scene/editor_obj/PineTree.tscn")
@onready var obj_cliff_0 = load("res://data/scene/editor_obj/Cliff_0.tscn")
@onready var obj_pickup = load("res://data/scene/pickup/Pickup.tscn")
@onready var obj_lifter = load("res://data/scene/lifter/Lifter.tscn")

# bricks
@onready var brick = load("res://data/scene/brick/Brick.tscn")
@onready var half_brick = load("res://data/scene/brick/HalfBrick.tscn")
@onready var cylinder_brick = load("res://data/scene/brick/CylinderBrick.tscn")
@onready var large_cylinder_brick = load("res://data/scene/brick/LargeCylinderBrick.tscn")
@onready var motor_seat = load("res://data/scene/brick/MotorSeat.tscn")

# explosion
@onready var explosion = load("res://data/scene/explosion/Explosion.tscn")
