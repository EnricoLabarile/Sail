extends Control
## THE TALK BOX: the panel at the top of the screen where an NPC talks (Assets/NPCs/npc/npc.gd opens it).
## (In Unreal: a UMG widget with an Image, two Text blocks and a little typewriter logic.)
##
## On the left a framed portrait, on the right the speaker's name and the words. Each page is typed out
## letter by letter (`letters_per_second`). A quick tap on the wheel's hub (helm.gd sends `hub_tapped`):
##   - while the page is still being typed: the whole page shows at once;
##   - once it's all there: the next page; after the last page, the box closes.
## While it's open the hub's long press doesn't work the anchor (boat.gd `talking`), so she can't sail off by mistake.
##
## Its layout (where it sits, how big, the frame's size) is set in talk_box.tscn: Box's anchors and offsets,
## Portrait / Name / Text's places inside it. Drawn crisp, on its own CanvasLayer (115), not through the dither.

@export var letters_per_second := 30.0   # how fast the words are typed out (higher = quicker)

const PAPER := Color("ebe7dc")
const INK := Color("1b1a17")

signal finished                           # the last page was closed

var pages: Array[String] = []             # the lines being shown, one entry a page
var page := 0                             # which page is showing now
var letters_shown := 0.0                  # how many letters of this page are typed out so far
var on_finished: Callable                 # who to tell when it's over (the NPC)

@onready var portrait: TextureRect = $Portrait
@onready var name_label: Label = $Name
@onready var text_label: Label = $Text


func _ready() -> void:
	add_to_group("talk_box")              # so an NPC finds it (npc.gd)
	visible = false
	_listen_to_helm.call_deferred()


func _process(dt: float) -> void:
	if not visible:
		return
	# The typewriter: a few more letters every frame, until the whole page is there.
	var total := text_label.get_total_character_count()
	if letters_shown < total:
		letters_shown = minf(total, letters_shown + letters_per_second * dt)
		text_label.visible_characters = int(letters_shown)


## Opens the box with these pages (an NPC calls it). `when_done` is called after the last page is closed.
func open(speaker: String, picture: Texture2D, lines: Array[String], when_done: Callable) -> void:
	pages = lines
	page = 0
	on_finished = when_done
	name_label.text = speaker
	portrait.texture = picture
	_set_boat_talking(true)
	visible = true
	_show_page()


## A quick tap on the hub: finish typing this page, or go on to the next, or close after the last.
func tap() -> void:
	if not visible:
		return
	if letters_shown < text_label.get_total_character_count():
		letters_shown = text_label.get_total_character_count()      # show the whole page at once
		text_label.visible_characters = -1                          # -1 = every letter
		return
	page += 1
	if page < pages.size():
		_show_page()
	else:
		_close()


func _show_page() -> void:
	text_label.text = pages[page]
	letters_shown = 0.0
	text_label.visible_characters = 0


func _close() -> void:
	visible = false
	_set_boat_talking(false)
	finished.emit()
	if on_finished.is_valid():
		on_finished.call()


## The boat ignores the anchor button's long press while someone is talking (boat.gd toggle_anchor).
func _set_boat_talking(on: bool) -> void:
	var boat := get_tree().get_first_node_in_group("player_boat")
	if boat:
		boat.talking = on


## The wheel's hub sends `hub_tapped` on a quick tap (helm.gd).
func _listen_to_helm() -> void:
	var helm := get_tree().get_first_node_in_group("helm")
	if helm:
		helm.hub_tapped.connect(tap)


## The panel: paper with an ink border and a hard ink shadow (like the hearts' panel), and the portrait's frame.
func _draw() -> void:
	var panel := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(panel.position + Vector2(3, 3), panel.size), INK)    # the shadow
	draw_rect(panel, PAPER)
	draw_rect(panel, INK, false, 2.0)
	# The portrait's frame: a double ink line round the picture's place.
	var frame := Rect2(portrait.position, portrait.size).grow(3.0)
	draw_rect(frame, INK, false, 2.0)
	draw_rect(frame.grow(-4.0), INK, false, 1.0)
