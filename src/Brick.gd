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
	STATIC
}

# Size of grid cells.
const CELL_SIZE = 1
# Range of placement.
var placement_range = 6
# Range of placement in Sandbox mode.
var sandbox_placement_range = 16
# When this brick is deglued, it will affect others in this radius.
var deglue_radius = 2
# How hard this brick must be hit to be unjoined.
var unjoin_velocity = 40
var health = 20
# variables for syncing with clients in physics_process
var time_since_moved = 0
var sync_step = 0
# for spawning buildings
var joinable = true
# for larger bricks
var mass_mult = 1
@export var flammable = true
var on_fire = false
var charred = false
@export var glued = true

@onready var group = name
@onready var world = Global.get_world()
@onready var brick_groups = world.get_node("BrickGroups")

@export var _state : States = States.DUMMY_PLACED
@export var _material : BrickMaterial = BrickMaterial.WOODEN
@export var _brick_type : String = "Brick"
@export var _colour : Color = "#fefefe"

@onready var wood_material = preload("res://data/materials/wood.tres")
@onready var wood_charred_material = preload("res://data/materials/wood_charred.tres")
@onready var metal_material = preload("res://data/materials/metal.tres")
@onready var plastic_material = preload("res://data/materials/plastic.tres")
@onready var rubber_material = preload("res://data/materials/rubber.tres")
@onready var static_material = preload("res://data/materials/static.tres")

# for showing cost in minigame
@onready var floaty_text = preload("res://data/scene/ui/FloatyText.tscn")

@onready var fire = $Fire
@onready var collider = $collider
@onready var cam_collider = $CameraMousePosInterceptor/collider
@onready var intersect_d = $IntersectDetector
@onready var model_mesh = $Smoothing/model/Cube
@onready var smoothing = $Smoothing

@onready var joint = $"Joint"
@onready var joint_detector = $"JointDetector"

@onready var inactivity_timer = $InactivityTimer

@onready var camera = get_viewport().get_camera_3d()
@onready var invalid_material = preload("res://data/materials/invalid_placement_material.tres")
@onready var delete_material = preload("res://data/materials/delete_placement_material.tres")
@onready var save_material = preload("res://data/materials/save_placement_material.tres")
@onready var hit_sounds_wood = [
	preload("res://data/audio/wood/wood_hit_0.ogg"),
	preload("res://data/audio/wood/wood_hit_1.ogg"),
	preload("res://data/audio/wood/wood_hit_2.ogg"),
	preload("res://data/audio/wood/wood_hit_3.ogg")
]
@onready var hit_sounds_metal = [
	preload("res://data/audio/metal/metal_hit_0.ogg"),
	preload("res://data/audio/metal/metal_hit_1.ogg"),
	preload("res://data/audio/metal/metal_hit_2.ogg")
]

# The tool that this brick was spawned by
var tool_from : Tool
# Whether or not this brick was just spawned by its tool. This variable
# is used in the build function.
var just_spawned_from_tool = true

