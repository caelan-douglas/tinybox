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

@onready var editor : Editor
@onready var editor_canvas : CanvasLayer = get_tree().current_scene.get_node("EditorCanvas")
@onready var select_area : Area3D = $SelectArea
@onready var scale_tooltip : Label = get_node("/root/PersistentScene/PersistentCanvas/ScaleTooltip")
var hovered_editable_object : Node = null
var hovered_item_properties : Dictionary = {}
var can_select_object : bool = true
var selected_item : PackedScene = null
var selected_item_name_internal : String = ""
var selected_item_properties : Dictionary = {}
var item_offset := Vector3(0, 0, 0)

@onready var property_editor : PropertyEditor
@onready var item_chooser : ItemChooser
@onready var preview_node : Node3D = $PreviewNode
var active_preview_instance : Node3D = null
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
	
	var selectable_body : Node3D = null
	if body is Area3D:
		if body.owner is TBWObject:
			if !(body.owner is Water):
				selectable_body = body.owner
	else:
		if body is Brick || body is TBWObject:
			selectable_body = body
	
	if can_select_object:
		if selectable_body != null:
			hovered_editable_object = selectable_body
			# show props for that object
			hovered_item_properties = property_editor.list_object_properties(selectable_body, self)
			var last_pos : Vector3 = select_area.global_position
			# avoid ui spam when clicking + dragging (wait to be still
			# to show editing notification )
			await get_tree().create_timer(0.5).timeout
			if selectable_body != null:
				if select_area.global_position == last_pos:
					property_editor.editing_hovered = true

func _on_body_deselected(_body : Node3D) -> void:
	# if we are not the authority of this object
	if !is_multiplayer_authority(): return
	
	var hovering_nothing := true
	for body : Node3D in select_area.get_overlapping_bodies():
		if body != active_preview_instance && body.owner != active_preview_instance:
			hovering_nothing = false
	for area : Node3D in select_area.get_overlapping_areas():
		if area != active_preview_instance && area.owner != active_preview_instance:
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
			# regen preview
			_on_item_picked(selected_item_name_internal, "", false)

func set_tool_active(mode : bool, from_click : bool = false, free_camera_on_inactive : bool = true) -> void:
	super(mode, from_click)
	if mode == false:
		item_chooser.hide_item_chooser()
		if item_chooser.is_connected("item_picked", _on_item_picked):
			item_chooser.disconnect("item_picked", _on_item_picked)
		if preview_node != null:
			preview_node.visible = false
		# deselecting tool, remove any properties from list
		if property_editor.properties_from_tool == self:
			property_editor.clear_list()
		set_select_area_visible.rpc(false)
		for c : Node in preview_node.get_children():
			c.queue_free()
		# player specific
		if type == ToolType.PLAYER:
			tool_player_owner.high_priority_lock = false
			tool_player_owner.locked = false
			tool_player_owner.set_camera(get_viewport().get_camera_3d())
			var camera : Camera3D = get_viewport().get_camera_3d()
			if camera is Camera:
				camera.set_target(tool_player_owner.target)
				camera.set_camera_mode(Camera.CameraMode.FREE)
	else:
		item_chooser.show_item_chooser()
		item_chooser.connect("item_picked", _on_item_picked)
		if preview_node != null:
			preview_node.visible = true
		# update object property list
		property_editor.relist_object_properties(selected_item_properties, self)
		# regenerate preview
		_on_item_picked(selected_item_name_internal, "", false)
		# editing a new object, not a hovered one (show notif)
		property_editor.editing_hovered = false
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
	if !SpawnableObjects.objects.has(item_name_internal):
		return
	selected_item = SpawnableObjects.objects[item_name_internal]
	selected_item_name_internal = item_name_internal
	# show editable properties
	var inst : Node3D = selected_item.instantiate()
	# relist properties while instance has script
	if relist_properties:
		selected_item_properties = property_editor.list_object_properties(inst, self)
	# set preview motor side
	if inst is MotorBrick:
		if selected_item_properties.has("flip_motor_side"):
			inst.set_property("flip_motor_side", selected_item_properties["flip_motor_side"])
	# disable script
	inst.set_script(null)
	# offset objects down a bit, also update preview
	if item_name_internal.begins_with("obj"):
		if item_name_internal != "obj_water" && item_name_internal != "obj_camera_preview_point":
			item_offset = Vector3(0, -0.5, 0)
	for c : Node in preview_node.get_children():
		c.queue_free()
	# add instance as preview
	preview_node.add_child(inst)
	inst.position += item_offset
	inst.rotation = last_rotation
	active_preview_instance = inst
	property_editor.editing_hovered = false
	var new_mesh : MeshInstance3D = find_item_mesh(Global.get_all_children(inst) as Array)
	if new_mesh != null:
		# apply construction material
		for i in range(new_mesh.get_surface_override_material_count()):
			new_mesh.set_surface_override_material(i, load("res://data/materials/editor_placement_material.tres") as Material)

