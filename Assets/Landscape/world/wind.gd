extends Node
## THE WIND AND THE CURRENT, for the whole game.
##
## This script is an Autoload (Project Settings → Globals → Autoload, name "Wind"): Godot creates it
## once when the game starts and any other script can read it by writing `Wind.from_deg`.
## (In Unreal it would be a World Subsystem.)
##
## WHAT THE WIND IS FOR NOW (Enrico, Nov 2026: there's no sail any more, so the wind never pushes the boat):
##   - GAMEPLAY: it sets which way THE CURRENT flows (below). The current is what matters: it carries the boat, a
##     burning bomb, a dead imp, a castaway let go, and a sea imp comes up on the side it flows toward. A wind zone
##     or an Aeolus jar turning the wind is really turning the current.
##   - THE LOOK: things drawn along it follow it (the sea's texture, the clouds, the wind lines, the gulls, the
##     gusts and the big waves, which also travel with it).
##
## Its direction (Enrico):
##   1. every level starts with it blowing NORTH (coming from the south);
##   2. a WIND ZONE (Assets/Landscape/wind_zone) the boat crosses turns it to a new direction (one set in the zone's
##      Inspector, or a random one), and so does an Aeolus jar: turn_to(). It turns smoothly over a few seconds;
##   3. RANDOM SHIFTS (switch: RANDOM_WIND below): if on, every SHIFT_EVERY_MIN..MAX seconds it turns by itself to a
##      new direction, at most SHIFT_MAX_DEG either way from where it is now. Any turn_to (a zone, a jar) starts the
##      count again (so the jar's current lasts).
## Its strength never changes: only its direction does.
##
## THE CURRENT (the HTML prototype's CURRENT_DRIFT): the wind sets the water moving, so the sea carries what floats on
## it the way the wind blows, at CURRENT_SPEED. Anything can ask `Wind.current()` for that push.


## Sent every time the wind's direction changes (at a wind zone, a jar, a new level, and every frame while it
## turns). Things drawn along the wind listen to it instead of checking every frame (the gusts, gust.gd).
signal direction_changed


# ---- Knobs (constants: values you set here by hand, they never change while playing) ----

const START_FROM_DEG := 180.0             # where the wind comes from when a level starts: 180 = from the south, so it blows north
const RANDOM_WIND := true                 # true = the wind shifts by itself now and then; false = only zones and jars turn it
const SHIFT_EVERY_MIN := 20.0             # seconds between two random shifts: at least...
const SHIFT_EVERY_MAX := 40.0             # ...and at most (a new random wait each time)
const SHIFT_MAX_DEG := 90.0               # a random shift turns it at most this many degrees either way (180 = anywhere)
const SHIFT_TURN_TIME := 4.0              # seconds a random shift takes to turn (as a wind zone's turn_time)
const CURRENT_SPEED := 2.0                # m/s the current carries floating things the way the wind blows (boat, bombs, a dead imp)


# ---- The value other scripts read ----

## Where the wind blows FROM, in degrees: 0 = from the north (top of the screen), 90 = from the east,
## 180 = from the south, 270 = from the west.
var from_deg := START_FROM_DEG:
	set(value):
		from_deg = value
		direction_changed.emit()      # tell whoever listens (the setter runs whenever from_deg is given a value)


# ---- Internal state (the "_" in front of a name means: only this script uses it) ----

var _turning := false                     # true while the wind is turning to a new direction
var _turn_start_deg := 0.0                # the direction when the turn began
var _turn_amount := 0.0                   # how many degrees this turn turns it (+ = clockwise)
var _turn_elapsed := 0.0                  # seconds since the turn began
var _turn_duration := 0.0                 # how many seconds this turn lasts
var _next_shift_left := 0.0               # seconds until the next random shift (RANDOM_WIND)


func _ready() -> void:
	# An autoload lives on when another level is loaded (the start screen's level list): so each new level
	# starts again with the wind blowing north. scene_changed = "the new level is in".
	get_tree().scene_changed.connect(reset)
	reset()


