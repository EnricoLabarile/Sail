@tool
@icon("res://Assets/Quests/event_trigger/event_trigger_icon.svg")
class_name EventTrigger
extends Node
## An event (Enrico, Nov 2026): "when these things in the world are done, make these other things happen".
## Like a little piece of Level Blueprint in Unreal, but a node you place in the level and fill in the Inspector.
##
## WHAT IT WATCHES: `watch`, things picked from the scene tree. Every kind of element sends the same signal,
## `done`, when its job is over (like an Event Dispatcher with the same name on every Blueprint):
##   Destructible destroyed · Pickup taken · Towable brought to its TowGoal · TowGoal reached · sea imp defeated ·
##   sea urchin killed · NPC / sign: a talk with it ended · lever pulled all the way · bridge lock opened.
## `need` ALL: every one of them must be done; ANY: the first one is enough.
##
## WHAT IT DOES, once, `delay` seconds after:
##   `show_nodes`   appear: they're hidden and switched off when the game starts (in the editor you still see them,
##                  to place them), and switched on here: the way to "spawn" something, or to swap an abandoned
##                  house for a mended one (put both in the same place: the new one here, the old one in remove_nodes).
##   `remove_nodes` deleted.
##   `call_on` + `method`: calls that function on that node, to set a state (e.g. a BridgeLock and "open").
## Then it sends its own signal `triggered`.

enum Need { ALL, ANY }

## Sent once, after the actions.
signal triggered

## The things to watch: drag them here from the scene tree (or "Assign…"). Each must have the signal `done`.
@export var watch: Array[Node] = []
## ALL: it happens when every watched thing is done. ANY: when the first one is.
@export var need := Need.ALL

@export_group("Then")
## Hidden and switched off at the start of the game; they appear when it happens.
@export var show_nodes: Array[Node] = []
## Deleted when it happens.
@export var remove_nodes: Array[Node] = []
## A node to call a function on when it happens (empty = none)...
@export var call_on: Node
## ...and the function's name, e.g. "open" (no brackets, no arguments).
@export var method := ""
## Seconds to wait between the condition being met and the actions.
@export var delay := 0.0

var done_count := 0        # how many watched things are done so far
var needed := 0            # how many of them there are (the ones with a `done` signal)
var fired := false         # it happens only once


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	hide_until_needed()
	listen_to_watched()


## The things that will appear: hidden and switched off for now. Process Mode "Disabled" stops their scripts and
## takes their collisions and sensors out of the physics (so the boat can't hit them, Land can't see them).
func hide_until_needed() -> void:
	for thing in show_nodes:
		if thing == null:
			continue
		if "visible" in thing:
			thing.visible = false
		thing.process_mode = Node.PROCESS_MODE_DISABLED


## Connect to each watched thing's `done`. ONE_SHOT: a thing counts once, even if it's done again (a lever pulled
## twice, an NPC talked to twice).
func listen_to_watched() -> void:
	for thing in watch:
		if thing == null:
			continue
		if not thing.has_signal("done"):
			push_warning("EventTrigger %s: %s has no 'done' signal, it can't be watched." % [name, thing.name])
			continue
		thing.done.connect(_on_watched_done, CONNECT_ONE_SHOT)
		needed += 1
	if needed == 0:
		push_warning("EventTrigger %s: nothing to watch." % name)


## One of the watched things is done: count it, and see if that's enough.
func _on_watched_done() -> void:
	if fired:
		return
	done_count += 1
	if need == Need.ANY or done_count >= needed:
		happen()


## The actions, once (after the delay).
func happen() -> void:
	fired = true
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	for thing in show_nodes:
		if is_instance_valid(thing):
			appear(thing)
	for thing in remove_nodes:
		if is_instance_valid(thing):
			thing.queue_free()
	call_method()
	triggered.emit()


## Switched back on (scripts, collisions) and shown.
func appear(thing: Node) -> void:
	thing.process_mode = Node.PROCESS_MODE_INHERIT
	if "visible" in thing:
		thing.visible = true


## call_on.method(), if both are set and the function exists.
func call_method() -> void:
	if not is_instance_valid(call_on) or method == "":
		return
	if call_on.has_method(method):
		call_on.call(method)
	else:
		push_warning("EventTrigger %s: %s has no function '%s'." % [name, call_on.name, method])


## The yellow triangle in the scene tree (editor only): what's set up wrong.
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if watch.is_empty():
		warnings.append("Nothing to watch: add things to 'watch'.")
	for thing in watch:
		if thing != null and not thing.has_signal("done"):
			warnings.append("%s has no 'done' signal: it can't be watched." % thing.name)
	if call_on != null and method == "":
		warnings.append("'call_on' is set but 'method' is empty.")
	return warnings
