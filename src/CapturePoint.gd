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
class_name CapturePoint

signal captured(whom : RigidPlayer)
signal lost(whom : RigidPlayer)

var radius : int = 8
var height : int = 6
const default_colour : Color = Color("c7a46a4d")
const contested_colour : Color = Color("be2f2f33")
var current_colour : Color = Color("c7a46a4d")
@onready var collider : CollisionShape3D = $Area/CollisionShape3D
@onready var mesh : MeshInstance3D = $Mesh
@onready var area : Area3D = $Area
@onready var label : Label3D = $Label3D

var held_by : RigidPlayer :
	set(p):
		if p == null:
			emit_signal("lost", held_by)
			set_colour.rpc(default_colour)
		else:
			# set colour to player's pant colour
			var player_armature : Skeleton3D = p.get_node("Smoothing/character_model/character/Skeleton3D")
			if player_armature != null:
				var pant_colour : Color = player_armature.get_node("pants").get_surface_override_material(0).albedo_color as Color
				if pant_colour != null:
					pant_colour.a = 0.3
					set_colour.rpc(Color(pant_colour))
			emit_signal("captured", p)
		held_by = p

@rpc("any_peer", "call_local", "reliable")
func set_colour(c : Color) -> void:
	# only accept changes from server
	if multiplayer.get_remote_sender_id() != 1:
		return
	var mat : Material = mesh.get_surface_override_material(0).duplicate()
	mat.albedo_color = c
	var add_material_to_cache := true
	# Check over the graphics cache to make sure we don't already have the same material created.
	for cached_material : Material in Global.capture_colour_cache:
		# If the material texture and colour matches (that's all that really matters):
		if (cached_material.albedo_color == c):
			# Instead of using the duplicate material we created, use the cached material.
			mat = cached_material
			# Don't add this material to cache, since we're pulling it from the cache already.
			add_material_to_cache = false
	# Add the material to the graphics cache if we need to.
	if add_material_to_cache:
		Global.add_to_capture_colour_cache(mat)
	mesh.set_surface_override_material(0, mat)
	current_colour = c

@rpc("any_peer", "call_local", "reliable")
func set_text(text : String) -> void:
	# only accept changes from server
	if multiplayer.get_remote_sender_id() != 1:
		return
	label.text = text

func _init() -> void:
	tbw_object_type = "obj_capture_point"
	properties_to_save = ["global_position", "global_rotation", "scale", "radius", "height"]

# run by server
func _ready() -> void:
	if !multiplayer.is_server():
		return
	area.connect("body_entered", _on_body_entered)
	area.connect("body_exited", _on_body_exited)
	capture_timer()

# runs as server
func capture_timer() -> void:
	if held_by != null:
		if held_by is RigidPlayer:
			# capture point must not be contested to get points
			var contested : bool = false
			for b in area.get_overlapping_bodies():
				if b is RigidPlayer && b != held_by:
					contested = true
					set_colour.rpc(Color(contested_colour))
					set_text.rpc("Contested point!")
			# if the point is not contested, and the person in it is alive, increment
			# their capture time
			if !contested && held_by._state != RigidPlayer.DEAD:
				held_by.update_capture_time(held_by.capture_time + 1)
				set_text.rpc(str("Point held by ", held_by.display_name, "!"))
	await get_tree().create_timer(1).timeout
	# loop every 1s
	capture_timer()

func _on_body_entered(body : PhysicsBody3D) -> void:
	# capture point must be empty to be taken
	var has_player : bool = false
	for b in area.get_overlapping_bodies():
		# if someone other than the person who entered is inside
		if b is RigidPlayer && b != body:
			has_player = true
	if !has_player:
		if body is RigidPlayer:
			held_by = body

func _on_body_exited(body : PhysicsBody3D) -> void:
	var players_in : Array[RigidPlayer] = []
	for b in area.get_overlapping_bodies():
		if b is RigidPlayer:
			players_in.append(b)
	# empty point, no one is holding
	if players_in.is_empty():
		held_by = null
		set_text.rpc("Capture Point")
	# if there is only one player, they are new capture king
	elif players_in.size() == 1:
		held_by = players_in[0]

func set_property(property : StringName, value : Variant) -> void:
	# make not unique
	if collider.shape != null:
		collider.shape = collider.shape.duplicate()
	if mesh.mesh != null:
		mesh.mesh = mesh.mesh.duplicate()
	# adjust radius and height
	if property == "radius":
		if collider.shape is CylinderShape3D:
			collider.shape.radius = value as float
		if mesh.mesh is CylinderMesh:
			mesh.mesh.top_radius = value
			mesh.mesh.bottom_radius = value
	if property == "height":
		if collider.shape is CylinderShape3D:
			collider.shape.height = value as float
		if mesh.mesh is CylinderMesh:
			mesh.mesh.height = value
		mesh.position.y = value as float/2
		collider.position.y = value as float/2
	super(property, value)

@rpc("any_peer", "call_remote", "reliable")
func sync_properties(props : Dictionary) -> void:
	for prop : String in props.keys():
		if prop != "script":
			set_property(prop, props[prop])

func properties_as_dict() -> Dictionary:
	var dict : Dictionary = {}
	for p : String in properties_to_save:
		dict[p] = get(p)
	return dict

@rpc("authority", "call_local", "reliable")
func set_visible_rpc(mode : bool) -> void:
	mesh.visible = mode;
	collider.disabled = !mode;
