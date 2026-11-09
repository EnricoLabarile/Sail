extends Node3D
## THE PADDLES (Enrico: the paddle wheels on her sides, worked by a lever; everything about them lives here, apart
## from the boat). On the `Paddles` node in boat.tscn, which holds the two wheels (paddle_wheel.tscn, a stand-in).
## (In Unreal: an Actor Component on the boat Pawn.)
##
## They're always fitted (Enrico, Nov 2026: no longer an item to switch on and off), and the throttle lever is always
## on the screen (Assets/UI/crank/crank.gd, Enrico, Nov 2026: a lever, no longer a crank turned round).
##
## THE HEAT (Enrico, Nov 2026: an overheat bar, it replaced the battery that ran down): `heat` goes from 0 (cold) to
## `max_heat`. While she runs (not overheated, the anchor up) they push her forward whichever way her bow points, at
## the boat's `top_speed` × the lever's share (Enrico: the one number for her speed is boat.gd's top_speed).
## What heats the engine up:
##   - BOOSTING, the lever held past the middle (`heat_rate()`); at the middle or below nothing, so cruising is free;
##   - a BOMB dropped (`add_heat(share)`, bomb_button.gd: a fixed share of the bar);
##   - an ENEMY hitting her (`take_hit()`, from boat.gd hit_by_enemy: `hit_heat` of the bar).
## It COOLS DOWN BY ITSELF: `cool_delay` seconds after the last boost it falls at `cool_rate`, but only while she's
## UNDER WAY (Enrico: not standing still, at anchor or with the lever pulled back). A booster cools it (`cool`).
## When the heat reaches `max_heat` she's AT THE BRINK (Enrico, Nov 2026: the vent window is a time again): she keeps
## going for `vent_window` seconds, and the lever pushed all the way right in that time (a grab that began in it) VENTS
## her (`vent()`: cold again), so a player who reacts in time never stops. If the window runs out, she OVERHEATS: the
## signal `overheated` (the boat blinks black, boat.gd) and she stops pushing until the lever goes all the way right
## (`turn_on`: cold again). All the way left TURNS HER OFF (the anchor goes down).
## THE STEAM: little puffs rising from her, more of them the hotter she is (see the steam, at the bottom).
## The current still carries her (the boat's).
##
## THE SPEED SETTING (Enrico): the lever's place says how fast she may go: all the way left 0%, in the middle (where its
## spring holds it) 50%, all the way right 100% (`set_lever_share(share)`, every frame from the lever; boat.gd multiplies
## her target speed by `speed_share()`). Not a brake: only the most she may reach.
##
## Their sound (Enrico, the prototype's): a low soft splash for every other paddle that comes round (4 a turn of the
## wheel, Sfx.paddle_splash) while they work; when the push ends it dies down as she slows (splash_level).
##
## The boat (boat.gd) calls: push_speed() and bite (her speed), speed_share(), turn_factor() (turning), update(dt)
## every frame, stop() when she's back home after sinking. The lever calls: is_running(), can_vent(), turn_on(),
## vent(), turn_off(), set_lever_share().


## Sent when she's started (turn_on) or vented (vent): the lever's flywheel revs up (crank.gd).
signal revved
## Sent the moment she overheats (heat at max_heat): the boat blinks black (boat.gd).
signal overheated

