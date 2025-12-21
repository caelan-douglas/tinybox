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

extends RigidBody3D
class_name RigidPlayer

signal hit_by_melee(tool : Tool)
signal died()
signal teleported()
signal kills_increased()

enum {
	IDLE,
	RUN,
	AIR,
	HIGH_JUMP,
	TRIPPED,
	STANDING_UP,
	IN_SEAT,
	EXIT_SEAT,
	DEAD,
	RESPAWN,
	DUMMY,
	DIVE,
	SWIMMING,
	SWIMMING_IDLE,
	SWIMMING_DASH,
	EXIT_SWIMMING,
	SLIDE,
	SLIDE_BACK,
	ROLL,
	ON_LEDGE
}

# DEBUG
var states_as_names : Array[String] = ["Idle", "Run", "Air", "High jump", "Tripped", "Standing up", "In seat", "Exit seat", "Dead", "Respawn", "Dummy", "Dive", "Swimming", "Swimming idle", "Swimming dash", "Exit swimming", "Slide", "Slide back", "Rolling", "On wall", "On ledge"]

enum CauseOfDeath {
	EXPLOSION,
	MELEE,
	HIT_BY_BRICK,
	OUT_OF_MAP,
	FIRE,
	FLAMETHROWER_EXPLOSION,
	HIT_BY_BALL,
	SWAMP_WATER
}

var _state : int = IDLE
var display_name := ""
var camera : Camera3D = null
var jump_force := 2.4
var high_jump_force := 12
# when holding jump
var extra_jump_force := 2.4
var move_speed : float = 5
var decel_multiplier := 0.85
var normal_decel_multiplier := 0.85
var ice_decel_multiplier := 0.98
var player_grav := 1.4
var team := "Default"
var seat_occupying : MotorSeat = null
var health : int = 20
var max_health : int = 20
var dead : bool = false
var spawns := []
var death_message := ""
var executing_player : Node3D = null
var death_camera_mode : Camera.CameraMode = Camera.CameraMode.FREE
var locked := false:
	get:
		return locked
	set(v):
		if high_priority_lock == true:
			locked = true
		else:
			locked = v
var high_priority_lock := false
# invulnerable on spawn
var invulnerable := true
var can_enter_seat := true
var on_fire := false
var in_air_from_lifter := false
var external_propulsion := false
var swim_dash_cooldown : int = 0
var lateral_velocity := Vector3.ZERO
var standing_on_object : Node3D = null
# 1 is finished
var checkpoint : int = 0

var last_hit_by_id : int = -1
var last_hit := false

var time_last_tripped : int = 0

var kills : int = 0
var deaths : int = 0
# -1 when not being used
var capture_time : int = -1

@onready var fire : Fire = $Fire
@onready var bubble_particles : GPUParticles3D = $Smoothing/character_model/character/Skeleton3D/NeckAttachment/Bubbles
@onready var character_model : Node3D = $Smoothing/character_model
@onready var drip_animator : AnimationPlayer = $Drip/AnimationPlayer
@onready var target : Node3D = $Smoothing/target
@onready var aim_target : Node3D = $Smoothing/aim_target
@onready var ground_detect : Area3D = $GroundDetect
@onready var slide_detect : Area3D = $GroundDetect
@onready var forward_detect : Area3D = $ForwardDetect
@onready var wall_detect : Area3D = $WallDetect
@onready var ledge_detect : Area3D = $LedgeDetect
@onready var forward_ray : RayCast3D = $ForwardRay
@onready var ledge_ray : RayCast3D = $LedgeRay
@onready var air_time : Timer = $AirTime
@onready var chat_time : Timer = $ChatTime
@onready var ledge_time : Timer = $LedgeTime
@onready var trip_time : Timer = $TripTime
@onready var slide_time : Timer = $SlideTime
@onready var swim_dash_time : Timer = $SwimDashTime
@onready var high_jump_time : Timer = $HighJumpTime
@onready var roll_time : Timer = $RollTime
@onready var respawn_time : Timer = $RespawnTime
@onready var trip_audio : AudioStreamPlayer3D = $TripAudio
@onready var bowling_audio : AudioStreamPlayer3D = $BowlingAudio
@onready var sparkle_audio_anim : AnimationPlayer = $SparkleAudio/AnimationPlayer
@onready var world : World = Global.get_world()
@onready var animator : AnimationTree = $AnimationTree
@onready var collider : CollisionShape3D = $collider
@onready var lifter_particles : GPUParticles3D = $LifterParticles
@onready var health_bar : ProgressBar = get_tree().current_scene.get_node("GameCanvas/HealthBar")
@onready var health_bar_text : Label = get_tree().current_scene.get_node("GameCanvas/HealthBar/Label")
@onready var respawn_overlay : AnimationPlayer = get_tree().current_scene.get_node("GameCanvas/RespawnOverlay/AnimationPlayer")
@onready var jump_particles : PackedScene = preload("res://data/scene/character/JumpParticles.tscn")
@onready var run_particles : PackedScene = preload("res://data/scene/character/RunParticles.tscn")
@onready var debug_menu : Control = get_tree().current_scene.get_node("DebugCanvas/DebugMenu")
@onready var influence_piv : Node3D = $InfluencePivot
@onready var influence_pos : Node3D = $InfluencePivot/InfluencePosition
@onready var chat_label : Label = $Smoothing/SubViewport/CanvasLayer/VBoxContainer/PanelContainer/ChatLabel
@onready var chat_panel : PanelContainer = $Smoothing/SubViewport/CanvasLayer/VBoxContainer/PanelContainer
@onready var name_label : Label = $Smoothing/SubViewport/CanvasLayer/VBoxContainer/NameLabel

@export var spawn_as_dummy : bool = false

func on_ice() -> bool:
	if standing_on_object is Brick:
		if standing_on_object._material == Brick.BrickMaterial.ICE:
			return true
	return false

var teleport_requested : bool = false
var teleport_pos : Vector3 = Vector3.ZERO
@rpc("any_peer", "call_local", "reliable")
func teleport(new_pos : Vector3) -> void:
	# if this change state request is not from the server or run locally, return
	if multiplayer.get_remote_sender_id() != 1 && multiplayer.get_remote_sender_id() != 0:
		return
	teleport_requested = true
	teleport_pos = new_pos

# Lights this player on fire.
@rpc("any_peer", "call_local", "reliable")
func light_fire(from_who_id : int = -1, initial_damage : int = 1) -> void:
	if !on_fire && _state != SWIMMING && _state != SWIMMING_IDLE && !invulnerable:
		on_fire = true
		# visual fire
		fire.light()
		if multiplayer.is_server():
			# take initial damage
			reduce_health(initial_damage, CauseOfDeath.FIRE, from_who_id)
			# 2 damage / s
			var fire_timer := Timer.new()
			fire_timer.wait_time = 0.5
			fire_timer.one_shot = false
			fire_timer.connect("timeout", reduce_health.bind(1, CauseOfDeath.FIRE, from_who_id))
			fire_timer.name = "FireTimer"
			add_child(fire_timer)
			fire_timer.start()
			# extinguish after time
			await get_tree().create_timer(4).timeout
			extinguish_fire.rpc()

# Extinguishes the fire on this player, and deletes the fire timer.
@rpc("any_peer", "call_local", "reliable")
func extinguish_fire() -> void:
	if on_fire:
		on_fire = false
		if multiplayer.is_server():
			if has_node("FireTimer"):
				if $FireTimer.is_connected("timeout", reduce_health):
					$FireTimer.disconnect("timeout", reduce_health)
				$FireTimer.stop()
				$FireTimer.queue_free()
	fire.extinguish()

func _set_can_enter_seat(mode : bool) -> void:
	can_enter_seat = mode

func change_appearance() -> void:
	update_appearance.rpc(Global.shirt, Global.shirt_texture, Global.hair, Global.shirt_colour, Global.pants_colour, Global.hair_colour, Global.skin_colour)

@rpc ("call_local")
func update_appearance(shirt : int, shirt_texture_base64 : String, hair : int, shirt_colour : Color, pants_colour : Color, hair_colour : Color, skin_colour : Color) -> void:
	var armature : Skeleton3D = get_node("Smoothing/character_model/character/Skeleton3D")
	var hair_material : Material = armature.get_node("hair_short/hair_short").get_surface_override_material(0)
	var shirt_material : Material = armature.get_node("shirt_shortsleeve").get_surface_override_material(0)
	var pants_material : Material = armature.get_node("pants").get_surface_override_material(0)
	var skin_material : Material = armature.get_node("Character_001").get_surface_override_material(0)
	
	if shirt_colour != null:
		shirt_material.albedo_color = shirt_colour
	if pants_colour != null:
		pants_material.albedo_color = pants_colour
		# update chat bubble colour as well, 
		# keep chat panel value below 70 for contrast
		chat_panel.self_modulate = pants_colour
		chat_panel.self_modulate.v = clampf(chat_panel.self_modulate.v, 0, 0.27)
		chat_panel.self_modulate.a = 0.85
	if hair_colour != null:
		hair_material.albedo_color = hair_colour
	if skin_colour != null:
		skin_material.albedo_color = skin_colour
	if shirt != null:
		match shirt:
			0:
				armature.get_node("shirt_jacket").visible = false
				armature.get_node("shirt_shortsleeve").visible = true
			1:
				armature.get_node("shirt_jacket").visible = true
				armature.get_node("shirt_shortsleeve").visible = false
	if shirt_texture_base64 != null && shirt_texture_base64 != "":
		# set shirt to base64 image
		var image : Image = Image.new()
		image.load_jpg_from_buffer(Marshalls.base64_to_raw(shirt_texture_base64))
		if image != null:
			if image is Image:
				shirt_material.albedo_texture = ImageTexture.new().create_from_image(image)
	if hair != null:
		var all_hairs : Array = []
		all_hairs.append(armature.get_node("hair_short"))
		all_hairs.append(armature.get_node("hair_ponytail"))
		all_hairs.append(armature.get_node("hair_baseballcap"))
		for h : Node in all_hairs:
			h.visible = false
		match hair:
			# short
			0:
				all_hairs[0].visible = true
			# ponytail
			1:
				all_hairs[1].visible = true
			# baseball cap
			3:
				all_hairs[2].visible = true

