extends Node3D
## ONE BOMB, dropped off the boat's bow (the bomb button, Assets/UI/bomb_button). It floats where it fell, carried by the current (drift_with_current), its
## fuse burning (the picture blinks, quicker and quicker, and swells and shrinks once a second), and after `fuse_time` seconds it blows up: everything
## within `blast_radius` loses `damage` hearts, and the screen shakes hard. The sea imps (sea_imp_zone.gd hit_imp_at, only while they're out
## of the water) and the boat too, if she's still that close: drop it ahead of an enemy's path, then get away.
## (In Unreal: a small actor with a timer that does a radial damage, then destroys itself.)

@export var fuse_time := 2.0         # seconds from dropping it to the blast
@export var blast_radius := 8      # metres the blast reaches
@export var damage := 1.0            # hearts it takes off whatever is in reach
@export var blast_time := 0.4        # seconds the blast's flash lasts (it grows and fades)
@export var shake_strength := 1.5    # metres the view jumps about when it goes off (being hurt shakes 0.5)
@export var shake_time := 0.6        # seconds that shake lasts, dying away
@export var pulse_time := 1.0        # seconds for one pulse: it shrinks and swells back once (Enrico: one a second)
@export var pulse_amount := 0.15     # how much it grows and shrinks: 0.15 = from 15% smaller to 15% bigger
@export var current_amount := 3    # how much the current carries it: 0 = not at all, 1 = like the boat


@onready var picture: MeshInstance3D = $Picture   # the bomb, facing the camera (a 2-frame sheet: dark, fuse lit)
@onready var blast: MeshInstance3D = $Blast       # the flash on the water when it goes off

var time := 0.0          # seconds since it was dropped
var exploded := false
var picture_scale := Vector3.ONE   # the Picture's own scale, as set in bomb.tscn (the pulse goes round it)


func _ready() -> void:
	picture.material_override = picture.material_override.duplicate()   # its own frame
	blast.material_override = blast.material_override.duplicate()       # its own fade
	blast.visible = false
	picture_scale = picture.scale    # whatever size it was given in the scene is its middle size


func _process(dt: float) -> void:
	time += dt
	if not exploded:
		# The fuse: the spark blinks, a little quicker as the blast nears.
		var blinks_per_second := lerpf(2.0, 8.0, time / fuse_time)
		var lit := int(time * blinks_per_second) % 2
		picture.material_override.set_shader_parameter("frame", lit)
		pulse()
		drift_with_current(dt)
		if time >= fuse_time:
			explode()
		return
	# The blast: a disc on the water growing to blast_radius and fading out, then the bomb is gone.
	var share := minf(1.0, (time - fuse_time) / blast_time)
	blast.scale = Vector3.ONE * blast_radius * (0.3 + 0.7 * share)
	var material: StandardMaterial3D = blast.material_override
	material.albedo_color.a = 1.0 - share
	if share >= 1.0:
		queue_free()


## While the fuse burns it swells and shrinks: one full cycle every pulse_time seconds. sin() goes smoothly from
## 0 up to 1, down to -1 and back to 0 over one cycle, so the size goes 1 → bigger → smaller → 1.
func pulse() -> void:
	var cycle := sin(time / pulse_time * TAU)          # TAU = a full circle (2 × PI): one cycle a pulse_time
	picture.scale = picture_scale * (1.0 + pulse_amount * cycle)


## While the fuse burns it floats: the current (the Wind autoload's, Wind.current(), downwind) carries it, as it
## does the boat and a dead imp. It stops where the next step would be on land, so it washes up against the shore.
## (Once it has blown up it stays put: the blast is where it went off.)
func drift_with_current(dt: float) -> void:
	var next_place: Vector3 = global_position + Wind.current() * current_amount * dt
	next_place.y = global_position.y	
	if not Land.is_land(next_place):
		global_position = next_place


## Boom: the bomb's picture goes, the flash shows, and everything in reach is hit.
func explode() -> void:
	exploded = true
	Sfx.bomb_blast()
	picture.visible = false
	blast.visible = true
	# The sea imps (each zone looks after its own imp).
	for zone in get_tree().get_nodes_in_group("sea_imps"):
		zone.hit_imp_at(global_position, blast_radius, damage)
	# The barrels in reach break open (barrel.gd), leaving what was inside.
	for barrel in get_tree().get_nodes_in_group("barrels"):
		barrel.blast_at(global_position, blast_radius)
	# The boat, if she's still too close.
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat:
		var off := boat.global_position - global_position
		off.y = 0.0
		if off.length() <= blast_radius:
			boat.take_damage(damage)
		# A powerful screen shake, wherever she is (the camera is the boat's: boat_camera.gd).
		boat.camera.shake_hard(shake_strength, shake_time)
