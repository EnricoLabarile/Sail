extends Node3D
## ONE BOMB, dropped off the boat's bow (the bomb button, Assets/UI/bomb_button). It floats where it fell, carried by the current (drift_with_current),
## leaving a trail of white dots on the water behind it (the Trail particles, Enrico: so the player sees which way it drifts), its
## fuse burning (the picture blinks, quicker and quicker, and swells and shrinks once a second), and after `fuse_time` seconds it blows up.
## The blast has two parts (Enrico): a tight CIRCLE round the bomb, `blast_radius` metres, and long straight lines, the ARMS
## (like Bomberman), `arm_length` metres long and `arm_width` wide: a CROSS (4 arms: north, east, south, west) or a
## DOUBLE_CROSS (8: the diagonals too), set by `pattern` (a basic bomb and an advanced one). Whatever is in the circle or on an
## arm loses `damage` hearts: the sea imps (sea_imp_zone.gd hit_imp_at, only while they're out of the water), the other enemies (group
## "bomb_targets": blast_at, e.g. the sea urchins), the barrels,
## and the boat too; between two arms, outside the circle, she's safe. While the fuse burns the circle and the arms show
## faintly on the water (where it will hit); at the blast the circle flashes and the arms shoot out white.
## The screen shakes hard wherever she is.
## (In Unreal: a small actor with a timer that does a few line traces for damage, then destroys itself.)

@export var fuse_time := 2.0         # seconds from dropping it to the blast
enum Pattern { CROSS, DOUBLE_CROSS }   # 4 arms, or 8 (the diagonals too)
@export var pattern := Pattern.CROSS   # CROSS = the basic bomb, DOUBLE_CROSS = the advanced one
@export var blast_radius := 6.0      # metres round the bomb the blast reaches every way (Enrico: fairly tight)
@export var arm_length := 10.0       # metres each arm of the blast reaches, from the bomb's middle (Enrico: far)
@export var arm_width := 4.0	         # metres wide each arm is (what's within half of it from the arm's line is hit)
@export var warning_opacity := 0.0  # how strongly the circle and arms show on the water while the fuse burns (0 = not at all)
@export var damage := 1.0            # hearts it takes off whatever is in reach
@export var blast_time := 0.4        # seconds the blast's flash lasts (it grows and fades)
@export var shake_strength := 1.5    # metres the view jumps about when it goes off (being hurt shakes 0.5)
@export var shake_time := 0.6        # seconds that shake lasts, dying away
@export var pulse_time := 1.0        # seconds for one pulse: it shrinks and swells back once (Enrico: one a second)
@export var pulse_amount := 0.15     # how much it grows and shrinks: 0.15 = from 15% smaller to 15% bigger
@export var current_amount := 3    # how much the current carries it: 0 = not at all, 1 = like the boat


@onready var picture: MeshInstance3D = $Picture   # the bomb, facing the camera (a 2-frame sheet: dark, fuse lit)
@onready var blast: MeshInstance3D = $Blast       # the circle on the water round the bomb (a 1 m disc scaled to blast_radius)
@onready var trail: CPUParticles3D = $Trail       # white dots it leaves on the water as it drifts (Enrico: shows which way it goes)

var time := 0.0          # seconds since it was dropped
var exploded := false
var picture_scale := Vector3.ONE   # the Picture's own scale, as set in bomb.tscn (the pulse goes round it)
var arms: Array[MeshInstance3D] = []   # the white strips on the water, one per arm (made in make_arms)


func _ready() -> void:
	picture.material_override = picture.material_override.duplicate()   # its own frame
	blast.material_override = blast.material_override.duplicate()       # its own fade
	show_circle(1.0, warning_opacity)   # the circle shows faintly while the fuse burns, like the arms
	picture_scale = picture.scale    # whatever size it was given in the scene is its middle size
	make_arms()


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
	# The blast: the circle flashes white, growing from 60% to its full size, and the arms shoot out to their full
	# length in the first third of blast_time; all of it fades out meanwhile. Then the bomb is gone.
	var share := minf(1.0, (time - fuse_time) / blast_time)
	var reach := arm_length * minf(1.0, share * 3.0)
	set_arms(reach, 1.0 - share)
	show_circle(0.6 + 0.4 * share, 1.0 - share)
	if share >= 1.0:
		queue_free()


