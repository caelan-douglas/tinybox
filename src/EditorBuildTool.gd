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
class_name EditorBuildTool

enum States {
	BUILD,
	SELECT
}

@onready var editor : Editor
@onready var editor_canvas : EditorCanvas = get_tree().current_scene.get_node("EditorCanvas")
@onready var select_area : Area3D = $SelectArea
@onready var build_collider : CollisionShape3D = $SelectArea/build_collider
@onready var grab_collider : CollisionShape3D = $SelectArea/grab_collider
@onready var scale_tooltip : Label = get_node("/root/PersistentScene/PersistentCanvas/ScaleTooltip")
var hovered_editable_object : Node = null
var hovered_item_properties : Dictionary = {}
var selected_item : PackedScene = null
var selected_item_name_internal : String = ""
var selected_building_path : String = ""
var selected_item_properties : Dictionary = {}
var item_offset := Vector3(0, 0, 0)
# active copied tbw, shared between build tools
static var preview : Node3D = null

var ui_subtitle : Label

# consistent across all tools
static var _state : States = States.BUILD

@onready var property_editor : PropertyEditor
@onready var item_chooser : ItemChooser
var drag_start_point : Vector3 = Vector3.ZERO
var b_scale : Vector3 = Vector3.ZERO
var drag_end_point : Vector3 = Vector3.ZERO
var last_rotation : Vector3 = Vector3.ZERO

func _ready() -> void:
	if type == ToolType.EDITOR:
		init("(empty)", null)
		property_editor = get_tree().current_scene.get_node("EditorCanvas/LeftPanel/PropertyEditor") 
		item_chooser = get_tree().current_scene.get_node("EditorCanvas/LeftPanel/ItemChooser") 
		editor = Global.get_world().get_current_map()
	else:
		init("Build Tool", get_parent().get_parent() as RigidPlayer)
		tool_overlay = get_tree().current_scene.get_node_or_null("GameCanvas/ToolOverlay/BuildTool")
		property_editor = get_tree().current_scene.get_node("GameCanvas/ToolOverlay/BuildTool/LeftPanel/PropertyEditor")
		item_chooser = get_tree().current_scene.get_node("GameCanvas/ToolOverlay/BuildTool/LeftPanel/ItemChooser")
	
	# for when an editable object is hovered
	select_area.connect("body_entered", _on_body_selected)
	select_area.connect("area_entered", _on_body_selected)
	# for when selection leaves body
	select_area.connect("body_exited", _on_body_deselected)
	select_area.connect("area_exited", _on_body_deselected)
	
	var camera : Camera = get_viewport().get_camera_3d()
	property_editor.connect("property_updated", _on_property_updated)

# When something is hovered with the selector in the editor.
func _on_body_selected(body : Node3D) -> void:
	# if we are not the authority of this object
	if !is_multiplayer_authority(): return
	if _state == States.SELECT: return
	
	
	var selectable_body : Node3D = null
	if body is Area3D:
		# don't select the preview instance
		if (body.owner is TBWObject) && body.owner != preview && body != hovered_editable_object:
			if !(body.owner is Water):
				selectable_body = body.owner
	else:
		# don't select the preview instance
		if (body is Brick || body is TBWObject) && body != preview && body != hovered_editable_object:
			selectable_body = body
	
	if selectable_body != null:
		hovered_editable_object = selectable_body
		# show props for that object
		hovered_item_properties = property_editor.list_object_properties(selectable_body, self)
		property_editor.editing_hovered = true

func _on_body_deselected(_body : Node3D) -> void:
	# if we are not the authority of this object
	if !is_multiplayer_authority(): return
	if _state == States.SELECT: return

	var hovering_nothing := true
	for body : Node3D in select_area.get_overlapping_bodies():
		if body != preview && body.owner != preview:
			hovering_nothing = false
	for area : Node3D in select_area.get_overlapping_areas():
		if area != preview && area.owner != preview:
			hovering_nothing = false
	# check currently hovering bodies
	if hovering_nothing:
		# clear list
		property_editor.clear_list()
		property_editor.editing_hovered = false
		hovered_editable_object = null
		# allow any tools to re show their list
		_on_editor_deselected()


