@tool
extends EditorPlugin

const ray_length = 1000
const vec_inf = Vector3(INF, INF, INF)  # Workaround for Vector3.INF typing issue

var selection = get_editor_interface().get_selection()
var selected : Node3D = null

var origin = Vector3()
var origin_2d = null

func _enter_tree():
	selection.connect("selection_changed", _on_selection_changed)
	
func _handles(object):
	if object is Node3D:
		return true
	return false

func _forward_3d_draw_over_viewport(overlay):
	if origin_2d != null:
		overlay.draw_circle(origin_2d, 4, Color.YELLOW)
	pass

func _forward_3d_gui_input(camera, event):
	if event is InputEventMouse and selected != null and Input.is_key_pressed(KEY_V):
		var from = camera.project_ray_origin(event.position)
		var direction = camera.project_ray_normal(event.position)
		var to = from + direction * ray_length

		if event.button_mask != MOUSE_BUTTON_LEFT:
			var meshes = find_meshes(selected)
			origin = find_closest_point(meshes, from, direction)

			if origin != vec_inf:
				origin_2d = camera.unproject_position(origin)
			else:
				origin_2d = null
			update_overlays()
		else:
			if origin != vec_inf:
				origin_2d = camera.unproject_position(origin)
				update_overlays()
				var ids = RenderingServer.instances_cull_ray(from, to, selected.get_world_3d().scenario)
				var meshes = []
				for id in ids:
					var obj = instance_from_id(id)
					if obj != selected and obj.get_parent() != selected and obj is Node3D:
						meshes += find_meshes(obj)
 
				var target = find_closest_point(meshes, from, direction)
				if target != vec_inf:
					selected.translate((target * selected.global_transform.basis) - (origin * selected.global_transform.basis))
					origin = target
					
				return true
	if not Input.is_key_pressed(KEY_V):
		origin_2d = null
		update_overlays()
	return false

func _on_selection_changed():
	var nodes = selection.get_selected_nodes()
	if nodes.size() == 1 and nodes[0] is Node3D:
		selected = nodes[0]
	else:
		selected = null
		origin = null

func find_meshes(node : Node3D) -> Array:
	var meshes : Array = []
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		if child is Node3D:
			meshes += find_meshes(child)
	return meshes
	
func find_closest_point(meshes : Array, from : Vector3, direction : Vector3) -> Vector3:
	# We cache the distance to not recalculate it for every check.
	# This also means we can use INF as the initial value. Any actual
	# distance will be smaller. We also use an infinite vector as the
	# invalid closest point. Otherwise vertices at position (0, 0, 0)
	# would not be considered as the closest point.
	var closest := vec_inf
	var closest_distance := INF
	
	# We will not use the distance between the vertex and the from position,
	# (that would always be the vertex closest to the camera). Instead we
	# use the distance between the vertex and the ray under the mouse cursor.
	# Ideally we would use the 2d distance of the unprojected vertices,
	# however unprojecting every vertex can have a performance penalty for
	# large meshes. This is a good balance between performance and accuracy.
	var segment_start := from
	var segment_end := from + direction
	
	for mesh in meshes:
		var vertices = mesh.get_mesh().get_faces()
		for i in range(vertices.size()):
			var current_point: Vector3 = mesh.global_transform * vertices[i]
			var current_on_ray := Geometry3D.get_closest_point_to_segment_uncapped(
				current_point, segment_start, segment_end)
			var current_distance := current_on_ray.distance_to(current_point)
			if closest == vec_inf or current_distance < closest_distance:
				closest = current_point
				closest_distance = current_distance
	
	return closest
