extends Node
## SOUNDS (the autoload "Sfx", like a GameInstance subsystem in Unreal): plays the game's sounds.
## The files in this folder were made from the HTML prototype's own sound code (art_src/audio/bake.py):
##   anchor_down.ogg  the anchor dropped: a thud, a splash, bubbles
##   anchor_up.ogg    the anchor weighed: the chain rattling in
##   wheel_rub.ogg    the ship's wheel: a soft wooden rub while it turns (a short loop)
##   wheel_thunk.ogg  the ship's wheel: a muted thud when it reaches full lock
##   pickup.ogg       a snappy two-note blip: something came aboard, anything (made by art_src/audio/make_pickup.py)
##   imp_death.ogg    a sea imp killed: a low falling growl with a gurgle of noise   } made by
##   bomb_blast.ogg   a bomb going off: a crack, a deep boom, a rumble               } art_src/audio/make_danger_sounds.py
##                    (played higher and quieter: BombBlast's Pitch Scale 1.5 and Volume -6 dB in sfx.tscn, Enrico)
##   hull_bump.ogg    the hull knocking against a shore or a barrel: a dull thud, a woody knock, a little scrape
##                    (made by art_src/audio/make_bump.py)
##   equip_bomb.ogg   the bomb equipped: two dry metallic clicks, like a gun being loaded (art_src/audio/make_equip.py)
## (The sea, the wind and the water along the hull were removed by Enrico; bake.html can still make them.)
## The players are nodes in sfx.tscn: open it to change a sound's loudness (Volume dB in the Inspector).
## Nothing plays while the game is paused (the game over card).
## (In Unreal: a few Audio Components on one actor, with their volumes set every Tick.)

@onready var anchor_down: AudioStreamPlayer = $AnchorDown
@onready var anchor_up: AudioStreamPlayer = $AnchorUp
@onready var wheel_rub: AudioStreamPlayer = $WheelRub
@onready var wheel_thunk: AudioStreamPlayer = $WheelThunk
@onready var pickup_sound: AudioStreamPlayer = $Pickup
@onready var imp_death_sound: AudioStreamPlayer = $ImpDeath
@onready var bomb_blast_sound: AudioStreamPlayer = $BombBlast
@onready var hull_bump_sound: AudioStreamPlayer = $HullBump
@onready var equip_bomb_sound: AudioStreamPlayer = $EquipBomb

## Seconds the imp's death sound waits before it plays. An imp is usually killed by a bomb, whose blast starts in
## the same instant and would cover it (Enrico couldn't hear it): a moment later, it's heard after the bang.
@export var imp_death_delay := 0.25

var rub_db := 0.0       # the rub's loudness as set in sfx.tscn (read at start): the code turns it down from there
var thunk_db := 0.0     # the same for the thud
var bump_db := 0.0      # the same for the hull's bump
var rub_share := 0.0    # how loud the rub is now, 0..1 (it follows the wheel's speed smoothly)


func _ready() -> void:
	rub_db = wheel_rub.volume_db
	thunk_db = wheel_thunk.volume_db
	bump_db = hull_bump_sound.volume_db
	# The rub goes round and round, silent until the wheel turns.
	wheel_rub.stream.loop = true
	wheel_rub.volume_db = -80.0
	wheel_rub.play()


## The anchor's sound: down = dropped (thud and splash), otherwise weighed (the chain coming in).
## boat.gd calls it when the anchor is worked.
func anchor(down: bool) -> void:
	if down:
		anchor_down.play()
	else:
		anchor_up.play()


## The wheel's rub, every frame (helm.gd): spin = how fast the wheel is turning, in radians a second.
## As in the prototype: full loudness from 7 rad/s, silent under a twentieth of that, and darker when slow
## (the prototype lowered its filter from 520 to 320 Hz; here the pitch does it). It eases in and out in about
## a tenth of a second, so it doesn't click on and off.
func wheel(spin: float, dt: float) -> void:
	var k := minf(1.0, spin / 7.0)
	var target := 0.0 if k < 0.05 else k
	rub_share = lerpf(rub_share, target, minf(1.0, dt / 0.08))
	wheel_rub.volume_db = rub_db + loudness_db(rub_share)
	wheel_rub.pitch_scale = 0.8 + 0.2 * k


## The thud when the wheel hits full lock (helm.gd): strength 0..1, softer when it gets there slowly.
func wheel_stop(strength: float) -> void:
	wheel_thunk.volume_db = thunk_db + loudness_db(strength)
	wheel_thunk.play()


## A thing taken at the floating shop (store_alternative.gd).
## Something came aboard (the boat calls it for anything going into the hold).
func came_aboard() -> void:
	pickup_sound.play()


## A sea imp killed (sea_imp_zone.gd, defeat): imp_death_delay seconds later (a timer, like a Delay node).
func imp_death() -> void:
	await get_tree().create_timer(imp_death_delay).timeout
	imp_death_sound.play()


## A bomb going off (bomb.gd, explode).
func bomb_blast() -> void:
	bomb_blast_sound.play()


## The boat bounced off something solid, a shore or a barrel (boat.gd, bump): strength 0..1, softer for a gentle
## knock, full for a hit at top speed.
func hull_bump(strength: float) -> void:
	hull_bump_sound.volume_db = bump_db + loudness_db(strength)
	hull_bump_sound.play()


## The bomb equipped (bomb_button.gd): a snappy click-clack.
func equip_bomb() -> void:
	equip_bomb_sound.play()


## A loudness share (0..1) in decibels, as volume_db wants: 1 = 0 dB (as set), 0.5 = -6 dB, 0 = -80 dB (silent).
## (linear_to_db(0) would be minus infinity, so it never goes below 0.0001.)
func loudness_db(share: float) -> float:
	return linear_to_db(maxf(share, 0.0001))