# Set the material of this brick to a different one, 
# and update any related properties.
@rpc("call_local")
func set_material(new : BrickMaterial) -> void:
	match(new):
		# Wood
		0:
			_material = BrickMaterial.WOODEN
			model_mesh.set_surface_override_material(0, wood_material)
			mass = 10 * mass_mult
			unjoin_velocity = 30
			
			# set physics material properties for brick.
			set_physics_material_properties(0.8, 0)
			
			flammable = true
		# Wood Charred
		1:
			_material = BrickMaterial.WOODEN_CHARRED
			model_mesh.set_surface_override_material(0, wood_charred_material)
			mass = 10 * mass_mult
			unjoin_velocity = 30
			
			# set physics material properties for brick.
			set_physics_material_properties(0.8, 0)
			
			flammable = false
		# Metal
		2:
			_material = BrickMaterial.METAL
			model_mesh.set_surface_override_material(0, metal_material)
			mass = 70 * mass_mult
			unjoin_velocity = 55
			
			# set physics material properties for brick.
			set_physics_material_properties(0.7, 0)
			
			flammable = false
		# Plastic
		3:
			_material = BrickMaterial.PLASTIC
			model_mesh.set_surface_override_material(0, plastic_material)
			mass = 5 * mass_mult
			unjoin_velocity = 15
			
			# set physics material properties for brick.
			set_physics_material_properties(0.5, 0.1)
			
			flammable = false
		# Rubber
		4:
			_material = BrickMaterial.RUBBER
			model_mesh.set_surface_override_material(0, rubber_material)
			mass = 30 * mass_mult
			unjoin_velocity = 35
			
			# set physics material properties for brick.
			set_physics_material_properties(1, 0.8)
			
			flammable = false
		# Static
		5:
			_material = BrickMaterial.STATIC
			model_mesh.set_surface_override_material(0, static_material)
			mass = 99
			unjoin_velocity = 9999
			
			# set physics material properties for brick.
			set_physics_material_properties(1, 0)
			
			flammable = false

func show_delete_overlay() -> void:
	var curr_mat = model_mesh.get_surface_override_material(0)
	model_mesh.set_surface_override_material(0, delete_material)
	await get_tree().process_frame
	model_mesh.set_surface_override_material(0, curr_mat)

func show_save_overlay() -> void:
	var curr_mat = model_mesh.get_surface_override_material(0)
	model_mesh.set_surface_override_material(0, save_material)
	await get_tree().process_frame
	model_mesh.set_surface_override_material(0, curr_mat)

func set_physics_material_properties(fric : float, bounce : float):
	var physmat = PhysicsMaterial.new()
	physmat.friction = fric
	physmat.bounce = bounce
	physics_material_override = physmat

# Returns the material resource of this brick.
func get_material():
	match(_material):
		0:
			return wood_material
		1:
			return wood_charred_material
		2:
			return metal_material
		3:
			return plastic_material
		4:
			return rubber_material
		5:
			return static_material

@rpc("any_peer", "call_local", "reliable")
func set_colour(new : Color) -> void:
	_colour = new
	var new_material = get_material().duplicate()
	# By default, new materials are added to the cache.
	var add_material_to_cache = true
	# Check over the graphics cache to make sure we don't already have the same material created.
	for cached_material in Global.graphics_cache:
		# If the material texture and colour matches (that's all that really matters):
		if cached_material.albedo_color == new && cached_material.albedo_texture == new_material.albedo_texture:
			# Instead of using the duplicate material we created, use the cached material.
			new_material = cached_material
			# Don't add this material to cache, since we're pulling it from the cache already.
			add_material_to_cache = false
	# Add the material to the graphics cache if we need to.
	if add_material_to_cache:
		Global.graphics_cache.append(new_material)
		new_material.albedo_color = new
	model_mesh.set_surface_override_material(0, new_material)

func get_colour():
	return _colour

# Set whether or not this brick is glued.
# Arg 1: New setting.
# Arg 2: Whether or not this brick being deglued will affect its group memebers.
# Arg 3: Whether or not to ungroup this brick as well.
@rpc("call_local")
func set_glued(new : bool, affect_others : bool = true, ungroup : bool = true) -> void:
	# static brick material cannot be unglued
	if _material == BrickMaterial.STATIC:
		return
	# iterate through all bricks in group. Do not run this on dummy bricks.
	if affect_others && (_state == States.BUILD || _state == States.PLACED):
		if brick_groups.groups.has(str(group)):
			for b in brick_groups.groups[str(group)]:
				# do not unglue static neighbours
				if b != null && b._material != BrickMaterial.STATIC:
					if new == false:
					# only deglue inside the deglue radius, OR if the brick to be deglued is above the one that was hit (allows roofs to fall)
						var is_above_threshold = (b.global_position.y > self.global_position.y) && abs(b.global_position.x - self.global_position.x) < 2 && abs(b.global_position.z - self.global_position.z) < 2
						if (b.global_position.distance_to(self.global_position) < deglue_radius) || is_above_threshold:
							b.glued = new
							b.freeze = new
					else:
						b.glued = new
						b.freeze = new
	
	# Do not run this on dummy bricks.
	if new == false && ungroup && (_state == States.BUILD || _state == States.PLACED):
		# erase self from group
		if brick_groups.groups.has(str(group)):
			brick_groups.groups.get(str(group)).erase(self)
		# reset group to own
		group = name
	
	glued = new
	freeze = new