## Back to the start: blowing north, not turning, the wait for the first random shift begun.
func reset() -> void:
	from_deg = START_FROM_DEG
	_turning = false
	_start_shift_wait()
	# _process runs every frame only when there is something to do: the random shifts' countdown (RANDOM_WIND)
	# or a turn. With random shifts off it rests until a zone turns it.
	set_process(RANDOM_WIND)


## A new random wait before the next random shift.
func _start_shift_wait() -> void:
	_next_shift_left = randf_range(SHIFT_EVERY_MIN, SHIFT_EVERY_MAX)


## A random shift: a new direction at most SHIFT_MAX_DEG either way from now, turned over SHIFT_TURN_TIME.
func _random_shift() -> void:
	var change := randf_range(-SHIFT_MAX_DEG, SHIFT_MAX_DEG)
	turn_to(from_deg + change, SHIFT_TURN_TIME)


## Turns the wind so it comes FROM `new_from_deg`, smoothly over `seconds` (0 = at once).
## It turns the short way round (e.g. from 350° to 10° it goes through 0°, not back through 180°).
## Called by a wind zone when the boat crosses it.
func turn_to(new_from_deg: float, seconds: float) -> void:
	new_from_deg = fposmod(new_from_deg, 360.0)
	_start_shift_wait()                   # any turn (zone, jar or random) restarts the wait for the next random one
	if seconds <= 0.0:
		from_deg = new_from_deg
		_turning = false
		set_process(RANDOM_WIND)          # keep counting toward the next random shift, if they're on
		return
	_turning = true
	_turn_start_deg = from_deg
	# wrapf(..., -180, 180) gives the shortest way: at most half a turn, + clockwise, - anticlockwise.
	_turn_amount = wrapf(new_from_deg - from_deg, -180.0, 180.0)
	_turn_elapsed = 0.0
	_turn_duration = seconds
	set_process(true)                     # _process runs only while it turns


## Godot calls _process once every frame (like Event Tick in Unreal), here only while the wind turns or the
## random shifts count down. dt is the time since the last frame, in seconds. (The game paused, it waits too.)
func _process(dt: float) -> void:
	# The countdown to the next random shift (not while a turn is going on).
	if RANDOM_WIND and not _turning:
		_next_shift_left -= dt
		if _next_shift_left <= 0.0:
			_random_shift()
		return
	if not _turning:
		set_process(false)                # nothing to do (random shifts off): rest until a zone turns it
		return

	_turn_elapsed += dt

	# progress goes from 0 (turn just begun) to 1 (turn done).
	var progress := minf(_turn_elapsed / _turn_duration, 1.0)

	# "Smoothstep": instead of turning at a steady speed, it starts slowly, speeds up in the middle
	# and slows down again at the end. Same idea as an "ease in/out" curve in a Timeline.
	var eased := progress * progress * (3.0 - 2.0 * progress)

	# The new direction = where it started + the part of the turn done so far.
	# fposmod(..., 360) keeps the angle between 0 and 360 (e.g. 370° becomes 10°).
	from_deg = fposmod(_turn_start_deg + _turn_amount * eased, 360.0)

	if progress >= 1.0:                   # the turn is over: it stays like this until the next zone (or random shift)
		_turning = false
		set_process(RANDOM_WIND)          # random shifts on: back to counting down


## The direction the wind comes from as an arrow lying on the sea (a Vector3 of length 1).
## In Godot's 3D, -Z is north and +X is east, so "from the north" = (0, 0, -1).
func from_vector() -> Vector3:
	var a := deg_to_rad(from_deg)         # sin and cos want radians, not degrees
	return Vector3(sin(a), 0.0, -cos(a))


## The current: how fast and which way the water carries anything floating, in m/s. It flows downwind (the
## opposite of where the wind comes from, -from_vector()) at CURRENT_SPEED, and turns with the wind.
func current() -> Vector3:
	return -from_vector() * CURRENT_SPEED
