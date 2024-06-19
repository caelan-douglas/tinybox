extends Map
class_name Lobby

enum GameWinCondition {
	BASE_DEFENSE,
	DEATHMATCH,
	TEAM_DEATHMATCH,
	KINGS
}

func _ready():
	var camera = get_viewport().get_camera_3d()
	camera.locked = true
	camera.global_position = Vector3(0, 52, 4)
	camera.global_rotation_degrees = Vector3(-10, 0, 0)
	super()
	# when map is initalized, set graphics on world
	get_parent().get_parent()._on_graphics_preset_changed()
	# move players when lobby is initialized
	var player = Global.get_player()
	if player:
		player.change_state(RigidPlayer.DUMMY)
	UIHandler.show_lobby_menu()
	Global.get_world().clear_bricks()