# Returns whether or not this brick is glued.
func get_glued():
	return glued

# Unfreezes this brick and the entire group that it belongs to.
@rpc("call_local")
func unfreeze_entire_group():
	if _material != BrickMaterial.STATIC:
		glued = false
		freeze = false
	if brick_groups.groups.has(str(group)):
		for b in brick_groups.groups[str(group)]:
			if b != null && b._material != BrickMaterial.STATIC:
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
	if !on_fire && flammable:
		on_fire = true
		fire.light()
		if is_multiplayer_authority():
			var fire_timer = Timer.new()
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
func explode(explosion_position : Vector3, from_whom = null) -> void:
	# only run on authority
	if !is_multiplayer_authority(): return
	
	set_glued(false)
	unjoin()
	var explosion_force = randi_range(80, 200)
	if explosion_force > 160:
		light_fire.rpc()
	#0.1s wait to allow for grace period for all affected bricks to unjoin
	await get_tree().create_timer(0.1).timeout
	var explosion_dir = explosion_position.direction_to(global_position) * explosion_force
	apply_impulse(explosion_dir, Vector3(randf_range(0, 0.05), randf_range(0, 0.05), randf_range(0, 0.05)))

# Calls on enter scene
func _ready():
	super()
	connect("body_entered", _on_body_entered)
	connect("sleeping_state_changed", _on_sleeping_state_changed)
	inactivity_timer.connect("timeout", _inactivity_despawn)
	# set material to spawn material
	set_material(_material)
		# set colour, if need be (avoid otherwise as not to make unnecessary new materials)
	if _colour.to_html(false) != "fefefe":
		set_colour(_colour)

# Spawns this brick, usually from a tool. Called reliably so that a client
# does not miss their brick being spawned.
# Arg 1: The authority this brick belongs to.
# Arg 2: The material to set this brick to on spawn.
@rpc("call_local", "reliable")
func spawn(auth : int, material : BrickMaterial = BrickMaterial.WOODEN) -> void:
	set_multiplayer_authority(auth)
	# set material to spawn material
	set_material(material)
	# what player this brick came from
	player_from = world.get_node(str(auth))
	tool_from = player_from.get_node("Tools/BuildTool")
	if is_multiplayer_authority():
		# notify other clients of this brick's properties
		_sync_properties_spawn.rpc([global_position, global_rotation, get_multiplayer_authority()])
	change_state.rpc(States.BUILD)

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
	var target_pos = Vector3()
	if camera is Camera:
		if camera.get_mouse_pos_3d():
			target_pos = Vector3(camera.get_mouse_pos_3d()["position"])
	# vector pointing to the target pos
	var direction = global_position.direction_to(target_pos)
	linear_velocity = direction * shot_speed
	angular_velocity = Vector3(1, 1, 1) * (shot_speed * 0.3)
	
	# make shot bricks on fire
	light_fire.rpc()
	
	if is_multiplayer_authority():
		# notify other clients of this brick's properties
		_sync_properties_spawn.rpc([global_position, global_rotation, get_multiplayer_authority()])

# sync ALL properties with client over rpc
@rpc("any_peer", "call_remote", "reliable")
func _sync_properties(args : Array) -> void:
	global_position = args[0]
	global_rotation = args[1]
	if _material != args[2]:
		set_material(args[2])
	# join with brick path, so long as the brick has one
	if args[3] != null && args[3] != NodePath():
		join(args[3])
	if glued != args[4] || freeze != args[4]:
		set_glued(args[4], false)

