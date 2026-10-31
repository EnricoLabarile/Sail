extends Node
## SOUNDS (the autoload "Sfx", like a GameInstance subsystem in Unreal): plays the game's sounds.
## The files in this folder were made from the HTML prototype's own sound code (art_src/audio/bake.py):
##   anchor_down.ogg  the anchor dropped: a thud, a splash, bubbles
##   anchor_up.ogg    the anchor weighed: the chain rattling in
##   wheel_rub.ogg    the ship's wheel: a soft wooden rub while it turns (a short loop)
##   wheel_thunk.ogg  the ship's wheel: a muted thud when it reaches full lock
##   pickup.ogg       a snappy two-note blip: something came aboard, anything (made by art_src/audio/make_pickup.py)
##   imp_death.ogg    an enemy killed (every enemy, Enrico; made for the sea imp): a low falling growl with a gurgle of noise   } made by
##   bomb_blast.ogg   a bomb going off: a crack, a deep boom, a rumble               } art_src/audio/make_danger_sounds.py
##                    (played higher and quieter: BombBlast's Pitch Scale 1.5 and Volume -6 dB in sfx.tscn, Enrico)
##   hull_bump.ogg    the hull knocking against a shore or a barrel: a dull thud, a woody knock, a little scrape
##                    (made by art_src/audio/make_bump.py)
##   equip_bomb.ogg   the bomb equipped: two dry metallic clicks, like a gun being loaded (art_src/audio/make_equip.py)
##   gust_whoosh.ogg  a very mild whoosh: the boat caught a wind gust (art_src/audio/make_whoosh.py)
##   button_press.ogg a button pressed: a soft low tock, 70 ms, 170 -> 130 Hz (art_src/audio/make_button_press.py)
##   book_open.ogg / book_close.ogg  the logbook: a page turning; closing, also the cover's soft thump (art_src/audio/make_page_turn.py)
##   boat_hurt.ogg    the boat losing hearts, whatever hurt her: a splintering crack on a heavy thud (art_src/audio/make_boat_hurt.py)
##   crank_click.ogg  one tooth of the paddles' crank going round: a dry clack (played rising, an octave a turn)  } made by
##   paddle_splash.ogg a paddle dipping into the water: a low soft splash and a thud (the prototype's)             } art_src/audio/
##   crank_unlock.ogg the crank free again: a latch's double click and a spring's ring                            } make_crank_sounds.py
##   booster.ogg      a booster orb taken: a rising whoosh, three bright notes going up, a low push (make_booster_sound.py)
##   lever_hook.ogg   the boat hooked to a lever: a low full click                                              } made by
##   lever_drag.ogg   the lever's handle dragged out: a 2 s loop of friction and a taut rope (Sfx.lever_drag)    } art_src/audio/
##   lever_done.ogg   the lever pulled all the way: a dry higher click, a snap                                   } make_lever_sounds.py
##   talk_blip.ogg    one syllable of a talking NPC, Animal Crossing style: a plain little dot of sound, 240 Hz (art_src/audio/make_talk_blip.py)
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
@onready var talk_blip_sound: AudioStreamPlayer = $TalkBlip
@onready var gust_whoosh_sound: AudioStreamPlayer = $GustWhoosh
@onready var button_press_sound: AudioStreamPlayer = $ButtonPress
@onready var boat_hurt_sound: AudioStreamPlayer = $BoatHurt
@onready var book_open_sound: AudioStreamPlayer = $BookOpen
@onready var book_close_sound: AudioStreamPlayer = $BookClose
@onready var crank_click_sound: AudioStreamPlayer = $CrankClick
@onready var paddle_splash_sound: AudioStreamPlayer = $PaddleSplash
@onready var crank_unlock_sound: AudioStreamPlayer = $CrankUnlock
@onready var booster_sound: AudioStreamPlayer = $Booster
@onready var lever_hook_sound: AudioStreamPlayer = $LeverHook
@onready var lever_drag_sound: AudioStreamPlayer = $LeverDrag
@onready var lever_done_sound: AudioStreamPlayer = $LeverDone

## The talk blips' pitch: each one picked at random between these (1 = as made), so a page babbles like a voice.
@export var talk_pitch_min := 0.96    # Enrico: only a little change of pitch (was 0.7–0.95, before 0.9–1.25)
@export var talk_pitch_max := 1.04

## Seconds an enemy's death sound waits before it plays. An enemy is usually killed by a bomb, whose blast starts in
## the same instant and would cover it (Enrico couldn't hear it): a moment later, it's heard after the bang.
@export var enemy_death_delay := 0.25

var drag_db := 0.0      # the lever drag's loudness as set in sfx.tscn (read at start): turned down from there
var splash_db := 0.0    # the paddle splash's loudness as set in sfx.tscn (read at start): turned down with the paddles' power
var rub_db := 0.0       # the rub's loudness as set in sfx.tscn (read at start): the code turns it down from there
var thunk_db := 0.0     # the same for the thud
var bump_db := 0.0      # the same for the hull's bump
var rub_share := 0.0    # how loud the rub is now, 0..1 (it follows the wheel's speed smoothly)


