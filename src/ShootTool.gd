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

extends Tool
class_name ShootTool

enum ShootType {
	BALL,
	BRICK,
	ROCKET,
	BOMB,
	WATER,
	FIRE,
	MISSILE
}

@export var tool_name : String = "Shoot Tool"
@export var _shoot_type : ShootType = ShootType.BALL
@export var shot_speed := 30
@export var shot_cooldown := 5
@export var explosion_size := 1.5
@export var charged_shot := false
var charged_shot_amt : float = 0
var charged_shot_amt_max : float = 60
@export var show_cooldown_on_ui_partner := false
@export var ammo : int = -1
@export var restore_ammo := false
@export var max_ammo_restore : int = 0
@export var fire_sound := false

@onready var restore_timer : Timer = Timer.new()
@onready var audio : AudioStreamPlayer3D = get_node_or_null("AudioStreamPlayer")
@onready var audio_anim : AnimationPlayer = get_node_or_null("AnimationPlayer")
var shot_cooldown_counter : int = 0
var ui_progress : ProgressBar = null

@onready var ball : PackedScene = preload("res://data/scene/clay_ball/ClayBall.tscn")
@onready var brick : PackedScene = preload("res://data/scene/brick/Brick.tscn")
@onready var rocket : PackedScene = preload("res://data/scene/rocket/Rocket.tscn")
@onready var bomb : PackedScene = preload("res://data/scene/bomb/Bomb.tscn")
@onready var water : PackedScene = preload("res://data/scene/water/WaterProjectile.tscn")
@onready var fire : PackedScene = preload("res://data/scene/fire/FireProjectile.tscn")
# for showing cost in minigame
@onready var floaty_text : PackedScene = preload("res://data/scene/ui/FloatyText.tscn")

var firing : bool = false

func set_shot_cooldown_counter(new : int) -> void:
	shot_cooldown_counter = new
	if ui_progress == null:
		ui_progress = ui_partner.get_node("ProgressBar")
	ui_progress.max_value = shot_cooldown
	ui_progress.value = new

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super.init(tool_name, get_parent().get_parent() as RigidPlayer)
	
	if !is_multiplayer_authority(): return
	
	update_ammo_display()
	# connect player's body entered & hit by melee tool detection
	if _shoot_type == ShootType.FIRE:
		tool_player_owner.connect("body_entered", _on_player_body_entered)
		tool_player_owner.connect("hit_by_melee", _on_player_body_entered)
	
	if restore_ammo:
		restore_timer.one_shot = false
		restore_timer.wait_time = 0.5
		restore_timer.connect("timeout", increase_ammo)
		add_child(restore_timer)
		restore_timer.start()
	
	tool_overlay = get_tree().current_scene.get_node_or_null("GameCanvas/ToolOverlay/ChargedTool")

@onready var explosion : PackedScene = SpawnableObjects.explosion
func _on_player_body_entered(body : Node3D) -> void:
	# run only as auth
	if !is_multiplayer_authority(): return
	# detect if player is hit by these AND tool is currently equipped
	if get_tool_active() && (body is ClayBall || body is MeleeTool || body is Bomb):
		explode.rpc(body.get_multiplayer_authority())

@rpc("any_peer", "call_local")
func explode(from_whom_id : int) -> void:
	var explosion_i : Explosion = explosion.instantiate()
	get_tree().current_scene.add_child(explosion_i)
	explosion_i.set_explosion_size(explosion_size)
	# player_from id is later used in death messages
	explosion_i.set_explosion_owner(from_whom_id)
	explosion_i.global_position = global_position
	explosion_i.play_sound()

func update_ammo_display() -> void:
	if !is_multiplayer_authority(): return
	# inf ammo
	if ammo < 1:
		ui_partner.text = str(ui_tool_name)
	# limited ammo
	else:
		ui_partner.text = str(ui_tool_name, " (", ammo, ")")

func reduce_ammo() -> void:
	if ammo > 0:
		ammo -= 1
		update_ammo_display()
		if ammo < 1 && !restore_ammo:
			delete()
		# delay restore timer
		if restore_ammo:
			restore_timer.stop()
			await get_tree().create_timer(2).timeout
			restore_timer.start()

func increase_ammo() -> void:
	# reset wait time (from ammo reduction)
	restore_timer.wait_time = 0.7
	if ammo < max_ammo_restore:
		ammo += 1
		update_ammo_display()

# Spawn a projectile. RUN AS SERVER
# Arg 1: The id to spawn this projectile for.
# Arg 2: The shot speed of this projectile.
@rpc("call_local")
func spawn_projectile(id : int, shot_speed_rpc : float, shoot_type_rpc : ShootType) -> void:
	# minigame costs
	var cost : int = 1
	var can_afford := true
	if can_afford && (ammo == -1 || ammo > 0):
		var p : Node = null
		match shoot_type_rpc:
			ShootType.BRICK:
				p = brick.instantiate()
			ShootType.ROCKET:
				p = rocket.instantiate()
				p.explosion_size = explosion_size
			ShootType.BOMB:
				p = bomb.instantiate()
				p.explosion_size = explosion_size
			ShootType.WATER:
				p = water.instantiate()
			ShootType.FIRE:
				p = fire.instantiate()
			ShootType.MISSILE:
				p = rocket.instantiate()
				p.guided = true
				p.explosion_size = explosion_size
			_:
				p = ball.instantiate()
		if p != null:
			# Spawn projectile for client (this function is run as server).
			Global.get_world().add_child(p, true)
			p.spawn_projectile.rpc(id, shot_speed_rpc)

