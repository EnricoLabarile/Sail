extends Node
## THE LOGBOOK: the button bottom left and the book that comes down from the top.
## (In Unreal: a UMG widget with an open/close animation, here made with Tweens.)
##
## A tap on the button opens the book in two steps, as in the HTML prototype:
##   1. the shut book slides down from above the screen (DROP_TIME);
##   2. its cover swings open on the spine, while the book slides to the middle (UNFOLD_TIME).
## Another tap closes it the other way round: the cover folds shut, then the book slides back up.
##
## Nodes (logbook.tscn):
##   IconLayer (CanvasLayer 95, under the dither, so the icon gets the 1-bit look) / BookIcon  ← book_icon.gd
##   BookLayer (CanvasLayer 120, over everything, crisp)                        / Book      ← book.gd

const DROP_TIME := 0.26       # seconds for the shut book to come down (or go back up)
const UNFOLD_TIME := 0.33     # seconds for the cover to swing open (or shut)
const BOOK_MAX := Vector2(420, 390)   # the book's largest size, in pixels
const TOP_GAP := 8.0          # space above the book when it's down

@onready var icon: Control = $IconLayer/BookIcon
@onready var book: Control = $BookLayer/Book

var is_open := false
var drop := 0.0               # 0 = up, out of sight; 1 = down, in place (changed by the Tween)
var _tween: Tween             # the animation running now, if any


func _ready() -> void:
	icon.pressed.connect(toggle)          # when the icon says "pressed", call toggle()
	book.visible = false


## Open the book if it's shut, shut it if it's open.
func toggle() -> void:
	set_open(not is_open)


func set_open(open: bool) -> void:
	is_open = open
	if _tween:
		_tween.kill()                     # stop the animation in progress, if any, and start from here
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)   # quick at first, gentle at the end
	if open:
		book.visible = true
		_tween.tween_property(self, "drop", 1.0, DROP_TIME)        # 1. down…
		_tween.tween_property(book, "unfold", 1.0, UNFOLD_TIME)    # 2. …then open
	else:
		_tween.tween_property(book, "unfold", 0.0, UNFOLD_TIME)    # 1. fold shut…
		_tween.tween_property(self, "drop", 0.0, DROP_TIME)        # 2. …then up
		_tween.tween_callback(func(): book.visible = false)        # 3. and hide it
	# the button's own little animation (cover opening on the icon), at the same time
	create_tween().tween_property(icon, "open_amount", 1.0 if open else 0.0, 0.3)


## Every frame: work out the book's size and place it from `drop` and `unfold`.
func _process(_dt: float) -> void:
	if not book.visible:
		return
	var screen := get_viewport().get_visible_rect().size
	var w := minf(BOOK_MAX.x, screen.x - 14.0)
	var h := minf(BOOK_MAX.y, screen.y - 96.0)
	book.size = Vector2(w, h)
	# Shut, the right half (the cover) is centred on the screen; open, the whole book is.
	var x: float = screen.x * 0.5 - w * (0.75 - 0.25 * book.unfold)
	# Up: above the top edge, out of sight. Down: TOP_GAP below the top.
	var y := lerpf(-h - 30.0, TOP_GAP, drop)
	book.position = Vector2(x, y)
