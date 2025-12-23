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
class_name Pickup

@onready var area : Area3D = $Area3D
var pickup_available := true

enum PickupType {
	ROCKET,
	BOMB,
	FLAMETHROWER,
	EXTINGUISHER,
	MISSILE,
	MEDKIT,
	PULSECANNON,
	BAT,
	BOUNCYBALL
}

const PICKUP_TYPES_AS_STRINGS : Array[String] = ["Rockets", "Bomb", "Flamethrower", "Extinguisher", "Missiles", "Medkit", "Pulse Cannon", "Bat", "Bouncyball"]

@export var type : PickupType = PickupType.ROCKET
@export var ammo : int = 2
@export var respawn_time : float = 10

@onready var audio : AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var respawn_timer : Timer = $RespawnTimer
@onready var label : Label3D = $Label3D

@onready var rocket_mesh : PackedScene = preload("res://data/scene/tool/visual_mesh/RocketLauncherVisualMesh.tscn")
@onready var bomb_mesh : PackedScene = preload("res://data/scene/tool/visual_mesh/BombVisualMesh.tscn")
@onready var flamethrower_mesh : PackedScene = preload("res://data/scene/tool/visual_mesh/FlamethrowerVisualMesh.tscn")
@onready var extinguisher_mesh : PackedScene = preload("res://data/scene/tool/visual_mesh/FireExtinguisherVisualMesh.tscn")
@onready var missile_mesh : PackedScene = preload("res://data/scene/tool/visual_mesh/MissileLauncherVisualMesh.tscn")
@onready var medkit_mesh : PackedScene = preload("res://data/scene/tool/visual_mesh/MedkitVisualMesh.tscn")
@onready var pulse_cannon_mesh : PackedScene = preload("res://data/scene/tool/visual_mesh/PulseCannonVisualMesh.tscn")
@onready var bat_mesh : PackedScene = preload("res://data/scene/tool/visual_mesh/BatVisualMesh.tscn")
@onready var bouncyball_mesh : PackedScene = preload("res://data/scene/tool/visual_mesh/ClayBallToolVisual.tscn")

@onready var rocket_tool : PackedScene = preload("res://data/scene/tool/RocketTool.tscn")
@onready var missile_tool : PackedScene = preload("res://data/scene/tool/MissileTool.tscn")
@onready var bomb_tool : PackedScene = preload("res://data/scene/tool/BombTool.tscn")
@onready var flamethrower_tool : PackedScene = preload("res://data/scene/tool/FlamethrowerTool.tscn")
@onready var extinguisher_tool : PackedScene = preload("res://data/scene/tool/ExtinguisherTool.tscn")
@onready var pulse_cannon_tool : PackedScene = preload("res://data/scene/tool/PulseCannonTool.tscn")
@onready var bat_tool : PackedScene = preload("res://data/scene/tool/BatTool.tscn")
@onready var bouncyball_tool : PackedScene = preload("res://data/scene/tool/BouncyballTool.tscn")

func _init() -> void:
	properties_to_save = ["global_position", "global_rotation", "scale", "type", "ammo", "respawn_time"]

func set_property(property : StringName, value : Variant) -> void:
	super(property, value)
	if property == "ammo":
		set_available_text()
	elif property == "respawn_time":
		respawn_timer.wait_time = respawn_time
		set_available_text()
	elif property == "type":
		set_mesh()

func _ready() -> void:
	respawn_timer.wait_time = respawn_time
	$Area3D.connect("body_entered", _on_body_entered)
	set_available_text()
	
	set_mesh()

func set_mesh() -> void:
	for c : Node in $MeshParent.get_children():
		c.queue_free()
	match(type):
		PickupType.ROCKET:
			var mesh_i : Node3D = rocket_mesh.instantiate()
			$MeshParent.add_child(mesh_i)
		PickupType.BOMB:
			var mesh_i : Node3D = bomb_mesh.instantiate()
			$MeshParent.add_child(mesh_i)
		PickupType.FLAMETHROWER:
			var mesh_i : Node3D = flamethrower_mesh.instantiate()
			$MeshParent.add_child(mesh_i)
		PickupType.EXTINGUISHER:
			var mesh_i : Node3D = extinguisher_mesh.instantiate()
			$MeshParent.add_child(mesh_i)
		PickupType.MISSILE:
			var mesh_i : Node3D = missile_mesh.instantiate()
			$MeshParent.add_child(mesh_i)
		PickupType.MEDKIT:
			var mesh_i : Node3D = medkit_mesh.instantiate()
			$MeshParent.add_child(mesh_i)
		PickupType.PULSECANNON:
			var mesh_i : Node3D = pulse_cannon_mesh.instantiate()
			$MeshParent.add_child(mesh_i)
		PickupType.BAT:
			var mesh_i : Node3D = bat_mesh.instantiate()
			$MeshParent.add_child(mesh_i)
		PickupType.BOUNCYBALL:
			var mesh_i : Node3D = bouncyball_mesh.instantiate()
			$MeshParent.add_child(mesh_i)

