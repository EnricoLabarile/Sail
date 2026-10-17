extends MeshInstance3D
## THE SEA: when the game starts, it puts the fog of war on screen.
##
## The fog is a screen effect (Assets/Landscape/world/fog.gdshader): a rectangle that the shader stretches
## over the whole screen, painting black where the boat hasn't been yet, over the sea and any 3D object.
## It's made here in code (and not as a node in the scene) so it doesn't cover the editor's view.

func _ready() -> void:
	var fog := ShaderMaterial.new()
	fog.shader = load("res://Assets/Landscape/world/fog.gdshader")
	fog.set_shader_parameter("fog_tex", Fog.texture)   # the picture of what's been seen (fog.gd)
	fog.render_priority = 2      # drawn after the sea (0) and the boat's outline (1): over everything
	var quad := QuadMesh.new()
	quad.material = fog
	var screen := MeshInstance3D.new()
	screen.mesh = quad
	screen.extra_cull_margin = 16384.0   # never skipped as "out of view" (the shader moves it)
	add_child(screen)
