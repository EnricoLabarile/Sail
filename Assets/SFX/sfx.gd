extends Node
## SOUNDS (the autoload "Sfx", like a GameInstance subsystem in Unreal): plays the game's sounds.
## The files in this folder were made from the HTML prototype's own sound code (art_src/audio/bake.py):
##   sea.ogg          the sea washing in slow swells, always on (a 48 s loop, stereo)
##   wind.ogg         the wind in slow gusts, always on (a 48 s loop)
##   rush.ogg         the water along the hull: louder and brighter the faster she goes (a 48 s loop)
##   anchor_down.ogg  the anchor dropped: a thud, a splash, bubbles
##   anchor_up.ogg    the anchor weighed: the chain rattling in
## The players are nodes in sfx.tscn: open it to change a sound's loudness (Volume dB in the Inspector).
## Nothing plays while the game is paused (the start screen), so the sounds start with "Set sail".
## (In Unreal: a few Audio Components on one actor, with their volumes set every Tick.)

@export var fade_in_time := 2.0   # seconds the sea, wind and hull water take to fade in at the start

@onready var sea: AudioStreamPlayer = $Sea
@onready var wind: AudioStreamPlayer = $Wind
@onready var rush: AudioStreamPlayer = $Rush
@onready var anchor_down: AudioStreamPlayer = $AnchorDown
@onready var anchor_up: AudioStreamPlayer = $AnchorUp

# Each looping sound's loudness as set in sfx.tscn (read at start): the code turns them down from there.
var sea_db := 0.0
var wind_db := 0.0
var rush_db := 0.0
var fade := 0.0   # 0..1: how far the start's fade-in has gone


func _ready() -> void:
	sea_db = sea.volume_db
	wind_db = wind.volume_db
	rush_db = rush.volume_db
	# The three loops go round and round, starting silent (the fade-in brings them up).
	for player in [sea, wind, rush]:
		player.stream.loop = true
		player.volume_db = -80.0
		player.play()


## Every frame: the fade-in at the start, and the hull water following her speed.
func _process(dt: float) -> void:
	fade = minf(1.0, fade + dt / fade_in_time)
	sea.volume_db = sea_db + loudness_db(fade)
	wind.volume_db = wind_db + loudness_db(fade)
	# The water along the hull, as in the prototype: loudness × her speed^1.5 (0 when still), and lower
	# when slow (the prototype lowered its filter from 500 to 260 Hz; here the pitch does it, 0.55 .. 1).
	var share := 0.0   # her speed as a share of top speed, 0..1
	var boat := get_tree().get_first_node_in_group("player_boat")
	if boat != null:
		share = clampf(boat.speed / boat.top_speed, 0.0, 1.0)
	rush.volume_db = rush_db + loudness_db(fade * pow(share, 1.5))
	rush.pitch_scale = 0.55 + 0.45 * share


## A loudness share (0..1) in decibels, as volume_db wants: 1 = 0 dB (as set), 0.5 = -6 dB, 0 = -80 dB (silent).
## (linear_to_db(0) would be minus infinity, so it never goes below 0.0001.)
func loudness_db(share: float) -> float:
	return linear_to_db(maxf(share, 0.0001))


## The anchor's sound: down = dropped (thud and splash), otherwise weighed (the chain coming in).
## boat.gd calls it when the anchor is worked.
func anchor(down: bool) -> void:
	if down:
		anchor_down.play()
	else:
		anchor_up.play()