@rpc("any_peer", "call_remote", "reliable")
func show_floaty_cost_client(cost : int) -> void:
	# floaty cost text
	if tool_visual:
		var floaty_i : Node3D = floaty_text.instantiate()
		floaty_i.get_node("Label").text = str("-$", cost)
		floaty_i.global_position = Vector3(tool_visual.global_position.x, tool_visual.global_position.y + 0.5, tool_visual.global_position.z)
		Global.get_world().add_child(floaty_i)

@rpc("any_peer", "call_local", "reliable")
func _set_tool_audio_playing(mode : bool) -> void:
	match(mode):
		true:
			audio_anim.stop()
			audio.volume_db = -10
			audio.play()
		false:
			audio_anim.play("fadeout")

func _physics_process(delta : float) -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	var stop_audio := false
	# if this tool is selected
	if get_tool_active():
		# for determining if player is actively trying to fire
		if Input.is_action_pressed("click") && (ammo > 0 || ammo == -1):
			firing = true
		else:
			firing = false
		# for actually handling firing
		if shot_cooldown_counter <= 0 && (ammo > 0 || ammo == -1):
			if Input.is_action_pressed("click") && !tool_player_owner.locked:
				# For single-click shots
				if !charged_shot:
					# Limit the speed at which we can fire.
					shot_cooldown_counter = shot_cooldown
					if (audio != null && audio_anim != null):
						if !audio.playing || audio_anim.is_playing():
							_set_tool_audio_playing.rpc(true)
					if fire_sound == true && audio != null:
						audio.pitch_scale = 1
						audio.play()
					# if we are NOT the server,
					# make server spawn ball so it is synced by MultiplayerSpawner
					spawn_projectile.rpc_id(1, multiplayer.get_unique_id(), shot_speed, _shoot_type)
					# Reduce ammo for self (client).
					reduce_ammo()
				else:
					if charged_shot_amt < charged_shot_amt_max:
						charged_shot_amt += 1
						power_meter.value = charged_shot_amt
						# just increased above
						if charged_shot_amt >= charged_shot_amt_max:
							power_meter_anim.play("power_max")
			elif Input.is_action_just_released("click") && charged_shot && charged_shot_amt > 0 && !tool_player_owner.locked:
				# Limit the speed at which we can fire.
				shot_cooldown_counter = shot_cooldown
				
				if (audio != null && audio_anim != null):
					if !audio.playing || audio_anim.is_playing():
						_set_tool_audio_playing.rpc(true)
				if fire_sound == true && audio != null:
					audio.pitch_scale = 1 + (0.5 * (charged_shot_amt/charged_shot_amt_max))
					audio.play()
				
				if !multiplayer.is_server():
					spawn_projectile.rpc_id(1, multiplayer.get_unique_id(), shot_speed * (1 + (1.25 * (charged_shot_amt/charged_shot_amt_max))), _shoot_type)
				else:
					spawn_projectile(multiplayer.get_unique_id(), shot_speed * (1 + (1.25 * (charged_shot_amt/charged_shot_amt_max))), _shoot_type)
				reduce_ammo()
			else:
				stop_audio = true
				_end_shot()
		elif (ammo < 1 && ammo != -1):
			stop_audio = true
			_end_shot()
		else:
			_end_shot()
	else: 
		stop_audio = true
		_end_shot()
		firing = false
	if stop_audio && (audio != null && audio_anim != null):
		# if audio is currently playing, and we are not fading out, fade out
		if audio.playing && !audio_anim.is_playing():
			_set_tool_audio_playing.rpc(false)
	if ui_partner:
		if shot_cooldown_counter > 0:
			# countdown as long as we are above 0.
			shot_cooldown_counter -= 1
			if show_cooldown_on_ui_partner:
				# if the button exists
				if ui_partner != null:
					# if the progress bar doesn't already exist
					if ui_progress == null:
						ui_progress = ui_partner.get_node("ProgressBar")
						ui_progress.max_value = shot_cooldown
					# if we are at 1 progress, set the ui progress bar to be
					# empty.
					if shot_cooldown_counter != 1:
						ui_progress.value = shot_cooldown_counter
					else: ui_progress.value = 0

func _end_shot() -> void:
	charged_shot_amt = 0
	if power_meter != null:
		power_meter.value = 0
		if power_meter_anim != null:
			power_meter_anim.play("RESET")

var power_meter : TextureProgressBar = null
var power_meter_anim : AnimationPlayer = null
func set_tool_active(mode : bool, from_click : bool = false, free_camera_on_inactive : bool = true) -> void:
	super(mode, from_click, free_camera_on_inactive)

	if tool_overlay != null:
		if !charged_shot:
			tool_overlay.visible = false
		else:
			tool_overlay.visible = mode
			power_meter = tool_overlay.get_node("Power")
			power_meter_anim = tool_overlay.get_node("Power/AnimationPlayer")
	