@export var max_heat := 40.0           # how much heat she takes before overheating (in seconds of the heating below)
## Heat a second of boosting adds with the lever all the way right (Enrico's knob): with max_heat 40 and 40 here, she
## overheats after 1 s of full boost from cold. Between the middle (nothing) and the right end it grows in a straight
## line; at the middle and below nothing.
@export var boost_heat := 40.0
## Seconds the lever must be HELD before pushing it past the middle counts as a boost and heats her (Enrico: the same
## move right vents her, so right after a vent or a grab it mustn't heat her at once). Counted from the grab and again
## from each vent (crank.gd sets `boost_counts`). Let go, no more heating at once, while the lever (and her speed)
## springs back to the middle.
@export var boost_wait := 0.25
@export var hit_heat := 0.25           # share of the bar an enemy's hit adds (0.25 = a quarter; boat.gd hit_by_enemy)
@export var cool_delay := 0.5          # seconds after the last boost before she starts cooling down (Enrico)
@export var cool_rate := 8.0           # heat she loses each second once she cools (8: from overheated to cold in 5 s)
@export var cool_min_speed := 0.5      # m/s she must be going to cool down by itself (slower = standing still: no)
@export var vent_window := 1.5         # seconds she keeps going at full heat before she overheats: the lever pushed right meanwhile vents her (Enrico)
@export var turn_mult := 1.5           # she turns this much quicker while they push
@export var take_up_rate := 3.75            # how quickly they take up and let go as a push starts or ends
@export var bite := 5.25               # how quickly her speed catches up with their push
@export var paddle_radius := 0.7       # metres: the wheels' size (to turn them as fast as the water goes by)
## How fast the wheels LOOK like they turn, as a share of "as fast as the water goes by" (Enrico: at her top speed the
## real rate was ~4.5 turns a second, a blur). Only the look and the splashes: her speed doesn't change. 1 = real.
@export var spin_scale := 0.35
@export var half_beam := 1.75          # metres from her middle to each wheel (turning, the two go at different speeds)
# The smoke (Enrico): white puffs rising from her chimney (the Marker3D `SmokeAttach` in boat.tscn, under Model, so
# it rocks with her; move it in the viewport to move the smoke). Nov 2026: always some while she runs, more the hotter
# she is, and a thick plume when she's overheated.
@export var steam_puffs_least := 4.0   # puffs a second while she runs cold (Enrico: the smoke always shows under way)
@export var steam_puffs_most := 14.0   # puffs a second while she runs at full heat (in between: in a straight line)
@export var steam_from := 0.1          # stopped (at anchor, tied up): share of the heat bar below which there's no smoke
@export var steam_rise := 1.5          # metres a second a puff rises
@export var steam_time := 1.4          # seconds a puff lives (it grows and fades meanwhile)
@export var steam_size_start := 0.25   # a puff's radius when it appears, metres…
@export var steam_size_end := 1.0      # …and when it's gone
@export var steam_alpha := 1.0         # how solid a puff is when it appears (it stays so for its first half, then fades)
@export var steam_drift := 1.2         # metres a second the wind carries a puff (downwind, Wind.from_vector), so it trails
@export var steam_spread := 0.4        # metres a second each puff wanders sideways at random, so they don't sit in one blob
@export_group("Engine sound")
## The engine's chuff-chuff (Sfx.engine, Enrico, Nov 2026): how "revved" it sounds, 0..1, follows the lever's place
## (where she's allowed to go) and her real speed, half each; boosting adds `boost_rev`; started or vented (signal
## `revved`) it kicks up by `rev_kick` for `rev_kick_time` seconds, fading, like an engine revving up.
@export var boost_rev := 0.3
@export var rev_kick := 0.6
@export var rev_kick_time := 1.0
@export_group("Overheated smoke")
@export var overheat_puffs := 30.0     # puffs a second while she's overheated (the thick plume)
@export var overheat_size := 1.5       # the puffs × this big while she's overheated
@export var overheat_time := 2.0       # seconds an overheated puff lives
@export var overheat_rise := 2.5       # metres a second it rises
@export var overheat_spread := 1.0     # metres a second it wanders sideways (a wider plume)
@export_group("")

const MAX_PUFFS := 70                  # puffs in the air at the same time, at most

var heat := 0.0           # how hot she is, 0..max_heat
var is_overheated := false  # true once the vent window ran out until the lever turns her on: they don't push
var at_brink := false       # at full heat, still going: the vent window is open (see brink_left)
var brink_left := 0.0       # seconds left in the vent window
var power := 0.0          # 0..1: how hard they push now (eased toward 1 while she runs)
var spin_left := 0.0      # the wheels' angles (radians)
var spin_right := 0.0
var splash_turn := 0.0    # how far the wheel has turned since the last splash (radians)
var splash_level := 0.0   # how loud the splashes are now (0..1): 1 while they push, then down as she slows
var boost_counts := false  # has the lever been held past boost_wait? (crank.gd, every frame): only then does a boost drain
var since_boost := 0.0     # seconds since she last boosted (she cools down once this reaches cool_delay)
var kick_left := 0.0       # seconds left of the engine sound's revving kick (after a start or a vent)
var puffs: Array[MeshInstance3D] = []   # the pool of steam puffs (made once)
var puff_ages: Array[float] = []         # seconds since each puff appeared (below 0 = not in use)
var puff_lives: Array[float] = []        # how long each puff lives (longer for an overheated one)
var puff_sizes: Array[float] = []        # each puff's size × (bigger for an overheated one)
var puff_rises: Array[float] = []        # how fast each puff rises
var puff_drifts: Array[Vector3] = []     # each puff's sideways way on the water: the wind's carry + its own wander
var next_puff_in := 0.0                  # seconds to the next puff
var lever_share := 0.5    # the most she may go, 0..1 of her speed (set by the lever every frame; 0.5 = the lever at rest)

