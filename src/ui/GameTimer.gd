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

extends ProgressBar
class_name GameTimer

var min_audio : AudioStreamPlayer
var end_audio : AudioStreamPlayer
@onready var anim : AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	min_audio = AudioStreamPlayer.new()
	end_audio = AudioStreamPlayer.new()
	min_audio.bus = "UI"
	end_audio.bus = "UI"
	min_audio.stream = load("res://data/audio/countdown.ogg")
	end_audio.stream = load("res://data/audio/countdown10sec.ogg")
	add_child(min_audio)
	add_child(end_audio)

@rpc("any_peer", "call_local", "reliable")
func update_timer(label : String, time_s : float) -> void:
	# only accept updates from server
	if multiplayer.get_remote_sender_id() != 1:
		return
	var timer_text : Label = get_node("Label")
	if timer_text != null:
		var mins := str(int(time_s as int / 60))
		var seconds := str('%02d' % (int(time_s as int) % 60))
		timer_text.text = str(label, " - ", mins, ":", seconds)
		value = time_s
	
	if (!min_audio.playing && !end_audio.playing):
		if round(time_s) == 60:
			min_audio.play()
			anim.play("flash_timer")
		elif round(time_s) == 10:
			end_audio.play()
			anim.play("flash_timer")

@rpc("any_peer", "call_local", "reliable")
func set_max_val_rpc(new : int) -> void:
	max_value = new
	value = new

@rpc("any_peer", "call_local", "reliable")
func set_visible_rpc(mode : bool) -> void:
	visible = mode
