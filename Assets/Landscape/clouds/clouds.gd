extends Node3D
## CLOUDS: flat pictures (image planes) high above the sea, drifting with the wind.
##
## When the game starts it makes cloud_count clouds, each a flat square (a PlaneMesh) showing one of the
## pictures in cloud_textures, at a random place on the map, a random size and a random turn. Every frame
## they all move downwind (the way the wind blows, from the Wind autoload), and a cloud that drifts off one
## edge of the map comes back in from the opposite edge.
## How solid each bit of a cloud is comes from the picture itself (its alpha, the PNG's transparency): the
## clouds are cut out in dots (cloud.gdshader), each pixel either cloud or sea, the soft edge made of dots.
## The clouds cast shadows on everything under them (sea, land, boat): a small camera looks down on the
## clouds alone and makes a "cloud map" (a SubViewport, like a Scene Capture 2D in Unreal), and a screen
## effect (cloud_shadow.gdshader) darkens every point of the world that has a cloud over it on that map.
## The cloud map sees soft copies of the clouds (the old see-through material, on a render layer of their own
## that only its camera sees), so the shadows keep their smooth edge.
## (In Unreal: a few planes with a masked unlit material, moved every Tick.)

@export var cloud_textures: Array[Texture2D] = []   # the pictures: the clouds use them in turn
@export var cloud_count := 64        # how many clouds over the whole map
@export var size_min := 30.0         # metres: the smallest cloud, a side…
@export var size_max := 50.0         # …and the biggest
@export var height := 35.0           # metres above the sea
@export var speed := 2.0             # metres a second they drift downwind

# The shadows.
@export var shadows_on := true                          # false = no shadows
@export var shadow_offset := Vector3(4.0, 0.0, 4.0)     # where a cloud's shadow falls on the sea, from the cloud, in
														# metres: +X = east (right), +Z = south (down). It sets the "sun"
@export var shadow_opacity := 0.35                      # how dark: 0 = invisible, 1 = solid black
@export var shadow_area := 160.0                        # metres round the boat the cloud map covers (bigger than the screen)
@export var shadow_resolution := 256                    # pixels a side of the cloud map (more = sharper, a bit dearer)
@export var shadow_updates_per_second := 10.0           # how often the cloud map is drawn again (not every frame: the
														# clouds move 0.2 m in a tenth of a second, less than a map pixel)

@export var opacity := 1.0          # how solid the clouds are: less = fewer dots kept (cloud.gdshader)

# The soft copies for the cloud map are on render layer 3 (value 4): the cloud-map camera sees only that layer,
# and the game's camera (Boat/Camera3D, its Cull Mask) leaves it out.
const MAP_LAYER := 4

const WORLD_SIZE := 504.0            # the map, a side (as Land.WORLD_SIZE): clouds wrap round inside it

var clouds: Array[MeshInstance3D] = []
var map_copies: Array[MeshInstance3D] = []   # map_copies[i] is the soft copy of clouds[i], for the cloud map
var map_camera: Camera3D            # the camera looking down on the clouds (makes the cloud map)
var map_wait := 0.0                 # seconds left before the cloud map is drawn again
var shadow_material: ShaderMaterial # the screen effect that draws the shadows (cloud_shadow.gdshader)


func _ready() -> void:
	set_sun_direction()
	if cloud_textures.is_empty():
		return                       # no pictures given: no clouds
	# Two materials per picture (clouds with the same picture share them): the dotted one for the game, the
	# soft see-through one for the cloud map.
	var materials: Array[ShaderMaterial] = []
	var soft_materials: Array[StandardMaterial3D] = []
	for texture in cloud_textures:
		materials.append(make_material(texture))
		soft_materials.append(make_soft_material(texture))
	# The clouds, using the pictures in turn, each with its soft copy for the map (same mesh, same place).
	for i in cloud_count:
		var cloud := make_cloud(materials[i % materials.size()])
		add_child(cloud)
		clouds.append(cloud)
		var copy := MeshInstance3D.new()
		copy.mesh = cloud.mesh
		copy.material_override = soft_materials[i % soft_materials.size()]
		copy.layers = MAP_LAYER
		copy.transform = cloud.transform
		add_child(copy)
		map_copies.append(copy)
	if shadows_on:
		add_cloud_map()
		add_shadow_effect()