# Returns this player's tool inventory.
func get_tool_inventory() -> ToolInventory:
	return $Tools

@rpc("any_peer", "call_local", "reliable")
func _server_receive_on_body_entered_from_client(path_to_body : String) -> void:
	# only run on server, and make sure this request is from owner client
	if !multiplayer.is_server() || multiplayer.get_remote_sender_id() != get_multiplayer_authority(): return
	
	var node : Node3D = get_node_or_null(path_to_body)
	if node != null:
		_on_body_entered(node)

# When this player hits something too hard, trip them.
func _on_body_entered(body : Node3D) -> void:
	# run on host client
	# TODO: Move this to button
	if is_multiplayer_authority():
		# stepped on button
		if body is ButtonBrick:
			body.stepped.rpc(get_path())
	
	# stuff handled by the server
	if multiplayer.is_server():
		# trip when hit by something fast, unless we're standing on it
		if (body is RigidBody3D) && !(body is RigidPlayer):
			if (body.linear_velocity.length() + body.angular_velocity.length()) > 4:
				if _state != STANDING_UP && _state != IN_SEAT:
					if standing_on_object != null:
						if body == standing_on_object:
							return
					# take damage from fast bricks hitting player
					# unless they are part of the group the player is standing on
					if body is Brick:
						if standing_on_object != null:
							if standing_on_object is Brick:
								if body.group == standing_on_object.group:
									return
						reduce_health(body.mass_mult as int, CauseOfDeath.HIT_BY_BRICK)
					change_state.rpc_id(get_multiplayer_authority(), TRIPPED)
			if body is Brick:
				if body.on_fire:
					light_fire.rpc()
		# trip other players
		elif _state == ROLL:
			if body is RigidPlayer:
				body.trip_by_player.rpc_id(body.get_multiplayer_authority(), global_transform.basis.z * 15)
				body.set_last_hit_by_id.rpc(self.get_multiplayer_authority())
	else:
		_server_receive_on_body_entered_from_client.rpc_id(1, body.get_path())

# Set this player's authority to its client.
func _enter_tree() -> void:
	set_multiplayer_authority(str(name).to_int(), true)

func _is_friendly_fire(other_player : RigidPlayer) -> bool:
	# default team can't have friendly fire
	if team != "Default":
		var executing_team : Team = Global.get_world().get_current_map().get_teams().get_team(other_player.team)
		var my_team : Team = Global.get_world().get_current_map().get_teams().get_team(team)
		if my_team == executing_team:
			return true
	return false

var time_last_reduced_health : int = 0
func reduce_health(amount : int, potential_cause_of_death : int = -1, potential_executor_id : int = -1, override_invincibility_period : bool = false) -> void:
	# server handles all player health
	if !multiplayer.is_server(): return
	# invincibility period
	if (Time.get_ticks_msec() - time_last_reduced_health > 499) || override_invincibility_period:
		# from server: update display for client and all players
		set_health(get_health() - amount, potential_cause_of_death, potential_executor_id)
		time_last_reduced_health = Time.get_ticks_msec()

@rpc("any_peer", "call_local", "reliable")
func _receive_server_health(new : int, potential_executor_id : int = -1) -> void:
	if is_multiplayer_authority():
		# flash health on damage
		if new < health:
			health_bar.get_node("AnimationPlayer").play("flash_health")
		
		health = new
		if potential_executor_id != -1:
			# set executing player (for camera lockon)
			executing_player = Global.get_world().get_node_or_null(str(potential_executor_id))
		else:
			executing_player = null
		
		# set visual health
		health_bar.value = get_health()
		health_bar_text.text = str(JsonHandler.find_entry_in_file("ui/health"), ": ", get_health())
		# low health colour
		if health_bar.value < 5:
			health_bar.self_modulate = Color("#ff4848")
		else:
			health_bar.self_modulate = Color("#61a48f")
	else:
		health = new

@rpc("any_peer", "call_local", "reliable")
func _receive_server_max_health(new : int) -> void:
	if is_multiplayer_authority():
		max_health = new
		# set visual health
		health_bar.max_value = max_health
	else:
		max_health = new

func set_max_health(new : int) -> void:
	# only runs as server
	if !multiplayer.is_server():
		return
	# send updated health to clients
	_receive_server_max_health.rpc(new)
	
	max_health = new
	if health > max_health:
		set_health(max_health)