# sync properties for spawning or new player join
@rpc("any_peer", "call_remote", "reliable")
func _sync_properties_spawn(args : Array) -> void:
	global_position = args[0]
	global_rotation = args[1]
	set_multiplayer_authority(args[2])
	# freeze always true for other clients
	freeze = true

# sync properties that need constant updates with client over rpc
@rpc("any_peer", "call_remote")
func _sync_properties_always(args : Array) -> void:
	global_position = args[0]
	global_rotation = args[1]

# When a new peer connects, send all this brick's properties to the peer.
func _on_peer_connected(id) -> void:
	# only execute from the owner
	if !is_multiplayer_authority(): return
	_sync_properties_spawn.rpc_id(id, [global_position, global_rotation, get_multiplayer_authority()])

# When hit by something else.
func _on_body_entered(body) -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	var total_velocity = linear_velocity.length()
	
	if body is RigidBody3D && !(body is ClayBall):
		total_velocity += body.linear_velocity.length()
	
	# Light other bricks or players on fire.
	if on_fire:
		if body is Brick:
			if (randi() % 10 > 7):
				body.light_fire.rpc()
	# Bricks hit by other bricks within the same group will not displace.
	if body is Brick:
		if body.group != self.group:
			# metal displaces other bricks more easily
			if _material == BrickMaterial.METAL:
				total_velocity += 18
			if total_velocity > 24:
				body.set_glued(false)
			# Unjoin this brick from its group if it is hit too hard.
			if total_velocity > body.unjoin_velocity:
				body.unjoin()
		
	# trip other players when my velocity is high
	if body is RigidPlayer && linear_velocity.length() > 2 && !(self is MotorSeat):
		body.trip_by_player.rpc(linear_velocity * 2)
	
	# Play sounds, but only if not hit by another brick. Projectiles get an
	# exception.
	if total_velocity > 7:
		if !(body is Brick && _state != States.DUMMY_PROJECTILE) && (_state != States.BUILD) && (_state != States.DUMMY_BUILD):
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
func despawn():
	queue_free()

