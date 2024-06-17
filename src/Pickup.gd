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

extends RestrictedNode3D

@onready var area = $Area3D
var pickup_available = true

enum PickupType {
	ROCKET,
	BOMB,
	FLAMETHROWER,
	EXTINGUISHER,
	MISSILE
}

@export var type : PickupType = PickupType.ROCKET
@export var ammo = 2
@export var respawn_time = 10

@onready var audio = $AudioStreamPlayer3D
@onready var respawn_timer = $RespawnTimer
@onready var label = $Label3D

@onready var rocket_mesh = preload("res://data/scene/tool/visual_mesh/RocketLauncherVisualMesh.tscn")
@onready var bomb_mesh = preload("res://data/scene/tool/visual_mesh/BombVisualMesh.tscn")
@onready var flamethrower_mesh = preload("res://data/scene/tool/visual_mesh/FlamethrowerVisualMesh.tscn")
@onready var extinguisher_mesh = preload("res://data/scene/tool/visual_mesh/FireExtinguisherVisualMesh.tscn")
@onready var missile_mesh = preload("res://data/scene/tool/visual_mesh/MissileLauncherVisualMesh.tscn")

@onready var rocket_tool = preload("res://data/scene/tool/RocketTool.tscn")
@onready var missile_tool = preload("res://data/scene/tool/MissileTool.tscn")
@onready var bomb_tool = preload("res://data/scene/tool/BombTool.tscn")
@onready var flamethrower_tool = preload("res://data/scene/tool/FlamethrowerTool.tscn")
@onready var extinguisher_tool = preload("res://data/scene/tool/ExtinguisherTool.tscn")

func _ready():
	super()
	if !scheduled_for_deletion:
		respawn_timer.wait_time = respawn_time
		$Area3D.connect("body_entered", _on_body_entered)
		set_available_text()
		
		match(type):
			PickupType.ROCKET:
				var mesh_i = rocket_mesh.instantiate()
				$MeshParent.add_child(mesh_i)
			PickupType.BOMB:
				var mesh_i = bomb_mesh.instantiate()
				$MeshParent.add_child(mesh_i)
			PickupType.FLAMETHROWER:
				var mesh_i = flamethrower_mesh.instantiate()
				$MeshParent.add_child(mesh_i)
			PickupType.EXTINGUISHER:
				var mesh_i = extinguisher_mesh.instantiate()
				$MeshParent.add_child(mesh_i)
			PickupType.MISSILE:
				var mesh_i = missile_mesh.instantiate()
				$MeshParent.add_child(mesh_i)

func _on_body_entered(body) -> void:
	if body is RigidPlayer && pickup_available:
		pickup_available = false
		audio.play()
		# hide child mesh
		if $MeshParent.get_child_count() > 0:
			$MeshParent.get_child(0).visible = false
		# only run on auth
		if body.get_multiplayer_authority() == multiplayer.get_unique_id():
			var tool_inv = body.get_tool_inventory()
			match(type):
				PickupType.ROCKET:
					# if we already have it, just add ammo
					var result = tool_inv.has_tool_by_name("RocketTool")
					if result:
						# don't add to infinite ammo
						if result.ammo >= 0:
							result.ammo += ammo
							result.update_ammo_display()
					else:
						var tool = rocket_tool.instantiate()
						tool.ammo = ammo
						tool_inv.add_child(tool)
				PickupType.BOMB:
					# if we already have it, just add ammo
					var result = tool_inv.has_tool_by_name("BombTool")
					if result:
						# don't add to infinite ammo
						if result.ammo >= 0:
							result.ammo += ammo
							result.update_ammo_display()
					else:
						var tool = bomb_tool.instantiate()
						tool.ammo = ammo
						tool_inv.add_child(tool)
				PickupType.FLAMETHROWER:
					# if we already have it, just add ammo
					var result = tool_inv.has_tool_by_name("FlamethrowerTool")
					if result:
						# don't add to infinite ammo
						if result.ammo >= 0:
							result.ammo += ammo
							result.update_ammo_display()
					else:
						var tool = flamethrower_tool.instantiate()
						tool.ammo = ammo
						# don't restore flamethrower fuel
						tool.restore_ammo = false
						tool_inv.add_child(tool)
				PickupType.EXTINGUISHER:
					# if we already have it, just add ammo (usually case for extinguisher)
					var result = tool_inv.has_tool_by_name("ExtinguisherTool")
					if result:
						# don't add to infinite ammo
						if result.ammo >= 0:
							result.ammo += ammo
							result.update_ammo_display()
					else:
						var tool = extinguisher_tool.instantiate()
						tool.ammo = ammo
						tool_inv.add_child(tool)
				PickupType.MISSILE:
					# if we already have it, just add ammo
					var result = tool_inv.has_tool_by_name("MissileTool")
					if result:
						# don't add to infinite ammo
						if result.ammo >= 0:
							result.ammo += ammo
							result.update_ammo_display()
					else:
						var tool = missile_tool.instantiate()
						tool.ammo = ammo
						tool_inv.add_child(tool)
		respawn_timer.start()
		await respawn_timer.timeout
		# reset label
		set_available_text()
		# show child mesh
		if $MeshParent.get_child_count() > 0:
			$MeshParent.get_child(0).visible = true
		pickup_available = true

func set_available_text():
	# different text for flamethrower and extinguisher
	if type == PickupType.EXTINGUISHER:
		label.text = str("Foam: ", ammo)
	elif type == PickupType.FLAMETHROWER:
		label.text = str("Fuel: ", ammo)
	else:
		label.text = str("Shots: ", ammo)

func _process(delta):
	if pickup_available == false:
		var cur_respawn = respawn_timer.time_left
		label.text = str("Respawn in ", round(cur_respawn), "...")
