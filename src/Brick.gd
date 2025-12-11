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

extends SyncedRigidbody3D
class_name Brick
signal placed

enum States {
	BUILD,
	PLACED,
	DUMMY_BUILD,
	DUMMY_PLACED,
	DUMMY_PROJECTILE
}

enum BrickMaterial {
	WOODEN,
	WOODEN_CHARRED,
	METAL,
	PLASTIC,
	RUBBER,
	GRASS,
	ICE
}

const BRICK_MATERIALS_AS_STRINGS : Array[String] = ["Wooden", "Wooden (charred)", "Metal", "Plastic", "Rubber", "Grass", "Ice"]

@export var properties_to_save : Array[String] = ["global_position", "global_rotation", "brick_scale", "_material", "_colour", "immovable", "joinable", "indestructible"]

# Size of grid cells.
const CELL_SIZE : int = 1
# Range of placement.
var placement_range : int = 6
# Range of placement in Sandbox mode.
var sandbox_placement_range : int = 16
# When this brick is deglued, it will affect others in this radius.
var deglue_radius : float = 2
# How hard this brick must be hit to be unjoined.
var unjoin_velocity : float = 40
var health : int = 20
# variables for syncing with clients in physics_process
var time_since_moved : float = 0
var sync_step : int = 0
# for spawning buildings
var joinable : bool = true
var groupable : bool = true
var immovable : bool = false
var indestructible : bool = false
# for larger bricks
@export var mass_mult : float = 1
@export var flammable : bool = true
var on_fire : bool = false
var charred : bool = false
@export var glued : bool = true
var has_static_neighbour : bool = false
var brick_scale : Vector3 = Vector3(1, 1, 1)

@onready var group : String = name
@onready var world : World = Global.get_world()
@onready var brick_groups : BrickGroups = world.get_node("BrickGroups")

@export var _state : States = States.DUMMY_PLACED
@export var _material : BrickMaterial = BrickMaterial.WOODEN
@onready var mesh_material : Material = Material.new()
@export var _brick_spawnable_type : String = "brick"
@export var _colour : Color = "#9a9a9a"

@onready var wood_material : Material = preload("res://data/materials/wood.tres")
@onready var wood_charred_material : Material = preload("res://data/materials/wood_charred.tres")
@onready var metal_material : Material = preload("res://data/materials/metal.tres")
@onready var plastic_material : Material = preload("res://data/materials/plastic.tres")
@onready var rubber_material : Material = preload("res://data/materials/rubber.tres")
@onready var grass_material : Material = preload("res://data/materials/grass.tres")
@onready var ice_material : Material = preload("res://data/materials/ice.tres")

# for showing cost in minigame
@onready var floaty_text : PackedScene = preload("res://data/scene/ui/FloatyText.tscn")

@onready var fire : Fire = $Fire
@onready var collider : CollisionShape3D = $collider
@onready var cam_collider : CollisionShape3D = $CameraMousePosInterceptor/collider
@onready var intersect_d : Area3D = $IntersectDetector
@onready var model_mesh : MeshInstance3D = $Smoothing/model/Cube
@onready var smoothing : Node3D = $Smoothing

@onready var joint_scn : PackedScene = preload("res://data/scene/brick/BrickJoint.tscn")
@onready var joint_detector : Area3D = $"JointDetector"
@onready var joint_collider : CollisionShape3D = $JointDetector/collider

@onready var inactivity_timer : Timer = $InactivityTimer

@onready var camera : Camera3D = get_viewport().get_camera_3d()
@onready var invalid_material : Material = preload("res://data/materials/invalid_placement_material.tres")
@onready var delete_material : Material = preload("res://data/materials/delete_placement_material.tres")
@onready var save_material : Material = preload("res://data/materials/save_placement_material.tres")
@onready var hit_sounds_wood : Array[AudioStream] = [
	preload("res://data/audio/wood/wood_hit_0.ogg"),
	preload("res://data/audio/wood/wood_hit_1.ogg"),
	preload("res://data/audio/wood/wood_hit_2.ogg"),
	preload("res://data/audio/wood/wood_hit_3.ogg")
]
@onready var hit_sounds_metal : Array[AudioStream] = [
	preload("res://data/audio/metal/metal_hit_0.ogg"),
	preload("res://data/audio/metal/metal_hit_1.ogg"),
	preload("res://data/audio/metal/metal_hit_2.ogg")
]

