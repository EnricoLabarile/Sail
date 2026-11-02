extends Node3D
## THE PADDLES (Enrico: the paddle wheels on her sides, worked by a lever; everything about them lives here, apart
## from the boat). On the `Paddles` node in boat.tscn, which holds the two wheels (paddle_wheel.tscn, a stand-in).
## (In Unreal: an Actor Component on the boat Pawn.)
##
## They're always fitted (Enrico, Nov 2026: no longer an item to switch on and off), and the throttle lever is always
## on the screen (Assets/UI/crank/crank.gd, Enrico, Nov 2026: a lever, no longer a crank turned round).
##
## THE BATTERY (the prototype's wound spring, still): `push_left` seconds of push. While there's some and the anchor is
## up, they push her forward whichever way her bow points, at the boat's `top_speed` × the lever's share (Enrico: the
## one number for her speed is boat.gd's top_speed). Pushing the lever
## all the way right TURNS HER ON (`turn_on()`: anchor up, battery full) when she's off; while she runs, all the way
## right again in the last `recharge_window` seconds of the battery fills it again (`can_wind()`), so a player who
## keeps an eye on it never stops. All the way left TURNS HER OFF (the anchor goes down, the battery is emptied).
## The battery runs down faster the faster she's allowed to go (Enrico): at the lever's 50% at the normal rate (one
## second a second), at 100% twice as fast, at 25% half as fast (`drain_rate()`). A booster adds to it (add_push).
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
## every frame, stop() when she's back home after sinking. The lever calls: is_running(), can_wind(), turn_on(),
## refill(), turn_off(), set_lever_share().


@export var push_time := 20.0           # seconds a full battery keeps them pushing (at the lever's 50%)
## How much faster the battery runs down with the lever all the way right (the boost) than at rest in the middle
## (Enrico: a knob for it). 2 = twice as fast (as before), 1 = no extra cost, 3 = three times. Between the middle
## and the right end it grows in a straight line; below the middle it drains less, as before (25% = half as fast).
@export var boost_drain := 2.0
@export var recharge_window := 3.0     # the last seconds of the battery in which the lever, pushed right, fills it again (Enrico)
@export var turn_mult := 1.5           # she turns this much quicker while they push
@export var take_up_rate := 3.75            # how quickly they take up and let go as a push starts or ends
@export var bite := 5.25               # how quickly her speed catches up with their push (the sail fills slower)
@export var paddle_radius := 0.7       # metres: the wheels' size (to turn them as fast as the water goes by)
## How fast the wheels LOOK like they turn, as a share of "as fast as the water goes by" (Enrico: at her top speed the
## real rate was ~4.5 turns a second, a blur). Only the look and the splashes: her speed doesn't change. 1 = real.
@export var spin_scale := 0.35
@export var half_beam := 1.75          # metres from her middle to each wheel (turning, the two go at different speeds)

var push_left := 0.0      # seconds of battery left (0 = empty: they don't push)
var power := 0.0          # 0..1: how hard they push now (eased toward 1 while push_left > 0)
var spin_left := 0.0      # the wheels' angles (radians)
var spin_right := 0.0
var splash_turn := 0.0    # how far the wheel has turned since the last splash (radians)
var splash_level := 0.0   # how loud the splashes are now (0..1): 1 while they push, then down as she slows
var lever_share := 0.5    # the most she may go, 0..1 of her speed (set by the lever every frame; 0.5 = the lever at rest)

@onready var boat: Node3D = owner                               # the boat (boat.tscn's root)
@onready var wheel_left: Node3D = $PaddleWheelLeft/Spin          # the part of each wheel that turns
@onready var wheel_right: Node3D = $PaddleWheelRight/Spin


## Are the paddles there? Always now (they used to be an item you could switch off).
func is_on() -> bool:
	return true


## Is she running? (Battery left and the anchor up.)
func is_running() -> bool:
	return push_left > 0.0 and not boat.anchored


## Can the battery be filled again now? When it's empty, or in its last recharge_window seconds.
func can_wind() -> bool:
	return push_left <= recharge_window


## The lever all the way right while she's off: the anchor comes up (or she casts off from a pier) and the battery is
## full. (boat.gd toggle_anchor plays the anchor's sound.)
func turn_on() -> void:
	if boat.talking:
		return                     # someone is talking: the anchor stays down meanwhile
	if boat.anchored:
		boat.toggle_anchor()
	push_left = push_time


## The lever all the way right while she runs, in the battery's last seconds: full again (not added to what was left).
func refill() -> void:
	if can_wind():
		push_left = push_time


## The lever all the way left: the anchor goes down (she stops) and the battery is emptied.
func turn_off() -> void:
	if boat.talking:
		return
	if not boat.anchored:
		boat.toggle_anchor()
	push_left = 0.0


## The lever says the most she may go (crank.gd, every frame): 0..1.
func set_lever_share(share: float) -> void:
	lever_share = clampf(share, 0.0, 1.0)


## The share of her speed she may reach (boat.gd multiplies her target speed by it).
func speed_share() -> float:
	return lever_share


## How fast the battery runs down (seconds of it per second): 1 at the lever's 50%, boost_drain at 100%, 0.5 at 25%.
func drain_rate() -> float:
	if lever_share <= 0.5:
		return lever_share / 0.5                 # below the middle: slower, down to nothing at the left end
	var past_middle := (lever_share - 0.5) / 0.5  # 0 at the middle, 1 at the right end
	return lerpf(1.0, boost_drain, past_middle)


## A booster (Assets/Items/booster) adds `seconds` of battery, never more than full (push_time).
func add_push(seconds: float) -> void:
	push_left = minf(push_time, push_left + seconds)


## The speed they give her now (m/s): 0 when not pushing.
func push_speed() -> float:
	return boat.top_speed * power      # the most she can go (boat.gd); the lever's share is applied by the boat


## Her turning is multiplied by this: quicker while they push.
func turn_factor() -> float:
	return turn_mult if power > 0.01 else 1.0


## Every frame (boat.gd): the battery runs down while she's under way (faster the faster the lever lets her go),
## the push eases in and out, and the wheels turn.
func update(dt: float) -> void:
	var pushing := is_running()
	if pushing:
		push_left = maxf(0.0, push_left - dt * drain_rate())
	var want := 1.0 if pushing else 0.0
	power += (want - power) * minf(1.0, dt * take_up_rate)
	if power < 0.005:
		power = 0.0
	spin_wheels(dt)


## The wheels turn with their push, or, under sail, freewheel, dragged round by the water going by; whichever is
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
## couple of seconds anyway (under sail the wheels only freewheel: no sound, Enrico asked for it while they work).
func update_splashes(dt: float, wheel_speed: float) -> void:
	if push_left > 0.0 and not boat.anchored:
		splash_level = 1.0                  # pushing: full
	else:
		splash_level = minf(splash_level, clampf(boat.speed / boat.top_speed, 0.0, 1.0))
		splash_level = maxf(0.0, splash_level - dt * 0.5)
	splash_turn += wheel_speed * dt
	if splash_turn >= TAU / 4.0:
		splash_turn = 0.0
		if splash_level > 0.02:
			Sfx.paddle_splash(splash_level)


## No push left (she's back home after sinking).
func stop() -> void:
	push_left = 0.0
	lever_share = 0.5
	power = 0.0
	splash_level = 0.0
