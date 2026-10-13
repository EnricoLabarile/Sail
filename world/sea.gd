extends MeshInstance3D
## A sea plane that keeps under the boat (its wavelets are fixed in the world, so they don't move with it).

func _process(_dt: float) -> void:
	var b := get_tree().get_first_node_in_group("player_boat") as Node3D
	if b:
		global_position = Vector3(snappedf(b.global_position.x, 10.0), 0.0, snappedf(b.global_position.z, 10.0))
