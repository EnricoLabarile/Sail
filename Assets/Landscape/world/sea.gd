@tool
extends MeshInstance3D
## THE SEA: when the game starts, it puts the fog of war on screen; every frame, it turns the sea's
## texture to follow the wind.
## It also shows this level's shore waves (shore_texture), in the game AND in the editor (@tool): it draws
## with its own copy of the material (material_override) holding this level's picture, so two levels never
## share it. In the editor that copy is taken off just before the scene is saved and put back right after, so
## it never ends up in the level's file.
##
## The fog is a screen effect (Assets/Landscape/world/fog.gdshader): a rectangle that the shader stretches
## over the whole screen, painting black where the boat hasn't been yet, over the sea and any 3D object.
## It's made here in code (and not as a node in the scene) so it doesn't cover the editor's view.

# The sea texture follows the wind (Wind.from_deg), a little late.
@export var follow_time := 5        # seconds: how late the texture turns after the wind
# The drawing points to its RIGHT: that's the way the wind blows in it. With the wind blowing toward the east
# (coming from the west, Wind.from_deg = 270) the drawing isn't turned at all; for any other wind it's turned by
# the difference. That's what the 90 below does: 270 + 90 = 360 = no turn.
@export var texture_turn_deg := 90.0  # change it only if the drawing should point another way (0 = toward the bottom)

# This level's shore picture (made by its ShoreBaker: Bake shore). The waves along the coasts are drawn from it,
# and Land reads it to know how far the coast is (the shallows). Each level picks its own file here.
@export var shore_texture: Texture2D:
	set(value):
		shore_texture = value
		use_shore_picture()          # the waves follow at once, in the editor too

# The fog of war's soft edge (fog.gdshader's falloff): metres it shades off over. 0 = as it comes (about one cell).
@export var fog_falloff := 0.0

var fog_material: ShaderMaterial      # the fog's material (to send it the falloff)
var texture_angle := 0.0              # where the texture is turned now (radians, clockwise from north)
var texture_offset := Vector2.ZERO    # a shift that keeps the water under the boat still while it turns
var sea_material: ShaderMaterial      # this sea's own copy of the material (the shore picture, the angle and the shift)


func _ready() -> void:
	use_shore_picture()
	if Engine.is_editor_hint():
		return                       # in the editor: only the shore waves (no fog, no turning with the wind)
	# The grid of the logbook's squares on the water (sea.gdshader's seam): its size from the world's.
	sea_material.set_shader_parameter("world_size", Land.WORLD_SIZE)
	sea_material.set_shader_parameter("cell_size", Land.WORLD_SIZE / 9.0)   # 9 x 9 squares, as the logbook's map
	Land.set_shore_picture(shore_texture)   # Land reads this level's picture too (how far the coast is: the shallows)
	texture_angle = deg_to_rad(Wind.from_deg + texture_turn_deg)   # start already facing the wind
	add_fog()


## This level's shore picture on the sea: a copy of the material from sea.tscn (made once) with the picture in it,
## worn as material_override, so each level's sea has its own and sea.tscn's stays as it is.
func use_shore_picture() -> void:
	if mesh == null or mesh.material == null:
		return                       # the scene is still loading (the setter can run before the mesh is there)
	if sea_material == null:
		sea_material = mesh.material.duplicate()
	sea_material.set_shader_parameter("shore_tex", shore_texture)
	material_override = sea_material


## In the editor, saving the level: the copy of the material comes off just before (so it isn't written into the
## file) and goes back on right after. (Godot sends these two notifications to every node of the saved scene.)
func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		material_override = null
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		material_override = sea_material


## The fog of war on screen (see the notes at the top).
func add_fog() -> void:
	var fog := ShaderMaterial.new()
	fog.shader = load("res://Assets/Landscape/world/fog.gdshader")
	fog.set_shader_parameter("fog_tex", Fog.texture)   # the picture of what's been seen (fog.gd)
	fog.set_shader_parameter("falloff", fog_falloff)
	fog.set_shader_parameter("world_size", Land.WORLD_SIZE)   # how much of the world the fog picture covers
	fog_material = fog
	fog.render_priority = 3      # drawn after the sea (0), outline and shadows (1), gulls, bombs and land drawings (2): over all but the clouds (4)
	var quad := QuadMesh.new()
	quad.material = fog
	var screen := MeshInstance3D.new()
	screen.mesh = quad
	screen.extra_cull_margin = 16384.0   # never skipped as "out of view" (the shader moves it)
	add_child(screen)


## Every frame: turn the sea's texture toward the wind.
func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return                       # in the editor the sea stays still
	# 0. The fog's soft edge, sent every frame so a change in the Inspector while the game runs shows at once.
	fog_material.set_shader_parameter("falloff", fog_falloff)
	# 1. Where the texture should face: where the wind comes from (+ the extra turn).
	var target := deg_to_rad(Wind.from_deg + texture_turn_deg)
	# 2. Turn toward it a bit each frame, so it gets there about follow_time seconds later.
	#    lerp_angle takes the short way round (from 350 to 10 degrees it goes through 0, not back).
	var new_angle := lerp_angle(texture_angle, target, minf(1.0, dt / follow_time))
	# 3. Turn round the boat, not round the middle of the map: far from home a small turn round the middle
	#    would make the water slide a long way. So the point of the sea under the boat must stay where it is:
	#    work out where that point is in the texture with the old angle and with the new one, and shift the
	#    texture by the difference. (When the angle doesn't change, the shift doesn't either: as she sails,
	#    the drawing stays fixed on the water.)
	var boat := get_tree().get_first_node_in_group("player_boat")
	if boat:
		var under_boat := Vector2(boat.global_position.x, boat.global_position.z)
		texture_offset += under_boat.rotated(-texture_angle) - under_boat.rotated(-new_angle)
	texture_angle = new_angle
	# 4. Send both to the sea's shader (sea.gdshader).
	sea_material.set_shader_parameter("wind_angle", texture_angle)
	sea_material.set_shader_parameter("wind_offset", texture_offset)