# Build mode, used when a brick is spawning from a tool.
func build() -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	
	# if the the tool no longer exists (ex. player left while holding it)
	if tool_from == null:
		# remove this for all peers
		despawn.rpc()
		return
	# if the user deselects the tool whilst this brick is being built, switches type,
	# or enters delete mode
	if (!tool_from.get_tool_active()) || tool_from.switched_type == true || tool_from._mode == BuildTool.BuildMode.DELETE:
		# the tool is no longer building
		tool_from.set_building(false)
		tool_from.switched_type = false
		# remove this for all peers
		despawn.rpc()
	# get mouse position in 3d space
	var m_3d = Vector3()
	if camera is Camera:
		m_3d = camera.get_mouse_pos_3d()
	var m_pos_3d = Vector3()
	# we must check if the mouse's ray is not hitting anything
	if m_3d:
		# if it is hitting something
		m_pos_3d = Vector3(m_3d["position"])
	# snap to grid
	var snapped_pos = (m_pos_3d / CELL_SIZE).round() * CELL_SIZE
	# match floor on y
	snapped_pos.y = m_pos_3d.y + (CELL_SIZE * 0.5)
	# snap in relation to other bricks if mouse is over brick
	if m_3d:
		if m_3d["collider"].owner is Brick:
			var m_3d_normal = m_3d["normal"]
			# we can get normal from the camera's mouse collision ray
			snapped_pos = m_3d["collider"].owner.global_position + m_3d_normal
	# offset Y pos from tool's offset value
	if tool_from != null:
		snapped_pos.y += tool_from.build_offset_y
	# don't lerp from spawn
	if !just_spawned_from_tool:
		# smooth movement between grid positions
		global_position = lerp(global_position, snapped_pos, 0.7)
	else: global_position = snapped_pos
	just_spawned_from_tool = false
	
	# placement range
	var too_far = global_position.distance_to(player_from.global_position) > placement_range
	if Global.get_world().minigame == null:
		too_far = global_position.distance_to(player_from.global_position) > sandbox_placement_range
	var valid = true
	if intersect_d == null || intersect_d.has_overlapping_bodies() || too_far:
		valid = false
	
	# Rotate brick
	if Input.is_action_just_pressed("debug_action_r"):
		tool_from.brick_rotation_y += 90
		rotate_y(deg_to_rad(90))
	# Rotate brick but differently
	if Input.is_action_just_pressed("debug_action_f"):
		tool_from.brick_rotation_x += 90
		rotate_x(deg_to_rad(90))
	
	# if there is an active minigame
	var cannot_afford = false
	var too_close_to_target = false
	var minigame = Global.get_world().minigame
	# minigame costs
	var cost = 2
	if minigame != null:
		# only base defense has costs and placement limits
		if minigame is MinigameBaseDefense:
			# minigame costs
			if _material == BrickMaterial.METAL:
				cost = 8
			elif _material == BrickMaterial.RUBBER:
				cost = 7
			if minigame.playing_team_names.has(player_from.team):
				# if we cannot afford brick, set to invalid
				if minigame.get_team_cash(player_from.team) < cost:
					valid = false
					cannot_afford = true
			# can't place directly next to target
			for target in minigame.team_targets:
				if target.team == player_from.team:
					if global_position.distance_to(target.global_position) < 5:
						valid = false
						too_close_to_target = true
	
	# if the type of brick is changing, this may be null during the change
	if model_mesh != null:
		if !valid:
			model_mesh.set_surface_override_material(0, invalid_material)
		else: 
			model_mesh.set_surface_override_material(0, get_material())
	
	# place brick
	if Input.is_action_just_pressed("click"):
		if valid:
			if minigame != null:
				# only base defense has costs
				if minigame is MinigameBaseDefense:
					if minigame.playing_team_names.has(player_from.team):
						# pay for brick
						minigame.set_team_cash.rpc(player_from.team, -cost)
						# floaty cost text
						var floaty_i = floaty_text.instantiate()
						floaty_i.get_node("Label").text = str("-$", cost)
						floaty_i.global_position = Vector3(global_position.x, global_position.y + 0.5, global_position.z)
						Global.get_world().add_child(floaty_i)
			change_state.rpc(States.PLACED)
			# If this brick was built by a tool, inform the tool it can
			# now build again.
			if tool_from != null:
				tool_from.set_building(false)
		else:
			if too_far:
				UIHandler.show_alert("Can't place! Too far away", 2, false, true)
			elif cannot_afford:
				UIHandler.show_alert("Your team can't afford this brick!", 2, false, true)
			elif too_close_to_target:
				UIHandler.show_alert("Can't place! Too close to team target!", 2, false, true)
			else:
				UIHandler.show_alert("Can't place! Intersection", 2, false, true)

# Check joint for any nearby bricks to join to.
# Arg 1: A set group to put this brick into. Used mainly for spawning prebuilt buildings.
func check_joints(set_group = "") -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	
	if joint_detector.has_overlapping_bodies():
		# update our child Joint
		update_joint(set_group)
	else:
		# we don't have any bricks to join to
		brick_groups.groups[str(group)] = []

