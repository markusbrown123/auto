#!/usr/bin/env python3
"""Authoring script for data/equipment.json: the equipment and progression layer.

data/items.json stays the hand-written base list (ids, names, base numbers). This script reads it together with
bosses.json, regions.json and quests.json and writes everything the progression rules need on top of it:
families and set bonuses, weight classes, materials, per-item tier/family/weight/requirements/acquisition/visual
reference/upgrade and mastery tracks, the new pieces (shoulders, boots, two swords, one shield), boss first-kill
rewards, optional-encounter exclusives, regional drop tables, forge recipes and the upgrade cost table.
Db merges it over items.json at load. Run:  python3 tools/gen_equipment.py   (from the project root)
Tune the economy numbers here, then check them with tools/econ_sim.sh."""
import json, os, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def load(name): return json.load(open(os.path.join(ROOT, "data", name)))
def exists(rel): return os.path.exists(os.path.join(ROOT, rel))

BASE = load("items.json")
ITEMS = BASE["items"]
BY_ID = {it["id"]: it for it in ITEMS}
FOES = {f["id"]: f for f in load("bosses.json")["bosses"]}
REGIONS = load("regions.json")["regions"]
REGION = {r["id"]: r for r in REGIONS}
QUESTS = load("quests.json")["quests"]
RANK = BASE["rarity_order"]                       # common uncommon rare epic legendary (the stored values)

# ------------------------------------------------------------------ vocabulary
SLOTS = ["weapon", "offhand", "shield", "helm", "chest", "shoulders", "gauntlets", "legs", "boots", "ring", "relic"]
ARMOUR = ["helm", "chest", "shoulders", "gauntlets", "legs", "boots"]
# The five ranks the player is shown. The stored `rarity` keeps its old values so every old id, colour and save works.
TIER = {"common": "common", "uncommon": "uncommon", "rare": "rare", "epic": "legendary", "legendary": "relic"}
TIER_NAME = {"common": "Common", "uncommon": "Uncommon", "rare": "Rare", "legendary": "Legendary", "relic": "Relic"}

# Per worn piece (six armour slots and the shield). Every key is read by Stats.compute and reaches the duel.
WEIGHTS = {
    "light":  {"name": "Light",  "regen_pct": 2.0,  "swing_cost_pct": -1.0, "block": 0.0,
               "text": "Each piece: stamina returns 2% faster, swings cost 1% less."},
    "medium": {"name": "Medium", "regen_pct": 0.0,  "swing_cost_pct": 0.0,  "block": 0.0, "text": "No penalty, no gift."},
    "heavy":  {"name": "Heavy",  "regen_pct": -2.0, "swing_cost_pct": 1.0,  "block": 0.012,
               "text": "Each piece: stamina returns 2% slower, swings cost 1% more, guarding costs 1.2% less."},
}

MATERIALS = {
    "m_iron":  {"price": 40, "name": "Old Iron",      "regions": ["courtyard", "blackwood"], "desc": "Garrison stock, sound under the rust."},
    "m_silver": {"price": 90, "name": "Grave Silver", "regions": ["cathedral", "crypt"],     "desc": "Poured for the dead. It takes an edge the living never asked of it."},
    "m_scale": {"price": 150, "name": "Wyrm Scale",    "regions": ["roost"],                  "desc": "Shed, not cut. Still warm."},
    "m_rime":  {"price": 150, "name": "Rimesteel",     "regions": ["citadel"],                "desc": "Steel that wintered in the Citadel and did not come back the same."},
    "m_glass": {"price": 240, "name": "Hollow Glass",  "regions": ["deep", "throne"],         "desc": "Not glass. Orren will not say what it was part of."},
    "m_core":  {"price": 0, "name": "Guardian Core", "regions": [],                         "desc": "What a guardian was built around. One to a guardian."},
}
REGION_MAT = {r: m for m, d in MATERIALS.items() for r in d["regions"]}

