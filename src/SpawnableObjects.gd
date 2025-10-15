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
	# SPECIAL
	"obj_water": load("res://data/scene/editor_obj/WorldWater.tscn"),
	"obj_pickup": load("res://data/scene/pickup/Pickup.tscn"),
	"obj_lifter": load("res://data/scene/lifter/Lifter.tscn"),
	"obj_sign": load("res://data/scene/editor_obj/Sign.tscn"),
	"obj_spawnpoint": load("res://data/scene/editor_obj/SpawnPoint.tscn"),
	# UTILITY
	"obj_camera_preview_point": load("res://data/scene/editor_obj/CameraPreviewPoint.tscn"),
	# TRACK PIECES
	"obj_track_straight": load("res://data/scene/editor_obj/track/TrackStraight.tscn"),
	"obj_track_slope": load("res://data/scene/editor_obj/track/TrackSlope.tscn"),
	"obj_track_turn": load("res://data/scene/editor_obj/track/TrackTurn.tscn"),
	"obj_track_turn_banked": load("res://data/scene/editor_obj/track/TrackTurnBanked.tscn"),
	"obj_track_big_slope": load("res://data/scene/editor_obj/track/TrackBigSlope.tscn"),
	"obj_track_divided_transition": load("res://data/scene/editor_obj/track/TrackDividedTransition.tscn"),
	"obj_track_divided": load("res://data/scene/editor_obj/track/TrackDivided.tscn"),
	"obj_capture_point": load("res://data/scene/editor_obj/CapturePoint.tscn"),
	# ENVIRONMENTS
	"env_sunny": load("res://data/scene/environments/Sunny.tscn"),
	"env_sunset": load("res://data/scene/environments/Sunset.tscn"),
	"env_night": load("res://data/scene/environments/Night.tscn"),
	"env_snowy": load("res://data/scene/environments/Snowy.tscn"),
	"env_thunderstorm": load("res://data/scene/environments/Thunderstorm.tscn"),
	"env_clouds": load("res://data/scene/environments/Clouds.tscn"),
	"env_molten": load("res://data/scene/environments/Molten.tscn"),
	"env_warp": load("res://data/scene/environments/Warp.tscn"),
	# BACKGROUNDS
	"bg_warp": load("res://data/scene/backgrounds/Warp.tscn"),
	# BRICKS
	"brick": load("res://data/scene/brick/Brick.tscn"),
	"brick_half": load("res://data/scene/brick/HalfBrick.tscn"),
	"brick_cylinder": load("res://data/scene/brick/CylinderBrick.tscn"),
	"brick_motor_seat": load("res://data/scene/brick/MotorSeat.tscn"),
	"brick_button": load("res://data/scene/brick/ButtonBrick.tscn"),
	"brick_lamp": load("res://data/scene/brick/LampBrick.tscn"),
	"brick_wedge": load("res://data/scene/brick/WedgeBrick.tscn"),
	"brick_explosive": load("res://data/scene/brick/ExplosiveBrick.tscn"),
	"brick_activator": load("res://data/scene/brick/ActivatorBrick.tscn"),
}

# Returns a list of items spawnable by the Editor.
func get_editor_spawnable_objects_list() -> Array[String]:
	var list := objects.keys()
	var return_list : Array[String] = []
	for item : String in list:
		if item.begins_with("obj") || item.begins_with("brick"):
			if item != "obj_water":
				return_list.append(item)
	return return_list

# explosion
@onready var explosion : PackedScene = load("res://data/scene/explosion/Explosion.tscn")

# Automatically populate the MultiplayerWorldObjSpawner node with all tbw objects.
func _ready() -> void:
	update_spawnable_scenes()

# called whenever the main menu is opened
func update_spawnable_scenes() -> void:
	var obj_spawner : MultiplayerSpawner = Global.get_world().get_node_or_null("MultiplayerObjSpawner")
	while obj_spawner == null:
		await get_tree().process_frame
		obj_spawner = Global.get_world().get_node_or_null("MultiplayerObjSpawner")
	for obj : Variant in objects:
		obj_spawner.add_spawnable_scene(objects[obj].resource_path as String)
