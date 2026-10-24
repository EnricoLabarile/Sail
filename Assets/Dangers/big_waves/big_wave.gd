extends Node3D
## ONE BIG WAVE (the prototype's "roller"), made by a wave zone (wave_zone.gd). A crest a few metres long,
## bowed forward in the middle like a crescent, rolling downwind. It builds up, breaks into foam and fades out
## over `duration` seconds (its flipbook plays once over that time). When its crest reaches the boat:
##   - she's going its way (bow within ~66° of its travel): she SURFS it, a push of speed for a while;
##   - otherwise (head-on or broadside): it hits her: half a heart, a shove its way, her speed cut, her bow
##     slewed round.
## A quiet hand helps the player: a wave coming up behind her while she runs with it speeds up to catch her
## (so she can surf), and one about to hit her badly slows down (time to turn away).
## (In Unreal: a small actor moving itself every Tick and testing the player's pawn against its crest.)
##
## The wave's own frame: its -Z (forward) is the way it travels (`direction`); its X is along the crest.
## Its origin is the middle of the line joining the crest's two ends; the crest's middle is `bow` metres ahead.

const DEPTH := 3.0             # metres the picture covers along the travel (the crest in its middle row)
const SURF_COS := 0.4          # she surfs if her heading is within ~66° of the wave's travel (cos 66° = 0.4)
const STRONG_ENOUGH := 0.55    # the wave only does anything while at least this strong (0..1, see strength())

var zone: Node3D               # the zone that made it (it dies down outside it)
var direction := Vector3.FORWARD   # the way it travels (flat, length 1)
var length := 6.0              # metres along the crest
var bow := 0.625               # metres the crest's middle runs ahead of its ends (as drawn in big_wave.png)
var thickness := 1.1           # metres: how thick the crest counts for hitting the boat
var speed := 2.75              # metres a second now…
var base_speed := 2.75         # …and its own pace (the quiet hand changes `speed` round this)
var duration := 5.0            # seconds from rising to gone
var time := 0.0                # its age, in seconds
var hit := false               # has it already reached the boat? (it acts once)

@onready var picture: MeshInstance3D = $Picture


## The zone calls this right after adding it to the world.
func launch(owner_zone: Node3D, spot: Vector3, travel: Vector3, crest_length: float, pace: float, life: float) -> void:
	zone = owner_zone
	direction = travel.normalized()
	length = crest_length
	speed = pace
	base_speed = pace
	duration = life
	global_position = Vector3(spot.x, 0.0, spot.z)
	# Turn it so its -Z points along `direction`: rotation.y = a points -Z to (-sin a, 0, -cos a).
	rotation.y = atan2(-direction.x, -direction.z)
	# The picture: a 1 x 1 m plane, scaled to the crest's length (across) and DEPTH (along the travel).
	picture.scale = Vector3(length, 1.0, DEPTH)
	picture.material_override = picture.material_override.duplicate()   # its own frame
	set_frame(0)


func _process(dt: float) -> void:
	var boat := get_tree().get_first_node_in_group("player_boat") as Node3D
	# 1. Its pace and its age (a wave hurrying after her also lives a little longer).
	var life_rate := 1.0
	if boat:
		life_rate = adjust_pace(boat, dt)
	time += dt * life_rate
	global_position += direction * speed * dt
	# 2. It dies down if it's about to reach land or leave its zone (it jumps to the last quarter of its life).
	var ahead := global_position + direction * 4.0
	if Land.is_land(ahead) or (zone and not zone.is_inside(ahead)):
		time = maxf(time, duration * 0.75)
	if time >= duration:
		queue_free()
		return
	# 3. The flipbook: frame 0 at birth, the last one at the end of its life.
	set_frame(int(time / duration * 16.0))
	# 4. Has its crest reached the boat?
	if boat:
		check_boat(boat)


## How strong it is now, 0..1: it builds up over the first 30% of its life, stays full, fades over the last 30%.
func strength() -> float:
	var p := time / duration
	if p < 0.3:
		return smoothstep(0.0, 1.0, p / 0.3)
	if p < 0.7:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (p - 0.7) / 0.3)


## Where the boat is in the wave's own frame: x = how far ahead of the wave (along its travel), y = where along
## the crest, as a share of half its length (-1 = one end, 0 = the middle, 1 = the other end).
func boat_in_wave(boat: Node3D) -> Vector2:
	var off := boat.global_position - global_position
	off.y = 0.0
	var across := Vector3(-direction.z, 0.0, direction.x)   # along the crest (a right angle to the travel)
	return Vector2(off.dot(direction), off.dot(across) / (length * 0.5))


## The quiet hand (the prototype's rollerPace): a wave coming up behind her while she runs with it hurries to
## her pace plus a little, so it catches her; one about to hit her badly slows to `spare` of its pace.
## Eased, so it never jumps. Gives back how fast its life runs (a hurrying wave lives longer).
func adjust_pace(boat: Node3D, dt: float) -> float:
	var target := base_speed
	var life_rate := 1.0
	if not hit and boat.berth == null:
		var b := boat_in_wave(boat)
		if b.x > -0.5 and b.x < 22.0 and absf(b.y) < 1.2:          # she's just ahead of it, in front of the crest
			var near := minf(1.0, (22.0 - b.x) / 8.0)               # full effect within 14 m, none from 22 m
			var forward: Vector3 = -boat.global_transform.basis.z
			var with_wave := forward.dot(direction)                 # 1 = she runs the wave's way
			if with_wave > SURF_COS:
				# her real pace the wave's way: her own way plus the current carrying her (boat.gd `drift`)
				var her_pace := maxf(0.0, boat.speed * with_wave + boat.drift.dot(direction))
				target = maxf(base_speed, minf(zone.max_pace, her_pace + zone.catch_up * near))
				life_rate = 1.0 - 0.4 * near
			else:
				target = base_speed * (1.0 - (1.0 - zone.spare) * near)
	speed += (target - speed) * minf(1.0, dt * 1.6)
	return life_rate


## The crest reaching the boat: surf or hit, once.
func check_boat(boat: Node3D) -> void:
	if hit or boat.berth != null or boat.sinking:
		return
	var s := strength()
	if s < STRONG_ENOUGH:
		return
	var b := boat_in_wave(boat)
	if absf(b.y) >= 1.0:
		return                                                       # beside the wave, past its ends
	var crest := bow * (1.0 - b.y * b.y)                             # the crest is further ahead in the middle
	var half := thickness * 0.6 * sqrt(1.0 - b.y * b.y) + 0.3        # thinner toward the ends
	if absf(b.x - crest) > half:
		return
	hit = true
	var forward: Vector3 = -boat.global_transform.basis.z
	var with_wave := forward.dot(direction)
	if with_wave > SURF_COS:
		boat.surf_wave()
	else:
		# head-on and broadside are the worst (the prototype's k2): how badly, 0..1
		var badly := s * (0.6 + 0.4 * (1.0 - maxf(0.0, with_wave)))
		boat.hit_by_wave(direction, s, badly, zone.damage)


func set_frame(frame: int) -> void:
	var material: ShaderMaterial = picture.material_override
	material.set_shader_parameter("frame", clampi(frame, 0, 15))
