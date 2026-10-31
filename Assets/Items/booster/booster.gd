@tool
extends Node3D
## A BOOSTER (Enrico): an orb floating over the water, placed by hand. When the boat sails over it:
##   - she goes faster for a while (her top speed × `speed_multiplier` for `boost_time` seconds: the gusts' boost,
##     boat.gd boost(); it multiplies the push she already has, from the sail or the paddles);
##   - the paddles' push gets `crank_refill` seconds more (if the paddles are on; never more than full: paddles.gd
##     add_push), so chaining boosters keeps her going;
##   - a screen shake and a power-up sound.
## Then it's gone: invisible and switched off for `respawn_time` seconds, and then it comes back, ready again.
## (In Unreal: a pickup actor with an overlap volume that hides itself and re-enables on a timer.)
##
## To place one: instance booster.tscn anywhere (like placing a Blueprint) and set its numbers in the Inspector.
## The look is a stand-in: a white sphere (the boat's toon_shade material) bobbing over the water.

## Metres round its middle the boat must come within to take it. The sensor follows it (in the editor too).
@export var reach := 3.0:
	set(value):
		reach = value
		_fit_sensor()
@export var speed_multiplier := 1.6    # her top speed × this while it lasts
@export var boost_time := 2.5          # seconds it lasts
@export var boost_accel := 4.0         # how quickly she picks up the extra speed (her usual is boat.gd's accel)
@export var crank_refill := 2.0        # seconds of push given to the paddles (if they're on)
@export var respawn_time := 30.0       # seconds it stays gone after being taken
@export var shake_strength := 0.4      # the screen shake when she takes it (metres)…
@export var shake_time := 0.25         # …and how long it lasts (seconds)
@export var bob_height := 0.25         # metres it bobs up and down
@export var bob_speed := 2.0           # how fast

var time := randf() * TAU               # where in its bob it is (each one starts at its own point)
var gone_left := 0.0                    # seconds before it comes back (0 = it's there)

@onready var orb: MeshInstance3D = $Orb
@onready var sensor: Area3D = $Sensor
@onready var orb_height: float = $Orb.position.y   # how high the orb sits, as placed in booster.tscn


func _ready() -> void:
	_fit_sensor()
	if Engine.is_editor_hint():
		return
	# The physics engine calls this when the boat's sensor comes in (OnBeginOverlap in Unreal).
	sensor.area_entered.connect(_on_sensor_entered)


## The sensor's cylinder is as wide as `reach` (each booster has its own copy of the shape: local to scene).
func _fit_sensor() -> void:
	var shape_node := get_node_or_null("Sensor/Shape") as CollisionShape3D
	if shape_node and shape_node.shape:
		shape_node.shape.radius = reach


func _process(dt: float) -> void:
	if Engine.is_editor_hint():
		return
	# Gone: count down, then come back.
	if gone_left > 0.0:
		gone_left -= dt
		if gone_left <= 0.0:
			come_back()
		return
	# There: it bobs gently.
	time += dt * bob_speed
	orb.position.y = orb_height + sin(time) * bob_height


## The boat came over it: the boost, the paddles' refill, the shake and the sound; then it's gone for a while.
func _on_sensor_entered(area: Area3D) -> void:
	var boat := area.get_parent() as Node3D
	if boat == null or not boat.is_in_group("player_boat"):
		return
	if gone_left > 0.0 or boat.sinking or boat.anchored:
		return                                  # gone, or she isn't sailing: nothing happens, it stays
	boat.boost(speed_multiplier, boost_time, boost_accel)   # boat.gd: a higher top speed for a while
	boat.paddles.add_push(crank_refill)                     # paddles.gd: more push (only if they're on)
	boat.camera.shake_hard(shake_strength, shake_time)      # boat_camera.gd
	Sfx.booster()
	disappear()


## Invisible and switched off (set_deferred: the sensor can't be switched off inside its own signal).
func disappear() -> void:
	gone_left = respawn_time
	orb.visible = false
	sensor.set_deferred("monitoring", false)


## Back: visible and ready again. (If the boat is already inside it, switching the sensor on counts as her coming in.)
func come_back() -> void:
	gone_left = 0.0
	orb.visible = true
	sensor.set_deferred("monitoring", true)