# The tool that this brick was spawned by
var tool_from : Tool
# Whether or not this brick was just spawned by its tool. This variable
# is used in the build function.
var just_spawned_from_tool : bool = true

func resize_mesh() -> void:
	var mesh_verticies : Array = model_mesh.mesh.surface_get_arrays(0)
	var new_mesh := ArrayMesh.new()
	var add_mesh_to_cache := true
	# mesh cache
	for cached_mesh : Array in Global.mesh_cache:
		if cached_mesh[0] == brick_scale:
			if cached_mesh[1] == _brick_spawnable_type:
				new_mesh = cached_mesh[2]
				add_mesh_to_cache = false
	if add_mesh_to_cache:
		# We have to make the mesh
		# scale mesh but keep bevels
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_verticies)
		var mdt := MeshDataTool.new()
		mdt.create_from_surface(new_mesh, 0)
		for i in range(mdt.get_vertex_count()):
			var vertex := mdt.get_vertex(i)
			# move, instead of scaling, beveled edges to correct points
			if vertex.y > 0:
				vertex.y += (brick_scale.y - 1) * 0.5
			if vertex.y < 0:
				vertex.y -= (brick_scale.y - 1) * 0.5
			
			if vertex.x > 0:
				vertex.x += (brick_scale.x - 1) * 0.5
			if vertex.x < 0:
				vertex.x -= (brick_scale.x - 1) * 0.5
			
			if vertex.z > 0:
				vertex.z += (brick_scale.z - 1) * 0.5
			if vertex.z < 0:
				vertex.z -= (brick_scale.z - 1) * 0.5
			# Save the mesh change
			mdt.set_vertex(i, vertex)
		new_mesh.clear_surfaces()
		mdt.commit_to_surface(new_mesh)
		Global.add_to_mesh_cache([brick_scale, _brick_spawnable_type, new_mesh])
	model_mesh.mesh = new_mesh