func _on_property_updated(properties : Dictionary) -> void:
	if property_editor.properties_from_tool == self:
	# When a property in the Property Editor is changed.
		if hovered_editable_object != null:
			if hovered_editable_object is TBWObject || hovered_editable_object is Brick:
				for property : String in hovered_item_properties.keys():
					hovered_editable_object.set_property(property, hovered_item_properties[property])
					
					if type == ToolType.PLAYER:
						hovered_editable_object.sync_properties.rpc(hovered_editable_object.properties_as_dict())
		else:
			selected_item_properties = properties
			update_subtitle()
			# regen preview
			_on_item_picked(selected_item_name_internal, "", false)

func update_subtitle() -> void:
	ui_subtitle = ui_partner.get_node("Subtitle")
	if ui_subtitle != null:
		# off by default
		ui_subtitle.visible = false
		if selected_item_properties.has("_material"):
			ui_subtitle.visible = true
			if ui_subtitle != null:
				# show the material of the brick as its subtitle
				ui_subtitle.text = str(Brick.BRICK_MATERIALS_AS_STRINGS[selected_item_properties["_material"] as int])

func set_tool_active(mode : bool, from_click : bool = false, free_camera_on_inactive : bool = true) -> void:
	super(mode, from_click)
	# zero out rotation for player
	if type == ToolType.PLAYER:
		global_rotation = Vector3.ZERO
		select_area.global_rotation = Vector3.ZERO
	if mode == false:
		item_chooser.hide_item_chooser()
		if item_chooser.is_connected("item_picked", _on_item_picked):
			item_chooser.disconnect("item_picked", _on_item_picked)
		clear_preview()
		set_select_area_visible.rpc(false)
		# player specific
		if type == ToolType.PLAYER:
			tool_player_owner.high_priority_lock = false
			tool_player_owner.locked = false
			tool_player_owner.set_camera(get_viewport().get_camera_3d())
			var camera : Camera3D = get_viewport().get_camera_3d()
			if camera is Camera:
				camera.set_target(tool_player_owner.target)
				camera.set_camera_mode(Camera.CameraMode.FREE)
		# reset camera zoom distance
		Global.set_camera_max_dist()
	else:
		# set to build by default
		change_state(States.BUILD)
		# show select area
		set_select_area_visible.rpc(true)
		
		# player specific
		if type == ToolType.PLAYER:
			tool_player_owner.high_priority_lock = true
			tool_player_owner.locked = true
			var camera : Camera3D = get_viewport().get_camera_3d()
			if camera is Camera:
				camera.set_target(null)
				camera.set_camera_mode(Camera.CameraMode.CONTROLLED)
				camera.controlled_cam_pos = (tool_player_owner.global_position + Vector3(0, 3, 0)).round()

func clear_preview() -> void:
	if preview != null:
		preview.queue_free()
	# deselecting tool, remove any properties from list
	if property_editor.properties_from_tool == self:
		property_editor.clear_list()

@rpc("any_peer", "call_local", "reliable")
func set_select_area_visible(mode : bool) -> void:
	select_area.visible = mode
	if select_area.has_node("NameLabel"):
		select_area.get_node("NameLabel").text = str(tool_player_owner.display_name, "'s Build Tool")

# when the editor stops hovering over something
func _on_editor_deselected() -> void:
	if active:
		# if there are copied properties, copy them over now
		if property_editor.copied_properties.size() > 0:
			# copy each property over, if the paste destination (our selected obj) has it
			for property : String in property_editor.copied_properties.keys():
				if selected_item_properties.has(property):
					selected_item_properties[property] = property_editor.copied_properties[property]
			property_editor.copied_properties = {}
		# update object property list
		property_editor.relist_object_properties(selected_item_properties, self)
		# editing a new object, not a hovered one (show notif)
		property_editor.editing_hovered = false

