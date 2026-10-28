extends Node
## THE WIND, for the whole game.
##
## This script is an Autoload (Project Settings → Globals → Autoload, name "Wind"): Godot creates it
## once when the game starts and any other script can read it by writing `Wind.from_deg`.
## (In Unreal it would be a World Subsystem.)
##
## What it does (Enrico):
##   1. every level starts with the wind blowing NORTH (coming from the south);
##   2. it never changes by itself: it stays as it is...
##   3. ...until the boat crosses a WIND ZONE (Assets/Landscape/wind_zone), which turns it to a new direction
##      (one set in the zone's Inspector, or a random one): turn_to(). It turns smoothly over a few seconds,
##      then stays again until the next zone.
## The wind's strength never changes: only its direction does.
##
## THE CURRENT lives here too (the HTML prototype's CURRENT_DRIFT): the wind sets the water moving, so the sea
## carries what floats on it downwind. Anything can ask `Wind.current()` for that push: the boat, a bomb, a dead imp.


## Sent every time the wind's direction changes (at a wind zone, a jar, a new level, and every frame while it
## turns). Things drawn along the wind listen to it instead of checking every frame (the gusts, gust.gd).
signal direction_changed


# ---- Knobs (constants: values you set here by hand, they never change while playing) ----

const START_FROM_DEG := 180.0             # where the wind comes from when a level starts: 180 = from the south, so it blows north
const CURRENT_SPEED := 1.5                # m/s the current carries floating things downwind (boat, bombs, a dead imp)


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


func _ready() -> void:
	# An autoload lives on when another level is loaded (the start screen's level list): so each new level
	# starts again with the wind blowing north. scene_changed = "the new level is in".
	get_tree().scene_changed.connect(reset)
	set_process(false)                    # nothing to do until a zone turns it


## Back to the start: blowing north, not turning.
func reset() -> void:
	from_deg = START_FROM_DEG
	_turning = false
	set_process(false)


## Turns the wind so it comes FROM `new_from_deg`, smoothly over `seconds` (0 = at once).
## It turns the short way round (e.g. from 350° to 10° it goes through 0°, not back through 180°).
## Called by a wind zone when the boat crosses it.
func turn_to(new_from_deg: float, seconds: float) -> void:
	new_from_deg = fposmod(new_from_deg, 360.0)
	if seconds <= 0.0:
		from_deg = new_from_deg
		_turning = false
		set_process(false)
		return
	_turning = true
	_turn_start_deg = from_deg
	# wrapf(..., -180, 180) gives the shortest way: at most half a turn, + clockwise, - anticlockwise.
	_turn_amount = wrapf(new_from_deg - from_deg, -180.0, 180.0)
	_turn_elapsed = 0.0
	_turn_duration = seconds
	set_process(true)                     # _process runs only while it turns


## Godot calls _process once every frame (like Event Tick in Unreal), here only while the wind turns.
## dt is the time since the last frame, in seconds.
func _process(dt: float) -> void:
	_turn_elapsed += dt

	# progress goes from 0 (turn just begun) to 1 (turn done).
	var progress := minf(_turn_elapsed / _turn_duration, 1.0)

	# "Smoothstep": instead of turning at a steady speed, it starts slowly, speeds up in the middle
	# and slows down again at the end. Same idea as an "ease in/out" curve in a Timeline.
	var eased := progress * progress * (3.0 - 2.0 * progress)

	# The new direction = where it started + the part of the turn done so far.
	# fposmod(..., 360) keeps the angle between 0 and 360 (e.g. 370° becomes 10°).
	from_deg = fposmod(_turn_start_deg + _turn_amount * eased, 360.0)

	if progress >= 1.0:                   # the turn is over: it stays like this until the next zone
		_turning = false
		set_process(false)


## The direction the wind comes from as an arrow lying on the sea (a Vector3 of length 1).
## In Godot's 3D, -Z is north and +X is east, so "from the north" = (0, 0, -1).
func from_vector() -> Vector3:
	var a := deg_to_rad(from_deg)         # sin and cos want radians, not degrees
	return Vector3(sin(a), 0.0, -cos(a))


## The current: how fast and which way the water carries anything floating, in m/s. It flows downwind (the
## opposite of where the wind comes from, -from_vector()) at CURRENT_SPEED, and turns with the wind.
func current() -> Vector3:
	return -from_vector() * CURRENT_SPEED
