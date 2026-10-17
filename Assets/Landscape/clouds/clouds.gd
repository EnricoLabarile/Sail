extends Node3D
## CLOUDS: flat pictures (image planes) high above the sea, drifting with the wind.
##
## When the game starts it makes cloud_count clouds, each a flat square (a PlaneMesh) showing one of the
## pictures in cloud_textures, at a random place on the map, a random size and a random turn. Every frame
## they all move downwind (the way the wind blows, from the Wind autoload), and a cloud that drifts off one
## edge of the map comes back in from the opposite edge.
## How see-through each bit of a cloud is comes from the picture itself (its alpha, the PNG's transparency).
## (In Unreal: a few planes with a translucent unlit material, moved every Tick.)

@export var cloud_textures: Array[Texture2D] = []   # the pictures: the clouds use them in turn
@export var cloud_count := 12        # how many clouds over the whole map
@export var size_min := 20.0         # metres: the smallest cloud, a side…
@export var size_max := 40.0         # …and the biggest
@export var height := 15.0           # metres above the sea
@export var speed := 2.0             # metres a second they drift downwind

const WORLD_SIZE := 504.0            # the map, a side (as Land.WORLD_SIZE): clouds wrap round inside it

var clouds: Array[MeshInstance3D] = []


func _ready() -> void:
	if cloud_textures.is_empty():
		return                       # no pictures given: no clouds
	# One material per picture (clouds with the same picture share it).
	var materials: Array[StandardMaterial3D] = []
	for texture in cloud_textures:
		materials.append(make_material(texture))
	# The clouds, using the pictures in turn.
	for i in cloud_count:
		var cloud := make_cloud(materials[i % materials.size()])
		add_child(cloud)
		clouds.append(cloud)


## A material that shows the picture as it is: no light on it (unshaded), see-through where the PNG is
## (alpha), both faces drawn.
func make_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 1     # see-through things: drawn after the sea (0), before the fog (2)
	return material


## One cloud: a flat square lying level (a PlaneMesh faces up), at a random place, size and turn.
func make_cloud(material: StandardMaterial3D) -> MeshInstance3D:
	var side := randf_range(size_min, size_max)
	var plane := PlaneMesh.new()
	plane.size = Vector2(side, side)
	var cloud := MeshInstance3D.new()
	cloud.mesh = plane
	cloud.material_override = material
	var half := WORLD_SIZE / 2.0
	cloud.position = Vector3(randf_range(-half, half), height, randf_range(-half, half))
	cloud.rotation.y = randf() * TAU   # turned any way, so the same picture looks different
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