# The eight armour families, and which of the existing suits each one is.
FAMILIES = {
    "crownless":    {"name": "Crownless",    "suits": ["worn", "garrison"], "weight": "medium", "region": "courtyard",
        "why": "The knight's own plate and the garrison's: soldiers of a throne with nobody on it.",
        "set": [[2, {"stamina": 6}], [4, {"hp": 12}], [6, {"regen_pct": 3.0}]]},
    "ashbound":     {"name": "Ashbound",     "suits": ["ash"],      "weight": "heavy",  "region": "courtyard",
        "why": "The Ashen Sentinel's scorched plate.",
        "set": [[2, {"resist": 8}], [4, {"block": 0.04}], [6, {"defense": 6}]]},
    "widow":        {"name": "Widow",        "suits": ["black"],    "weight": "light",  "region": "blackwood",
        "why": "The black lacquered suit: the lightest and darkest of the eight, the one a mourner would wear to a duel.",
        "set": [[2, {"dex": 2}], [4, {"crit": 5}], [6, {"swing_cost_pct": -4.0}]]},
    "gravekeeper":  {"name": "Gravekeeper",  "suits": ["vigil"],    "weight": "medium", "region": "crypt",
        "why": "The vigil plate of those who stood watch over the dead; the Gravewarden still carries half of it.",
        "set": [[2, {"hp": 10}], [4, {"defense": 4}], [6, {"stamina": 10}]]},
    "frostwarden":  {"name": "Frostwarden",  "suits": ["frost"],    "weight": "heavy",  "region": "citadel",
        "why": "Rimebound plate of the Frozen Citadel.",
        "set": [[2, {"resist": 10}], [4, {"hp": 15}], [6, {"block": 0.05}]]},
    "dragonforged": {"name": "Dragonforged", "suits": ["wyrm"],     "weight": "heavy",  "region": "roost",
        "why": "Broodscale harness from the Wyrm's Roost.",
        "set": [[2, {"resist": 8}], [4, {"strength": 3}], [6, {"crit": 6}]]},
    "sovereign":    {"name": "Sovereign",    "suits": ["regal"],    "weight": "medium", "region": "throne",
        "why": "The Monarch's own harness.",
        "set": [[2, {"hp": 12}], [4, {"strength": 2, "dex": 2}], [6, {"defense": 8}]]},
    "architect":    {"name": "Architect",    "suits": ["hollow"],   "weight": "light",  "region": "deep",
        "why": "The hollowed suit from the Deep: the oldest work, made by whoever built the guardians.",
        "set": [[2, {"stamina": 8}], [4, {"regen_pct": 4.0}], [6, {"crit": 8}]]},
}
SUIT_FAMILY = {s: f for f, d in FAMILIES.items() for s in d["suits"]}
STAT_TEXT = {"stamina": "+%d stamina", "hp": "+%d health", "regen_pct": "stamina returns %d%% faster", "resist": "+%d resistance",
    "block": "guarding costs %d%% less", "defense": "+%d defence", "dex": "+%d dexterity", "strength": "+%d strength",
    "crit": "+%d critical", "swing_cost_pct": "swings cost %d%% less"}
def bonus_text(b):
    bits = []
    for k, v in b.items():
        n = abs(v * 100 if k == "block" else v)
        bits.append(STAT_TEXT[k] % round(n))
    return ", ".join(bits)

# ------------------------------------------------------------------ the economy table (tuned with tools/econ_sim.sh)
UPGRADE_MAX = 5
# gold for level n+1 = base[rank] * step[n]; shards = shard[rank] * (n+1); materials from level 3 for rare and above.
UPGRADE = {
    "max": UPGRADE_MAX,
    "gold_base": [50, 85, 150, 260, 400],
    "gold_step": [1.0, 1.6, 2.4, 3.4, 4.6],
    "shard": [1, 1, 1, 2, 2],
    "slot_mult": {"weapon": 1.0, "shield": 0.8, "chest": 0.8, "helm": 0.6, "legs": 0.6, "shoulders": 0.5, "gauntlets": 0.5, "boots": 0.5},
    "mat_from_level": 2,           # the third level and up asks for the item's material...
    "mat_min_rank": 2,             # ...for rare and above
    "core_min_rank": 3,            # the last level of legendary and relic gear asks for one guardian core
    "growth": {"weapon": {"damage_pct": 10}, "armour": {"defense_pct": 10}, "shield": {"defense_pct": 10, "block": 0.03}},
}
SELL_RATE = 0.35
SHARD_PRICE = 60                  # Orren sells shards, and the material of any region already cleared; he buys neither back
BUYBACK_RATE = 3.0                 # a sold one-of-a-kind item can be bought back for this many times what it sold for
SHOP_STAGE = {"common": 0, "uncommon": 0, "rare": 1, "epic": 3, "legendary": 5}     # regions cleared before Orren stocks it
REWARDS = {
    "repeat": [1.0, 0.85, 0.7, 0.55, 0.4],     # gold/xp/material share by how often this foe is among the last `window` wins
    "window": 8,
    "drop_chance": 0.10,           # an ordinary foe drops a piece of regional gear
    "elite_drop_chance": 0.22,
    "discover_chance": 0.30,       # a rumour: an undiscovered item of this region becomes a known silhouette with its hint
    "pity": 3,                     # after this many wins in a row with nothing new to look at, something new is forced
    "mat_fight": 1, "mat_elite": 2, "mat_boss": 4,
    "shards_fight": 1, "shards_boss": 3, "shards_boss_per_region": 1,      # a guardian gives 3 shards, plus one for each region before its own
    "mat_chance": 0.65,
    "dup_gold": 0.25,              # a guaranteed reward already held pays this share of the foe's gold instead...
    "dup_mats": 2,                 # ...and this many of the region's material
    "ng_item_chance": 0.5,
    "ng_gold": 1.0, "ng_xp": 0.5,  # each cycle of New Game Plus adds this share to what a foe pays
}
REQUIRE = {"attack_pct": -15.0, "swing_cost_pct": 20.0, "regen_pct": -3.0}      # what an unmet requirement costs

