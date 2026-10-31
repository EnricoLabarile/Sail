class_name ItemData
extends Resource
## ONE KIND OF ITEM: what it's called, its picture, its prices and its rules. Each kind is a .tres file in
## Assets/Inventory/items/ (fish.tres, bomb.tres…). (In Unreal: a Data Asset.)
## The Inventory reads every file in that folder when the game starts, so a new kind of item is just a new .tres
## there (right-click the folder → New Resource → ItemData), no code. A store sells the ones picked in its
## Inspector (store.gd, for_sale).

@export var id := ""                  # the name the code uses for it ("fish", "bomb"…): must be unique
@export var display_name := ""        # the name the player reads (at the store)
@export var icon: Texture2D           # its picture in the logbook and at the store
@export var buy_price := 0            # coins a merchant asks for one (0 = no merchant sells it)
@export var sell_price := 0           # coins a merchant pays for one of yours (0 = merchants don't buy it)
@export var stackable := false        # true: they pile up in ONE slot of the hold, with their number on it
@export var equippable := false       # true: it can go in the A or B slot (a tap on its slot in the logbook)
## Switched on and off by a tap on its slot in the logbook, instead of going in A or B (the sail, Enrico):
## Inventory.toggle / is_on. Leave `equippable` off for these.
@export var toggle_on_tap := false
## Equipped by itself whenever one comes aboard, in the first empty slot (A, then B).
@export var equip_on_pickup := false