# Set a custom property
func set_property(property : StringName, value : Variant) -> void:
	if property == "_colour":
		set_colour(value as Color)
	elif property == "_material":
		set_material(value as Brick.BrickMaterial)
	elif property == "immovable":
		immovable = value as bool
	elif property == "joinable":
		joinable = value as bool
	elif property == "brick_scale":
		if value is Vector3:
			# bricks can only have integer as scales
			var scale_new : Vector3 = (value as Vector3).round()
			if scale_new != Vector3(1, 1, 1) && scale_new != brick_scale:
				# set property for saving
				brick_scale = scale_new
				# set mass multiplication using length of 1, 1, 1 as base
				# ex. 1, 1, 1 would be mass_mult 1
				# 2, 2, 2 would be mass_mult 2
				mass_mult = scale_new.length() / Vector3(1, 1, 1).length()
				# make new shape to avoid changing all of them
				collider.shape = collider.shape.duplicate()
				joint_collider.shape = joint_collider.shape.duplicate()
				cam_collider.shape = cam_collider.shape.duplicate()
				var fire_size : float = scale_new.length() * 0.5
				fire.scale = brick_scale
				# scale actual fire plane mesh
				if fire_size > 1.5:
					fire.set_particle_scale(Vector2(fire_size, fire_size))
				if collider.shape is BoxShape3D:
					# all normal bricks
					if _brick_spawnable_type != "brick_half":
						collider.shape.size = scale_new
						joint_collider.shape.size = scale_new + Vector3(0.3, 0.3, 0.3)
						cam_collider.shape.size = scale_new + Vector3(0.4, 0.4, 0.4)
					# half bricks
					else:
						var half_scale := Vector3(scale_new.x, scale_new.y * 0.5, scale_new.z)
						collider.shape.size = half_scale
						joint_collider.shape.size = half_scale + Vector3(0.3, 0.3, 0.3)
						cam_collider.shape.size = scale_new + Vector3(0.4, 0.4, 0.4)
					# Scaling mesh
					resize_mesh()
				# wedge
				elif collider.shape is ConvexPolygonShape3D:
					for i : int in range(collider.shape.points.size()):
						collider.shape.points[i] *= scale_new
					joint_collider.shape.size = scale_new + Vector3(0.3, 0.3, 0.3)
					cam_collider.shape.size = scale_new + Vector3(0.4, 0.4, 0.4)
					# Scaling mesh
					resize_mesh()
				elif collider.shape is CylinderShape3D:
					# can't have oddly shaped wheels
					if scale_new.z > scale_new.y:
						scale_new.y = scale_new.z
					else:
						scale_new.z = scale_new.y
					collider.shape.height = (scale_new).x
					collider.shape.radius = (scale_new).y * 0.5
					# different scale arrangement for model
					model_mesh.scale = Vector3(scale_new.y, scale_new.x, scale_new.y)
					joint_collider.shape.height = scale_new.x + 0.3
					joint_collider.shape.radius = (scale_new.y * 0.5) + 0.3
					cam_collider.shape.height = scale_new.x + 0.4
					cam_collider.shape.radius = (scale_new.y * 0.5) + 0.2
					
					var joint_spot_left : Node3D = $JointSpotLeft
					var joint_spot_right : Node3D = $JointSpotRight
					var motor_mesh : Node3D = $Smoothing/MotorMesh
					joint_spot_left.position.z = scale_new.x * 0.5
					joint_spot_right.position.z = -scale_new.x * 0.5
					motor_mesh.position.z = scale_new.x * 0.5
					motor_mesh.scale = Vector3(scale_new.y * 0.8, 0.25, scale_new.y * 0.8)
	else:
		set(property, value)

# Set the material of this brick to a different one, 
# and update any related properties.
@rpc("call_local")
func set_material(new : BrickMaterial) -> void:
	match(new):
		# Wood
		0:
			_material = BrickMaterial.WOODEN
			model_mesh.set_surface_override_material(0, wood_material)
			mass = 5 * mass_mult
			unjoin_velocity = 30
			
			# set physics material properties for brick.
			set_physics_material_properties(0.8, 0)
			
			flammable = true
		# Wood Charred
		1:
			_material = BrickMaterial.WOODEN_CHARRED
			model_mesh.set_surface_override_material(0, wood_charred_material)
			mass = 5 * mass_mult
			unjoin_velocity = 30
			
			# set physics material properties for brick.
			set_physics_material_properties(0.8, 0)
			
			flammable = false
		# Metal
		2:
			_material = BrickMaterial.METAL
			model_mesh.set_surface_override_material(0, metal_material)
			mass = 10 * mass_mult
			unjoin_velocity = 55
			
			# set physics material properties for brick.
			set_physics_material_properties(0.7, 0)
			
			flammable = false
		# Plastic
		3:
			_material = BrickMaterial.PLASTIC
			model_mesh.set_surface_override_material(0, plastic_material)
			mass = 3 * mass_mult
			unjoin_velocity = 15
			
			# set physics material properties for brick.
			set_physics_material_properties(0.5, 0.1)
			
			flammable = false
		# Rubber
		4:
			_material = BrickMaterial.RUBBER
			model_mesh.set_surface_override_material(0, rubber_material)
			mass = 5 * mass_mult
			unjoin_velocity = 35
			
			# set physics material properties for brick.
			set_physics_material_properties(0.9, 0.6)
			
			flammable = false
		# Grass
		5:
			_material = BrickMaterial.GRASS
			model_mesh.set_surface_override_material(0, grass_material)
			mass = 3 * mass_mult
			unjoin_velocity = 15
			
			# set physics material properties for brick.
			set_physics_material_properties(0.7, 0)
			
			flammable = false
		# Ice
		6:
			_material = BrickMaterial.ICE
			model_mesh.set_surface_override_material(0, ice_material)
			mass = 3 * mass_mult
			unjoin_velocity = 15
			
			# set physics material properties for brick.
			set_physics_material_properties(0.05, 0)
			
			flammable = false
	mesh_material = model_mesh.get_surface_override_material(0)

