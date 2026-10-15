extends MeshInstance3D
## THE SEA: hands the fog of war's picture (the Fog autoload, fog.gd) to the sea's shader.
## The shader then paints black where the boat hasn't been yet.

func _ready() -> void:
	var material: ShaderMaterial = mesh.material
	material.set_shader_parameter("fog_tex", Fog.texture)