@onready var boat: Node3D = owner                               # the boat (boat.tscn's root)
@onready var wheel_left: Node3D = $PaddleWheelLeft/Spin          # the part of each wheel that turns
@onready var wheel_right: Node3D = $PaddleWheelRight/Spin
@onready var smoke_attach: Node3D = boat.find_child("SmokeAttach")   # the chimney's top, where the smoke comes out


func _ready() -> void:
	make_puffs()
	revved.connect(_on_revved_for_sound)    # started or vented: the engine's sound revs up for a moment


## Is she running? (Not overheated and the anchor up.)
func is_running() -> bool:
	return not is_overheated and not boat.anchored


## How hot she is, 0 (cold) to 1 (overheated): the lever's plate shows it.
func heat_share() -> float:
	return heat / max_heat


## Can she be vented now? While the vent window is open (at full heat, before she overheats).
func can_vent() -> bool:
	return at_brink


## Cold again: no heat, not overheated, and the lever's flywheel spins in overdrive (crank.gd).
func cool_right_down() -> void:
	heat = 0.0
	is_overheated = false
	at_brink = false
	revved.emit()


## The lever all the way right while she's off: the anchor comes up (or she casts off from a pier) and she's cold.
## (boat.gd toggle_anchor plays the anchor's sound.)
func turn_on() -> void:
	if boat.talking:
		return                     # someone is talking: the anchor stays down meanwhile
	if boat.anchored:
		boat.toggle_anchor()
	cool_right_down()


## The lever all the way right while she runs, close to overheating: cold again.
func vent() -> void:
	if can_vent():
		cool_right_down()


## The lever all the way left: the anchor goes down (she stops).
func turn_off() -> void:
	if boat.talking:
		return
	if not boat.anchored:
		boat.toggle_anchor()


## The lever says the most she may go (crank.gd, every frame): 0..1.
func set_lever_share(share: float) -> void:
	lever_share = clampf(share, 0.0, 1.0)


## The share of her speed she may reach (boat.gd multiplies her target speed by it).
func speed_share() -> float:
	return lever_share


## How fast boosting heats her (heat per second). Only the boost (Enrico, Nov 2026): 0 at the lever's middle and
## below, and past the middle only once the boost counts (held boost_wait seconds, crank.gd sets boost_counts); then
## from 0 just past the middle up to boost_heat at the right end, in a straight line.
func heat_rate() -> float:
	if not is_boosting():
		return 0.0                               # cruising, or just grabbed / vented / let go: free
	var past_middle := (lever_share - 0.5) / 0.5  # 0 at the middle, 1 at the right end
	return boost_heat * past_middle


## A booster (Assets/Items/booster) takes `amount` of heat away, never below cold.
func cool(amount: float) -> void:
	heat = maxf(0.0, heat - amount)


## The speed they give her now (m/s): 0 when not pushing.
func push_speed() -> float:
	return boat.top_speed * power      # the most she can go (boat.gd); the lever's share is applied by the boat


## Her turning is multiplied by this: quicker while they push.
func turn_factor() -> float:
	return turn_mult if power > 0.01 else 1.0


## Adds `share` (0..1) of the whole bar to her heat (Enrico, Nov 2026: a bomb adds 0.75, bomb_button.gd). Like
## boosting, it starts the wait before she cools down again (since_boost back to 0). Reaching max_heat, she overheats.
func add_heat(share: float) -> void:
	heat = minf(max_heat, heat + max_heat * share)
	since_boost = 0.0
	check_overheat()


## An enemy hit her (boat.gd hit_by_enemy): hit_heat of the bar.
func take_hit() -> void:
	add_heat(hit_heat)


## Has she just reached max_heat? Then the vent window opens: she keeps going for vent_window seconds (update_brink
## counts them down). With no window (vent_window 0) she overheats at once.
func check_overheat() -> void:
	if heat < max_heat or is_overheated or at_brink:
		return
	if vent_window <= 0.0:
		overheat()
		return
	at_brink = true
	brink_left = vent_window


## The vent window, every frame: if the heat went down meanwhile (she let go of the boost and cooled a little), it
## closes, no harm done; otherwise it counts down, and at 0 she overheats.
func update_brink(dt: float) -> void:
	if not at_brink:
		return
	if heat < max_heat:
		at_brink = false
		return
	brink_left -= dt
	if brink_left <= 0.0:
		overheat()