func show_delete_overlay() -> void:
	var curr_mat : Material = model_mesh.get_surface_override_material(0)
	model_mesh.set_surface_override_material(0, delete_material)
	await get_tree().process_frame
	model_mesh.set_surface_override_material(0, curr_mat)

func show_save_overlay() -> void:
	var curr_mat : Material = model_mesh.get_surface_override_material(0)
	model_mesh.set_surface_override_material(0, save_material)
	await get_tree().process_frame
	model_mesh.set_surface_override_material(0, curr_mat)

func set_physics_material_properties(fric : float, bounce : float) -> void:
	var physmat : PhysicsMaterial = PhysicsMaterial.new()
	physmat.friction = fric
	physmat.bounce = bounce
	physics_material_override = physmat

# Returns the material resource of this brick.
func get_mesh_material() -> Material:
	return mesh_material

@rpc("any_peer", "call_local", "reliable")
func set_colour(new : Color) -> void:
	_colour = new
	# Duplicate current material.
	var new_material : Material = get_mesh_material().duplicate()
	# By default, new materials are added to the cache.
	var add_material_to_cache := true
	# Check over the graphics cache to make sure we don't already have the same material created.
	for cached_material : Material in Global.graphics_cache:
		# If the material texture and colour matches (that's all that really matters):
		if (cached_material.albedo_color == new && 
		cached_material.albedo_texture == new_material.albedo_texture && 
		cached_material.normal_texture == new_material.normal_texture):
			# Instead of using the duplicate material we created, use the cached material.
			new_material = cached_material
			# Don't add this material to cache, since we're pulling it from the cache already.
			add_material_to_cache = false
	# Add the material to the graphics cache if we need to.
	if add_material_to_cache:
		Global.add_to_graphics_cache(new_material)
		new_material.albedo_color = new
	model_mesh.set_surface_override_material(0, new_material)

func get_colour() -> Color:
	return _colour

# Set whether or not this brick is glued.
# Arg 1: New setting.
# Arg 2: Whether or not this brick being deglued will affect its group memebers.
# Arg 3: Whether or not to ungroup this brick as well.
@rpc("call_local")
func set_glued(new : bool, affect_others : bool = true, addl_radius : float = 0) -> void:
	if !is_multiplayer_authority(): return
	# static brick material cannot be unglued
	if immovable || indestructible:
		return
	# iterate through all bricks in group. Do not run this on dummy bricks.
	if affect_others && (_state == States.BUILD || _state == States.PLACED):
		if brick_groups.groups.has(str(group)):
			for b : Variant in brick_groups.groups[str(group)]:
				# do not unglue static neighbours
				if b != null:
					b = b as Brick
					if !b.immovable && !b.indestructible:
						if new == false:
						# only deglue inside the deglue radius
							if b == self || b.global_position.distance_to(self.global_position) < deglue_radius + addl_radius:
								b.glued = new
								b.freeze = new
								b.has_static_neighbour = false
						else:
							b.glued = new
							b.freeze = new
	# wait a bit in case of an explosion (see explode func in Explosion.gd)
	await get_tree().create_timer(0.2).timeout
	check_group_static_neighbours()

func check_group_static_neighbours(include_self : bool = true) -> void:
	var no_static_neighbours := true
	# update and check entire group
	if brick_groups.groups.has(str(group)):
		for b : Variant in brick_groups.groups[str(group)]:
			# check if at least 1 brick has a static neighbour
			if b != null:
				b = b as Brick
				if b == self && !include_self:
					pass
				elif b.glued && b.has_static_neighbour:
					no_static_neighbours = false
	# no static neighbours, entire group should fall
	if no_static_neighbours:
		unfreeze_entire_group()

# Returns whether or not this brick is glued.
func get_glued() -> bool:
	return glued

