@tool
extends EditorScenePostImport
## THE ISLAND PIECES' IMPORT SCRIPT (Enrico): every 3D model (.fbx, .glb…) imported from this folder,
## res://Assets/Landscape/islands/, comes out ready, with nothing to tick by hand in Advanced Import Settings:
##   1. every surface of every mesh gets the shared island material, island.tres (the same as "Use External");
##   2. every mesh gets a collision: a StaticBody3D with a CollisionShape3D of its exact shape (Trimesh, the slow
##      precise kind), which is what Land.is_land hits. Same layout Godot makes with Physics ticked:
##      MeshInstance3D → StaticBody3D → CollisionShape3D.
## A mesh that already has a body (Physics ticked by hand, or a "-col" name in Blender) is left as it is.
## (In Unreal: an import pipeline / Editor Utility that sets the material and the collision on every new static mesh.)
##
## How it's hooked up: Project Settings → Import Defaults → Scene → Import Script points here, so every NEW model
## goes through it. Models from any other folder (the boat…) come out untouched: the script checks the folder first.
## Already-imported files keep their own settings (their .import file); to put one through it, set Import Script in
## its Import dock and press Reimport (several files can be selected and done at once).

const FOLDER := "res://Assets/Landscape/islands/"
const MATERIAL := preload("res://Assets/Landscape/islands/island.tres")


## Godot calls this after building the imported scene, before saving it. What it gives back is what's saved.
func _post_import(scene: Node) -> Object:
	if not get_source_file().begins_with(FOLDER):
		return scene                      # not an island piece: as it came
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		set_material(node)
		add_collision(node, scene)
	return scene


## The island material on every surface of the mesh.
func set_material(mesh_node: MeshInstance3D) -> void:
	var mesh := mesh_node.mesh
	if mesh == null:
		return
	for surface in mesh.get_surface_count():
		mesh.surface_set_material(surface, MATERIAL)


## A StaticBody3D with a trimesh CollisionShape3D under the mesh, unless it already has a body.
func add_collision(mesh_node: MeshInstance3D, scene: Node) -> void:
	if mesh_node.mesh == null:
		return
	for child in mesh_node.get_children():
		if child is StaticBody3D:
			return                        # it has one already
	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	mesh_node.add_child(body)
	body.owner = scene                    # owner = the scene's root, or the node isn't saved with it
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = mesh_node.mesh.create_trimesh_shape()   # the exact shape of the mesh (concave, "Trimesh")
	body.add_child(shape)
	shape.owner = scene
