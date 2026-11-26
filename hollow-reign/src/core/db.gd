extends Node
## Static game data, loaded from JSON so content can be added without code changes.

var items: Dictionary = {}
var item_list: Array = []
var classes: Dictionary = {}
var rarity_order: Array = []
var foes: Dictionary = {}
var regions: Array = []
var combos: Array = []
var combo_by_id: Dictionary = {}
var region_by_id: Dictionary = {}
var lore: Array = []
var lore_by_id: Dictionary = {}
var quests: Array = []
var quest_by_id: Dictionary = {}

const RARITY_COLOR := {
	"common": Color("#9a958c"), "uncommon": Color("#7d9a6a"), "rare": Color("#5f86b0"),
	"epic": Color("#8d62b0"), "legendary": Color("#c9a14a"),
}
const SLOTS := ["weapon", "shield", "helm", "chest", "gauntlets", "legs", "ring", "relic"]
const SLOT_NAME := {"weapon": "Weapon", "shield": "Shield", "helm": "Helm", "chest": "Chest", "gauntlets": "Gauntlets", "legs": "Greaves", "ring": "Ring", "relic": "Relic"}
const ATTRS := ["health", "strength", "dex", "endurance", "defense", "crit", "resist"]
const ATTR_NAME := {"health": "Health", "strength": "Strength", "dex": "Dexterity", "endurance": "Endurance", "defense": "Defense", "crit": "Critical", "resist": "Resistance"}
const ATTR_DESC := {
	"health": "+12 maximum health", "strength": "Damage with heavy weapons", "dex": "Damage with quick weapons",
	"endurance": "+6 stamina, faster recovery", "defense": "Reduces damage taken", "crit": "Damage against staggered foes",
	"resist": "Resists frost and flame",
}

func _ready() -> void:
	var d: Dictionary = _load("res://data/items.json")
	classes = d.classes
	rarity_order = d.rarity_order
	item_list = d.items
	for it in item_list:
		items[it.id] = it
	for f in _load("res://data/bosses.json").bosses:
		foes[f.id] = f
	combos = _load("res://data/combos.json").combos
	for c in combos:
		combo_by_id[c.id] = c
	regions = _load("res://data/regions.json").regions
	for r in regions:
		region_by_id[r.id] = r
	lore = _load("res://data/lore.json").lore
	for l in lore:
		lore_by_id[l.id] = l
	quests = _load("res://data/quests.json").quests
	for q in quests:
		quest_by_id[q.id] = q

func _load(path: String) -> Dictionary:
	var txt := FileAccess.get_file_as_string(path)
	var v = JSON.parse_string(txt)
	assert(v is Dictionary, "bad data file " + path)
	return v

func item(id: String) -> Dictionary:
	return items.get(id, {})

func rarity_color(it: Dictionary) -> Color:
	return RARITY_COLOR.get(it.get("rarity", "common"), Color.WHITE)

func rarity_rank(it: Dictionary) -> int:
	return rarity_order.find(it.get("rarity", "common"))
