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

func _ready():
	super()

func _physics_process(delta):
	for body in area.get_overlapping_bodies():
		if body is RigidPlayer || body is Brick || body is Bomb || body is ClayBall:
			if body.get_multiplayer_authority() == multiplayer.get_unique_id():
				var force = 160
				if body is RigidPlayer:
					force = 21
					if !body.in_air_from_lifter:
						body.in_air_from_lifter = true
						# will only run on auth
						body.sparkle_audio_anim.play("fadein")
				if body is Bomb || body is ClayBall:
					force = 15
				body.apply_force(Vector3.UP * force)