func _on_item_picked(item_name_internal : String, item_name_display : String = "", relist_properties : bool = true) -> void:
	ui_tool_name = item_name_display
	if item_name_display != "":
		ui_partner.text = str(item_name_display)
	item_offset = Vector3.ZERO
	
	# if this is a building
	if item_name_internal.split(";").size() > 1:
		selected_item_name_internal = item_name_internal
		selected_item = PackedScene.new()
		# in case preview is being regenerated
		if item_name_display != "":
			selected_building_path = item_name_display
		selected_item_properties = {}
		
		# load preview
		var lines := _load_selected_building_path_lines()
		_show_clipboard_preview(lines)
		
	else:
		# not a building
		
		if !SpawnableObjects.objects.has(item_name_internal):
			return
		selected_item = SpawnableObjects.objects[item_name_internal]
		selected_item_name_internal = item_name_internal
		# show editable properties
		var inst : Node3D = selected_item.instantiate()
		# relist properties while instance has script
		if relist_properties:
			selected_item_properties = property_editor.list_object_properties(inst, self)
		# offset objects down a bit, also update preview
		if item_name_internal.begins_with("obj"):
			if item_name_internal != "obj_water" && item_name_internal != "obj_camera_preview_point":
				item_offset = Vector3(0, -0.5, 0)
		# add instance as preview
		if preview != null:
			preview.queue_free()
		preview = inst
		preview.rotation = last_rotation
		add_child(inst)
		
		# set preview-specific parameters ------------
		# set preview motor side
		if inst is MotorBrick:
			if selected_item_properties.has("flip_motor_side"):
				inst.set_property("flip_motor_side", selected_item_properties["flip_motor_side"])
		# set capture point radius and height
		if inst is CapturePoint:
			if selected_item_properties.has("radius"):
				inst.set_property("radius", selected_item_properties["radius"])
			if selected_item_properties.has("height"):
				inst.set_property("height", selected_item_properties["height"])
		# -------------------------------------------
		
		# disable script
		inst.set_script(null)
		# remove collision
		remove_item_collision(Global.get_all_children(inst) as Array)
		inst.position += item_offset
		inst.rotation = last_rotation
		property_editor.editing_hovered = false
		var new_mesh : MeshInstance3D = find_item_mesh(Global.get_all_children(inst) as Array)
		if new_mesh != null:
			# apply construction material
			for i in range(new_mesh.get_surface_override_material_count()):
				new_mesh.set_surface_override_material(i, load("res://data/materials/editor_placement_material.tres") as Material)
	# show subtitle for build tool
	update_subtitle()

func find_item_mesh(array : Array) -> MeshInstance3D:
	for c : Variant in array:
		if c is MeshInstance3D:
			return c
		elif c is Array:
			return find_item_mesh(c as Array)
	return null

# Removes all collision from an item
func remove_item_collision(array : Array) -> void:
	for c : Variant in array:
		if c is CollisionShape3D || c is Area3D:
			c.queue_free()
		elif c is Array:
			remove_item_collision(c as Array)

func selected_item_is_draggable() -> bool:
	if selected_item_name_internal.begins_with("brick") && selected_item_name_internal != "brick_motor_seat" && selected_item_name_internal != "brick_button":
		return true
	else: return false

func selected_item_is_brick() -> bool:
	if selected_item_name_internal.begins_with("brick") || selected_item_name_internal.split(";").size() > 1:
		return true
	else: return false

func selected_item_is_scalable() -> bool:
	if selected_item_name_internal.begins_with("obj"):
		return true
	else: return false

func change_state(new : States) -> void:
	_state = new
	match (_state):
		States.BUILD:
			if type == ToolType.EDITOR:
				editor_canvas.toggle_select_mode_ui(false)
			# show item picker list
			item_chooser.show_item_chooser()
			if !item_chooser.is_connected("item_picked", _on_item_picked):
				item_chooser.connect("item_picked", _on_item_picked)
			# regenerate preview based on object name
			_on_item_picked(selected_item_name_internal, "", false)
			# update object property list
			property_editor.relist_object_properties(selected_item_properties, self)
			# editing a new object, not a hovered one
			property_editor.editing_hovered = false
			# update UI subtitle
			update_subtitle()
		States.SELECT:
			if type == ToolType.EDITOR:
				editor_canvas.toggle_select_mode_ui(true)
			item_chooser.hide_item_chooser()
			clear_preview()
			# re show the selection
			_show_clipboard_preview(Global.get_tbw_lines("temp"))
			# re show options for the selection
			if grabbed.size() > 0:
				property_editor.show_grab_actions(grabbed, self)

# share copied objs between buildtools
static var grabbed : Array = []
static var copied_lines : Array = []
func set_grabbed() -> void:
	var new_grabbed := []
	if select_area != null:
		for obj : Node3D in select_area.get_overlapping_bodies():
			if obj is TBWObject || obj is Brick:
				new_grabbed.append(obj)
	if new_grabbed.size() > 0:
		grabbed = new_grabbed
	copy_grabbed()
	property_editor.show_grab_actions(grabbed, self)