# ONLY RUNS AS SERVER
func set_health(new : int, potential_cause_of_death : int = -1, potential_executor_id : int = -1) -> void:
	if !multiplayer.is_server():
		return
	
	if !invulnerable && !dead:
		# send updated health to clients
		_receive_server_health.rpc(new, potential_executor_id)
		# server will keep track of this
		health = new
		
		if health <= 0:
			# shorter respawn in sandbox
			respawn_time.wait_time = Global.get_world().get_current_map().respawn_time
			# death feed handler
			if potential_cause_of_death != -1:
				# determine if there is an executing player
				executing_player = null
				var executing_player_name : String = ""
				if potential_executor_id != -1:
					executing_player = Global.get_world().get_node_or_null(str(potential_executor_id))
					if executing_player != null:
						executing_player_name = executing_player.display_name
				# determine cause of death
				match potential_cause_of_death:
					CauseOfDeath.EXPLOSION:
						if executing_player != null:
							if potential_executor_id == get_multiplayer_authority():
								death_message = str(display_name, " blew themselves up!")
							elif executing_player_name != null:
								# If friendly fire is OFF, don't increment the executor's kills, show special message
								if _is_friendly_fire(executing_player as RigidPlayer):
									death_message = str(executing_player_name, " blew up their teammate ", display_name, "! Good going!")
								# If friendly fire is ON
								else:
									# run increment kills command on server side
									executing_player.update_kills(executing_player.kills + 1)
									# play kill sound for executor
									Global.play_kill_sound.rpc_id(potential_executor_id)
									match randi() % 4:
										0:
											death_message = str(executing_player_name, " exploded ", display_name, "!")
										1:
											death_message = str(executing_player_name, " deconstructed ", display_name, " on an atomic level!")
										2:
											death_message = str(executing_player_name, " blew ", display_name, " to smithereens!")
										3:
											death_message = str(executing_player_name, " randomized the molecular structure of ", display_name, "!")
						else:
							death_message = str(display_name, " blew up!")
					CauseOfDeath.FLAMETHROWER_EXPLOSION:
						if executing_player != null:
							if potential_executor_id == get_multiplayer_authority():
								death_message = str(display_name, " was involved in a flamethrower accident!")
							elif executing_player_name != null:
								# If friendly fire is OFF, don't increment the executor's kills, show special message
								if _is_friendly_fire(executing_player as RigidPlayer):
									death_message = str(executing_player_name, " blew up their teammate ", display_name, "! Good job!")
								# If friendly fire is ON
								else:
									# run increment kills command on the authority of the executing player
									executing_player.update_kills(executing_player.kills + 1)
									# play kill sound for executor
									Global.play_kill_sound.rpc_id(potential_executor_id)
									match randi() % 2:
										0:
											death_message = str(executing_player_name, " taught ", display_name, " the importance of flamethrower safety!")
										1:
											death_message = str(executing_player_name, " showed ", display_name, " that fuel tanks are explosive!")
						else:
							death_message = str(display_name, " got really, really unlucky!")
					CauseOfDeath.MELEE:
						if executing_player != null:
							if executing_player_name != null:
								# If friendly fire is OFF, don't increment the executor's kills, show special message
								if _is_friendly_fire(executing_player as RigidPlayer):
									death_message = str(executing_player_name, " pulverized their teammate ", display_name, "! Great work!")
								# If friendly fire is ON
								else:
									# run increment kills command on the authority of the executing player
									executing_player.update_kills(executing_player.kills + 1)
									# play kill sound for executor
									Global.play_kill_sound.rpc_id(potential_executor_id)
									match randi() % 3:
										0:
											death_message = str(executing_player_name, " batted out ", display_name, "!")
										1:
											death_message = str(executing_player_name, " hit ", display_name, " one too many times!")
										2:
											death_message = str(executing_player_name, " hit a home run on ", display_name, "!")
						else:
							death_message = str(display_name, " was struck by a bat!")
					CauseOfDeath.HIT_BY_BALL:
						if executing_player != null:
							if potential_executor_id == get_multiplayer_authority():
								death_message = str(display_name, " hit themselves with a ball!")
							elif executing_player_name != null:
								# If friendly fire is OFF, don't increment the executor's kills, show special message
								if _is_friendly_fire(executing_player as RigidPlayer):
									death_message = str(executing_player_name, " hit their teammate ", display_name, " too hard with a ball! Great work!")
								# If friendly fire is ON
								else:
									# run increment kills command on the authority of the executing player
									executing_player.update_kills(executing_player.kills + 1)
									# play kill sound for executor
									Global.play_kill_sound.rpc_id(potential_executor_id)
									match randi() % 3:
										0:
											death_message = str(executing_player_name, " threw ", display_name, " a curveball!")
										1:
											death_message = str(executing_player_name, " practiced their aim on ", display_name, "!")
										2:
											death_message = str(executing_player_name, " played fetch with ", display_name, "!")
						else:
							death_message = str(display_name, " was struck by a ball!")
					CauseOfDeath.OUT_OF_MAP:
						# if we were last hit by someone's projectile
						if last_hit && last_hit_by_id != -1:
							var last_hit_executing_player : RigidPlayer = Global.get_world().get_node_or_null(str(last_hit_by_id))
							var last_hit_executing_player_name : String = ""
							if last_hit_executing_player != null:
								last_hit_executing_player_name = last_hit_executing_player.display_name
							# self, or if player who hit self has left
							if last_hit_by_id == get_multiplayer_authority() || last_hit_executing_player == null:
								death_message = str(display_name, " hit themselves away!")
							# don't increment kills for friendly fire
							elif _is_friendly_fire(last_hit_executing_player):
								death_message = str(last_hit_executing_player_name, " knocked their teammate ", display_name, " off the map!")
							# If friendly fire is ON
							else:
								last_hit_executing_player.update_kills(last_hit_executing_player.kills + 1)
								# play kill sound for last hit executor
								Global.play_kill_sound.rpc_id(last_hit_by_id)
								match randi() % 2:
									0:
										death_message = str(last_hit_executing_player_name, " sent ", display_name, " into the stratosphere!")
									1:
										death_message = str(last_hit_executing_player_name, " knocked ", display_name, " off the map!")
						else:
							if external_propulsion:
								match randi() % 3:
									0:
										death_message = str(display_name, " is really bad at flying!")
									1:
										death_message = str(display_name, " needs flying lessons!")
									2:
										death_message = str(display_name, " cannot control a fire extinguisher!")
							else:
								match randi() % 2:
									0:
										death_message = str(display_name, " flew away!")
									1:
										death_message = str(display_name, " was sent into orbit!")
					CauseOfDeath.HIT_BY_BRICK:
						match randi() % 2:
							0:
								death_message = str(display_name, " was flattened!")
							1:
								death_message = str(display_name, " got squashed!")
					CauseOfDeath.FIRE:
						# on fire from explosion or flamethrower
						if executing_player != null:
							if potential_executor_id == get_multiplayer_authority():
								death_message = str(display_name, " played with fire!")
							elif executing_player_name != null:
								# If friendly fire is OFF, don't increment the executor's kills, show special message
								if _is_friendly_fire(executing_player as RigidPlayer):
									death_message = str(executing_player_name, " turned their teammate ", display_name, " into a pile of ash!")
								# If friendly fire is ON
								else:
									# run increment kills command on the authority of the executing player
									executing_player.update_kills(executing_player.kills + 1)
									# play kill sound for executor
									Global.play_kill_sound.rpc_id(potential_executor_id)
									match randi() % 3:
										0:
											death_message = str(executing_player_name, " burned ", display_name, " to a crisp!")
										1:
											death_message = str(executing_player_name, " cooked ", display_name, " on high at 200C!")
										2:
											death_message = str(executing_player_name, " just grilled some fresh ", display_name, "!")
						# on fire from environment
						else:
							match randi() % 3:
								0:
									death_message = str(display_name, " burned up!")
								1:
									death_message = str(display_name, " went up in flames!")
								2:
									death_message = str(display_name, " is feeling toasty!")
					CauseOfDeath.SWAMP_WATER:
						match randi() % 2:
							0:
								death_message = str(display_name, " swam in some unhealthy water!")
							1:
								death_message = str(display_name, " inhaled some tasty swamp water!")
			#default death feeds
			else:
				match randi() % 3:
					0:
						death_message = str(display_name, " died!")
					1:
						death_message = str(display_name, " has met their demise!")
					2:
						death_message = str(display_name, " will be back in 10 seconds!")
			# set server deaths
			if !dead:
				update_deaths(deaths + 1)
			# set server dead flag
			dead = true
			emit_signal("died")
			# display death feed to server
			UIHandler.show_alert.rpc(death_message, 5, false, UIHandler.alert_colour_death)
			# now we set the death message, change the state
			change_state.rpc_id(get_multiplayer_authority(), DEAD)
			# start timer, connected to respawn
			respawn_time.start()
			var cur_respawn := respawn_time.wait_time
			for second in respawn_time.wait_time:
				# in case we instantly changed states
				UIHandler.show_alert.rpc_id(get_multiplayer_authority(), str("Respawn in ", int(cur_respawn), "..."), 1, false, Color("#c67171"))
				cur_respawn -= 1
				await get_tree().create_timer(1).timeout
			# if we are still dead after timer, don't intercept states:
			change_state.rpc_id(get_multiplayer_authority(), RESPAWN)
			dead = false
			extinguish_fire.rpc()
			set_health(max_health)
			protect_spawn()

func get_health() -> int:
	return health

@rpc("any_peer", "call_local", "reliable")
func set_last_hit_by_id(who : int) -> void:
	if multiplayer.get_remote_sender_id() != 1 && multiplayer.get_remote_sender_id() != 0 && multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	last_hit_by_id = who
	if last_hit_by_id == -1:
		last_hit = false
	else: last_hit = true

# Update this player's team with a new team.
@rpc("any_peer", "call_local", "reliable")
func update_team(new : String) -> void:
	var team_list : Array = world.get_current_map().get_teams().get_team_list()
	for t : Team in team_list:
		if t.members.has(str(name)):
			t.members.erase(str(name))
	# Make this the team resource
	team = new
	var world_team : Team = world.get_current_map().get_teams().get_team(new)
	if world_team != null:
		world_team.members.append(str(name))
	# Make nametag colour team's colour
	# default colour name should be white, but the team's colour is technically grey
	if new == "Default":
		name_label.modulate = Color("#fff")
	else:
		name_label.modulate = world.get_current_map().get_teams().get_team(new).colour
	Global.update_player_list_information()
	set_spawns(world.get_spawnpoint_for_team(team))

# Update this player's name with a new name.
@rpc("call_local")
func update_name(new : String) -> void:
	name_label.text = new
	display_name = new
	
	# Add the player to the player list.
	var player_list : Control = get_tree().current_scene.get_node("GameCanvas/PlayerList")
	player_list.add_player(self)

@rpc("any_peer", "call_local", "reliable")
func set_name_visible(mode : bool) -> void:
	if multiplayer.get_remote_sender_id() != 1 && multiplayer.get_remote_sender_id() != get_multiplayer_authority() && multiplayer.get_remote_sender_id() != 0:
		return
	# only visible for others
	if multiplayer.get_unique_id() != get_multiplayer_authority():
		name_label.visible = mode
	else:
		name_label.visible = false

# Update peers with new name and team info on join.
@rpc("call_local", "reliable")
func update_info(_who : int, to_connected_peer : bool = false) -> void:
	# If updating info to all other peers
	if !to_connected_peer:
		update_team.rpc(team)
		update_name.rpc(Global.display_name)
	# If updating info to only a specific (usually joined) peer
	else:
		update_team.rpc_id(_who, team)
		update_name.rpc_id(_who, Global.display_name)
	change_appearance()
	# server handles kills and deaths
	if multiplayer.is_server():
		update_kills(kills)
		update_deaths(deaths)

func set_camera(new : Camera3D) -> void:
	camera = new
	if !camera.is_connected("camera_mode_changed", _on_camera_mode_changed):
		camera.connect("camera_mode_changed", _on_camera_mode_changed)
	if camera is Camera:
		camera.set_camera_mode(Camera.CameraMode.FREE)
		camera.set_target(target, false)

func _ready() -> void:
	# used for main menu preview
	if spawn_as_dummy:
		change_state(DUMMY)
		invulnerable = true
		freeze = true
		# update appearance
		change_appearance()
		name_label.visible = false
	# execute for everyone
	else:
		Global.get_world().add_player_to_list(self)
		gravity_scale = player_grav
		if multiplayer.is_server():
			protect_spawn(3.5, false)
			# update spawns when world is loaded as server
			Global.get_world().connect("tbw_loaded", _on_tbw_loaded)
			# keep clients in stasis until they are connected
			global_position = Vector3(0, world.get_current_map().death_limit_high - 5, 0)
			freeze = true
		# only execute on yourself
		if !is_multiplayer_authority():
			#freeze = true
			return
		get_tool_inventory().reset()
		set_camera(get_viewport().get_camera_3d())
		connect("body_entered", _on_body_entered)
		multiplayer.connected_to_server.connect(update_info)
		# when someone connects, broadcast our player info to only them
		multiplayer.peer_connected.connect(update_info.bind(true))
		# update peers with name and team
		update_info(get_multiplayer_authority())
		# update peers with appearance
		change_appearance()
		# set default spawns
		set_spawns(world.get_spawnpoint_for_team(team))
		go_to_spawn()
		# hide your own name label
		name_label.visible = false
		# in case we were not present on client when server sent
		# protect spawn call
		_receive_server_protect_spawn(3.5, false)
		
		# hide loading screen (set in main on server join)
		Global.get_world().set_loading_canvas_visiblity(false)