## The game's cloud material: the picture cut out in dots (cloud.gdshader).
func make_material(texture: Texture2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://Assets/Landscape/clouds/cloud.gdshader")
	material.set_shader_parameter("cloud_tex", texture)
	material.set_shader_parameter("opacity", opacity)
	return material


## The cloud map's material: the picture as it is, see-through where the PNG is (alpha), no light, both faces.
## Soft, so the shadows made from it keep a smooth edge.
func make_soft_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## The "sun" for everything that fakes its light (the boat: Assets/Boat/fake_light.gdshaderinc), so it's lit
## from where the clouds' shadows say: a shadow falls shadow_offset sideways while dropping `height`, so the
## sun is the other way, up. It's a global shader parameter (Project Settings > Shader Globals: sun_direction;
## in Unreal a Material Parameter Collection), so every material can read it.
func set_sun_direction() -> void:
	var toward_sun := Vector3(-shadow_offset.x, height, -shadow_offset.z).normalized()
	RenderingServer.global_shader_parameter_set("sun_direction", toward_sun)


## The cloud map: a SubViewport (an off-screen picture, like a Render Target in Unreal) with a camera
## looking straight down from above the clouds. The camera sees only the clouds' layer, on a see-through
## background, so the picture's alpha is where the clouds are. It's redrawn every frame (12 squares: cheap).
## The SubViewport is inside the game's world, so it sees the same clouds.
func add_cloud_map() -> void:
	var map := SubViewport.new()
	map.size = Vector2i(shadow_resolution, shadow_resolution)
	map.transparent_bg = true                                  # no clouds = see-through
	map.render_target_update_mode = SubViewport.UPDATE_ONCE    # drawn now, then again shadow_updates_per_second times a second
	add_child(map)
	map_camera = Camera3D.new()
	map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	map_camera.size = shadow_area                 # metres it sees, a side
	map_camera.cull_mask = MAP_LAYER              # only the clouds' soft copies
	map_camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)   # looking straight down, north at the top
	map_camera.position = Vector3(0.0, height + 10.0, 0.0)
	map_camera.far = 30.0
	map.add_child(map_camera)


## The screen effect that draws the shadows (cloud_shadow.gdshader): a rectangle stretched over the screen
## by its shader, like the fog. It's handed the cloud map and how it lies on the sea.
func add_shadow_effect() -> void:
	shadow_material = ShaderMaterial.new()
	shadow_material.shader = load("res://Assets/Landscape/clouds/cloud_shadow.gdshader")
	shadow_material.render_priority = 1   # after the sea (0), before the fog (3) (the clouds are solid: drawn earlier)
	shadow_material.set_shader_parameter("cloud_map", map_camera.get_viewport().get_texture())
	shadow_material.set_shader_parameter("map_size", shadow_area)
	shadow_material.set_shader_parameter("cloud_height", height)
	# The sun's slant: the shadow moves shadow_offset sideways while falling the clouds' height.
	shadow_material.set_shader_parameter("sun_shift", Vector2(shadow_offset.x, shadow_offset.z) / height)
	shadow_material.set_shader_parameter("shadow_opacity", shadow_opacity)
	var quad := QuadMesh.new()
	quad.material = shadow_material
	var screen := MeshInstance3D.new()
	screen.mesh = quad
	screen.extra_cull_margin = 16384.0   # never skipped as "out of view" (the shader moves it)
	add_child(screen)


## Keeps the cloud map over the boat (so it covers what's on screen). It moves in steps of one pixel of
## the map, so the shadows don't shimmer as she sails.
func follow_boat() -> void:
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat == null:
		return
	var pixel := shadow_area / float(shadow_resolution)   # metres one pixel of the map covers
	var center := Vector2(snappedf(boat.global_position.x, pixel), snappedf(boat.global_position.z, pixel))
	map_camera.position.x = center.x
	map_camera.position.z = center.y
	shadow_material.set_shader_parameter("map_center", center)


## One cloud: a flat square lying level (a PlaneMesh faces up), at a random place, size and turn.
func make_cloud(material: ShaderMaterial) -> MeshInstance3D:
	var side := randf_range(size_min, size_max)
	var plane := PlaneMesh.new()
	plane.size = Vector2(side, side)
	var cloud := MeshInstance3D.new()
	cloud.mesh = plane
	cloud.material_override = material
	var half := WORLD_SIZE / 2.0
	cloud.position = Vector3(randf_range(-half, half), height, randf_range(-half, half))
	
	return cloud


## Every frame: move every cloud downwind, and wrap it round at the map's edges.
func _process(dt: float) -> void:
	# Downwind: the opposite of where the wind comes from.
	var step := -Wind.from_vector() * speed * dt
	var half := WORLD_SIZE / 2.0
	for cloud in clouds:
		cloud.position += step
		# wrapf keeps a number inside a range: past one edge, it comes back from the other.
		cloud.position.x = wrapf(cloud.position.x, -half, half)
		cloud.position.z = wrapf(cloud.position.z, -half, half)
	# The soft copies follow their clouds.
	for i in map_copies.size():
		map_copies[i].position = clouds[i].position
	# The cloud map: a few times a second it moves over the boat and is drawn once more (UPDATE_ONCE). Not every
	# frame: it's a second picture of the world, and drawing it costs about as much as a small scene.
	if map_camera != null:
		map_wait -= dt
		if map_wait <= 0.0:
			map_wait = 1.0 / shadow_updates_per_second
			follow_boat()
			map_camera.get_viewport().render_target_update_mode = SubViewport.UPDATE_ONCE
