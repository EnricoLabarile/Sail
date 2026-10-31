extends Node3D
## THE PADDLES (Enrico: the paddle wheels on her sides, worked by a crank; everything about them lives here, apart
## from the boat). On the `Paddles` node in boat.tscn, which holds the two wheels (paddle_wheel.tscn, a stand-in).
## (In Unreal: an Actor Component on the boat Pawn.)
##
## Like the sail they are an item in the hold ("paddles", Assets/Inventory/items/paddles.tres): a tap on their slot in
## the logbook switches them on or off (Inventory.toggle). Off: no wheels on her sides, no crank on the screen.
##
## How they push (the prototype's wound spring): one FULL turn of the crank (Assets/UI/crank/crank.gd) winds them,
## and then they push her forward, whichever way her bow points (into the wind too), at `paddle_speed` for
## `push_time` seconds. Meanwhile the crank is locked, except in the last `recharge_window` seconds (Enrico): a full
## turn then winds them full again, so a player who keeps an eye on it never stops. The current still carries her
## (the boat's). At anchor they don't push. With the sail set too, she goes at whichever gives more.
##
## Their sound (Enrico, the prototype's): a low soft splash for every other paddle that comes round (4 a turn of the
## wheel, Sfx.paddle_splash) while they work; when the push ends it dies down as she slows (splash_level).
##
## The boat (boat.gd) calls: push_speed() and bite (her speed), turn_factor() (turning), update(dt) every frame,
## stop() when she's back home after sinking. The crank calls: is_on(), can_wind(), wound().

const ITEM := "paddles"   # the item's id (paddles.tres)

@export var paddle_speed := 8.0       # m/s they give her (58.8 px/s in the prototype)
@export var push_time := 20.0           # seconds a full turn of the crank keeps them pushing
@export var recharge_window := 3.0     # the last seconds of a push in which the crank can be wound again (Enrico)
@export var turn_mult := 1.5           # she turns this much quicker while they push
@export var take_up_rate := 3.75            # how quickly they take up and let go as a push starts or ends
@export var bite := 5.25               # how quickly her speed catches up with their push (the sail fills slower)
@export var paddle_radius := 0.7       # metres: the wheels' size (to turn them as fast as the water goes by)
@export var half_beam := 1.75          # metres from her middle to each wheel (turning, the two go at different speeds)

var push_left := 0.0      # seconds of push left (0 = not wound)
var power := 0.0          # 0..1: how hard they push now (eased toward 1 while push_left > 0)
var spin_left := 0.0      # the wheels' angles (radians)
var spin_right := 0.0
var splash_turn := 0.0    # how far the wheel has turned since the last splash (radians)
var splash_level := 0.0   # how loud the splashes are now (0..1): 1 while they push, then down as she slows

@onready var boat: Node3D = owner                               # the boat (boat.tscn's root)
@onready var wheel_left: Node3D = $PaddleWheelLeft/Spin          # the part of each wheel that turns
@onready var wheel_right: Node3D = $PaddleWheelRight/Spin


func _ready() -> void:
	Inventory.toggled.connect(_on_toggled)   # switched on or off in the logbook
	visible = is_on()


## Are the paddles on? They must be aboard and switched on.
func is_on() -> bool:
	return Inventory.is_on(ITEM)


## Can the crank be wound now? When they're on and not pushing, or in the last recharge_window seconds of a push.
func can_wind() -> bool:
	return is_on() and push_left <= recharge_window


## A full turn of the crank: they're wound full, for push_time seconds (from now, not added to what was left).
func wound() -> void:
	if can_wind():
		push_left = push_time


## A booster (Assets/Items/booster) adds `seconds` of push, never more than full (push_time). Only if they're on.
func add_push(seconds: float) -> void:
	if is_on():
		push_left = minf(push_time, push_left + seconds)


## The speed they give her now (m/s): 0 when not pushing.
func push_speed() -> float:
	return paddle_speed * power


## Her turning is multiplied by this: quicker while they push.
func turn_factor() -> float:
	return turn_mult if power > 0.01 else 1.0


## Every frame (boat.gd): the push counts down while she's under way, eases in and out, and the wheels turn.
func update(dt: float) -> void:
	var pushing: bool = push_left > 0.0 and not boat.anchored
	if pushing:
		push_left = maxf(0.0, push_left - dt)
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
	# 1. How fast (rad/s): the water's speed divided by the wheel's radius.
	var pushed := push_speed() / paddle_radius
	var freewheel := maxf(boat.speed, 0.0) / paddle_radius * 0.9
	var base := maxf(pushed, freewheel)
	# 2. Turning left (turn_speed +), the right wheel is on the outside: faster; the left one slower.
	var turn_part: float = boat.turn_speed * half_beam / paddle_radius * 0.9
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
		splash_level = minf(splash_level, clampf(boat.speed / paddle_speed, 0.0, 1.0))
		splash_level = maxf(0.0, splash_level - dt * 0.5)
	splash_turn += wheel_speed * dt
	if splash_turn >= TAU / 4.0:
		splash_turn = 0.0
		if splash_level > 0.02:
			Sfx.paddle_splash(splash_level)


## No push left (she's back home after sinking, or they were switched off).
func stop() -> void:
	push_left = 0.0
	power = 0.0
	splash_level = 0.0


## Switched on or off in the logbook: the wheels show or go; off, any push left is lost.
func _on_toggled(item: String, _on: bool) -> void:
	if item != ITEM:
		return
	visible = is_on()
	if not is_on():
		stop()