func _ready() -> void:
	rub_db = wheel_rub.volume_db
	thunk_db = wheel_thunk.volume_db
	bump_db = hull_bump_sound.volume_db
	splash_db = paddle_splash_sound.volume_db
	# The lever's drag goes round and round, silent until a handle is dragged out (like the wheel's rub).
	drag_db = lever_drag_sound.volume_db
	lever_drag_sound.stream.loop = true
	lever_drag_sound.volume_db = -80.0
	lever_drag_sound.play()
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


## An enemy killed (Enrico: every enemy makes this sound; sea_imp_zone.gd defeat, sea_urchin.gd blast_at):
## enemy_death_delay seconds later (a timer, like a Delay node).
func enemy_death() -> void:
	await get_tree().create_timer(enemy_death_delay).timeout
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


## One syllable of a talking NPC (talk_box.gd, while the letters are typed out): the blip at a random pitch.
func talk_blip() -> void:
	talk_blip_sound.pitch_scale = randf_range(talk_pitch_min, talk_pitch_max)
	talk_blip_sound.play()


## The boat lost hearts (Enrico: one sound for every kind of damage). boat.gd take_damage plays it, so anything
## that hurts her (fireballs, spikes, bombs, boiling water, maelstroms, waves, enemies) makes it by itself.
func boat_hurt() -> void:
	boat_hurt_sound.play()


## A button pressed (Enrico: every press gets it, with the button flashing black; for now the wheel's hub).
func button_press() -> void:
	button_press_sound.play()


## The logbook (logbook.gd): a page turning as the cover swings open, or as it folds shut (with the cover's thump).
func book(opening: bool) -> void:
	if opening:
		book_open_sound.play()
	else:
		book_close_sound.play()


## A loudness share (0..1) in decibels, as volume_db wants: 1 = 0 dB (as set), 0.5 = -6 dB, 0 = -80 dB (silent).
## (linear_to_db(0) would be minus infinity, so it never goes below 0.0001.)
func loudness_db(share: float) -> float:
	return linear_to_db(maxf(share, 0.0001))


## One tooth of the paddles' crank (crank.gd): a dry clack. `tooth` counts the teeth of this turn (0..15): each one a
## little higher, so by the end of the turn it has gone up an octave (pitch 2 = an octave up).
func crank_click(tooth: int, teeth: int) -> void:
	crank_click_sound.pitch_scale = pow(2.0, float(tooth) / teeth)
	crank_click_sound.play()


## A paddle of the wheels dipping into the water (paddles.gd), as loud as the paddles push now (power 0..1): as she
## comes to a halt the splashes get quieter and further apart, and stop.
func paddle_splash(power: float) -> void:
	paddle_splash_sound.volume_db = splash_db + loudness_db(power)
	paddle_splash_sound.pitch_scale = randf_range(0.9, 1.1)      # each splash a little different
	paddle_splash_sound.play()


## The crank can be wound again (crank.gd): a snappy mechanical unlock.
func crank_unlock() -> void:
	crank_unlock_sound.play()


## The boat took a booster orb (booster.gd): a power-up.
func booster() -> void:
	booster_sound.play()


## The boat hooked to a lever (lever.gd): a low, full click.
func lever_hook() -> void:
	lever_hook_sound.play()


## A lever's handle being dragged out (lever.gd, every frame while she's hooked): `level` 0..1 is how fast it comes out
## (0 = still: silent). Louder and a little higher the faster.
func lever_drag(level: float) -> void:
	lever_drag_sound.volume_db = drag_db + loudness_db(level) if level > 0.01 else -80.0
	lever_drag_sound.pitch_scale = 0.85 + 0.3 * clampf(level, 0.0, 1.0)


## A lever pulled all the way (lever.gd): a dry, higher click.
func lever_done() -> void:
	lever_done_sound.play()


## The boat caught a wind gust (gust.gd): a very mild whoosh.
func gust_whoosh() -> void:
	gust_whoosh_sound.play()


# ---------- In the background: silent and paused ----------
# Enrico: with the browser in the background (another tab, another app, the phone's screen off) the game went on
# playing its sounds. Godot tells every node when the game loses or gets back the focus (a notification, like
# Unreal's "application will deactivate" delegates): then the sound is muted (the Master bus) and the game paused,
# and both come back as they were when it returns. (On the PC this also happens when you click another window.)

var paused_before_background := false   # was the game already paused (start screen, game over) when it went away?
var in_background := false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		go_to_background()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		come_back()


## The game went into the background: mute every sound and pause the game.
func go_to_background() -> void:
	if in_background:
		return
	in_background = true
	paused_before_background = get_tree().paused
	AudioServer.set_bus_mute(0, true)        # bus 0 = Master: everything goes through it
	get_tree().paused = true


## The game is back in front: sound on, and the game goes on (unless it was already paused before).
func come_back() -> void:
	if not in_background:
		return
	in_background = false
	AudioServer.set_bus_mute(0, false)
	get_tree().paused = paused_before_background
