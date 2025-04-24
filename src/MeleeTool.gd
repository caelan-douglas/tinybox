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
class_name MeleeTool

enum MeleeType {
	BAT
}

@export var tool_name := "Bat"
@export var _melee_type : MeleeType = MeleeType.BAT
@export var damage : int = 4
@export var cooldown : int = 7
var knockback : int = 0
var cooldown_counter : int = 0
var deflect_time := 0
var is_hitting := false

var hit_area : Area3D = null
var large_hit_area : Area3D = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super.init(tool_name, get_parent().get_parent() as RigidPlayer)

func add_visual_mesh_instance() -> void:
	visual_mesh_instance = visual_mesh.instantiate()
	tool_visual.add_child(visual_mesh_instance)
	hit_area = visual_mesh_instance.get_node_or_null("mesh/HitArea")
	if hit_area:
		hit_area.connect("body_entered", on_hit)
	large_hit_area = visual_mesh_instance.get_node_or_null("mesh/LargeHitArea")
	if large_hit_area:
		large_hit_area.connect("body_entered", on_large_hit)

func _physics_process(delta : float) -> void:
	# only execute on yourself
	if !is_multiplayer_authority(): return
	# if this tool is selected
	if get_tool_active():
		if cooldown_counter <= 0:
			if Input.is_action_pressed("click"):
				# Limit the speed at which we can hit
				cooldown_counter = cooldown
				swing.rpc()
	cooldown_counter -= 1
	if deflect_time > 0:
		deflect_time -= 1

@rpc("call_local")
func swing() -> void:
	if visual_mesh_instance != null:
		# we must get it here because the visual mesh instance changes
		var animator : AnimationPlayer = visual_mesh_instance.get_node_or_null("AnimationPlayer")
		if animator:
			animator.play("hit")
		is_hitting = true
		await get_tree().create_timer(0.2).timeout
		is_hitting = false

func on_hit(body : Node3D) -> void:
	if !self.is_inside_tree(): return
	# reduce player health on hit
	if body is RigidPlayer:
		# only take damage if not tripped
		# don't take damage from our own tool
		if multiplayer.is_server():
			if (body._state != RigidPlayer.TRIPPED) && (body.get_multiplayer_authority() != get_multiplayer_authority()):
				body.reduce_health(damage, RigidPlayer.CauseOfDeath.MELEE, get_multiplayer_authority())
				body.change_state.rpc_id(body.get_multiplayer_authority(), RigidPlayer.TRIPPED)
				# running as server
				body.emit_signal("hit_by_melee", self)
		# only run this on the authority of who was hit (not necessarily
		# the authority of the tool)
		# and don't run on ourselves
		if (body.get_multiplayer_authority() == multiplayer.get_unique_id()) && (body.get_multiplayer_authority() != get_multiplayer_authority()):
			# running as hit player's authority
			if !multiplayer.is_server():
				body.emit_signal("hit_by_melee", self)
			# apply small impulse from bat hit
			body.apply_impulse(Vector3(randi_range(-2, 2), 5, randi_range(-2, 2)))
			# apply impulse from knockback (defaults zero, changed with modifiers)
			if knockback > 0:
				var knockback_vec : Vector3 = global_position.direction_to(body.global_position).normalized() * knockback
				knockback_vec.y = knockback * 0.5
				body.apply_impulse(knockback_vec)
			# we hit a player, set the player's last hit by ID to this one
			body.set_last_hit_by_id.rpc(get_multiplayer_authority())
	elif body is Character:
		body.set_health(body.get_health() - damage)
	# kick players out of seats
	elif body is MotorSeat:
		if body.controlling_player != null:
			# if it's someone else. don't kick ourselves out...
			if body.controlling_player.get_multiplayer_authority() != get_multiplayer_authority():
				body.controlling_player.seat_destroyed.rpc_id(body.controlling_player.get_multiplayer_authority(), true)
				body.set_controlling_player.rpc(-1)

func on_large_hit(body : Node3D) -> void:
	# only run on auth
	if !is_multiplayer_authority(): return
	
	# Deflects rockets, bombs, balls, and other players.
	if (body is Rocket || body is Bomb || body is ClayBall) && deflect_time < 1 && is_hitting:
		if visual_mesh_instance != null:
			var deflect : AudioStreamPlayer3D = visual_mesh_instance.get_node_or_null("DeflectAudio")
			deflect_time = 40
			deflect.play()
		# deflect body on body's auth
		body.deflect.rpc_id(body.get_multiplayer_authority(), -tool_player_owner.global_transform.basis.z)