# Unfreezes this brick and the entire group that it belongs to.
@rpc("call_local")
func unfreeze_entire_group() -> void:
	# don't unfreeze in the editor
	if Global.get_world().get_current_map() is Editor:
		var editor : Editor = Global.get_world().get_current_map() as Editor
		if !editor.test_mode:
			return
	if !immovable:
		glued = false
		freeze = false
	if brick_groups.groups.has(str(group)):
		for b : Variant in brick_groups.groups[str(group)]:
			if b != null:
				b = b as Brick
				if !b.immovable:
					b.glued = false
					b.freeze = false

# Reduce this brick's health by a set amount. Will char wooden bricks if their health falls below 0.
func reduce_health(amount : int) -> void:
	if !is_multiplayer_authority(): return
	
	health -= amount
	if health <= 0 && flammable:
		health = 0
		set_charred(true)
	
# Sets this brick to a charred state. As of now, only functional on wooden bricks.
func set_charred(new : bool) -> void:
	if !is_multiplayer_authority(): return
	
	if charred != new:
		charred = new
		set_glued(false)
		unjoin()
		set_material.rpc(BrickMaterial.WOODEN_CHARRED)
		extinguish_fire.rpc()
		
# Lights this brick on fire.
@rpc("any_peer", "call_local")
func light_fire() -> void:
	if !on_fire && flammable && !immovable:
		on_fire = true
		fire.light()
		if is_multiplayer_authority():
			var fire_timer := Timer.new()
			fire_timer.wait_time = 20
			fire_timer.one_shot = false
			fire_timer.connect("timeout", reduce_health.bind(20))
			fire_timer.name = "FireTimer"
			add_child(fire_timer)
			fire_timer.start()

# Extinguishes the fire on this brick, and deletes the fire timer.
@rpc("any_peer", "call_local")
func extinguish_fire() -> void:
	if on_fire:
		on_fire = false
		if is_multiplayer_authority():
			if has_node("FireTimer"):
				$FireTimer.queue_free()
		fire.extinguish()

# Explodes this brick. The brick will set on fire if it can, and the explosion is strong enough. Sends
# the brick flying in a direction based on the position of the explosion.
# Arg 1: The position of the explosion. Required to determine impulse on the brick.
# Arg 2: From who this explosion came from.
@rpc("any_peer", "call_local")
func explode(explosion_position : Vector3, from_whom : int = -1, _explosion_force : float = 4) -> void:
	# only run on authority
	if !is_multiplayer_authority(): return
	if immovable || indestructible: return
	set_glued(false)
	set_non_groupable_for(1)
	unjoin()
	var explosion_force : float = randi_range(20, 40) * (_explosion_force)
	if explosion_force > 60:
		light_fire.rpc()
	#0.1s wait to allow for grace period for all affected bricks to unjoin
	await get_tree().create_timer(0.1).timeout
	
	var explosion_dir := explosion_position.direction_to(global_position).normalized() * explosion_force
	apply_impulse(explosion_dir, Vector3(randf_range(0, 0.05), randf_range(0, 0.05), randf_range(0, 0.05)))

func set_non_groupable_for(seconds : float) -> void:
	# avoid grouping together bricks that just exploded
	groupable = false
	await get_tree().create_timer(seconds).timeout
	groupable = true

# Calls on enter scene
func _ready() -> void:
	super()
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	connect("body_entered", _on_body_entered)
	connect("sleeping_state_changed", _on_sleeping_state_changed)
	inactivity_timer.connect("timeout", _inactivity_despawn)
	# set material to spawn material
	set_material(_material)
	
	# Freeze while loading, this is set in peer connected
	if !multiplayer.is_server():
		freeze = true

# Spawns this brick in Editor mode.
@rpc("call_local", "reliable")
func spawn_editor(pos : Vector3, material : BrickMaterial = BrickMaterial.WOODEN) -> void:
	set_multiplayer_authority(1)
	# set material to spawn material
	set_material(material)
	change_state.rpc(States.PLACED)
	global_position = pos

