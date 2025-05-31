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

extends Node

@onready var thunders : Array[AudioStreamOggVorbis] = [\
	preload("res://data/audio/thunder_0.ogg"),\
	preload("res://data/audio/thunder_1.ogg"),\
	preload("res://data/audio/thunder_2.ogg"),\
	]

# min time between thunders in seconds
const MIN_THUNDER_TIME : int = 10
# max time between thunders
const MAX_THUNDER_TIME : int = 40

@onready var thunder_timer : Timer = Timer.new()
@onready var thunder_audio : AudioStreamPlayer3D = $ThunderAudio
@export var lightning_animator : AnimationPlayer

func _ready() -> void:
	# Sync thunder timing between clients.
	if multiplayer.is_server():
		add_child(thunder_timer)
		thunder_timer.connect("timeout", _on_thunder_timer_timeout)
		set_thunder_timer_server()

func set_thunder_timer_server() -> void:
	thunder_timer.wait_time = randi_range(MIN_THUNDER_TIME, MAX_THUNDER_TIME)
	thunder_timer.start()

func _on_thunder_timer_timeout() -> void:
	if multiplayer.is_server():
		thunder_rpc.rpc()
		# Set up timer again, as server
		set_thunder_timer_server()

@rpc("authority", "call_local", "reliable")
func thunder_rpc() -> void:
	# Play random audio, move audio to random spot
	# for 3d autio effect
	thunder_audio.global_position = Vector3(randi_range(-1000, 1000), 0, (randi_range(-1000, 1000)))
	thunder_audio.stream = thunders.pick_random()
	thunder_audio.play()
	# Play lightning effect
	if lightning_animator != null:
		lightning_animator.play("lightning")
