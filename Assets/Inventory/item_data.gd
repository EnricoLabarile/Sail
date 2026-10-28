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
@export var equippable := false       # true: tapping its slot in the logbook equips it (bombs, traps)
## Which equip slot it goes in. "main": bombs and traps, one at a time (the bomb button). "wind": the Aeolus Jar,
## with its own button under the bomb's, so it's equipped alongside a bomb or a trap, not instead of it.
@export_enum("main", "wind") var equip_slot := "main"
## Equipped by itself whenever one comes aboard (the bomb, the Aeolus Jar).
@export var equip_on_pickup := false