# ------------------------------------------------------------------ new pieces
SUIT_NAME = {"worn": "Wayfarer", "garrison": "Garrison", "black": "Blackwood", "ash": "Ashen", "vigil": "Vigil", "frost": "Rimebound",
    "regal": "Monarch's", "hollow": "Hollowed", "wyrm": "Broodscale"}
SHOULDER_WORD = {"worn": "Pauldrons", "garrison": "Pauldrons", "black": "Spaulders", "ash": "Pauldrons", "vigil": "Mantle", "frost": "Pauldrons",
    "regal": "Pauldrons", "hollow": "Spaulders", "wyrm": "Pauldrons"}
BOOT_WORD = {"worn": "Boots", "garrison": "Sabatons", "black": "Treads", "ash": "Sabatons", "vigil": "Sabatons", "frost": "Sabatons",
    "regal": "Sabatons", "hollow": "Treads", "wyrm": "Sabatons"}
SHOULDER_DESC = {
    "worn": "Two plain plates on worn straps. They sit as if they had been yours for years.",
    "garrison": "Stamped with a company number. The company is a line in a roll nobody reads.",
    "black": "Lacquered so the light slides off. Cut high, to leave the arms their reach.",
    "ash": "The scorch goes all the way through. They are heavier than they look, and they look heavy.",
    "vigil": "A short mantle of plates, made to be stood in for a very long time.",
    "frost": "Frost gathers on them indoors.",
    "regal": "Fluted, and gilded only where a hand would never touch.",
    "hollow": "Thin as a leaf and it will not dent. Nobody alive knows how to make the seam.",
    "wyrm": "Scales set in overlapping rows, each one drilled by hand.",
}
BOOT_DESC = {
    "worn": "Flat-soled and resoled. Whoever walked in them last walked a long way.",
    "garrison": "Issued in pairs, in three sizes. These are the middle size.",
    "black": "Soft at the ankle and silent on leaf-fall.",
    "ash": "The soles have fused and been ground flat again, more than once.",
    "vigil": "Worn smooth inside by one man standing still.",
    "frost": "They grip ice as though they were part of it.",
    "regal": "Made for a floor that was polished every morning.",
    "hollow": "They weigh nothing and leave no print.",
    "wyrm": "Scaled to the knee, and proof against a hot floor.",
}
# where each new piece comes from: "shop" (with a price), a foe id (an optional encounter's exclusive, or a guardian's pool), "craft"
SHOULDER_FROM = {"worn": "shop", "garrison": "shop", "black": "shop", "ash": "gate_colossus", "vigil": "bell_ringer", "frost": "hoarbeast",
    "regal": "throne_colossus", "hollow": "the_unburied", "wyrm": "brood_keeper"}
BOOT_FROM = {"worn": "shop", "garrison": "shop", "black": "veil_dancer", "ash": "ashen_sentinel", "vigil": "shop", "frost": "craft",
    "regal": "craft", "hollow": "craft", "wyrm": "craft"}