## She overheats: no push until the lever turns her on, and the signal for the boat's black blink.
func overheat() -> void:
	at_brink = false
	is_overheated = true
	overheated.emit()


## Is she boosting now? The lever held past the middle long enough for the boost to count (boost_counts). Holding it
## there overheated counts too: she cools down only once she lets go of the boost.
func is_boosting() -> bool:
	return lever_share > 0.5 and boost_counts


## Every frame (boat.gd): boosting heats her (heat_rate) and she cools down by itself once she hasn't boosted for
## cool_delay seconds; the push eases in and out, the wheels turn, and the steam rises.
func update(dt: float) -> void:
	update_heat(dt)
	update_brink(dt)
	var want := 1.0 if is_running() else 0.0
	power += (want - power) * minf(1.0, dt * take_up_rate)
	if power < 0.005:
		power = 0.0
	spin_wheels(dt)
	update_steam(dt)
	update_engine_sound(dt)


## Tells the engine's sound how revved she is (Sfx.engine): off (anchored, tied up, overheated) = -1 (it fades out);
## running = half the lever's place + half her speed share, plus the boost and the kick after a start or a vent.
func update_engine_sound(dt: float) -> void:
	kick_left = maxf(0.0, kick_left - dt)
	if not is_running():
		Sfx.engine(-1.0, dt)
		return
	var speed_part := clampf(absf(boat.speed) / boat.top_speed, 0.0, 1.0)
	var rev := 0.5 * lever_share + 0.5 * speed_part
	if is_boosting():
		rev += boost_rev
	rev += rev_kick * (kick_left / rev_kick_time)
	Sfx.engine(rev, dt)


func _on_revved_for_sound() -> void:
	kick_left = rev_kick_time


## The heat: boosting, it rises (and the wait before she cools starts again from 0); not boosting, the wait counts
## up, and once it's past cool_delay it falls at cool_rate, never below cold, as long as she's under way (running and
## going at least cool_min_speed) OR switched off (Enrico, Nov 2026: at anchor or tied up the engine rests and cools,
## overheated too; the lever's filling goes down with it). Standing still with the anchor up and the lever pulled back,
## nothing (Enrico: that would cool her for free while she can still go).
func update_heat(dt: float) -> void:
	if is_boosting():
		since_boost = 0.0
		if is_running():
			heat = minf(max_heat, heat + dt * heat_rate())
			check_overheat()
		return
	since_boost += dt
	var under_way: bool = is_running() and boat.speed >= cool_min_speed
	var switched_off: bool = boat.anchored             # at anchor or tied up at a pier
	if since_boost >= cool_delay and (under_way or switched_off):
		heat = maxf(0.0, heat - dt * cool_rate)


## The wheels turn with their push, or freewheel, dragged round by the water going by (carried by a wave, a gust…); whichever is
## quicker (as in the prototype). Turning, the wheel on the outside of the turn goes faster, the inside one slower.
func spin_wheels(dt: float) -> void:
	if not visible:
		return
	# 1. How fast (rad/s): the water's speed divided by the wheel's radius. Pushing, the speed the lever lets her
	#    reach (push × its share: at the lever's 50% they turn half as fast as at 100%); else freewheeling with her
	#    own speed. Then × spin_scale, so they don't turn into a blur.
	var pushed := push_speed() * lever_share / paddle_radius
	var freewheel := maxf(boat.speed, 0.0) / paddle_radius * 0.9
	var base := maxf(pushed, freewheel) * spin_scale
	# 2. Turning left (turn_speed +), the right wheel is on the outside: faster; the left one slower.
	var turn_part: float = boat.turn_speed * half_beam / paddle_radius * 0.9 * spin_scale
	# 3. Going forward, the top of a wheel moves toward the bow (-Z): a negative turn round X.
	#    (wrapf keeps the angle between -PI and PI, so the number never grows huge)
	update_splashes(dt, base)
	spin_left = wrapf(spin_left - (base - turn_part) * dt, -PI, PI)
	spin_right = wrapf(spin_right - (base + turn_part) * dt, -PI, PI)
	wheel_left.rotation.x = spin_left
	wheel_right.rotation.x = spin_right


## The splashes: one every quarter turn of the wheel (every other of its 8 paddles), so they come quicker the faster
## it turns. Loud while they push; after a push it falls with her speed (she's coming to a halt) and fades within a
## couple of seconds anyway (freewheeling makes no sound: Enrico asked for it only while they work).
func update_splashes(dt: float, wheel_speed: float) -> void:
	if is_running():
		splash_level = 1.0                  # pushing: full
	else:
		splash_level = minf(splash_level, clampf(boat.speed / boat.top_speed, 0.0, 1.0))
		splash_level = maxf(0.0, splash_level - dt * 0.5)
	splash_turn += wheel_speed * dt
	if splash_turn >= TAU / 4.0:
		splash_turn = 0.0
		if splash_level > 0.02:
			Sfx.paddle_splash(splash_level)