func find_item_mesh(array : Array) -> MeshInstance3D:
	for c : Variant in array:
		if c is MeshInstance3D:
			return c
		elif c is Array:
			return find_item_mesh(c as Array)
	return null

func selected_item_is_draggable() -> bool:
	if selected_item_name_internal.begins_with("brick") && selected_item_name_internal != "brick_motor_seat" && selected_item_name_internal != "brick_button":
		return true
	else: return false

func selected_item_is_brick() -> bool:
	if selected_item_name_internal.begins_with("brick"):
		return true
	else: return false

func selected_item_is_scalable() -> bool:
	if selected_item_name_internal.begins_with("obj"):
		return true
	else: return false

func _physics_process(delta : float) -> void:
	if !is_multiplayer_authority(): return
	
	var camera := get_viewport().get_camera_3d()
	if active:
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
		
		if preview_node != null:
			preview_node.global_position = camera.controlled_cam_pos
			var rot_amount : float = 22.5
			if selected_item_is_brick():
				rot_amount = 90
			if active_preview_instance != null:
				# rotation
				if Input.is_action_just_pressed("editor_rotate_reset"):
					active_preview_instance.rotation = Vector3.ZERO
				elif Input.is_action_just_pressed("editor_rotate_left"):
					active_preview_instance.rotate(Vector3.UP, deg_to_rad(rot_amount))
				elif Input.is_action_just_pressed("editor_rotate_right"):
					active_preview_instance.rotate(Vector3.UP, deg_to_rad(-rot_amount))
				elif Input.is_action_just_pressed("editor_rotate_up"):
					active_preview_instance.rotate(camera.basis.x.round(), deg_to_rad(-rot_amount))
				elif Input.is_action_just_pressed("editor_rotate_down"):
					active_preview_instance.rotate(camera.basis.x.round(), deg_to_rad(rot_amount))
				elif Input.is_action_just_pressed("editor_scale_up"):
					if selected_item_is_scalable():
						active_preview_instance.scale += Vector3(1, 1, 1)
						active_preview_instance.scale = clamp(active_preview_instance.scale, Vector3(1, 1, 1), Vector3(10, 10, 10))
				elif Input.is_action_just_pressed("editor_scale_down"):
					if selected_item_is_scalable():
						active_preview_instance.scale -= Vector3(1, 1, 1)
						active_preview_instance.scale = clamp(active_preview_instance.scale, Vector3(1, 1, 1), Vector3(10, 10, 10))
				active_preview_instance.rotation = Vector3(snapped(active_preview_instance.rotation.x, deg_to_rad(22.5)) as float, snapped(active_preview_instance.rotation.y, deg_to_rad(22.5)) as float, snapped(active_preview_instance.rotation.z, deg_to_rad(22.5)) as float)
				last_rotation = active_preview_instance.rotation 
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# place
			if Input.is_action_just_pressed("click"):
				drag_start_point = get_viewport().get_camera_3d().controlled_cam_pos
			if Input.is_action_pressed("click"):
				if selected_item_is_draggable():
					# Click and drag to scale bricks
					drag_end_point = get_viewport().get_camera_3d().controlled_cam_pos
					active_preview_instance.global_position = drag_start_point.lerp(drag_end_point, 0.5)
					b_scale = abs(drag_end_point - drag_start_point) + Vector3(1, 1, 1)
					b_scale = b_scale.clamp(Vector3(1, 1, 1), Vector3(2000, 2000, 2000))
					active_preview_instance.scale = Vector3(1, 1, 1)
					active_preview_instance.global_scale(b_scale)
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
							elif body.owner != active_preview_instance:
								valid = false
								break
						elif body.owner != active_preview_instance:
							valid = false
							break
					
					# however if there are any overlapping bodies it's no longer valid
					for body in select_area.get_overlapping_bodies():
						if body != active_preview_instance:
							valid = false
					
					# place if valid
					if valid && selected_item != null:
						var inst : Node3D = selected_item.instantiate()
						Global.get_world().add_child(inst, true)
						inst.global_position = drag_start_point.lerp(drag_end_point, 0.5)
						inst.global_rotation = active_preview_instance.global_rotation
						if selected_item_is_draggable():
							if selected_item_properties.has("brick_scale"):
								if selected_item_name_internal == "brick_cylinder":
									# x is forward on wheels
									selected_item_properties["brick_scale"] = Vector3(active_preview_instance.scale.z, active_preview_instance.scale.y, active_preview_instance.scale.x)
								else:
									selected_item_properties["brick_scale"] = active_preview_instance.scale
						else:
							# match global transform for objects
							inst.global_transform = active_preview_instance.global_transform
						
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