# Spawns this brick as a projectile. Called reliably so that a client
# does not miss their brick being spawned.
# Arg 1: The authority this brick belongs to.
# Arg 2: The speed to shoot at.
# Arg 3: The material to spawn this brick with.
@rpc("call_local", "reliable")
func spawn_projectile(auth : int, shot_speed : int = 30, material : BrickMaterial = BrickMaterial.METAL) -> void:
	set_multiplayer_authority(auth)
	# set material to spawn material
	set_material(material)
	change_state(States.DUMMY_PROJECTILE)
	player_from = world.get_node(str(auth))
	
	if !is_multiplayer_authority(): return
	# Set projectile spawn point to player point
	if player_from != null:
		global_position = player_from.global_position
		global_position = Vector3(global_position.x, global_position.y + 2.5, global_position.z)
	
	# Set velocity to the position entry of the get_mouse_pos_3d dict.
	var target_pos := Vector3()
	if camera is Camera:
		if camera.get_mouse_pos_3d():
			target_pos = Vector3(camera.get_mouse_pos_3d()["position"] as Vector3)
	# vector pointing to the target pos
	var direction := global_position.direction_to(target_pos)
	linear_velocity = direction * shot_speed
	angular_velocity = Vector3(1, 1, 1) * (shot_speed * 0.3)
	
	# make shot bricks on fire
	light_fire.rpc()
	
	if is_multiplayer_authority():
		# notify other clients of this brick's properties
		sync_properties.rpc(properties_as_dict())

@rpc("any_peer", "call_remote", "reliable")
func sync_properties(props : Dictionary) -> void:
	for prop : String in props.keys():
		if prop != "script":
			set_property(prop, props[prop])

# When a new peer connects, send all this brick's properties to the peer.
func _on_peer_connected(id : int) -> void:
	# only execute from the owner
	if !is_multiplayer_authority(): return
	sync_properties.rpc_id(id, properties_as_dict())

# When hit by something else.
func _on_body_entered(body : PhysicsBody3D) -> void:
	# only execute on server
	if !multiplayer.is_server(): return
	var total_velocity : float = linear_velocity.length()
	# Light other bricks on fire.
	if on_fire:
		if body is Brick:
			if (randi() % 10 > 7):
				body.light_fire.rpc()
	# Bricks hit by other bricks within the same group will not displace.
	if body is Brick:
		if body.group != self.group:
			# don't unglue bricks bigger than ourselves
			if mass_mult > body.mass_mult:
				total_velocity *= (mass * 0.25)
				if total_velocity > 24:
					body.set_glued(false, true, mass_mult)
				# Unjoin this brick from its group if it is hit too hard.
				if total_velocity > body.unjoin_velocity:
					var impact_region : float = mass_mult * 0.5
					impact_region = clamp(impact_region, 0, 12)
					if brick_groups.groups.has(str(body.group)):
						for brick : Variant in brick_groups.groups[str(body.group)]:
							if brick != null:
								if brick is Brick:
									if brick.global_position.distance_to(body.global_position) < impact_region:
										brick.unjoin()
					body.unjoin()
				# stepped on button
				if body is ButtonBrick:
					body.stepped.rpc(get_path())
	# Play sounds
	if total_velocity > 7:
		if !(body is Brick) && !(self is MotorBrick) && (_state != States.BUILD) && (_state != States.DUMMY_BUILD):
			if $SoundExpiration.is_stopped():
				play_hit_sound.rpc((-20 + (total_velocity * 2)))
				$SoundExpiration.start()

# Plays sound when the brick hits something
# Arg 1: Volume in dB
@rpc("call_local")
func play_hit_sound(volume : float) -> void:
	match _material:
		BrickMaterial.METAL:
			$AudioStreamPlayer3D.stream = hit_sounds_metal[randi() % 3]
		_:
			$AudioStreamPlayer3D.stream = hit_sounds_wood[randi() % 4]
	$AudioStreamPlayer3D.volume_db = volume
	$AudioStreamPlayer3D.play()

# Remove this brick
@rpc("any_peer", "call_local")
func despawn(check_world_groups : bool = true) -> void:
	if _state == States.PLACED && check_world_groups:
		brick_groups.check_world_groups()
	queue_free()

