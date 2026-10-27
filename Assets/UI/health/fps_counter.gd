extends Label
## THE FPS COUNTER, under the hearts (Enrico: to see how the phone copes). It isn't updated every frame: a Timer
## child (`Tick`, every update_every seconds) asks the engine for the frames per second and writes them in.
## (In Unreal: "stat fps", as a small UMG text updated by a looping timer.)

@export var update_every := 0.5      # seconds between two readings


func _ready() -> void:
	var tick := Timer.new()
	tick.name = "Tick"
	tick.wait_time = update_every
	tick.autostart = true
	tick.timeout.connect(_show_fps)
	add_child(tick)
	_show_fps()


## Engine.get_frames_per_second(): how many frames were drawn in the last second.
func _show_fps() -> void:
	text = "%d fps" % Engine.get_frames_per_second()
