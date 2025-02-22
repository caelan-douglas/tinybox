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
@onready var label : Label3D = $Mesh/Label3D

@onready var capture_audio : AudioStreamPlayer = $Capture
@onready var lost_audio : AudioStreamPlayer = $Lost
@onready var contested_audio : AudioStreamPlayer = $Contested

var contested : bool = false

var held_by : RigidPlayer :
	set(p):
		if p == null:
			emit_signal("lost", held_by)
			set_colour.rpc(default_colour)
		else:
			# set colour to player's pant colour when player has default team
			if p.team == "Default":
				var player_armature : Skeleton3D = p.get_node("Smoothing/character_model/character/Skeleton3D")
				if player_armature != null:
					var pant_colour : Color = player_armature.get_node("pants").get_surface_override_material(0).albedo_color as Color
					if pant_colour != null:
						pant_colour.a = 0.3
						set_colour.rpc(Color(pant_colour))
			else:
				# set colour to team colour if player has a team
				var tc : Color = Global.get_world().get_current_map().get_teams().get_team(p.team).colour
				tc.a = 0.3
				set_colour.rpc(tc)
			emit_signal("captured", p)
		held_by = p

@rpc("authority", "call_local", "reliable")
func capture_audio_rpc(mode: bool) -> void:
	if mode:
		capture_audio.play()
	else:
		capture_audio.stop()

@rpc("authority", "call_local", "reliable")
func lost_audio_rpc(mode: bool) -> void:
	if mode:
		lost_audio.play()
	else:
		lost_audio.stop()

@rpc("authority", "call_local", "reliable")
func contested_audio_rpc(mode: bool) -> void:
	if mode:
		contested_audio.play()
	else:
		contested_audio.stop()

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
	Global.get_world().connect("tbw_loaded", _on_tbw_loaded)
	area.connect("body_entered", _on_body_entered)
	area.connect("body_exited", _on_body_exited)
	capture_timer()

func _on_tbw_loaded() -> void:
	set_visible_rpc.rpc(false)

# runs as server
func capture_timer() -> void:
	if held_by != null:
		if held_by is RigidPlayer:
			if held_by._state == RigidPlayer.DEAD:
				_on_body_exited(held_by)
			# capture point must not be contested to get points
			var no_contest : bool = true
			for b in area.get_overlapping_bodies():
				if b is RigidPlayer:
					if b != held_by && b._state != RigidPlayer.DEAD:
						no_contest = false
						# ignore in teams
						if held_by.team != "Default":
							if held_by.team == b.team:
								no_contest = true
						if !no_contest && !contested:
							# Play audio for entered player and holding player
							contested_audio_rpc.rpc_id(b.get_multiplayer_authority(), true)
							if held_by != null:
								contested_audio_rpc.rpc_id(held_by.get_multiplayer_authority(), true)
							contested = true
							set_colour.rpc(Color(contested_colour))
							set_text.rpc("Contested point!")
			if no_contest:
				contested = false
			# if the point is not contested, and the person in it is alive, increment
			# their capture time
			if !contested:
				if held_by != null:
					held_by.update_capture_time(held_by.capture_time + 1)
					# show team name if player is not on default team
					if held_by.team != "Default":
						set_text.rpc(str("Point held by ", held_by.team, " team!"))
					else:
						set_text.rpc(str("Point held by ", held_by.display_name, "!"))
	await get_tree().create_timer(1).timeout
	# loop every 1s
	capture_timer()

var capture_transitional_players : Array[RigidPlayer] = []
func _on_body_entered(body : PhysicsBody3D) -> void:
	# ignore dead players
	if body is RigidPlayer:
		if body._state == RigidPlayer.DEAD:
			return
	# cancel lose audio for current holder if they re-enter within 1s
	if held_by != null:
		if body is RigidPlayer:
			if body == held_by:
				lost_audio_rpc.rpc_id(held_by.get_multiplayer_authority(), false)
	# capture point must be empty to be taken
	var has_player : bool = false
	for b in area.get_overlapping_bodies():
		# if someone other than the person who entered is inside
		if b is RigidPlayer && b != body:
			if b._state != RigidPlayer.DEAD:
				has_player = true
	if !has_player:
		if body is RigidPlayer && body != held_by:
			if body._state != RigidPlayer.DEAD:
				# add to transitional players (for managing audio)
				capture_transitional_players.append(body)
				# start audio
				capture_audio_rpc.rpc_id(body.get_multiplayer_authority(), true)
				# if still holding after 1s, captured
				await get_tree().create_timer(1).timeout
				if area.get_overlapping_bodies().has(body):
					held_by = body
				# remove from transitional players
				capture_transitional_players.erase(body)

func _on_body_exited(body : PhysicsBody3D) -> void:
	# check transitional players
	if body is RigidPlayer:
		if capture_transitional_players.has(body):
			# stop capture audio for transitional player, they have left
			# the capture point
			capture_audio_rpc.rpc_id(body.get_multiplayer_authority(), false)
	var players_in : Array[RigidPlayer] = []
	for b in area.get_overlapping_bodies():
		if b is RigidPlayer:
			if b._state != RigidPlayer.DEAD:
				players_in.append(b)
	# empty point, no one is holding
	if players_in.is_empty():
		var holder_is_dead : bool = false
		if held_by != null:
			if held_by._state == RigidPlayer.DEAD:
				holder_is_dead = true
			
		# grace period 1s for holder
		if !holder_is_dead:
			await get_tree().create_timer(1).timeout
		# start playing lose sound for current holder
		if held_by != null:
			if !area.get_overlapping_bodies().has(held_by) || held_by._state == RigidPlayer.DEAD:
				lost_audio_rpc.rpc_id(held_by.get_multiplayer_authority(), true)
			else:
				# someone is back in, stop process
				return
		# if still empty after 1s
		if !holder_is_dead:
			await get_tree().create_timer(1).timeout
		var new_players_in : Array[RigidPlayer] = []
		for b in area.get_overlapping_bodies():
			if b is RigidPlayer:
				if b._state != RigidPlayer.DEAD:
					new_players_in.append(b)
		if new_players_in.is_empty():
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
	# always show in editor
	if Global.get_world().get_current_map() is Editor:
		mode = true
	mesh.visible = mode;
	collider.disabled = !mode;