# Check joint for any nearby bricks to join to.
# Arg 1: A set group to put this brick into. Used mainly for spawning prebuilt buildings.
func check_joints(specific_body : Node3D = null) -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	# update our child Joint
	var found_brick := false
	
	var bodies_to_check : Array[Node3D] = []
	if specific_body != null:
		bodies_to_check.append(specific_body)
	# join bricks that are adjacent
	for body in joint_detector.get_overlapping_bodies():
		if !bodies_to_check.has(body):
			bodies_to_check.append(body)
	
	for body in bodies_to_check:
		# don't join with self
		if body is Brick && body != self:
			# if this is immovable (loaded first)
			if self.immovable:
				body.has_static_neighbour = true
			# if other loaded first
			if body.immovable:
				has_static_neighbour = true
			found_brick = true
			if body.joinable && self.joinable:
				# don't let normal bricks join to motor bricks; 
				if body is MotorBrick && !(self is MotorBrick):
					# in case motor brick did not check for this brick
					body.check_joints(self)
					continue
				# Don't let wheels join with seats
				if (body is MotorBrick && self is MotorSeat) || (body is MotorSeat && self is MotorBrick):
					continue
				
				join(body.get_path())
				# if the motor detector doesn't have the body, it is
				# joined on the non-motor side, so join the body to
				# us as well
				if self is MotorBrick:
					var motor_pos : Vector3 = $JointSpotLeft.global_position
					var joint_pos : Vector3 = $JointSpotRight.global_position
					if self.flip_motor_side:
						motor_pos = $JointSpotRight.global_position
						joint_pos = $JointSpotLeft.global_position
					# add a bit of bias towards the non-motor side so that
					# bricks that are placed on the outer edge of a wheel
					# will attach to it
					if body.global_position.distance_to(joint_pos) < body.global_position.distance_to(motor_pos) + 0.02:
						body.join(self.get_path())
		elif body is StaticBody3D:
			has_static_neighbour = true

var joint_path_list : Array[String] = []
# Join with another brick.
# Arg 1: The other brick to join to, as a NodePath.
@rpc ("call_local")
func join(path_to_brick : NodePath, set_group : String = "") -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	
	# Do not join to self.
	if (path_to_brick == self.get_path()):
		print(str(multiplayer.get_unique_id(), " id:", "[Brick]: Can't join with self"))
		return
	
	# Do not join to dummy bricks.
	var brick_node_state : States = get_node(path_to_brick)._state
	if (brick_node_state == States.DUMMY_BUILD || brick_node_state == States.DUMMY_PLACED || brick_node_state == States.DUMMY_PROJECTILE):
		return
	
	# Do not create duplicate joints.
	if joint_path_list.has(path_to_brick.get_name(path_to_brick.get_name_count() - 1)):
		print(str(multiplayer.get_unique_id(), " id:", "[Brick]: Tried duplicate joint"))
		return
	
	var joint : Generic6DOFJoint3D = joint_scn.instantiate()
	add_child(joint, true)
	if self is MotorBrick:
		# wheels have no z angular limit
		joint.set("angular_limit_z/enabled", false)
		# prevents large wheels from clipping through other large bricks
		joint.set("exclude_nodes_from_collision", false)
		# find closest joint spot
		var joint_spot_left : Node3D = $JointSpotLeft
		var joint_spot_right : Node3D = $JointSpotRight
		var joining_to_pos : Vector3 = get_node(path_to_brick).global_position as Vector3
		var left_closer : bool = true
		if joint_spot_left.global_position.distance_to(joining_to_pos) > joint_spot_right.global_position.distance_to(joining_to_pos):
			left_closer = false
		if left_closer:
			joint.global_position = joint_spot_left.global_position
		else: joint.global_position = joint_spot_right.global_position
	joint.set_node_b(path_to_brick)
	joint.set_node_a(self.get_path())
	joint_path_list.append(path_to_brick.get_name(path_to_brick.get_name_count() - 1))