## The circle on the water: `size` of blast_radius (1 = full), `opacity` 0..1 (1 = solid white).
func show_circle(size: float, opacity: float) -> void:
	blast.visible = opacity > 0.0
	blast.scale = Vector3(blast_radius * size, 1.0, blast_radius * size)   # the disc is 1 m across its radius
	var material: StandardMaterial3D = blast.material_override
	material.albedo_color.a = opacity


## The directions the arms point, flat on the water: 4 (north, east, south, west) or 8 (the diagonals too).
## Each is a one-metre-long arrow; a step of a quarter turn (4 arms) or an eighth (8 arms) between them.
func arm_directions() -> Array[Vector3]:
	var count := 4
	if pattern == Pattern.DOUBLE_CROSS:
		count = 8
	var directions: Array[Vector3] = []
	for i in count:
		var angle := TAU * i / count
		directions.append(Vector3(sin(angle), 0.0, -cos(angle)))   # angle 0 = north (−Z), then clockwise seen from above
	return directions


## Is this point in the blast? It is if it's inside the circle (blast_radius round the bomb), or on one of the arms (no
## further along it than arm_length, and no further to its side than half arm_width). `extra` makes everything that much bigger: a barrel is hit
## if any part of it is touched, so it passes its own radius.
func in_blast(point: Vector3, extra := 0.0) -> bool:
	var off := point - global_position
	off.y = 0.0
	if off.length() <= blast_radius + extra:
		return true                                   # inside the circle round the bomb
	var half_width := arm_width * 0.5 + extra
	for direction in arm_directions():
		var along := off.dot(direction)               # how far along this arm the point is
		if along < 0.0 or along > arm_length + extra:
			continue                                  # behind the arm, or past its end
		var aside := (off - direction * along).length()   # how far from the arm's line, sideways
		if aside <= half_width:
			return true
	return false


## The arms' pictures: a flat white strip on the water per arm (made here in code, so changing `pattern` or the
## sizes in the Inspector is all it takes). Each strip is one metre long and starts at the bomb; set_arms stretches it.
func make_arms() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = 2
	material.albedo_color = Color(0.92, 0.9, 0.86, warning_opacity)   # the blast's paper white
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(arm_width, 1.0)
	mesh.center_offset = Vector3(0.0, 0.0, -0.5)      # from the bomb (z 0) out to z −1: forward, so its far end is the arm's tip
	for direction in arm_directions():
		var arm := MeshInstance3D.new()
		arm.mesh = mesh
		arm.material_override = material              # one material for all the arms: they fade together
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arm.position.y = 0.08                         # just above the water
		arm.rotation.y = atan2(-direction.x, -direction.z)   # turn its forward (−Z) to the arm's direction
		add_child(arm)
		arms.append(arm)
	set_arms(arm_length, warning_opacity)


## Stretch every arm to `length` metres and set how see-through they are (1 = solid white).
func set_arms(length: float, opacity: float) -> void:
	for arm in arms:
		arm.scale = Vector3(1.0, 1.0, maxf(0.01, length))
		arm.visible = opacity > 0.0
	if not arms.is_empty():
		var material: StandardMaterial3D = arms[0].material_override
		material.albedo_color.a = opacity


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


## Boom: the bomb's picture goes, the circle and the arms flash out, and everything in them is hit (in_blast).
func explode() -> void:
	exploded = true
	Sfx.bomb_blast()
	picture.visible = false
	trail.emitting = false            # no more dots once it's gone off
	# The sea imps (each zone looks after its own imp): one in the circle or on an arm is hit. hit_imp_at is given the
	# imp's own place, so its own distance check always passes; it still checks the imp is out of the water.
	for zone in get_tree().get_nodes_in_group("sea_imps"):
		var imp_place: Vector3 = zone.imp.global_position
		if in_blast(imp_place):
			zone.hit_imp_at(imp_place, 0.1, damage)
	# Every other enemy (group "bomb_targets", Enrico: every new enemy can be bombed): each one decides for itself
	# whether the blast touches it (its own blast_at, e.g. sea_urchin.gd).
	for target in get_tree().get_nodes_in_group("bomb_targets"):
		target.blast_at(self)
	# The barrels the blast touches break open (barrel.gd), leaving what was inside.
	for barrel in get_tree().get_nodes_in_group("barrels"):
		barrel.blast_at(self)
	# The boat, if she's in the circle or on an arm (between two arms, outside the circle, she's safe).
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	if boat:
		if in_blast(boat.global_position):
			boat.take_damage(damage)
		# A powerful screen shake, wherever she is (the camera is the boat's: boat_camera.gd).
		boat.camera.shake_hard(shake_strength, shake_time)