func _on_tbw_loaded() -> void:
	# set default spawns
	respawn_time.wait_time = Global.get_world().get_current_map().respawn_time
	set_spawns.rpc_id(get_multiplayer_authority(), world.get_spawnpoint_for_team(team))
	if !(Global.get_world().get_current_map() is Editor):
		go_to_spawn.rpc_id(get_multiplayer_authority())

@rpc("any_peer", "call_local")
func set_lifter_particles(mode : bool) -> void:
	lifter_particles.emitting = mode

func _physics_process(delta : float) -> void:
	# spawned dummies check idle (for menu animation)
	if spawn_as_dummy:
		check_idle()
	
	if !is_multiplayer_authority(): return
	# Idle animations
	# reset idle time when clicking, ex. using tools
	if Input.is_action_pressed("click"):
		idle_time = 0
	# (Also do dummy for main menu preview)
	if _state == IDLE:
		check_idle()
	# If in the air from a lifter, show indication
	if in_air_from_lifter && !lifter_particles.emitting:
		set_lifter_particles.rpc(true)
	elif lifter_particles.emitting:
		set_lifter_particles.rpc(false)
	# Set animation blend
	animator["parameters/BlendRun/blend_amount"] = clamp(linear_velocity.length() / move_speed, 0, 1)
	# Set looking direction
	var hor_linear_velocity := Vector3(linear_velocity.x, 0, linear_velocity.z)
	if _state != TRIPPED and _state != DEAD and _state != STANDING_UP and _state != ON_LEDGE:
		# if the active camera has the custom Camera script
		if camera is Camera:
			if camera.get_camera_mode() == Camera.CameraMode.FREE:
				if hor_linear_velocity.length () > 0.01:
					rotation.y = lerp_angle(rotation.y, atan2(linear_velocity.x, linear_velocity.z), delta * 12)
			elif camera.get_camera_mode() == Camera.CameraMode.AIM:
				rotation.y = camera.rotation.y + PI
	
	if _state == IN_SEAT:
		if seat_occupying is MotorSeat:
			# set player's position and rotation to that of the seat
			# we do this outside of the main integrate forces loop as
			# setting global position can only be done inside physics
			# process on a seperate thread
			global_position = seat_occupying.global_position
			global_rotation = seat_occupying.global_rotation
			translate_object_local(Vector3(0, -0.7, 0))
			rotate_object_local(Vector3.UP, deg_to_rad(180))
	
var idle_time : int = 0
var idle_max : int = 300
func check_idle() -> void:
	idle_time += 1
	if idle_time > idle_max:
		play_idle_animation.rpc()
		idle_time = 0
		if _state == IDLE:
			idle_max = randi_range(300, 800)
		else:
			# longer idle for dummy
			idle_max = randi_range(900, 1600)