# Update this brick's joint.
func update_joint(set_group = "") -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	var found_brick = false
	# join bricks that are adjacent
	for body in joint_detector.get_overlapping_bodies():
		# don't join with self
		if body is Brick && self != body:
			found_brick = true
			if body.joinable && body.get_material() != static_material:
				# Don't let wheels join with each other
				if body is MotorBrick && self is MotorBrick:
					pass
				# Don't let wheels join with seats
				elif (body is MotorBrick && self is MotorSeat) || (body is MotorSeat && self is MotorBrick):
					pass
				else:
					join(body.get_path(), set_group)
					return
	if !found_brick:
		# we don't have any bricks to join to
		brick_groups.groups[str(group)] = []

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
	var brick_node_state = get_node(path_to_brick)._state
	if (brick_node_state == States.DUMMY_BUILD || brick_node_state == States.DUMMY_PLACED || brick_node_state == States.DUMMY_PROJECTILE):
		return
	
	joint.set_node_b(path_to_brick)
	joint.set_node_a(self.get_path())
	# Update the brick groups.
	update_joined_brick_groups(path_to_brick, set_group)

# Update the BrickGroups group.
func update_joined_brick_groups(path_to_brick : NodePath, set_group : String = "") -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	
	# if we are determining group dynamically
	if set_group == "":
		var brick = get_node(path_to_brick)
		# Set my group to the other brick's group.
		group = brick.group
		# Add this brick and the other brick to the group if they are not already in it.
		if !brick_groups.groups[str(group)].has(self):
			brick_groups.groups[str(group)].append(self)
		if !brick_groups.groups[str(group)].has(brick):
			brick_groups.groups[str(group)].append(brick)
	# determing group based on set group name
	else:
		group = set_group
		if !brick_groups.groups.has(str(set_group)):
			brick_groups.groups[str(set_group)] = []
		brick_groups.groups[str(set_group)].append(self)
	
# Unjoin this brick from its partner.
@rpc("any_peer", "call_local", "reliable")
func unjoin() -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	
	joint.set_node_a(NodePath())
	joint.set_node_b(NodePath())
	
	# reset group
	group = name

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

func _physics_process(delta):
	# only execute on yourself
	if !is_multiplayer_authority(): return
	# used by motor seat
	sync_step += 1
	
	# handle smoothing, wait a frame to allow smoothing to
	# move bricks before disabling its process
	if (freeze && sync_step > 2) && (_state != States.BUILD):
		smoothing.set_physics_process(false)
		smoothing.set_process(false)
	else:
		smoothing.set_physics_process(true)
		smoothing.set_process(true)
	
	match _state:
		States.BUILD:
			build()
		_:
			# despawn brick if it falls out of map
			if global_position.y < -50:
				despawn.rpc()

# State change
@rpc("any_peer", "call_local")
func change_state(state) -> void:
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
				rotate_y(deg_to_rad(tool_from.brick_rotation_y))
				rotate_x(deg_to_rad(tool_from.brick_rotation_x))
			# check if this is placed next to any other bricks, if so, join them
			check_joints()
		States.PLACED:
			cam_collider.disabled = false
			collider.disabled = false
			# Only unfreeze if the brick is not glued on spawn, as the glued
			# function makes use of the freeze function.
			if !get_glued():
				freeze = false
			# check if this is placed next to any other bricks, if so, join them
			check_joints()
		States.DUMMY_BUILD:
			cam_collider.disabled = true
			collider.disabled = true
			
			freeze = true
		States.DUMMY_PLACED:
			cam_collider.disabled = false
			collider.disabled = false
			# freeze = true on dummy placed bricks so that
			# they do not try to calculate their own physics on
			# non-authority peers.
			freeze = true
		States.DUMMY_PROJECTILE:
			cam_collider.disabled = false
			collider.disabled = false
			# freeze = true on dummy projectiles, as brick projectiles
			# are dummies on both authority and non-authority.
			freeze = false

func entered_water() -> void:
	super()
	extinguish_fire()
	gravity_scale = -0.3

@rpc("any_peer", "call_remote", "reliable")
func request_group_from_authority(id_from):
	var group_array = []
	if brick_groups.groups.has(str(group)):
		for b in brick_groups.groups[str(group)]:
			if b != null:
				group_array.append(b)
	# for every brick in the array, tell the non-auth its new group is this one's
	for b in group_array:
		brick_groups.receive_group_from_authority.rpc_id(id_from, b.name)
