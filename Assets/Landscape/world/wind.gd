extends Node
## THE WIND, for the whole game.
##
## This script is an Autoload (Project Settings → Globals → Autoload, name "Wind"): Godot creates it
## once when the game starts and any other script can read it by writing `Wind.from_deg`.
## (In Unreal it would be a World Subsystem.)
##
## What it does, as in the HTML prototype:
##   1. at the start the wind comes from one of the 8 directions of the compass (N, NE, E, SE, S, SW, W, NW),
##      picked at random;
##   2. it HOLDS steady for a while;
##   3. then it SHIFTS to another of the 8: one or two steps round (45° or 90°), left or right at random,
##      turning smoothly over a few seconds;
##   4. then it holds again, and so on.
## The wind's strength never changes: only its direction does.
##
## THE CURRENT lives here too (the HTML prototype's CURRENT_DRIFT): the wind sets the water moving, so the sea
## carries what floats on it downwind. Anything can ask `Wind.current()` for that push: the boat, a bomb, a dead imp.


# ---- Knobs (constants: values you set here by hand, they never change while playing) ----
# A Vector2 is used here as a pair of numbers: x = the smallest value, y = the largest.
# Each time, a random number between the two is picked.

const FIRST_HOLD := Vector2(28.0, 36.0)   # seconds the wind holds still at the start of the game
const HOLD := Vector2(30.0, 40.0)         # seconds it holds still between one shift and the next
const DIRECTIONS := 16                     # how many directions the wind can come from (8 = every 45°)
const SHIFT_STEPS := Vector2i(1, 1)       # how many steps round a shift turns it (1 = 45°, 2 = 90°)
const SHIFT_TIME := Vector2(3.0, 5.0)     # how many seconds a shift takes
const CURRENT_SPEED := 2.5                # m/s the current carries floating things downwind (boat, bombs, a dead imp)


# ---- The value other scripts read ----

## Where the wind blows FROM, in degrees: 0 = from the north (top of the screen), 90 = from the east,
## 180 = from the south, 270 = from the west.
## It starts on one of the 8 directions, picked at random (randi() % 8 gives a whole number from 0 to 7).
var from_deg := (randi() % DIRECTIONS) * step_deg()


# ---- Internal state (the "_" in front of a name means: only this script uses it) ----

var _hold_left := randf_range(FIRST_HOLD.x, FIRST_HOLD.y)   # seconds left before the next shift
var _shifting := false                    # true while the wind is turning
var _shift_start_deg := 0.0               # the direction when the shift began
var _shift_amount := 0.0                  # how many degrees this shift turns it (+ = clockwise)
var _shift_elapsed := 0.0                 # seconds since the shift began
var _shift_duration := 0.0                # how many seconds this shift lasts


## Godot calls _process once every frame (like Event Tick in Unreal).
## dt is the time since the last frame, in seconds.
func _process(dt: float) -> void:
	if _shifting:
		_update_shift(dt)
	else:
		_update_hold(dt)


## While the wind holds still: count down, and when the time is up start a shift.
func _update_hold(dt: float) -> void:
	_hold_left -= dt
	if _hold_left > 0.0:
		return                            # still time left: nothing to do this frame

	# Time's up: get a new shift ready.
	_shifting = true
	_shift_start_deg = from_deg
	# A whole number of steps (1 or 2), each step 45°: so it always ends on one of the 8 directions.
	_shift_amount = randi_range(SHIFT_STEPS.x, SHIFT_STEPS.y) * step_deg()
	if randf() < 0.5:                     # half the time it turns the other way
		_shift_amount = -_shift_amount
	_shift_elapsed = 0.0
	_shift_duration = randf_range(SHIFT_TIME.x, SHIFT_TIME.y)


## While the wind is turning: move the direction a little further each frame.
func _update_shift(dt: float) -> void:
	_shift_elapsed += dt

	# progress goes from 0 (shift just begun) to 1 (shift done).
	var progress := minf(_shift_elapsed / _shift_duration, 1.0)

	# "Smoothstep": instead of turning at a steady speed, it starts slowly, speeds up in the middle
	# and slows down again at the end. Same idea as an "ease in/out" curve in a Timeline.
	var eased := progress * progress * (3.0 - 2.0 * progress)

	# The new direction = where it started + the part of the shift done so far.
	# fposmod(..., 360) keeps the angle between 0 and 360 (e.g. 370° becomes 10°).
	from_deg = fposmod(_shift_start_deg + _shift_amount * eased, 360.0)

	if progress >= 1.0:                   # the shift is over: hold still again for a while
		_shifting = false
		# Land exactly on the direction (no tiny leftover like 44.9999° from the sums).
		from_deg = fposmod(round(from_deg / step_deg()) * step_deg(), 360.0)
		_hold_left = randf_range(HOLD.x, HOLD.y)


## The angle between two neighbouring directions: 360 / 8 = 45°.
func step_deg() -> float:
	return 360.0 / DIRECTIONS


## The direction the wind comes from as an arrow lying on the sea (a Vector3 of length 1).
## In Godot's 3D, -Z is north and +X is east, so "from the north" = (0, 0, -1).
func from_vector() -> Vector3:
	var a := deg_to_rad(from_deg)         # sin and cos want radians, not degrees
	return Vector3(sin(a), 0.0, -cos(a))


## The current: how fast and which way the water carries anything floating, in m/s. It flows downwind (the
## opposite of where the wind comes from, -from_vector()) at CURRENT_SPEED, and turns with the wind.
func current() -> Vector3:
	return -from_vector() * CURRENT_SPEED