## She's back home after sinking: cold, the lever at rest, no push.
func stop() -> void:
	heat = 0.0
	is_overheated = false
	at_brink = false
	lever_share = 0.5
	power = 0.0
	splash_level = 0.0


# ---- the steam ----

## Makes the pool of puffs once: small white balls (a ball looks the same from every side, so it needs no turning to
## the camera), each with its own material so each fades on its own. `top_level`: placed in the world, so a puff stays
## where it rose while she sails on, and doesn't rock with her.
func make_puffs() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	for i in MAX_PUFFS:
		var puff := MeshInstance3D.new()
		puff.mesh = mesh
		puff.top_level = true
		puff.visible = false
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color.WHITE
		material.render_priority = 2                 # among the see-through things, after the sea and the wake
		puff.material_override = material
		add_child(puff)
		puffs.append(puff)
		puff_ages.append(-1.0)
		puff_lives.append(steam_time)
		puff_sizes.append(1.0)
		puff_rises.append(steam_rise)
		puff_drifts.append(Vector3.ZERO)


## Puffs a second now (0 = no smoke): overheated, the thick plume; running, from steam_puffs_least (cold) to
## steam_puffs_most (full heat); stopped, only while she's still warm (above steam_from), cooling down.
func puffs_per_second() -> float:
	var share := heat_share()
	if is_overheated:
		return overheat_puffs
	if is_running():
		return lerpf(steam_puffs_least, steam_puffs_most, share)
	if share >= steam_from:
		return steam_puffs_most * share
	return 0.0


## Every frame: a new puff every so often (puffs_per_second), and every puff in the air rises, grows and fades.
func update_steam(dt: float) -> void:
	var rate := puffs_per_second()
	if rate > 0.0:
		next_puff_in -= dt
		if next_puff_in <= 0.0:
			next_puff_in = 1.0 / rate
			start_puff()
	for i in MAX_PUFFS:
		if puff_ages[i] < 0.0:
			continue
		var puff := puffs[i]
		puff_ages[i] += dt
		var age := puff_ages[i] / puff_lives[i]         # 0 when it appears, 1 when it's gone
		if age >= 1.0:
			puff_ages[i] = -1.0                         # done: free for the next one
			puff.visible = false
			continue
		puff.global_position += (puff_drifts[i] + Vector3(0.0, puff_rises[i], 0.0)) * dt
		var radius := lerpf(steam_size_start, steam_size_end, age) * puff_sizes[i]
		puff.scale = Vector3.ONE * radius
		# Solid for its first half, then it fades away (smoothstep: a soft start and end to the fading).
		var fade := 1.0 - smoothstep(0.5, 1.0, age)
		(puff.material_override as StandardMaterial3D).albedo_color.a = steam_alpha * fade


## One puff out of the chimney (SmokeAttach; a hair to one side or the other, at random), using a free one of the
## pool. Overheated, it's bigger, lives longer and rises faster (the thick plume).
func start_puff() -> void:
	var free_one := puff_ages.find(-1.0)
	if free_one == -1:
		return                                          # all in the air: skip this one
	var puff := puffs[free_one]
	var chimney: Vector3 = boat.global_position + Vector3(0.0, 0.8, 0.0)   # no marker: over her middle, as before
	if smoke_attach:
		chimney = smoke_attach.global_position
	var spot := chimney + Vector3(randf_range(-0.1, 0.1), 0.0, randf_range(-0.1, 0.1))
	puff_lives[free_one] = overheat_time if is_overheated else steam_time
	puff_sizes[free_one] = overheat_size if is_overheated else 1.0
	puff_rises[free_one] = overheat_rise if is_overheated else steam_rise
	# Its sideways way: carried downwind (the wind blows toward -from_vector), plus a little wander of its own.
	var wander := overheat_spread if is_overheated else steam_spread
	var angle := randf() * TAU
	puff_drifts[free_one] = -Wind.from_vector() * steam_drift + Vector3(cos(angle), 0.0, sin(angle)) * randf() * wander
	puff.global_transform = Transform3D(Basis().scaled(Vector3.ONE * steam_size_start * puff_sizes[free_one]), spot)
	puff.visible = true
	puff_ages[free_one] = 0.0
