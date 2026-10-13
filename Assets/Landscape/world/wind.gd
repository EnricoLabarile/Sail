extends Node
## The wind, for the whole game (an Autoload: like a World Subsystem in Unreal, reachable from any
## script as `Wind`). As in the HTML prototype: it starts from a random direction, holds steady for a
## while (longer at the start), then shifts by 30–90° one way or the other over a few seconds, eased
## in and out, and holds again; its strength swells and fades slowly between 0.5 and 1.

const FIRST_HOLD := Vector2(28.0, 36.0)   # s of steady wind at the start
const HOLD := Vector2(12.0, 22.0)         # s of steady wind between shifts
const SHIFT_DEG := Vector2(30.0, 90.0)    # how far a shift turns it
const SHIFT_TIME := Vector2(3.0, 5.0)     # s a shift takes
const STRENGTH_MID := 0.75                # the breeze swells this ± STRENGTH_SWING (0.5..1, as in the prototype)…
const STRENGTH_SWING := 0.25
const STRENGTH_RATE := 0.06               # …this slowly (rad/s of a sine: a full swell every ~100 s)

var from_deg := randf() * 360.0           # where the wind blows from: 0 = north (up the screen), 90 = east
var strength := STRENGTH_MID              # 0.5..1, how fresh the breeze is

var _hold := randf_range(FIRST_HOLD.x, FIRST_HOLD.y)
var _shift_from := 0.0
var _shift_by := 0.0
var _shift_t := 0.0
var _shift_dur := 0.0
var _strength_t := 0.0

func _process(dt: float) -> void:
	if _shift_dur > 0.0:
		_shift_t += dt
		var k := minf(1.0, _shift_t / _shift_dur)
		from_deg = fposmod(_shift_from + _shift_by * k * k * (3.0 - 2.0 * k), 360.0)
		if k >= 1.0:
			_shift_dur = 0.0
			_hold = randf_range(HOLD.x, HOLD.y)
	else:
		_hold -= dt
		if _hold <= 0.0:
			_shift_from = from_deg
			_shift_by = randf_range(SHIFT_DEG.x, SHIFT_DEG.y) * (1.0 if randf() < 0.5 else -1.0)
			_shift_t = 0.0
			_shift_dur = randf_range(SHIFT_TIME.x, SHIFT_TIME.y)
	_strength_t += dt * STRENGTH_RATE
	strength = STRENGTH_MID + STRENGTH_SWING * sin(_strength_t)

## Where the wind comes from, as a direction on the sea (Godot's -Z is north).
func from_vector() -> Vector3:
	return Vector3(sin(deg_to_rad(from_deg)), 0.0, -cos(deg_to_rad(from_deg)))