func copy_grabbed() -> void:
	var ok : bool = await Global.get_world().save_tbw("temp", false, grabbed, true)
	if ok:
		_show_clipboard_preview(Global.get_tbw_lines("temp"))

func delete_grabbed() -> void:
	for brick : Node in grabbed:
		if brick is Brick:
			brick.despawn.rpc(true)
	grabbed = []

var save_grabbed_name_lineedit : LineEdit = null
func save_grabbed() -> void:
	var save_name := ""
	if save_grabbed_name_lineedit != null:
		if save_grabbed_name_lineedit.text == "":
			UIHandler.show_alert("Enter a name to save as first.", 4, false, UIHandler.alert_colour_error)
			return
		save_name = save_grabbed_name_lineedit.text
	else:
		save_name = str("Building", ("%X" % Time.get_unix_time_from_system()))
	Global.get_world().save_tbw(save_name, false, grabbed)
	await get_tree().physics_frame
	item_chooser.refresh_saved_list()

func paste_grabbed() -> void:
	if copied_lines.size() > 0 && preview != null:
		Global.get_world().ask_server_to_load_building.rpc_id(1, Global.display_name, copied_lines, get_viewport().get_camera_3d().controlled_cam_pos as Vector3, false, preview.rotation)

func _physics_process(delta : float) -> void:
	if !is_multiplayer_authority(): return
	
	if active:
		var camera := get_viewport().get_camera_3d()
		var rot_amount : float = 22.5
		if selected_item_is_brick():
			rot_amount = 90
		if preview != null:
			# rotation
			if Input.is_action_just_pressed("editor_rotate_reset"):
				preview.rotation = Vector3.ZERO
			elif Input.is_action_just_pressed("editor_rotate_left") && !Global.is_text_focused:
				preview.rotate(Vector3.UP, deg_to_rad(rot_amount))
			elif Input.is_action_just_pressed("editor_rotate_right") && !Global.is_text_focused:
				preview.rotate(Vector3.UP, deg_to_rad(-rot_amount))
			elif Input.is_action_just_pressed("editor_rotate_up") && !Global.is_text_focused:
				preview.rotate(find_closest_axis(camera.basis.x.normalized()), deg_to_rad(-rot_amount))
			elif Input.is_action_just_pressed("editor_rotate_down") && !Global.is_text_focused:
				preview.rotate(find_closest_axis(camera.basis.x.normalized()), deg_to_rad(rot_amount))
			elif Input.is_action_just_pressed("editor_scale_up") && !Global.is_text_focused:
				if selected_item_is_scalable():
					preview.scale += Vector3(1, 1, 1)
					preview.scale = clamp(preview.scale, Vector3(1, 1, 1), Vector3(10, 10, 10))
			elif Input.is_action_just_pressed("editor_scale_down") && !Global.is_text_focused:
				if selected_item_is_scalable():
					preview.scale -= Vector3(1, 1, 1)
					preview.scale = clamp(preview.scale, Vector3(1, 1, 1), Vector3(10, 10, 10))
			preview.rotation = Vector3(snapped(preview.rotation.x, deg_to_rad(22.5)) as float, snapped(preview.rotation.y, deg_to_rad(22.5)) as float, snapped(preview.rotation.z, deg_to_rad(22.5)) as float)
			last_rotation = preview.rotation 
		
		if preview != null:
			preview.visible = true
			preview.global_position = select_area.global_position + item_offset
		
		# change states
		if Input.is_action_just_pressed("editor_select_toggle") && !Global.is_text_focused:
			match (_state):
				States.BUILD:
					change_state(States.SELECT)
				States.SELECT:
					change_state(States.BUILD)
		
		# SELECT MODE -----------
		if _state == States.SELECT:
			grab_collider.disabled = false
			build_collider.disabled = true
			if select_area != null:
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
					# drag select
					if Input.is_action_just_pressed("click"):
						drag_start_point = get_viewport().get_camera_3d().controlled_cam_pos
					elif Input.is_action_pressed("click"):
						# don't show preview while dragging
						preview.visible = false
						drag_end_point = get_viewport().get_camera_3d().controlled_cam_pos
						var drag_scale : Vector3 = drag_end_point - drag_start_point + Vector3(1, 1, 1)
						select_area.scale = abs(drag_end_point - drag_start_point) + Vector3(1, 1, 1)
						select_area.scale = select_area.scale.clamp(Vector3(1, 1, 1), Vector3(9999, 9999, 9999))
						select_area.global_position = drag_start_point.lerp(drag_end_point, 0.5)
					elif Input.is_action_just_released("click"):
						# when recapturing mouse with click
						if editor != null:
							if editor.editor_canvas.mouse_just_captured:
								return
						drag_end_point = get_viewport().get_camera_3d().controlled_cam_pos
						# paste on single click, no drag
						if drag_start_point == drag_end_point:
							paste_grabbed()
							return
						set_grabbed()
					else:
						select_area.scale = Vector3(1, 1, 1)
						select_area.global_position = get_viewport().get_camera_3d().controlled_cam_pos
		# BUILD MODE ------------
		else:
			grab_collider.disabled = true
			build_collider.disabled = false
			if select_area != null:
				select_area.global_position = get_viewport().get_camera_3d().controlled_cam_pos
				if Input.is_action_pressed("editor_delete"):
					# Delete the hovered object
					if select_area != null:
						# bricks, decor objects
						for body in select_area.get_overlapping_bodies():
							if body is Brick || body is TBWObject:
								# sync despawns in multiplayer
								if type == ToolType.PLAYER && body is Brick:
									body.despawn.rpc()
								if type == ToolType.PLAYER && body is TBWObject:
									return
								body.queue_free()
								# clear list
								property_editor.clear_list()
								property_editor.editing_hovered = false
								# allow any tools to re show their list
								_on_editor_deselected()
						# Lifters, pickups, etc.
						for area in select_area.get_overlapping_areas():
							if type == ToolType.PLAYER:
								return
							if area.owner is Water:
								continue
							elif area.owner is TBWObject:
								area.owner.queue_free()
								# clear list
								property_editor.clear_list()
								property_editor.editing_hovered = false
								# allow any tools to re show their list
								_on_editor_deselected()
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				# place
				if Input.is_action_just_pressed("click"):
					drag_start_point = get_viewport().get_camera_3d().controlled_cam_pos
				if Input.is_action_pressed("click"):
					if selected_item_is_draggable():
						# Click and drag to scale bricks
						drag_end_point = get_viewport().get_camera_3d().controlled_cam_pos
						preview.global_position = drag_start_point.lerp(drag_end_point, 0.5)
						b_scale = abs(drag_end_point - drag_start_point) + Vector3(1, 1, 1)
						b_scale = b_scale.clamp(Vector3(1, 1, 1), Vector3(2000, 2000, 2000))
						preview.scale = Vector3(1, 1, 1)
						preview.global_scale(b_scale)
						if b_scale != Vector3(1, 1, 1):
							scale_tooltip.text = str(b_scale.x, " x ", b_scale.y, " x ", b_scale.z)
				if Input.is_action_just_released("click"):
					# when recapturing mouse with click
					if editor != null:
						if editor.editor_canvas.mouse_just_captured:
							return
					scale_tooltip.text = ""
					# if the selected item isn't scalable, ignore drag and just place
					# at the same place as the end point
					if !selected_item_is_draggable():
						drag_start_point = get_viewport().get_camera_3d().controlled_cam_pos
					drag_end_point = get_viewport().get_camera_3d().controlled_cam_pos
					if select_area != null:
						# if there is something where we are trying to place
						var valid : bool = true
						
						# if it's trying to place underwater, that's fine
						for body in select_area.get_overlapping_areas():
							if body.owner is TBWObject:
								if body.owner.tbw_object_type == "obj_water":
									valid = true
								elif body.owner != preview:
									valid = false
									break
							elif body.owner != preview:
								valid = false
								break
						
						# however if there are any overlapping bodies it's no longer valid
						for body in select_area.get_overlapping_bodies():
							if body != preview:
								valid = false
						
						# place if valid
						if valid && selected_item != null:
							
							# --- is a building ---
							if selected_item_name_internal.split(";").size() > 1:
								var lines := _load_selected_building_path_lines()
								if lines.size() > 0:
									Global.get_world().ask_server_to_load_building.rpc_id(1, Global.display_name, lines, get_viewport().get_camera_3d().controlled_cam_pos as Vector3, false, preview.rotation)
								else:
									UIHandler.show_alert("Building not found or corrupt!", 8, false, UIHandler.alert_colour_error)
							
							# --- object or brick ---
							else:
								var inst : Node3D = selected_item.instantiate()
								Global.get_world().add_child(inst, true)
								inst.global_position = drag_start_point.lerp(drag_end_point, 0.5)
								inst.global_rotation = preview.global_rotation
								if selected_item_is_draggable():
									if selected_item_properties.has("brick_scale"):
										if selected_item_name_internal == "brick_cylinder":
											# x is forward on wheels
											selected_item_properties["brick_scale"] = Vector3(preview.scale.z, preview.scale.y, preview.scale.x)
										else:
											selected_item_properties["brick_scale"] = preview.scale
								else:
									# match global transform for objects
									inst.global_transform = preview.global_transform
								
								if inst is TBWObject || inst is Brick:
									for property : String in selected_item_properties.keys():
										inst.set_property(property, selected_item_properties[property])
								
								# player specific
								if inst is Brick && type == ToolType.PLAYER:
									var line : String = ""
									var type : String = inst._brick_spawnable_type
									line += str(type)
									for p : String in inst.properties_to_save:
										line += str(" ; ", p , ":", inst.get(p))
									Global.get_world().ask_server_to_load_building.rpc_id(1, Global.display_name, [line], Vector3.ZERO, true)
									inst.queue_free()
						# if trying to spawn a brick in an invalid location
						# and not dragging
						elif !$InvalidAudio.playing && Input.is_action_just_released("click"):
							$InvalidAudio.play()
							# show alert that nothing is selected
							if selected_item == null:
								UIHandler.show_alert("Select something to place from the left.\n(Press ESC to free your mouse.)", 3, false, UIHandler.alert_colour_error)
							else:
								UIHandler.show_alert("Can't place there! Selection (green)\nmust be unobstructed", 4, false, UIHandler.alert_colour_error)
					# regenerate after placement
					_on_item_picked(selected_item_name_internal, "", false)