@rpc("call_local")
func play_idle_animation() -> void:
	animator.set("parameters/IdleOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func play_jump_particles() -> void:
	var jump_particles_i : GPUParticles3D = jump_particles.instantiate()
	add_child(jump_particles_i)
	jump_particles_i.emitting = true

var air_duration : float = 0
var last_move_direction := Vector3.ZERO
var air_from_jump := false
var on_wall_cooldown : int = 0
var standing_on_object_last_pos : Vector3 = Vector3.ZERO
var init_velocity := Vector3.ZERO
# Manages movement
func _integrate_forces(state : PhysicsDirectBodyState3D) -> void:
	# handle movement
	if is_multiplayer_authority():
		# executes on owner only
		var is_on_ground := false
		if ground_detect.has_overlapping_bodies():
			is_on_ground = true
		
		if camera == null:
			camera = get_viewport().get_camera_3d()
		
		# only captured mouse gets move dir
		var move_direction := Vector3.ZERO
		if !Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			move_direction = get_movement_direction()
		
		var grounded_on_standing_object : bool = false
		# check if standing on something
		if ground_detect.has_overlapping_bodies() && _state != DEAD && _state != RESPAWN:
			# check every body standing on
			for body in ground_detect.get_overlapping_bodies():
				# if this is not what we are already standing on
				if standing_on_object != body:
					influence_piv.global_position = body.global_position
					influence_piv.global_rotation = body.global_rotation
					influence_pos.global_position = global_position
					standing_on_object_last_pos = influence_pos.global_position
					set_standing_on_object_rpc.rpc(body.get_path())
				else:
					grounded_on_standing_object = true
		elif _state != AIR && _state != DIVE && _state != HIGH_JUMP:
			if standing_on_object != null:
				set_standing_on_object_rpc.rpc("null")
		# move if standing on something
		if standing_on_object != null:
			influence_pos.global_position = standing_on_object_last_pos
			influence_piv.global_position = standing_on_object.global_position
			influence_piv.global_rotation = standing_on_object.global_rotation
			var standing_influence : float = 1
			if !grounded_on_standing_object:
				standing_influence -= (clampf(influence_pos.global_position.distance_to(global_position) - 3, 0, 10)*0.15)
				standing_influence = clampf(standing_influence, 0, 1)
			if !teleport_requested:
				global_position += (influence_pos.global_position - standing_on_object_last_pos) * standing_influence
			if grounded_on_standing_object:
				standing_on_object_last_pos = global_position
		
		match _state:
			IDLE:
				var adj_decel_multiplier := decel_multiplier
				if standing_on_object != null:
					if standing_on_object is RigidBody3D:
						var adj_vel : float = standing_on_object.linear_velocity.length()
						if adj_vel > 0.1:
							decel_multiplier = 0
				state.linear_velocity.x *= adj_decel_multiplier
				state.linear_velocity.z *= adj_decel_multiplier
				if is_on_ground and Input.is_action_pressed("jump") && !locked:
					air_from_jump = true
					# jump particles
					play_jump_particles()
					# high jump, but only if not holding jump
					if Input.is_action_just_pressed("jump") && !high_jump_time.is_stopped():
						apply_central_impulse(Vector3.UP * high_jump_force)
						change_state(HIGH_JUMP)
					else:
						apply_central_impulse(Vector3.UP * jump_force)
						change_state(AIR)
				elif move_direction.x or move_direction.z:
					if is_on_ground:
						change_state(RUN)
					else:
						change_state(AIR)
				elif !is_on_ground:
					change_state(AIR)
			RUN:
				if not move_direction.x and not move_direction.z:
					change_state(IDLE)
				elif !is_on_ground:
					change_state(AIR)
				elif is_on_ground and Input.is_action_pressed("jump") && !locked:
					air_from_jump = true
					# jump particles
					play_jump_particles()
					# high jump, but only if not holding jump
					if Input.is_action_just_pressed("jump") && !high_jump_time.is_stopped():
						apply_central_impulse(Vector3.UP * high_jump_force)
						change_state(HIGH_JUMP)
					else:
						apply_central_impulse(Vector3.UP * jump_force)
						change_state(AIR)
				elif is_on_ground and Input.is_action_just_pressed("shift") && !locked && linear_velocity.length() > 1.1:
					change_state(SLIDE_BACK)
				elif !locked:
					state.linear_velocity.x = move_direction.x * move_speed
					state.linear_velocity.z = move_direction.z * move_speed
					# Add particle effect if direction immediately changes
					# only on authority client
					# 140deg change
					if last_move_direction.angle_to(move_direction) > 2.443:
						var run_particles_i : GPUParticles3D = run_particles.instantiate()
						# so that rotation does not inherit character's rotation
						get_tree().current_scene.add_child(run_particles_i)
						run_particles_i.global_rotation.y = atan2(state.linear_velocity.x, state.linear_velocity.z)
						run_particles_i.global_position = Vector3(global_position.x, global_position.y + 0.2, global_position.z)
						run_particles_i.emitting = true
					last_move_direction = move_direction
				else:
					# change to idle when locked
					change_state(IDLE)
			AIR:
				# avoid setting velocity when being pushed by extinguisher
				if !external_propulsion:
					state.linear_velocity.x = move_direction.x * move_speed
					state.linear_velocity.z = move_direction.z * move_speed
				air_duration += 1
				if on_wall_cooldown > 0:
					on_wall_cooldown -= 1
				if is_on_ground && air_time.is_stopped() && ledge_time.is_stopped():
					# when landing from 1st jump, a second well-timed jump can do a high jump
					if air_from_jump == true:
						high_jump_time.start()
					change_state(IDLE)
				# when the player holds jump, do a longer jump
				# extra jump force / air duration to make a more parabolic jump
				if (Input.is_action_pressed("jump") && !locked && air_duration < 20 && air_duration > 0) || (air_from_jump && air_duration > 0 && air_duration < 5):
					apply_central_impulse(Vector3.UP * (extra_jump_force / (air_duration + 1 * 0.333)))
				# jump grace period
				if Input.is_action_just_pressed("jump") && !locked && air_duration < 5:
					apply_central_impulse(Vector3.UP * jump_force)
					# jump particles
					play_jump_particles()
				# dive if jump is pressed again mid-air and we have space to dive
				elif Input.is_action_just_pressed("jump") && !locked && air_duration > 8 && !forward_detect.has_overlapping_bodies():
					change_state(DIVE)
				# ledge detect
				if !slide_detect.has_overlapping_bodies() && wall_detect.has_overlapping_bodies() && !ledge_detect.has_overlapping_bodies() && on_wall_cooldown < 1 && forward_ray.is_colliding():
					change_state(ON_LEDGE)
			HIGH_JUMP:
				# avoid setting velocity when being pushed by extinguisher
				if !external_propulsion:
					state.linear_velocity.x = move_direction.x * move_speed
					state.linear_velocity.z = move_direction.z * move_speed
				air_duration += 1
				if is_on_ground && air_time.is_stopped() && ledge_time.is_stopped():
					change_state(IDLE)
				# ledge detect
				if !slide_detect.has_overlapping_bodies() && wall_detect.has_overlapping_bodies() && !ledge_detect.has_overlapping_bodies() && on_wall_cooldown < 1 && forward_ray.is_colliding():
					change_state(ON_LEDGE)
			DIVE:
				# high velocity into roll
				if Input.is_action_just_pressed("jump") && !locked && lateral_velocity.length() > 10:
					apply_central_impulse(Vector3.UP * 4)
					change_state(ROLL)
				if !slide_detect.has_overlapping_bodies() && wall_detect.has_overlapping_bodies() && !ledge_detect.has_overlapping_bodies() && on_wall_cooldown < 1 && forward_ray.is_colliding():
					change_state(ON_LEDGE)
				# if we just dived, and hit something
				for body in get_colliding_bodies():
					if !(body is MotorSeat):
						# on ground
						if slide_detect.has_overlapping_bodies():
							change_state(SLIDE)
			ON_LEDGE:
				# align with wall
				if forward_ray.is_colliding():
					var normal : Vector3 = -forward_ray.get_collision_normal()
					# angle to wall normal
					var diff := global_transform.basis.z.signed_angle_to(normal, Vector3.UP)
					# rotate smoothly
					if abs(diff) > 0.05:
						rotate_y(diff * 0.2)
				# align with ledge
				var top := ledge_ray.get_collision_point()
				var offset := 1.45
				var diff := (global_position.y + offset) - top.y
				if abs(diff) > 0.01:
					linear_velocity = Vector3(0, -diff * 5, 0)
				linear_velocity = linear_velocity.clamp(Vector3(0, -5, 0), Vector3(0, 5, 0))
				# if no longer on ledge
				if (!forward_detect.has_overlapping_bodies() || ledge_detect.has_overlapping_bodies() || is_on_ground) && air_time.is_stopped():
					change_state(IDLE)
				# jump / move off wall
				if Input.is_action_just_pressed("jump") && !locked:
					air_from_jump = true
					on_wall_cooldown = 20
					apply_central_impulse(Vector3.UP * 4)
					change_state(AIR)
					# also start ledge time to avoid 'double jump' from jumping on
					# surface we just went up to
					ledge_time.start()
				elif !(Input.is_action_pressed("forward") || Input.is_action_pressed("left") || Input.is_action_pressed("right")) && on_wall_cooldown < 1 && !locked:
					on_wall_cooldown = 20
					rotate_object_local(Vector3.UP, deg_to_rad(180))
					change_state(AIR)
			SLIDE:
				if is_on_ground:
					if Time.get_ticks_msec() % 8 == 0:
						play_jump_particles()
					# jump if pressed or going too slow
					if (Input.is_action_pressed("jump") && !locked && slide_time.time_left < 0.5) || linear_velocity.length() < 1:
						air_from_jump = true
						apply_central_impulse(Vector3.UP * jump_force)
						change_state(AIR)
				# somewhat controllable when sliding
				var dir : Vector3 = -camera.get_global_transform().basis.z
				dir.y = 0
				dir = dir.normalized()
				apply_force(dir * 3, Vector3.ZERO)
				# align to ground normal
				if state.get_contact_count() > 0:
					var ground_normal := state.get_contact_local_normal(0)
					align_character_model_normal(ground_normal)
			SLIDE_BACK:
				if is_on_ground:
					if Time.get_ticks_msec() % 8 == 0:
						play_jump_particles()
					# jump if pressed or going too slow
					if Input.is_action_pressed("jump") && !locked:
						#apply_central_impulse(Vector3.UP * jump_force)
						change_state(ROLL)
					if linear_velocity.length() < 2:
						air_from_jump = true
						apply_central_impulse(Vector3.UP * jump_force)
						change_state(AIR)
				# somewhat controllable when sliding
				var dir : Vector3 = -camera.get_global_transform().basis.z
				dir.y = 0
				dir = dir.normalized()
				apply_force(dir * 3, Vector3.ZERO)
				# align to ground normal
				if state.get_contact_count() > 0:
					var ground_normal := state.get_contact_local_normal(0)
					align_character_model_normal(ground_normal)
			ROLL:
				if is_on_ground:
					if int(roll_time.time_left * 10) % 2 == 0:
						play_jump_particles()
					if (Input.is_action_pressed("jump") && !locked && roll_time.time_left < 0.5) || roll_time.is_stopped():
						change_state(SLIDE)
				# if going too slow
				if linear_velocity.length() < 1:
					air_from_jump = true
					apply_central_impulse(Vector3.UP * jump_force)
					change_state(AIR)
				var dir : Vector3 = -camera.get_global_transform().basis.z
				dir.y = 0
				dir = dir.normalized()
				# cap velocity
				var max_speed : float = 15
				# basis of camera minus vertical component
				var cam_horiz_basis : Vector3 = camera.get_global_transform().basis.z
				cam_horiz_basis.y = 0
				# basis of player minus vertical component
				var horiz_basis : Vector3 = get_global_transform().basis.z
				horiz_basis.y = 0
				var cam_align : float = cam_horiz_basis.angle_to(horiz_basis)
				var mult : float = (1/(cam_align/3.14159))
				# limit speed unless we are facing a different direction for turning
				if state.linear_velocity.length() < max_speed * mult:
					apply_force(dir * 25, Vector3.ZERO)
			TRIPPED:	
				pass
			IN_SEAT:
				if seat_occupying is MotorSeat && !locked:
					var dir_forward : float = Input.get_action_strength("forward") - Input.get_action_strength("back")
					var dir_steer : float = Input.get_action_strength("right") - Input.get_action_strength("left")
					seat_occupying.drive.rpc(dir_forward, dir_steer)
					state.linear_velocity = Vector3.ZERO
				if Input.is_action_just_pressed("exit_vehicle") && !locked:
					change_state(EXIT_SEAT)
			STANDING_UP:
				pass
			DEAD:
				# align to ground normal
				if state.get_contact_count() > 0:
					var ground_normal := state.get_contact_local_normal(0)
					align_character_model_normal(ground_normal)
			SWIMMING, SWIMMING_IDLE:
				if swim_dash_cooldown > 0:
					swim_dash_cooldown -= 1
				var force_forward : float = Input.get_action_strength("back") - Input.get_action_strength("forward")
				var force_sideways : float = Input.get_action_strength("right") - Input.get_action_strength("left")
				var dir : Vector3 = camera.get_global_transform().basis.z * (move_speed * 0.8 * force_forward)
				dir += camera.get_global_transform().basis.x * (move_speed * 0.8 * force_sideways)
				apply_force(dir, Vector3.ZERO)
				if dir.length() >= 1 && _state != SWIMMING:
					change_state(SWIMMING)
				elif dir.length() < 1 && _state != SWIMMING_IDLE:
					change_state(SWIMMING_IDLE)
				if Input.is_action_just_pressed("shift") && swim_dash_cooldown < 1:
					change_state(SWIMMING_DASH)
				# rotate model in direction of swimming
				# arctan between y vel and total horizontal vel
				character_model.rotation.x = lerp_angle(character_model.rotation.x, atan2(linear_velocity.y, Vector2(linear_velocity.z, linear_velocity.x).length()) - 0.26, 0.15)
			SWIMMING_DASH:
				swim_dash_cooldown = 110
				character_model.rotation.x = lerp_angle(character_model.rotation.x, atan2(linear_velocity.y, Vector2(linear_velocity.z, linear_velocity.x).length()) - 0.56, 0.15)
				pass
		lateral_velocity = Vector3(linear_velocity.x, 0, linear_velocity.z)
	
	# handle teleport requests
	if teleport_requested:
		set_standing_on_object_rpc.rpc("null")
		var t := state.transform
		t.origin = teleport_pos
		state.set_transform(t)
		await get_tree().physics_frame
		teleport_requested = false
		freeze = false
		emit_signal("teleported")
	
	# handle out of map ( runs outside auth check )
	if multiplayer.is_server():
		if !invulnerable:
			if global_position.y < Global.get_world().get_current_map().death_limit_low || global_position.y > Global.get_world().get_current_map().death_limit_high:
				set_health(0, CauseOfDeath.OUT_OF_MAP)

@rpc("any_peer", "call_local", "reliable")
func set_standing_on_object_rpc(what_path : String) -> void:
	# if this change state request is not from the server or the owner client, return
	if multiplayer.get_remote_sender_id() != 1 && multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	
	if what_path == "null":
		standing_on_object = null
	else:
		standing_on_object = get_node(what_path)
		decel_multiplier = normal_decel_multiplier
		if on_ice():
			# more slippy on ice
			decel_multiplier = ice_decel_multiplier

# When the player enters a seat
@rpc("any_peer", "call_local")
func entered_seat(path_to_seat : String) -> void:
	# Don't enter the seat in special states
	if can_enter_seat and (_state == IDLE || _state == AIR || _state == RUN || _state == DIVE || _state == SLIDE || _state == SLIDE_BACK || _state == SWIMMING || _state == SWIMMING_IDLE):
		change_state(IN_SEAT)
		seat_occupying = get_node(path_to_seat)
		# DEBUG
		if debug_menu.visible:
			var wheel_list_formatted : String = ""
			for wheel : Node in seat_occupying.attached_motors:
				wheel_list_formatted += str(wheel.name, "\n")
			UIHandler.show_toast(str("Vehicle information:\nVehicle weight:", seat_occupying.vehicle_weight, "\nVehicle wheels:", wheel_list_formatted), 20)
		UIHandler.show_alert("Press [ Jump ] to stop driving!", 6)
	# don't enter seat if in special state, tell seat that we could not enter
	else:
		var failed_seat : Node3D = get_node(path_to_seat)
		if failed_seat is MotorSeat:
				failed_seat.set_controlling_player.rpc(-1)

# When the seat the player in gets destroyed (called from seat)
@rpc("any_peer", "call_local")
func seat_destroyed(offset := false) -> void:
	seat_occupying = null
	if offset:
		global_position.y += 2
	change_state(TRIPPED)
	apply_central_impulse(Vector3.UP * jump_force)

@rpc("any_peer", "call_local")
func trip_by_player(hit_velocity : Vector3) -> void:
	# if this change state request is not from the server or run locally, return
	if multiplayer.get_remote_sender_id() != 1 && multiplayer.get_remote_sender_id() != 0:
		return
	# only execute on yourself
	if !is_multiplayer_authority(): return
	change_state(TRIPPED)
	play_bowling_audio.rpc()
	await get_tree().physics_frame
	linear_velocity = hit_velocity

@rpc("any_peer", "call_local", "reliable")
func change_state(state : int) -> void:
	# if this change state request is not from the server or run locally, return
	if multiplayer.get_remote_sender_id() != 1 && multiplayer.get_remote_sender_id() != 0:
		return
	# only execute on client from here on
	if !is_multiplayer_authority(): return
	# reset idle timer
	idle_time = 0
	
	# if we are dead, only allow change state to respawn (or dummy)
	# when respawning, only change state to idle
	# can't be tripped when swimming
	if (_state == DEAD && state != RESPAWN && state != DUMMY) || (_state == RESPAWN && state != IDLE) || ((_state == SWIMMING || _state == SWIMMING_IDLE) && state == TRIPPED):
		return
	
	# trip invincibility timer
	if (Time.get_ticks_msec() - time_last_tripped) < 1000 && state == TRIPPED:
		return
	
	# dummies can only change to idle default state
	if (_state == DUMMY) && (state != IDLE):
		return
	
	# convert tripped state to idle state when invulnerable
	if (state == TRIPPED && invulnerable == true):
		state = IDLE
	
	if _state != TRIPPED || (_state == TRIPPED && (state == SWIMMING || state == SWIMMING_IDLE)):
		lock_rotation = true
		# disable dizzy stars visual effect
		$Smoothing/dizzy_stars.visible = false
		$Smoothing/dizzy_stars/AnimationPlayer.stop()
		rotation = Vector3(0, rotation.y, 0)
	
	# reset external propulsion (unless going from slide into jump while extinguishing, to avoid 'hiccup')
	external_propulsion = false
	if (_state == SLIDE && state == AIR):
		if get_tool_inventory().get_active_tool() is ShootTool:
			var st : ShootTool = get_tool_inventory().get_active_tool()
			if st._shoot_type == ShootTool.ShootType.WATER && st.firing:
				external_propulsion = true
	
	# set to new state
	if _state != state:
		_state = state
		enter_state()

# Runs once on new state
func enter_state() -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	
	# DEBUG
	if debug_menu.visible:
		UIHandler.show_toast(str(states_as_names[_state], ": AD ", air_duration, ": AFJ", air_from_jump), 3)
	
	# reset blend states
	animator["parameters/BlendSit/blend_amount"] = 0
	
	if _state != DUMMY:
		animator["parameters/BlendOutroPose/blend_amount"] = 0
		freeze = false
	
	animator.set("parameters/IdleOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	
	if _state != AIR:
		air_from_jump = false
		if _state != DIVE && _state != EXIT_SEAT:
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendJump/blend_amount", 0.0, 0.1)
			tween.tween_property(animator, "parameters/BlendDive/blend_amount", 0.0, 0.3)
	
	# reset collider height
	if _state != SLIDE && _state != SLIDE_BACK && _state != ROLL:
		set_collider_short(false)
	else:
		set_collider_short(true)
	
	if _state != AIR && _state != HIGH_JUMP:
		air_duration = 0
	
	if _state != HIGH_JUMP:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendHighJump/blend_amount", 0.0, 0.1)
	
	if _state != SLIDE:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendSlide/blend_amount", 0.0, 0.2)
		
	if _state != SLIDE_BACK:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendSlideBack/blend_amount", 0.0, 0.2)
	
	if _state != ROLL:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendRoll/blend_amount", 0.0, 0.2)
	
	if _state != ON_LEDGE:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendOnLedge/blend_amount", 0.0, 0.2)
	
	if _state != DEAD:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendDead/blend_amount", 0.0, 0.3)
	
	# lifter handling
	if _state != AIR && _state != DIVE && _state != HIGH_JUMP:
		in_air_from_lifter = false
		sparkle_audio_anim.play("fadeout")
	
	# only reset last_hit_by when the player walks on ground
	if _state == RUN || _state == RESPAWN:
		set_last_hit_by_id.rpc(-1)
	
	# reset from states that change the character's model rotation
	if _state != SWIMMING && _state != SWIMMING_IDLE && _state != SWIMMING_DASH && _state != SLIDE && _state != SLIDE_BACK:
		character_model.rotation_degrees = Vector3(0, -180, 0)
	
	# reset swimming animation
	if _state != SWIMMING && _state != SWIMMING_IDLE && _state != SWIMMING_DASH:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendSwim/blend_amount", -1.0, 0.5)
	
	if _state != SWIMMING_DASH:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendSwimDash/blend_amount", 0.0, 0.2)
	
	# tools handling
	if _state == DEAD || _state == TRIPPED || _state == DUMMY || _state == ROLL:
		# disable tools
		if get_tool_inventory() != null:
			get_tool_inventory().set_disabled(true)
	# if invulnerable (spawning in), keep tools disabled, otherwise re-enable
	elif !invulnerable && _state != RESPAWN:
		# re-enable tools
		if get_tool_inventory() != null:
			get_tool_inventory().set_disabled(false)
	
	match _state:
		IDLE:
			# re-enable collider
			set_player_collider.call_deferred(true)
			physics_material_override.friction = 0
			change_state_non_authority.rpc(IDLE)
			# wait a bit after landing to set friction (avoids landings feeling jumpy)
			await get_tree().create_timer(0.1).timeout
			if _state == IDLE:
				physics_material_override.friction = 1
		RUN:
			physics_material_override.friction = 0
			# reset swim dash when on land
			swim_dash_cooldown = 0
		AIR:
			physics_material_override.friction = 0
			air_time.start()
			# set jump animation playhead back to 0
			animator.set("parameters/TimeSeek/seek_request", 0.0)
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendJump/blend_amount", 1.0, 0.1)
			change_state_non_authority.rpc(AIR)
		HIGH_JUMP:
			physics_material_override.friction = 0
			air_time.start()
			animator.set("parameters/TimeSeekHighJump/seek_request", 0.0)
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendHighJump/blend_amount", 1.0, 0.1)
			change_state_non_authority.rpc(HIGH_JUMP)
		DIVE:
			var forward : Vector3 = get_global_transform().basis.z
			apply_central_impulse(forward * 4)
			apply_central_impulse(Vector3.UP * 4)
			animator.set("parameters/TimeSeekDive/seek_request", 0.0)
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendDive/blend_amount", 1.0, 0.2)
			change_state_non_authority.rpc(DIVE)
		SLIDE:
			# re-enable collider
			set_player_collider.call_deferred(true)
			slide_time.start()
			physics_material_override.friction = 0.5
			var forward : Vector3 = get_global_transform().basis.z
			apply_central_impulse(forward)
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendSlide/blend_amount", 1.0, 0.3)
			change_state_non_authority.rpc(SLIDE)
		SLIDE_BACK:
			# re-enable collider
			set_player_collider.call_deferred(true)
			slide_time.start()
			physics_material_override.friction = 0.5
			var forward : Vector3 = get_global_transform().basis.z
			apply_central_impulse(forward * 6)
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendSlideBack/blend_amount", 1.0, 0.3)
			change_state_non_authority.rpc(SLIDE_BACK)
		ROLL:
			# re-enable collider
			set_player_collider.call_deferred(true)
			roll_time.start()
			physics_material_override.friction = 0.5
			var forward : Vector3 = get_global_transform().basis.z
			apply_central_impulse(forward * linear_velocity.length() * 0.5)
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendRoll/blend_amount", 1.0, 0.2)
			change_state_non_authority.rpc(ROLL)
			# roll time is handled in integrate_forces
		TRIPPED:
			# re-enable collider
			set_player_collider.call_deferred(true)
			if !trip_audio.playing:
				play_trip_audio.rpc()
			trip_time.start()
			lock_rotation = false
			physics_material_override.friction = 1
			# dizzy stars visual effect
			$Smoothing/dizzy_stars.visible = true
			$Smoothing/dizzy_stars/AnimationPlayer.play("dizzy")
			change_state_non_authority.rpc(TRIPPED)
			# stand up after trip timeout
			await trip_time.timeout
			# don't stand up in mid-air
			while get_colliding_bodies().is_empty():
				if is_inside_tree():
					await get_tree().physics_frame
				else: return
			# if we are still tripped after waiting, don't intercept states:
			if _state == TRIPPED:
				change_state(STANDING_UP)
		STANDING_UP:
			# dizzy stars visual effect
			$Smoothing/dizzy_stars.visible = false
			$Smoothing/dizzy_stars/AnimationPlayer.stop()
			var tween : Tween = create_tween()
			tween.tween_property(self, "rotation", Vector3(0, rotation.y, 0), 0.4)
			change_state_non_authority.rpc(IDLE)
			# for handling trip invincibility
			time_last_tripped = Time.get_ticks_msec()
			await get_tree().create_timer(0.4).timeout
			# if we are still standing up after waiting (do not intercept states):
			if _state == STANDING_UP:
				change_state(IDLE)
		IN_SEAT:
			# dizzy stars visual effect
			$Smoothing/dizzy_stars.visible = false
			$Smoothing/dizzy_stars/AnimationPlayer.stop()
			physics_material_override.friction = 1
			animator["parameters/BlendSit/blend_amount"] = 1
			change_state_non_authority.rpc(IN_SEAT)
			set_player_collider.call_deferred(false)
		EXIT_SEAT:
			_set_can_enter_seat(false)
			if seat_occupying is MotorSeat:
				# reset speed
				seat_occupying.drive.rpc(0, 0)
				seat_occupying.set_controlling_player.rpc(-1)
			set_global_position.call_deferred(Vector3(seat_occupying.global_position.x, seat_occupying.global_position.y + 3, seat_occupying.global_position.z))
			set_global_rotation(Vector3.ZERO)
			# re-enable collider
			set_player_collider.call_deferred(true)
			# take linear velocity of chair if it is moving fast
			if seat_occupying.linear_velocity.length() > 5:
				change_state(DIVE)
				linear_velocity = seat_occupying.linear_velocity * 1.25
			else:
				change_state(IDLE)
			seat_occupying = null
			get_tree().create_timer(0.5).connect("timeout", _set_can_enter_seat.bind(true))
		DEAD:
			# dizzy stars visual effect
			$Smoothing/dizzy_stars.visible = false
			$Smoothing/dizzy_stars/AnimationPlayer.stop()
			var tween : Tween = create_tween()
			tween.tween_property(self, "rotation", Vector3(0, rotation.y, 0), 0.2)
			tween.tween_property(animator, "parameters/BlendDead/blend_amount", 1.0, 0.3)
			change_state_non_authority.rpc(DEAD)
			if !trip_audio.playing:
				play_trip_audio.rpc()
			# reset gravity in case we were swimming
			gravity_scale = player_grav
			linear_damp = 0
			physics_material_override.friction = 1
			# set camera mode to tracking
			# remember what camera mode we had
			if camera is Camera:
				death_camera_mode = camera.get_camera_mode()
				if executing_player != null:
					camera.set_target(executing_player.target)
				camera.locked = true
				camera.set_camera_mode(Camera.CameraMode.TRACK)
		RESPAWN:
			# reset camera
			if camera is Camera:
				camera.locked = false
				camera.set_camera_mode(death_camera_mode)
				camera.set_target(target)
				camera.fov = UserPreferences.camera_fov
			# reset executing player
			executing_player = null
			go_to_spawn()
			set_global_rotation(Vector3.ZERO)
			linear_velocity = Vector3.ZERO
			change_state(IDLE)
			# disable and re enable collider for 1 physics tick to change
			# state into any that is affected by entering areas (like water)
			if !collider.disabled:
				collider.disabled = true
				await get_tree().physics_frame
				collider.disabled = false
		DUMMY:
			linear_velocity = Vector3.ZERO
			freeze = true
			change_state_non_authority.rpc(DUMMY)
			pass
		SWIMMING:
			gravity_scale = 0
			linear_damp = 0.8
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendSwim/blend_amount", 1.0, 0.5)
			change_state_non_authority.rpc(SWIMMING)
			# always get propulsed by rockets when swimming
			external_propulsion = true
		SWIMMING_IDLE:
			gravity_scale = 0
			linear_damp = 0.8
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendSwim/blend_amount", 0.0, 0.5)
			# TODO: Maybe a little inefficient, merge swimming & swimming idle states with
			# blended animations somehow
			change_state_non_authority.rpc(SWIMMING_IDLE)
			# always get propulsed by rockets when swimming
			external_propulsion = true
		SWIMMING_DASH:
			animator.set("parameters/TimeSeekSwimDash/seek_request", 0.0)
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendSwimDash/blend_amount", 1.0, 0.2)
			# boost
			var forward : Vector3 = -camera.get_global_transform().basis.z
			apply_central_impulse(forward * 12)
			change_state_non_authority.rpc(SWIMMING_DASH)
			swim_dash_time.start()
			# stand up after slide timeout
			await swim_dash_time.timeout
			# if we are still sliding after waiting, don't intercept states:
			if _state == SWIMMING_DASH:
				change_state(SWIMMING)
		EXIT_SWIMMING:
			drip_animator.play("drip")
			gravity_scale = player_grav
			linear_damp = 0
			change_state_non_authority.rpc(EXIT_SWIMMING)
			change_state(IDLE)
		ON_LEDGE:
			air_time.start()
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			play_jump_particles()
			tween.tween_property(animator, "parameters/BlendOnLedge/blend_amount", 1.0, 0.2)
			change_state_non_authority.rpc(ON_LEDGE)
		_:
			set_global_rotation(Vector3.ZERO)
			return

@rpc("any_peer", "call_local", "reliable")
func go_to_spawn() -> void:
	# if this go to spawn request is not from the server or run locally, return
	if multiplayer.get_remote_sender_id() != 1 && multiplayer.get_remote_sender_id() != 0:
		return
	# find team spawns
	var spawn : Vector3 = Vector3.ZERO
	spawn = spawns[randi() % spawns.size()]
	teleport(spawn)

# run on client from server
@rpc("any_peer", "call_local", "reliable")
func set_spawns(new_spawns : Array) -> void:
	# if this go to spawn request is not from the server or run locally, return
	if multiplayer.get_remote_sender_id() != 1 && multiplayer.get_remote_sender_id() != get_multiplayer_authority() && multiplayer.get_remote_sender_id() != 0:
		return
	spawns = new_spawns

# replicates states on non-authority clients, mainly for animation reasons
@rpc("call_remote", "reliable")
func change_state_non_authority(state : int) -> void:
	_state = state
	
	if _state != DUMMY:
		animator["parameters/BlendOutroPose/blend_amount"] = 0
	if _state != AIR:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendJump/blend_amount", 0.0, 0.1)
	if _state != HIGH_JUMP:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendHighJump/blend_amount", 0.0, 0.1)
	if _state != DIVE:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendDive/blend_amount", 0.0, 0.1)
	if _state != IN_SEAT:
		animator["parameters/BlendSit/blend_amount"] = 0
	if _state != SLIDE:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendSlide/blend_amount", 0.0, 0.2)
	if _state != SLIDE_BACK:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendSlideBack/blend_amount", 0.0, 0.2)
	if _state != ROLL:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendRoll/blend_amount", 0.0, 0.2)
	if _state != SWIMMING && _state != SWIMMING_IDLE && _state != SWIMMING_DASH:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendSwim/blend_amount", -1.0, 0.5)
	if _state != SWIMMING_DASH:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendSwimDash/blend_amount", 0.0, 0.2)
	if _state != DEAD:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendDead/blend_amount", 0.0, 0.2)
	if _state != ON_LEDGE:
		var tween : Tween = get_tree().create_tween().set_parallel(true)
		tween.tween_property(animator, "parameters/BlendOnLedge/blend_amount", 0.0, 0.2)
	# reset idle animation
	animator.set("parameters/IdleOneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	
	match _state:
		IDLE:
			# dizzy stars visual effect
			$Smoothing/dizzy_stars.visible = false
			$Smoothing/dizzy_stars/AnimationPlayer.stop()
		AIR:
			air_time.start()
			# set jump animation playhead back to 0
			animator.set("parameters/TimeSeek/seek_request", 0.0)
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendJump/blend_amount", 1.0, 0.1)
			# jump particles
			play_jump_particles()
		HIGH_JUMP:
			air_time.start()
			animator.set("parameters/TimeSeekHighJump/seek_request", 0.0)
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendHighJump/blend_amount", 1.0, 0.1)
			play_jump_particles()
		TRIPPED:
			# dizzy stars visual effect
			$Smoothing/dizzy_stars.visible = true
			$Smoothing/dizzy_stars/AnimationPlayer.play("dizzy")
		DIVE:
			# non-parallel tween runs sequentially
			var tween : Tween = get_tree().create_tween()
			animator.set("parameters/TimeSeekDive/seek_request", 0.0)
			tween.tween_property(animator, "parameters/BlendDive/blend_amount", 1.0, 0.2)
		SLIDE:
			# non-parallel tween runs sequentially
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendSlide/blend_amount", 1.0, 0.3)
			for i in range(9):
				play_jump_particles()
				await get_tree().create_timer(0.2).timeout
		SLIDE_BACK:
			# non-parallel tween runs sequentially
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendSlideBack/blend_amount", 1.0, 0.3)
			for i in range(9):
				play_jump_particles()
				await get_tree().create_timer(0.2).timeout
		ROLL:
			# non-parallel tween runs sequentially
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendRoll/blend_amount", 1.0, 0.2)
			for i in range(10):
				play_jump_particles()
				await get_tree().create_timer(0.2).timeout
		SWIMMING:
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendSwim/blend_amount", 1.0, 0.5)
		SWIMMING_IDLE:
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendSwim/blend_amount", 0.0, 0.5)
		SWIMMING_DASH:
			animator.set("parameters/TimeSeekSwimDash/seek_request", 0.0)
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendSwimDash/blend_amount", 1.0, 0.2)
		EXIT_SWIMMING:
			drip_animator.play("drip")
		IN_SEAT:
			animator["parameters/BlendSit/blend_amount"] = 1
		DEAD:
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendDead/blend_amount", 1.0, 0.3)
		ON_LEDGE:
			air_time.start()
			play_jump_particles()
			var tween : Tween = get_tree().create_tween().set_parallel(true)
			tween.tween_property(animator, "parameters/BlendOnLedge/blend_amount", 1.0, 0.2)
		DUMMY:
			pass

@rpc("call_local")
func play_trip_audio() -> void:
	trip_audio.play()

@rpc("call_local")
func play_bowling_audio() -> void:
	if !bowling_audio.playing:
		bowling_audio.play()

func get_movement_direction() -> Vector3:
	# only execute on yourself
	if !is_multiplayer_authority(): return Vector3.ZERO
	var dir := Vector3.ZERO
	
	dir.x = Input.get_action_strength("right") - Input.get_action_strength("left")
	dir.z = Input.get_action_strength("back") - Input.get_action_strength("forward")
	if camera != null:
		dir = dir.rotated(Vector3.UP, camera.rotation.y).normalized()
	
	return dir

func set_player_collider(new : bool) -> void:
	# collider only off when player is in a seat
	if new == false && _state == IN_SEAT:
		collider.set_disabled(true)
	else:
		collider.set_disabled(false)

func set_collider_short(mode : bool) -> void:
	if mode == false:
		collider.shape.height = 1.628
		collider.position.y = 0.809
	else:
		collider.shape.height = 0.814
		collider.position.y = 0.405

@rpc("any_peer", "call_local")
func explode(explosion_position : Vector3, from_whom : int = 1, _explosion_force : float = 4) -> void:
	# only run on server and auth
	if multiplayer.get_remote_sender_id() != 1 && multiplayer.get_remote_sender_id() != 0:
		return
	# default death type is explosion
	var cause_of_death : CauseOfDeath = CauseOfDeath.EXPLOSION
	# reduce health depending on distance of explosion; notify health handler who it was from
	var offset_pos : Vector3 = Vector3(global_position.x, global_position.y + 0.4, global_position.z)
	if multiplayer.is_server():
		set_health(get_health() - (28 / int(1 + offset_pos.distance_to(explosion_position))), cause_of_death, from_whom)
		# only trip / light fire if we are not dead
		if get_health() > 0:
			change_state.rpc_id(get_multiplayer_authority(), TRIPPED)
			light_fire.rpc(from_whom)
	
	# run on authority (client who exploded)
	if !is_multiplayer_authority(): return
	# check if holding flamethrower, if so set proper cause of death
	var flamethrower : Tool = get_tool_inventory().has_tool_by_name("FlamethrowerTool")
	if flamethrower != null && get_tool_inventory().tool_just_holding != null:
		if flamethrower == get_tool_inventory().tool_just_holding:
			cause_of_death = CauseOfDeath.FLAMETHROWER_EXPLOSION
	var explosion_dir : Vector3 = explosion_position.direction_to(global_position) * 25
	apply_impulse(explosion_dir * (_explosion_force/4))

# server side
func update_kills(new_kills : int) -> void:
	if !multiplayer.is_server():
		return
	if (new_kills > kills):
		emit_signal("kills_increased")
	kills = new_kills
	_receive_server_kills.rpc(new_kills)
	Global.update_player_list_information()

# server side
func update_deaths(new_deaths : int) -> void:
	if !multiplayer.is_server():
		return
	deaths = new_deaths
	_receive_server_deaths.rpc(new_deaths)
	Global.update_player_list_information()

# server side
func update_capture_time(new_capture_time : int) -> void:
	if !multiplayer.is_server():
		return
	capture_time = new_capture_time
	_receive_server_capture_time.rpc(new_capture_time)
	Global.update_player_list_information()

func update_checkpoint(new_checkpoint : int) -> void:
	if !multiplayer.is_server():
		return
	checkpoint = new_checkpoint

# client side
@rpc("any_peer", "call_local", "reliable")
func _receive_server_kills(new : int) -> void:
	if multiplayer.is_server(): return
	kills = new
	Global.update_player_list_information()

# client side
@rpc("any_peer", "call_local", "reliable")
func _receive_server_deaths(new : int) -> void:
	if multiplayer.is_server(): return
	deaths = new
	Global.update_player_list_information()

# client side
@rpc("any_peer", "call_local", "reliable")
func _receive_server_capture_time(new : int) -> void:
	if multiplayer.is_server(): return
	capture_time = new
	Global.update_player_list_information()

# for fun
@rpc("any_peer", "call_local", "reliable")
func set_model_size(new : int = 1) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	character_model.scale = Vector3(new, new, new)

func protect_spawn(time : float = 3.5, overlay := true) -> void:
	_receive_server_protect_spawn.rpc(time, overlay)
	invulnerable = true
	await get_tree().create_timer(time).timeout
	# some dummy states are used for invincibility
	if _state != DUMMY:
		invulnerable = false

@rpc("any_peer", "call_local", "reliable")
func _receive_server_protect_spawn(time : float = 3.5, overlay := true) -> void:
	invulnerable = true
	$SpawnAnimator.play("spawn")
	if overlay && is_multiplayer_authority():
		respawn_overlay.play("respawn")
	await get_tree().create_timer(time).timeout
	# some dummy states are used for invincibility
	if _state != DUMMY:
		invulnerable = false
	# re-enable tools
	if is_multiplayer_authority():
		if get_tool_inventory() != null && _state != DUMMY && _state != ROLL:
			get_tool_inventory().set_disabled(false)

func _on_camera_mode_changed() -> void:
	if !locked:
		if camera.get_camera_mode() == Camera.CameraMode.FREE:
			camera.set_target(target)
		elif camera.get_camera_mode() == Camera.CameraMode.AIM:
			camera.set_target(aim_target)

func entered_water() -> void:
	bubble_particles.emitting = true
	change_state(SWIMMING)
	if multiplayer.is_server():
		extinguish_fire.rpc()

func exited_water() -> void:
	bubble_particles.emitting = false
	change_state(EXIT_SWIMMING)

@rpc("any_peer", "call_local", "reliable")
func set_move_speed(new : int) -> void:
	# if this change state request is not from the server
	if multiplayer.get_remote_sender_id() != 1: return
	move_speed = new

@rpc("any_peer", "call_local", "reliable")
func set_jump_force(new : float) -> void:
	# if this change state request is not from the server
	if multiplayer.get_remote_sender_id() != 1: return
	jump_force = new

func align_character_model_normal(ground_normal : Vector3) -> void:
	# make sure we only align model in supported states
	if _state == SLIDE || _state == SLIDE_BACK || _state == DEAD:
		var old_scale : Vector3 = character_model.scale
		# from: https://kidscancode.org/godot_recipes/3.x/3d/3d_align_surface/index.html
		character_model.global_transform.basis.y = ground_normal
		character_model.global_transform.basis.x = -character_model.global_transform.basis.z.cross(ground_normal)
		character_model.global_transform.basis = character_model.global_transform.basis.orthonormalized()
		character_model.scale = old_scale

func show_chat(what : String) -> void:
	if UserPreferences.show_chats_above_players:
		chat_panel.visible = true
		chat_label.text = what
		chat_time.stop()
		chat_time.start()
		await chat_time.timeout
		chat_panel.visible = false

# for removing player from world
func despawn() -> void:
	get_tool_inventory().delete_all_tools()
	Global.get_world().remove_player_from_list(self)
	queue_free()
