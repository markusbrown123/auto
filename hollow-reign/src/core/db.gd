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
## The eight slots the first inventory screens were built around. Kept as it was for them.
const SLOTS := ["weapon", "shield", "helm", "chest", "gauntlets", "legs", "ring", "relic"]
## Every equipment slot, in the order a screen should offer them. `offhand` exists in saves and rules but no item
## uses it yet (docs/EQUIPMENT_PROGRESSION.md, "Proposed").
const EQUIP_SLOTS := ["weapon", "offhand", "shield", "helm", "chest", "shoulders", "gauntlets", "legs", "boots", "ring", "relic"]
const ARMOUR_SLOTS := ["helm", "chest", "shoulders", "gauntlets", "legs", "boots"]
const SLOT_NAME := {"weapon": "Weapon", "offhand": "Off hand", "shield": "Shield", "helm": "Helm", "chest": "Chest", "shoulders": "Shoulders",
	"gauntlets": "Gauntlets", "legs": "Greaves", "boots": "Boots", "ring": "Ring", "relic": "Relic"}
const TIER_COLOR := {"common": Color("#9a958c"), "uncommon": Color("#7d9a6a"), "rare": Color("#5f86b0"), "legendary": Color("#8d62b0"), "relic": Color("#c9a14a")}

## The equipment and progression rules (data/equipment.json, written by tools/gen_equipment.py).
var equipment: Dictionary = {}
var families: Dictionary = {}
var materials: Dictionary = {}
var aliases: Dictionary = {}
var challenges: Dictionary = {}
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
	_load_equipment()
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

## Lays the generated equipment layer over the base item list: new pieces are appended, every item gains its tier,
## family, weight class, requirements, acquisition, visual reference and upgrade/mastery tracks.
func _load_equipment() -> void:
	equipment = _load("res://data/equipment.json")
	families = equipment.families
	materials = equipment.materials
	aliases = equipment.aliases
	for c in equipment.challenges:
		challenges[c.id] = c
	for id: String in equipment.items:
		var e: Dictionary = equipment.items[id]
		if e.has("base") and not items.has(id):
			var it: Dictionary = e.base.duplicate(true)
			item_list.append(it)
			items[id] = it
		if not items.has(id):
			continue
		for k: String in e:
			if k != "base":
				items[id][k] = e[k]
	Stats.rules = equipment

## An item definition by id. Old and alternative ids resolve to the stored one; an unknown id gives {}.
func item(id: String) -> Dictionary:
	return items.get(aliases.get(id, id), {})

## The stored id for an id that may be an alias.
func canon(id: String) -> String:
	return str(aliases.get(id, id))

## One of the five ranks shown to the player: common, uncommon, rare, legendary, relic.
func tier(it: Dictionary) -> String:
	return str(it.get("tier", equipment.tiers.get(it.get("rarity", "common"), "common")))

func tier_color(it: Dictionary) -> Color:
	return TIER_COLOR.get(tier(it), Color.WHITE)

func family(it: Dictionary) -> Dictionary:
	return families.get(it.get("family", ""), {})

func material_name(id: String) -> String:
	return "Shards" if id == "shards" else str(materials.get(id, {}).get("name", id))

func rarity_color(it: Dictionary) -> Color:
	return RARITY_COLOR.get(it.get("rarity", "common"), Color.WHITE)

func rarity_rank(it: Dictionary) -> int:
	return rarity_order.find(it.get("rarity", "common"))