func _load_selected_building_path_lines() -> Array:
	var lines := []
	var load_file := FileAccess.open(str("user://building/", selected_building_path), FileAccess.READ)
	# if does not exist in user dir, try the built-in dir
	if load_file == null:
		load_file = FileAccess.open(str("res://data/building/", selected_building_path), FileAccess.READ)
	
	if load_file != null:
		# load building
		while not load_file.eof_reached():
			var line := load_file.get_line()
			lines.append(str(line))
	return lines

func _show_clipboard_preview(lines : Array) -> void:
	# clear old clipboard
	if preview != null:
		preview.queue_free()
	copied_lines = lines
	preview = await Global.get_world().parse_tbw(copied_lines, true)
	for child : Node in preview.get_children():
		child.set_script(null)
	#container.reparent(preview_node)
	await get_tree().physics_frame
	if preview != null:
		preview.position = Vector3.ZERO
		# make all children have preview material and remove collision
		for child : Node in preview.get_children():
			remove_item_collision(Global.get_all_children(child) as Array)
			var new_mesh : MeshInstance3D = find_item_mesh(Global.get_all_children(child) as Array)
			if new_mesh != null:
				# apply construction material
				for i in range(new_mesh.get_surface_override_material_count()):
					new_mesh.set_surface_override_material(i, load("res://data/materials/editor_placement_material.tres") as Material)
		preview.rotation = last_rotation
	
# Find the closest Vector3 axis to a normalized vector using dot.
func find_closest_axis(normalized_vector : Vector3) -> Vector3:
	var axes : Array[Vector3] = [\
		Vector3(1, 0, 0),
		Vector3(0, 1, 0),\
		Vector3(0, 0, 1),\
	]
	
	var closest_axis := axes[0]
	var max_dot : float = -1
	var signed_max_dot : float = -1
	# find closest axis out of 6 dof
	for a in axes:
		var dot : float = normalized_vector.dot(a)
		if abs(dot) > max_dot:
			max_dot = abs(dot)
			signed_max_dot = dot
			closest_axis = a
	
	if signed_max_dot >= 0:
		return closest_axis
	else:
		return closest_axis * -1