func _on_body_entered(body : Node3D) -> void:
	if body is RigidPlayer && pickup_available:
		_take_pickup(body as RigidPlayer)

func _take_pickup(body : RigidPlayer) -> void:
	pickup_available = false
	audio.play()
	# hide child mesh
	if $MeshParent.get_child_count() > 0:
		$MeshParent.get_child(0).visible = false
	# run on server for health
	if type == PickupType.MEDKIT && multiplayer.is_server():
		# ammo is health for medkit pickup
		if (body.get_health() < body.max_health):
			var newhealth : int = clamp(body.get_health() + ammo, 0, body.max_health)
			body.set_health(newhealth)
	# only run on auth
	elif body.get_multiplayer_authority() == multiplayer.get_unique_id():
		var tool_inv : ToolInventory = body.get_tool_inventory()
		var result : Tool = null
		var tool_idx : ToolInventory.ToolIdx = ToolInventory.ToolIdx.RocketTool
		match(type):
			PickupType.ROCKET:
				# if we already have it, just add ammo
				result = tool_inv.has_tool_by_name("RocketTool")
				tool_idx = ToolInventory.ToolIdx.RocketTool
			PickupType.BOMB:
				# if we already have it, just add ammo
				result = tool_inv.has_tool_by_name("BombTool")
				tool_idx = ToolInventory.ToolIdx.BombTool
			PickupType.FLAMETHROWER:
				# if we already have it, just add ammo
				result = tool_inv.has_tool_by_name("FlamethrowerTool")
				tool_idx = ToolInventory.ToolIdx.Flamethrower
			PickupType.EXTINGUISHER:
				# if we already have it, just add ammo (usually case for extinguisher)
				result = tool_inv.has_tool_by_name("ExtinguisherTool")
				tool_idx = ToolInventory.ToolIdx.Extinguisher
			PickupType.MISSILE:
				# if we already have it, just add ammo
				result = tool_inv.has_tool_by_name("MissileTool")
				tool_idx = ToolInventory.ToolIdx.Missile
			PickupType.PULSECANNON:
				# if we already have it, just add ammo
				result = tool_inv.has_tool_by_name("PulseCannonTool")
				tool_idx = ToolInventory.ToolIdx.PulseCannon
			PickupType.BAT:
				result = tool_inv.has_tool_by_name("BatTool")
				tool_idx = ToolInventory.ToolIdx.Bat
			PickupType.BOUNCYBALL:
				result = tool_inv.has_tool_by_name("BouncyballTool")
				tool_idx = ToolInventory.ToolIdx.Bouncyball
		if type != PickupType.MEDKIT:
			if result && type != PickupType.BAT:
				# don't add to infinite ammo
				if result.ammo >= 0:
					result.ammo += ammo
					result.update_ammo_display()
			else:
				tool_inv.add_tool.rpc(tool_idx, ammo)
	respawn_timer.start()
	await respawn_timer.timeout
	# reset label
	set_available_text()
	# show child mesh
	if $MeshParent.get_child_count() > 0:
		$MeshParent.get_child(0).visible = true
	pickup_available = true
	# check overlapping bodies after pickup is made available
	# in case someone is still standing on it
	for check_body : Node3D in $Area3D.get_overlapping_bodies():
		if check_body is RigidPlayer && pickup_available:
			_take_pickup(check_body as RigidPlayer)
			# don't keep iterating once we give the item away
			return

func set_available_text() -> void:
	# different text for flamethrower and extinguisher
	if type == PickupType.EXTINGUISHER:
		label.text = str("Foam: ", ammo)
	elif type == PickupType.FLAMETHROWER:
		label.text = str("Fuel: ", ammo)
	elif type == PickupType.MEDKIT:
		label.text = str("Health: ", ammo)
	elif type == PickupType.PULSECANNON:
		label.text = str("Pulse Energy: ", ammo)
	elif type == PickupType.BAT:
		label.text = str("Bat")
	else:
		label.text = str("Shots: ", ammo)

func _process(delta : float) -> void:
	if pickup_available == false:
		var cur_respawn : float = respawn_timer.time_left
		label.text = str("Respawn in ", int(cur_respawn) + 1, "...")
