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

extends MotorBrick
class_name MotorFlyBrick

var addl_accel : float = 0
@onready var thruster_particles : GPUParticles3D = $ThrusterParticles
@onready var thruster_audio : AudioStreamPlayer3D = $ThrusterAudio

# Set a custom property
func set_property(property : StringName, value : Variant) -> void:
	super(property, value)

# Set the material of this brick to a different one, 
# and update any related properties.
@rpc("call_local")
func set_material(new : Brick.BrickMaterial) -> void:
	pass

@rpc("any_peer", "call_local", "reliable")
func set_colour(new : Color) -> void:
	# don't change colour
	pass

@rpc("any_peer", "call_local")
func set_parent_controller(as_path : NodePath) -> void:
	super(as_path)

func _init() -> void:
	max_speed = 350
	properties_to_save = ["global_position", "global_rotation", "brick_scale", "immovable", "joinable", "indestructible", "max_speed", "tag"]
	control_scheme = ControlScheme.ALTERNATE
	explode_velocity = 40

func _ready() -> void:
	super()
	thruster_audio.seek(randf_range(0, 4))

@rpc("any_peer", "call_remote", "reliable")
func sync_properties(props : Dictionary) -> void:
	super(props)

func enter_state() -> void:
	super()

func _get_airspeed() -> float:
	return linear_velocity.length()

func _physics_process(delta : float) -> void:
	thruster_audio.volume_db = lerpf(thruster_audio.volume_db, (30 * absf(speed)) - 30, 0.1)
	thruster_audio.volume_db = clampf(thruster_audio.volume_db, -80, 0)
	
	thruster_audio.stream_paused = true if (thruster_audio.volume_db < -29) else false
	
	addl_accel = clampf(_get_airspeed() * 32, 0, 4000)
	apply_force(basis.y * speed * (max_speed) * mass_mult)
	thruster_particles.emitting = true if (speed != 0) else false
	
func reduce_health(amount : int) -> void:
	if !is_multiplayer_authority(): return
	super(amount)
	
	if health < 1:
		create_explosion.rpc()

func entered_water() -> void:
	super()

func exited_water() -> void:
	super()
