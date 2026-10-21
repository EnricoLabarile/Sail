extends Node3D
## ONE SLINGSHOT STONE (made by the slingshot, Assets/UI/slingshot/slingshot.gd): it flies in an arc from the
## bow to where it lands, with its shadow on the water below it; landing in the water it plays its splash once
## and is gone; landing on land it's simply gone (as in the prototype).
## (In Unreal: a small projectile actor that moves itself along a curve, then plays a flipbook and destroys itself.)
##
## Its picture is a sheet of frames (stone.png, frames_x × frames_y): frame 0 is the stone in flight, the rest
## (1 to the last) the splash.

@export var frames_x := 4            # frames across the sheet (as the picture you draw)
@export var frames_y := 4            # frames down
@export var splash_fps := 12.0       # frames a second of the splash
@export var shadow_opacity := 0.35   # how dark its shadow is (the clouds' shadows are 0.35)

@onready var picture: MeshInstance3D = $Picture   # the stone (and later the splash), facing the camera
@onready var shadow: MeshInstance3D = $Shadow     # the spot of ink on the water

var from := Vector3.ZERO       # where it was shot from
var to := Vector3.ZERO         # where it lands (on the water)
var flight_time := 0.7         # seconds in the air
var arc_height := 2.9          # metres the arc rises above the straight line
var time := 0.0                # seconds since it was shot
var splash_time := -1.0        # seconds since it hit the water (-1 = still flying)
var shadow_slide := Vector2.ZERO   # how far the shadow slides on the water for every metre of height (as the clouds')


## The slingshot calls this right after adding the stone to the world.
func launch(start: Vector3, end: Vector3, seconds: float, height: float) -> void:
	from = start
	to = end
	flight_time = seconds
	arc_height = height
	# Each stone has its own copy of the materials (so each shows its own frame).
	picture.material_override = picture.material_override.duplicate()
	shadow.material_override = shadow.material_override.duplicate()
	set_frame(0)
	shadow.material_override.set_shader_parameter("opacity", shadow_opacity)
	# The shadow falls the way the clouds' shadows do (clouds.gd): a cloud `height` up casts its shadow
	# `shadow_offset` away, so for every metre the stone is up its shadow slides shadow_offset / height.
	var clouds := get_tree().get_first_node_in_group("clouds")
	if clouds != null:
		shadow_slide = Vector2(clouds.shadow_offset.x, clouds.shadow_offset.z) / clouds.height
	place(0.0)


func _process(dt: float) -> void:
	# 1. Flying: along the line, up and down in an arc.
	if splash_time < 0.0:
		time += dt
		var t := minf(time / flight_time, 1.0)
		place(t)
		if t >= 1.0:
			land()
		return
	# 2. Splashing: frame 1, 2, … then gone.
	splash_time += dt
	var frame := 1 + int(splash_time * splash_fps)
	if frame >= frames_x * frames_y:
		queue_free()
		return
	set_frame(frame)


## Puts the stone where it is at this moment of its flight (t: 0 = just shot, 1 = landing), and its shadow under it.
func place(t: float) -> void:
	var ground := from.lerp(to, t)   # the point on the straight line from the bow to the landing spot
	# The height: from the bow's height down to the water, plus the arc (4 t (1 - t) is 0 at both ends, 1 in the middle).
	var height := from.y * (1.0 - t) + arc_height * 4.0 * t * (1.0 - t)
	picture.global_position = Vector3(ground.x, height, ground.z)
	# The shadow: on the water under it, slid a little away from the sun the higher it is.
	var slide := shadow_slide * height
	shadow.global_position = Vector3(ground.x + slide.x, 0.02, ground.z + slide.y)


## Landed: in the water a splash (its sound and its frames); on land it's simply gone.
## Either way every sea imp's zone is told where it fell, so an imp that's up there is hit (sea_imp_zone.gd).
func land() -> void:
	for zone in get_tree().get_nodes_in_group("sea_imps"):
		zone.stone_landed(to)
	if Land.is_land(to):
		queue_free()
		return
	splash_time = 0.0
	shadow.visible = false
	picture.global_position = Vector3(to.x, 0.0, to.z)   # the splash rises from the water
	set_frame(1)
	Sfx.stone_splash()


func set_frame(frame: int) -> void:
	var material: ShaderMaterial = picture.material_override
	material.set_shader_parameter("frame", frame)
	material.set_shader_parameter("frames_x", frames_x)
	material.set_shader_parameter("frames_y", frames_y)