ENCOUNTERS = {"pike_sergeant": "s_round"}          # optional foe -> its exclusive first-kill item (filled in below)
# boss -> extra pool entries [id, chance]. Three Ashen pieces had no way to be obtained at all: the Sentinel carries them.
BOSS_EXTRA = {"ashen_sentinel": [["a_ash_helm", 0.5], ["a_ash_gauntlets", 0.5], ["a_ash_legs", 0.5]]}
CRAFT_ONLY = []

def suit_piece(suit, slot):
    return BY_ID["a_%s_%s" % (suit, slot)]

NEW = []
for suit in SUIT_NAME:
    helm, chest, legs = suit_piece(suit, "helm"), suit_piece(suit, "chest"), suit_piece(suit, "legs")
    fam = FAMILIES[SUIT_FAMILY[suit]]
    light = fam["weight"] == "light"
    res = int(helm.get("resist", 0)) // 2
    for slot, word, desc, src in [("shoulders", SHOULDER_WORD, SHOULDER_DESC, SHOULDER_FROM), ("boots", BOOT_WORD, BOOT_DESC, BOOT_FROM)]:
        it = {"id": "a_%s_%s" % (suit, slot), "name": "%s %s" % (SUIT_NAME[suit], word[suit]), "slot": slot, "rarity": helm["rarity"],
              "price": 0, "desc": desc[suit], "ng_min": 0, "look": dict(helm.get("look", {}))}
        if slot == "shoulders":
            it["defense"] = max(1, round(helm["defense"] * 0.34) - (1 if light else 0))
            if chest.get("hp"):
                it["hp"] = chest["hp"] // 3
        else:
            it["defense"] = max(1, round(helm["defense"] * 0.28))
            it["stamina"] = max(2, int(legs.get("stamina", 0)) // 2) + (2 if light else 0)
        if res:
            it["resist"] = res
        how = src[suit]
        if how == "shop":
            base = helm["price"] if helm["price"] else {"worn": 100}[suit]
            it["price"] = int(round(base * (0.7 if slot == "shoulders" else 0.6) / 5.0)) * 5
        elif how == "craft":
            CRAFT_ONLY.append(it["id"])
        elif FOES[how]["boss"]:
            BOSS_EXTRA.setdefault(how, []).append([it["id"], 0.5])
        else:
            ENCOUNTERS[how] = it["id"]
        NEW.append(it)

NEW += [
    {"id": "w_cold_resolve", "name": "Cold Resolve", "slot": "weapon", "cls": "sword", "rarity": "epic", "damage": 40, "price": 0, "crit": 6,
     "desc": "A narrow blade of folded rimesteel. It does not hurry, and it does not change its mind.", "element": "frost", "ng_min": 0,
     "look": {"metal": "#b8ccd8", "glow": "#9fe0ff"}},
    {"id": "w_twin_relics", "name": "Twin Relics", "slot": "weapon", "cls": "dual", "rarity": "legendary", "damage": 35, "price": 0, "crit": 18,
     "desc": "Two short blades of the old make. Called, they assemble in the hand, hilt first.", "element": None, "ng_min": 0,
     "look": {"metal": "#c8ccd4", "glow": "#9ad8ff", "curved": False}},
    {"id": "s_round", "name": "Gatehouse Round", "slot": "shield", "rarity": "uncommon", "price": 0, "defense": 3, "block": 0.10, "stamina": 6,
     "desc": "A small round shield, light enough to forget you are carrying.", "ng_min": 0, "look": {"color": "#6a5a3a"}},
]
CRAFT_ONLY.append("w_cold_resolve")
ALL = ITEMS + NEW
for it in NEW:
    assert it["id"] not in BY_ID, it["id"]
    BY_ID[it["id"]] = it

# ------------------------------------------------------------------ per-item facts
# The brief's ten sword directions, and the item each one is. `was` is the name the item carried before.
NAMED = {
    "Wayfarer": {"id": "w_rusted_sword"},
    "Silver Vow": {"id": "w_dawnline", "was": "Dawnline"},
    "Ashbrand": {"id": "w_censer_sword"},
    "King's Remnant": {"id": "w_throneshard", "was": "Throneshard"},
    "Cold Resolve": {"id": "w_cold_resolve", "new": True},
    "Nightward": {"id": "w_vigil_edge", "was": "Vigil Edge"},
    "Oathbreaker": {"id": "w_oath_axe", "note": "was an axe; now a greatsword as the brief asks. The id is kept."},
    "Veilcutter": {"id": "w_starfall", "was": "Starfall"},
    "Twin Relics": {"id": "w_twin_relics", "new": True},
    "Eternal Edge": {"id": "w_monarch"},
}
# Semantic ids that resolve to the stored ones (Db.item accepts either; saves holding them are rewritten on load).
ALIASES = {"w_wayfarer": "w_rusted_sword", "w_silver_vow": "w_dawnline", "w_ashbrand": "w_censer_sword", "w_kings_remnant": "w_throneshard",
    "w_nightward": "w_vigil_edge", "w_oathbreaker": "w_oath_axe", "w_veilcutter": "w_starfall", "w_eternal_edge": "w_monarch"}
ADVANCED = ["w_monarch", "w_starfall", "w_throneshard", "w_twin_relics", "w_hunger", "s_rime"]       # Recall-capable: the old make
QUEST_ITEMS = ["x_name", "r_crown"]            # story keepsakes: never sold
UNSELLABLE = ["w_rusted_sword"]
WEAPON_FAMILY = {"w_rusted_sword": "crownless", "w_knight_sword": "crownless", "w_dawnline": "crownless", "w_ashen_great": "ashbound",
    "w_censer_sword": "ashbound", "w_ember_fangs": "ashbound", "w_woodcutter": "widow", "w_headsman": "widow", "w_twin_fangs": "widow",
    "w_pilgrim_blades": "widow", "w_vigil_edge": "gravekeeper", "w_crypt_great": "gravekeeper", "w_frost_great": "frostwarden",
    "w_rime_sword": "frostwarden", "w_cold_resolve": "frostwarden", "w_wyrmfang": "dragonforged", "w_monarch": "sovereign",
    "w_throneshard": "sovereign", "w_oath_axe": "sovereign", "w_starfall": "architect", "w_hunger": "architect", "w_twin_relics": "architect",
    "s_plank": "crownless", "s_garrison": "crownless", "s_round": "crownless", "s_tower": "ashbound", "s_reliquary": "gravekeeper",
    "s_rime": "frostwarden", "s_scale": "dragonforged", "r_iron": "crownless", "r_ember": "ashbound", "r_widow": "widow", "r_frost": "frostwarden",
    "r_crown": "sovereign", "r_brood": "dragonforged", "x_candle": "crownless", "x_bell": "gravekeeper", "x_tooth": "widow", "x_tear": "frostwarden",
    "x_heart": "architect", "x_name": "architect"}
SHIELD = {"s_plank": ["heater", "medium"], "s_garrison": ["kite", "medium"], "s_round": ["round", "light"], "s_tower": ["segmented", "heavy"],
    "s_reliquary": ["kite", "heavy"], "s_rime": ["curved", "medium"], "s_scale": ["segmented", "heavy"]}
GEAR_MODEL = {"w_rusted_sword": "wayfarer", "w_oath_axe": "oathbreaker", "w_monarch": "eternal_edge", "s_plank": "shield_heater", "s_round": "shield_round"}
DUEL_ALIAS = {"w_censer_sword": "w_vigil_edge", "w_monarch": "w_starfall", "w_woodcutter": "w_headsman", "w_oath_axe": "w_headsman"}    # duel.gd MODEL_ALIAS
CHALLENGES = [
    {"id": "both_hands", "name": "Both Hands", "text": "Master two sets of twin blades.", "need": {"mastered_cls": "dual", "count": 2},
     "reward": {"item": "w_twin_relics"}},
]
CRAFT = {
    "a_wyrm_boots":   {"gold": 700,  "shards": 6,  "materials": {"m_scale": 6}},
    "a_frost_boots":  {"gold": 700,  "shards": 6,  "materials": {"m_rime": 6}},
    "a_hollow_boots": {"gold": 1200, "shards": 10, "materials": {"m_glass": 8, "m_core": 1}},
    "a_regal_boots":  {"gold": 1200, "shards": 10, "materials": {"m_glass": 8, "m_core": 1}},
    "w_cold_resolve": {"gold": 1500, "shards": 10, "materials": {"m_rime": 10, "m_core": 1}},
}
FINISHES = {"issued": "As issued", "graphite": "Dark graphite", "brushed": "Brushed steel", "gilt": "Restrained gilt"}
ACCENTS = {"heraldry": "Your heraldry", "none": "None", "ember": "Ember", "frost": "Frost", "gold": "Gold"}

def rank(it): return RANK.index(it["rarity"])

def find_sources(it):
    out = []
    iid = it["id"]
    if iid in ["w_rusted_sword", "s_plank", "a_worn_helm", "a_worn_chest", "a_worn_gauntlets", "a_worn_legs"]:
        out.append({"type": "start"})
    for f in FOES.values():
        pool = list(f.get("loot", [])) + BOSS_EXTRA.get(f["id"], [])
        for e in pool:
            if e[0] == iid and f["boss"]:
                out.append({"type": "boss", "id": f["id"], "region": f["region"], "guaranteed": float(e[1]) >= 1.0})
    for foe, item in ENCOUNTERS.items():
        if item == iid:
            out.append({"type": "encounter", "id": foe, "region": FOES[foe]["region"]})
    for r in REGIONS:
        for i, s in enumerate(r["stages"]):
            for o in s["options"]:
                if iid in o.get("items", []):
                    out.append({"type": "region", "id": r["id"], "region": r["id"], "stage": i, "label": o["label"]})
    for q in QUESTS:
        if q["reward"].get("item") == iid:
            out.append({"type": "quest", "id": q["id"], "giver": q["giver"]})
    if iid in CRAFT:
        out.append({"type": "craft", "id": iid, "region": FAMILIES[family_of(it)]["region"]})
    for c in CHALLENGES:
        if c["reward"].get("item") == iid:
            out.append({"type": "challenge", "id": c["id"]})
    if int(it.get("price", 0)) > 0:
        out.append({"type": "shop", "stage": SHOP_STAGE[it["rarity"]]})
    if int(it.get("ng_min", 0)) >= 1:
        out.append({"type": "ng", "ng": int(it["ng_min"])})
    order = ["start", "boss", "encounter", "region", "quest", "challenge", "craft", "shop", "ng"]
    out.sort(key=lambda s: (order.index(s["type"]), 0 if s.get("guaranteed", True) else 1))
    return out

def family_of(it):
    suit = it.get("look", {}).get("set")
    if suit:
        return SUIT_FAMILY[suit]
    return WEAPON_FAMILY[it["id"]]

def hint(src):
    t = src["type"]
    reg = REGION[src["region"]]["name"] if "region" in src else ""
    return {
        "start": "You woke with it.",
        "boss": "A guardian of %s carries it." % reg,
        "encounter": "Something rare walks %s. It does not always show itself." % reg,
        "region": "Left behind somewhere along the road through %s." % reg,
        "quest": "%s has asked something of you." % src.get("giver", "Someone"),
        "challenge": "Earned at the forge, by mastery.",
        "craft": "Orren could make it, given what %s leaves behind." % reg,
        "shop": "Orren sells it, once you have walked far enough.",
        "ng": "Only offered to those who return.",
    }[t]

def requirement(it):
    r = rank(it)
    if it["slot"] == "weapon":
        c = it["cls"]
        if c in ("greatsword", "axe"):
            return {"strength": 5 + 2 * r} if r >= 1 else {}
        if c == "dual":
            return {"dex": 5 + 2 * r} if r >= 1 else {}
        return {"strength": 4 + r, "dex": 4 + r} if r >= 3 else {}
    if weight_of(it) == "heavy":
        return {"endurance": 4 + 2 * r}
    return {}

def weight_of(it):
    if it["slot"] in ARMOUR:
        return FAMILIES[family_of(it)]["weight"]
    if it["slot"] == "shield":
        return SHIELD[it["id"]][1]
    return None

def visual(it):
    """What of this item is really drawn today. suit: wearing the chest swaps the whole knight model. model: its own mesh.
    alias: another item's mesh, tinted. none: numbers only (a `part` reference is recorded for the modular-armour pass)."""
    out = {"visual": "none"}
    slot, iid = it["slot"], it["id"]
    if slot in ARMOUR:
        suit = it["look"]["set"]
        part_suit = "base" if suit == "worn" else suit
        part_slot = "arms" if slot == "gauntlets" else slot
        out["part"] = part_suit
        out["part_slot"] = part_slot
        out["part_ready"] = all(exists("assets/models/parts/%s_%s_%s.res" % (b, part_suit, part_slot)) for b in "mf")
        if slot == "chest":
            out["visual"] = "suit"
            out["model"] = "knight_{body}" if suit == "worn" else "knight_{body}_%s" % suit
            assert suit == "worn" or exists("assets/models/knight_m_%s.glb" % suit), suit
    elif slot in ("weapon", "shield"):
        if exists("assets/models/%s.glb" % iid) and iid not in DUEL_ALIAS:
            out["visual"] = "model"
            out["model"] = iid
        elif iid in DUEL_ALIAS:
            out["visual"] = "alias"
            out["model"] = DUEL_ALIAS[iid]
        if iid in GEAR_MODEL and exists("assets/models/gear/%s.glb" % GEAR_MODEL[iid]):
            out["gear_model"] = "gear/" + GEAR_MODEL[iid]      # the hand-modelled replacement, for the pass that adopts it
    return out

def mastery(it):
    need = 3 + rank(it) * 2                    # Stats.mastery_needed
    at = [-(-need // 3), -(-need * 2 // 3), need]
    slot = it["slot"]
    if slot == "weapon":
        marks = [{"at": at[0], "type": "history", "ref": it["id"], "text": "More of its history"},
                 {"at": at[1], "type": "combo", "ref": it["cls"], "text": "A technique for its class, and swings with it cost 3% less"},
                 {"at": at[2], "type": "attr_point", "text": "Mastered: one attribute point"}]
    elif slot in ARMOUR:
        marks = [{"at": at[0], "type": "discovery", "ref": family_of(it), "text": "Word of another piece of its family"},
                 {"at": at[1], "type": "efficiency", "text": "Worn in: stamina returns 1% faster while you wear it"},
                 {"at": at[2], "type": "attr_point", "text": "Mastered: one attribute point"}]
    elif slot == "shield":
        marks = [{"at": at[1], "type": "efficiency", "text": "Learned: guarding with it costs 2% less"},
                 {"at": at[2], "type": "attr_point", "text": "Mastered: one attribute point"}]
    else:
        marks = [{"at": at[2], "type": "attr_point", "text": "Mastered: one attribute point"}]
    return {"need": need, "marks": marks}

def upgrade_cost(it, level):
    r = rank(it)
    u = UPGRADE
    gold = int(round(u["gold_base"][r] * u["gold_step"][level] * u["slot_mult"].get(it["slot"], 1.0) / 5.0)) * 5
    out = {"gold": gold, "shards": u["shard"][r] * (level + 1), "materials": {}}
    if level >= u["mat_from_level"] and r >= u["mat_min_rank"]:
        out["materials"][material_of(it)] = (level - u["mat_from_level"] + 1) * (1 if it["slot"] not in ("weapon", "chest") else 2)
    if level == u["max"] - 1 and r >= u["core_min_rank"]:
        out["materials"]["m_core"] = 1
    return out

def material_of(it):
    return REGION_MAT[FAMILIES[family_of(it)]["region"]]

OUT = {}
problems = []
for it in ALL:
    iid = it["id"]
    fam = family_of(it)
    srcs = find_sources(it)
    if not srcs:
        problems.append("no source: " + iid)
        continue
    e = {"tier": TIER[it["rarity"]], "family": fam, "sources": srcs, "source": srcs[0], "hint": hint(srcs[0])}
    w = weight_of(it)
    if w:
        e["weight"] = w
    if it["slot"] == "shield":
        e["shield_class"] = SHIELD[iid][0]
    e.update(visual(it))
    if it.get("look", {}).get("set") == "worn":
        e["set_piece"] = False             # the starting plate is too far gone to count towards the Crownless set
    req = requirement(it)
    if req:
        e["req"] = req
    e["mat"] = material_of(it)
    e["advanced"] = iid in ADVANCED
    base = int(it["price"]) if int(it.get("price", 0)) > 0 else 80 + 120 * rank(it)
    e["sell"] = int(base * SELL_RATE)
    if iid in QUEST_ITEMS:
        e["quest_item"] = True
    if iid in QUEST_ITEMS or iid in UNSELLABLE:
        e["unsellable"] = True
    if int(it.get("price", 0)) > 0:
        e["shop_stage"] = SHOP_STAGE[it["rarity"]]
    if it["slot"] in UPGRADE["slot_mult"]:
        kind = "weapon" if it["slot"] == "weapon" else ("shield" if it["slot"] == "shield" else "armour")
        e["upgrade"] = {"max": UPGRADE_MAX, "growth": UPGRADE["growth"][kind], "costs": [upgrade_cost(it, n) for n in range(UPGRADE_MAX)]}
    e["mastery"] = mastery(it)
    if iid in CRAFT:
        e["craft"] = CRAFT[iid]
    for name, n in NAMED.items():
        if n["id"] == iid and n.get("was"):
            e["formerly"] = n["was"]
    if it in NEW:
        e["base"] = it                      # a new item: Db adds it to the list
    OUT[iid] = e

# guardians: what the first kill always gives, what it may also give, and what a later kill gives instead
BOSS = {}
FIRST_OVERRIDE = {"azhurion": ["w_starfall"]}      # was a second Wyrmfang: a guardian's guaranteed reward is its own
taken = {}
for f in FOES.values():
    if not f["boss"]:
        continue
    loot = list(f.get("loot", [])) + BOSS_EXTRA.get(f["id"], [])
    first = FIRST_OVERRIDE.get(f["id"], [e[0] for e in loot if float(e[1]) >= 1.0])
    pool = [[e[0], float(e[1])] for e in loot if e[0] not in first and float(e[1]) < 1.0]
    for iid in first:
        if iid in taken:
            problems.append("%s is guaranteed by both %s and %s" % (iid, taken[iid], f["id"]))
        taken[iid] = f["id"]
    BOSS[f["id"]] = {"first": first, "pool": pool, "materials": {REGION_MAT[f["region"]]: REWARDS["mat_boss"], "m_core": 1}}
for iid, bid in taken.items():
    s = [x for x in OUT[iid]["sources"] if x["type"] == "boss" and x["id"] == bid]
    if s:
        s[0]["guaranteed"] = True
        OUT[iid]["sources"].sort(key=lambda x: 0 if (x["type"] == "boss" and x.get("guaranteed")) else 1)
        OUT[iid]["source"] = OUT[iid]["sources"][0]
        OUT[iid]["hint"] = hint(OUT[iid]["source"])

# what an ordinary foe of a region may drop: gear Orren would otherwise sell, of that region's rank
BAND = {"courtyard": [0, 1], "blackwood": [1, 2], "cathedral": [2], "crypt": [2, 3], "roost": [3], "citadel": [3], "deep": [3], "throne": [3]}
DROPS = {}
for r in REGIONS:
    DROPS[r["id"]] = [it["id"] for it in ALL if int(it.get("price", 0)) > 0 and rank(it) in BAND[r["id"]] and it["slot"] not in ("ring", "relic")
        and it["id"] not in [q["reward"].get("item") for q in QUESTS] and it["id"] not in taken]
ELITES = sorted(f["id"] for f in FOES.values() if not f["boss"] and float(f.get("poise", 0)) >= 85)

if problems:
    print("\n".join(problems))
    sys.exit(1)

doc = {
    "version": 1,
    "slots": SLOTS, "armour_slots": ARMOUR,
    "tiers": TIER, "tier_name": TIER_NAME, "tier_order": ["common", "uncommon", "rare", "legendary", "relic"],
    "weights": WEIGHTS, "require_penalty": REQUIRE,
    "families": {k: {"name": v["name"], "suits": v["suits"], "weight": v["weight"], "region": v["region"], "why": v["why"],
        "set": [{"pieces": n, "bonus": b, "text": bonus_text(b)} for n, b in v["set"]]} for k, v in FAMILIES.items()},
    "suit_family": SUIT_FAMILY,
    "materials": MATERIALS, "region_material": REGION_MAT,
    "upgrade": UPGRADE, "sell_rate": SELL_RATE, "buyback_rate": BUYBACK_RATE, "shard_price": SHARD_PRICE, "shop_stage": SHOP_STAGE,
    "rewards": REWARDS,
    "aliases": ALIASES, "named": NAMED, "region_order": [r["id"] for r in REGIONS],
    "boss_rewards": BOSS, "encounters": ENCOUNTERS, "drops": DROPS, "elites": ELITES,
    "challenges": CHALLENGES,
    "finishes": FINISHES, "accents": ACCENTS,
    "items": OUT,
}
with open(os.path.join(ROOT, "data", "equipment.json"), "w") as f:
    json.dump(doc, f, indent=1, ensure_ascii=False)
    f.write("\n")
print("equipment.json: %d items (%d new), %d families, %d materials" % (len(OUT), len(NEW), len(FAMILIES), len(MATERIALS)))