# Unjoin this brick from its partner.
@rpc("any_peer", "call_local", "reliable")
func unjoin() -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	if indestructible:
		return
	
	joint_path_list = []
	
	for j in get_children():
		if j is Generic6DOFJoint3D:
			var other_brick : Variant = Global.get_world().get_node_or_null(str(j.node_b))
			if other_brick != null:
				for other_j : Node in other_brick.get_children():
					if other_j is Generic6DOFJoint3D:
						other_j.queue_free()
			j.queue_free()

# When this brick sleeps or unsleeps, controlled by the physics engine.
func _on_sleeping_state_changed() -> void:
	# If we are sleeping, and we are NOT glued, and we are NOT in a group (eg. lone brick)
	if sleeping && glued == false && group == name && !(self is MotorSeat):
		# then start the inactivity timer.
		inactivity_timer.start()
		# if we're not sleeping
	else:
		inactivity_timer.stop()

# despawn based on inactivity
func _inactivity_despawn() -> void:
	despawn.rpc()

func _physics_process(delta : float) -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	# used by motor seat
	sync_step += 1
	
	# handle smoothing, wait a bit to allow smoothing to
	# move bricks before disabling its process
	if (freeze && sync_step > 120) && (_state != States.BUILD):
		smoothing.set_physics_process(false)
		smoothing.set_process(false)
	else:
		smoothing.set_physics_process(true)
		smoothing.set_process(true)
	
	match _state:
		_:
			# despawn brick if it falls out of map
			if global_position.y < -1024:
				despawn.rpc()

# State change
@rpc("any_peer", "call_local")
func change_state(state : States) -> void:
	if state == States.PLACED:
		# make server brick owner when brick is placed
		set_multiplayer_authority(1)
	# if we are the auth of this brick, set its actual state
	if is_multiplayer_authority():
		_state = state
	# otherwise use dummy state replica.
	else:
		match state:
			States.BUILD, States.DUMMY_BUILD:
				_state = States.DUMMY_BUILD
			States.PLACED, States.DUMMY_PLACED:
				_state = States.DUMMY_PLACED
			States.DUMMY_PROJECTILE:
				_state = States.DUMMY_PROJECTILE
	enter_state()

# Function runs once on new state.
func enter_state() -> void:
	match _state:
		States.BUILD:
			cam_collider.disabled = true
			collider.disabled = true
			# Freeze so that the brick doesn't move upon spawn.
			freeze = true
			# Align this brick if we're picking it up.
			rotation = Vector3.ZERO
			# Set the rotation to the tool rotation.
			if tool_from != null:
				rotate_y(deg_to_rad(tool_from.brick_rotation_y as float))
				rotate_x(deg_to_rad(tool_from.brick_rotation_x as float))
			# check if this is placed next to any other bricks, if so, join them
			check_joints()
		States.PLACED:
			cam_collider.disabled = false
			collider.disabled = false
			# Only unfreeze if the brick is not glued on spawn, as the glued
			# function makes use of the freeze function.
			if !get_glued():
				freeze = false
			await get_tree().physics_frame
			# check if this is placed next to any other bricks, if so, join them
			check_joints()
			# update world groups if placed by a tool
			if tool_from != null:
				brick_groups.check_world_groups()
		States.DUMMY_BUILD:
			cam_collider.disabled = true
			collider.disabled = true
			
			#freeze = true
		States.DUMMY_PLACED:
			cam_collider.disabled = false
			collider.disabled = false
			# freeze = true on dummy placed bricks so that
			# they do not try to calculate their own physics on
			# non-authority peers.
			#freeze = true
		States.DUMMY_PROJECTILE:
			cam_collider.disabled = false
			collider.disabled = false
			# freeze = true on dummy projectiles, as brick projectiles
			# are dummies on both authority and non-authority.
			#freeze = false

func entered_water() -> void:
	super()
	extinguish_fire()
	gravity_scale = -0.3

func properties_as_dict() -> Dictionary:
	var dict : Dictionary = {}
	for p : String in properties_to_save:
		dict[p] = get(p)
	dict["freeze"] = freeze
	return dict
