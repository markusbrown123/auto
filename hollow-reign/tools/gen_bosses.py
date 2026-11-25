#!/usr/bin/env python3
"""Authoring script for data/bosses.json (the JSON is what the game loads)."""
import json, os
def A(dir, windup, dmg, **k):
    d = dict(dir=dir, windup=windup, dmg=dmg, swing=0.30, guard=round(dmg*1.3), parry=True, unblockable=False, element=None, kind="slash")
    d["dodge"] = "L" if "L" in dir else "R" if "R" in dir else "any"
    d.update(k); return d
def C(id, w, attacks, recover=1.2, tags=("basic",), range="near", retreat=False, gap=0.15):
    return dict(id=id, w=w, attacks=attacks, recover=recover, tags=list(tags), range=range, retreat=retreat, gap=gap)
B = []
# ---------------------------------------------------------------- lesser foes
def lesser(id, name, region, hp, dmg, rig, speed=1.0, el=None, xp=60, gold=40):
    return dict(id=id, name=name, title="", region=region, boss=False, hp=hp, armor=0.0, posture=60, patience=3, adapt=0.3,
        idle=[0.9,1.6], weak=None, xp=xp, gold=gold, loot=[], rig=rig, music="combat_a",
        punish=A("D",0.5,dmg,swing=0.25),
        phases=[dict(at=1.0, speed=speed, combos=[
            C("cut_l",3,[A("L",0.85,dmg,element=el)],1.3),
            C("cut_r",3,[A("R",0.85,dmg,element=el)],1.3),
            C("chop",2,[A("D",1.0,round(dmg*1.3),element=el)],1.5),
            C("one_two",2,[A("L",0.8,dmg),A("R",0.6,dmg)],1.5,tags=("anti_dodge",)),
            C("shove",1,[A("U",0.9,round(dmg*0.8),guard=dmg*3,kind="thrust")],1.2,tags=("anti_block",)),
        ])])
B += [
 lesser("hollow_soldier","Hollow Soldier","courtyard",220,12,dict(scale=1.0,metal="#5a5a5c",cloth="#3a2a22",weapon="sword",eye="#ffb060",helm="kettle")),
 lesser("blackwood_stalker","Blackwood Stalker","blackwood",300,16,dict(scale=1.02,metal="#2e3a2c",cloth="#1c2418",weapon="axe",eye="#b6ff7a",helm="hood"),speed=1.1,xp=110,gold=70),
 lesser("ash_acolyte","Ash Acolyte","cathedral",380,21,dict(scale=1.05,metal="#6a5a48",cloth="#5a1a14",weapon="sword",eye="#ff7a3a",helm="hood"),speed=1.12,el="fire",xp=170,gold=110),
 lesser("crypt_warden","Crypt Warden","crypt",480,26,dict(scale=1.1,metal="#48564e",cloth="#20282a",weapon="greatsword",eye="#7affc8",helm="great"),speed=1.1,xp=240,gold=150),
 lesser("frost_thrall","Frost Thrall","citadel",560,31,dict(scale=1.08,metal="#8aa6b4",cloth="#2a3a48",weapon="axe",eye="#8fdcff",helm="kettle"),speed=1.18,el="frost",xp=320,gold=200),
 lesser("throne_guard","Throne Guard","throne",680,37,dict(scale=1.15,metal="#8c7a52",cloth="#3a0e0e",weapon="greatsword",eye="#ffd98a",helm="great"),speed=1.22,xp=420,gold=260),
]
# ---------------------------------------------------------------- 1 Ashen Sentinel
B.append(dict(id="ashen_sentinel", name="The Ashen Sentinel", title="Warden of the Fallen Courtyard", region="courtyard", boss=True,
 hp=620, armor=0.1, posture=100, patience=3, adapt=0.5, idle=[1.0,1.7], weak="frost", xp=400, gold=300,
 loot=[["w_ashen_great",1.0],["s_tower",0.6],["a_ash_chest",0.5],["r_ember",0.5]], music="combat_a", arena="courtyard",
 intro="He kept the gate when there was a kingdom behind it. He keeps it still.",
 rig=dict(scale=1.45,bulk=1.25,metal="#3e3a37",cloth="#2a1410",weapon="greatsword",eye="#ff6a2a",helm="great",crest="plume",ember=True,cape=True),
 punish=A("D",0.55,22,swing=0.28),
 phases=[
  dict(at=1.0, speed=1.0, combos=[
   C("sweep_l",3,[A("L",1.25,20)],1.5),
   C("sweep_r",3,[A("R",1.25,20)],1.5),
   C("overhead",3,[A("D",1.45,28,swing=0.34,kind="slam")],1.8),
   C("rise",2,[A("U",1.2,18)],1.4),
   C("two_sweep",2,[A("L",1.2,18),A("R",0.9,20)],1.7,tags=("anti_dodge",)),
  ]),
  dict(at=0.5, speed=1.08, roar="The Sentinel's armour splits. Embers pour from the seams.", combos=[
   C("sweep_l",2,[A("L",1.15,22,element="fire")],1.4),
   C("sweep_r",2,[A("R",1.15,22,element="fire")],1.4),
   C("overhead",3,[A("D",1.4,32,swing=0.34,kind="slam",element="fire")],1.8),
   C("three",3,[A("L",1.1,20),A("R",0.85,20),A("D",1.0,30,kind="slam")],2.0,tags=("anti_dodge",)),
   C("delayed",2,[A("D",2.1,34,swing=0.26,kind="slam")],1.9,tags=("anti_parry",)),
   C("pommel",2,[A("U",0.95,16,guard=75,kind="thrust")],1.3,tags=("anti_block",)),
   C("cinder_wave",1,[A("L",1.5,30,unblockable=True,dodge="none",kind="sweep",element="fire")],1.8,tags=("anti_block","anti_dodge")),
  ])]))
# ---------------------------------------------------------------- 2 Hollow Executioner
B.append(dict(id="hollow_executioner", name="The Hollow Executioner", title="Last Justice of the Blackwood", region="blackwood", boss=True,
 hp=900, armor=0.12, posture=110, patience=2, adapt=0.8, idle=[0.8,1.4], weak="fire", xp=700, gold=480,
 loot=[["w_headsman",1.0],["x_tooth",0.7],["a_black_chest",0.5],["a_black_helm",0.5]], music="combat_a", arena="blackwood",
 intro="The sentences were all passed long ago. He is only catching up.",
 rig=dict(scale=1.35,bulk=1.5,metal="#2c2a2a",cloth="#3a0c0c",weapon="cleaver",eye="#d8d0c0",helm="hood",apron=True),
 punish=A("DL",0.5,26,swing=0.25),
 phases=[
  dict(at=1.0, speed=1.0, combos=[
   C("hack_l",3,[A("DL",1.0,24)],1.3),
   C("hack_r",3,[A("DR",1.0,24)],1.3),
   C("held_chop",3,[A("D",1.9,36,swing=0.24,kind="slam")],1.7,tags=("anti_parry",)),
   C("breaker",3,[A("D",1.2,22,guard=95,kind="slam")],1.4,tags=("anti_block",)),
   C("hack_hack",2,[A("DL",0.95,22),A("DR",0.7,22)],1.5,tags=("anti_dodge",)),
  ]),
  dict(at=0.55, speed=1.12, roar="He drags the cleaver through the roots. Something under the wood answers.", combos=[
   C("hack_l",2,[A("DL",0.9,26)],1.2),
   C("hack_r",2,[A("DR",0.9,26)],1.2),
   C("feint_chop",3,[A("D",2.3,40,swing=0.22,kind="slam")],1.7,tags=("anti_parry",)),
   C("breaker2",3,[A("D",1.1,22,guard=90,kind="slam"),A("U",0.8,22,guard=90,kind="thrust")],1.6,tags=("anti_block",)),
   C("frenzy",3,[A("DL",0.9,22),A("DR",0.65,22),A("DL",0.65,22),A("D",1.3,34,swing=0.24,kind="slam")],2.2,tags=("anti_dodge",)),
   C("reap",2,[A("R",1.4,38,unblockable=True,dodge="none",kind="sweep")],1.8,tags=("anti_block","anti_dodge")),
  ])]))
# ---------------------------------------------------------------- 3 Crimson Widow
B.append(dict(id="crimson_widow", name="The Crimson Widow", title="Mourner of the Cathedral Steps", region="cathedral", boss=True,
 hp=980, armor=0.05, posture=85, patience=2, adapt=1.0, idle=[0.5,1.0], weak=None, xp=1000, gold=650,
 loot=[["w_twin_fangs",1.0],["r_widow",0.7],["a_vigil_gauntlets",0.5]], music="combat_a", arena="cathedral_steps",
 intro="She was promised a wedding in the Cathedral. She has been waiting at the doors ever since.",
 rig=dict(scale=1.12,bulk=0.78,metal="#5a1616",cloth="#7a1010",weapon="dual",eye="#ff4a4a",helm="veil",cape=True,skirt=True),
 punish=A("L",0.4,18,swing=0.2),
 phases=[
  dict(at=1.0, speed=1.0, combos=[
   C("flick_l",2,[A("L",0.7,15,swing=0.22)],1.0),
   C("flick_r",2,[A("R",0.7,15,swing=0.22)],1.0),
   C("cross",3,[A("DL",0.7,14,swing=0.22),A("DR",0.45,14,swing=0.22)],1.2),
   C("triple",3,[A("L",0.7,13,swing=0.22),A("R",0.45,13,swing=0.22),A("U",0.5,16,swing=0.22)],1.4,tags=("anti_dodge",)),
   C("lunge",2,[A("U",0.8,22,swing=0.2,kind="thrust")],1.2,range="far"),
   C("step_back",2,[A("R",0.65,14,swing=0.22)],0.5,retreat=True),
   C("pierce",1,[A("U",1.0,20,guard=70,swing=0.2,kind="thrust")],1.2,tags=("anti_block",)),
  ]),
  dict(at=0.5, speed=1.15, roar="She tears away the veil. There is nothing beneath it to pity.", combos=[
   C("cross",2,[A("DL",0.62,15,swing=0.2),A("DR",0.42,15,swing=0.2)],1.1),
   C("quad",3,[A("L",0.65,13,swing=0.2),A("R",0.42,13,swing=0.2),A("DL",0.42,13,swing=0.2),A("DR",0.42,16,swing=0.2)],1.5,tags=("anti_dodge",)),
   C("stutter",3,[A("L",0.6,14,swing=0.2),A("R",1.25,22,swing=0.18)],1.3,tags=("anti_parry",)),
   C("lunge",3,[A("U",0.7,24,swing=0.2,kind="thrust")],1.1,range="far"),
   C("step_back",2,[A("L",0.6,15,swing=0.2)],0.4,retreat=True),
   C("pierce",2,[A("U",0.9,20,guard=80,swing=0.2,kind="thrust")],1.1,tags=("anti_block",)),
   C("red_dance",2,[A("L",0.9,26,unblockable=True,dodge="L",parry=False,kind="sweep"),A("R",0.7,26,unblockable=True,dodge="R",parry=False,kind="sweep")],1.7,tags=("anti_block","anti_parry")),
  ])]))
# ---------------------------------------------------------------- 4 Cathedral Beast
B.append(dict(id="cathedral_beast", name="The Cathedral Beast", title="What the Congregation Became", region="cathedral", boss=True,
 hp=1500, armor=0.08, posture=130, patience=3, adapt=0.9, idle=[0.8,1.5], weak="fire", xp=1500, gold=900,
 loot=[["w_censer_sword",1.0],["x_bell",0.7],["s_reliquary",0.6],["a_vigil_chest",0.5]], music="combat_b", arena="cathedral",
 intro="They prayed to be made strong enough to endure. They were answered.",
 rig=dict(scale=1.75,bulk=1.7,metal="#8c7a52",cloth="#4a4038",weapon="claws",eye="#ffe08a",helm="beast",hunch=0.5,horns=True),
 punish=A("L",0.5,26,swing=0.25,kind="sweep"),
 phases=[
  dict(at=1.0, speed=1.0, combos=[
   C("rake_l",3,[A("L",1.0,24,kind="sweep")],1.3),
   C("rake_r",3,[A("R",1.0,24,kind="sweep")],1.3),
   C("double_rake",3,[A("L",1.0,22,kind="sweep"),A("R",0.7,22,kind="sweep")],1.5,tags=("anti_dodge",)),
   C("slam",3,[A("D",1.5,38,unblockable=True,parry=False,dodge="any",kind="slam")],1.9,tags=("anti_block","anti_parry")),
   C("pounce",3,[A("D",1.2,30,kind="lunge",guard=70)],1.5,range="far"),
   C("recoil",1,[A("U",0.9,20,kind="sweep")],0.5,retreat=True),
  ]),
  dict(at=0.6, speed=1.1, roar="The bell above tolls once, by itself. The Beast rises onto two legs.", combos=[
   C("rake_l",2,[A("L",0.9,26,kind="sweep")],1.2),
   C("rake_r",2,[A("R",0.9,26,kind="sweep")],1.2),
   C("flurry",3,[A("L",0.9,22,kind="sweep"),A("R",0.6,22,kind="sweep"),A("L",0.6,22,kind="sweep"),A("D",1.2,36,unblockable=True,parry=False,kind="slam")],2.1,tags=("anti_dodge","anti_block")),
   C("slam",2,[A("D",1.4,40,unblockable=True,parry=False,dodge="any",kind="slam")],1.8,tags=("anti_block","anti_parry")),
   C("held_slam",2,[A("D",2.3,44,unblockable=True,parry=False,dodge="any",swing=0.24,kind="slam")],1.9,tags=("anti_parry",)),
   C("pounce",3,[A("D",1.05,32,kind="lunge",guard=80)],1.4,range="far"),
   C("recoil",2,[A("U",0.8,22,kind="sweep")],0.4,retreat=True),
   C("gore",2,[A("U",1.2,34,unblockable=True,dodge="L",kind="lunge")],1.6,tags=("anti_block",)),
  ])]))
# ---------------------------------------------------------------- optional: Gravewarden
B.append(dict(id="gravewarden", name="The Gravewarden", title="Keeper of the Sunken Crypt", region="crypt", boss=True,
 hp=1700, armor=0.18, posture=140, patience=3, adapt=0.9, idle=[0.9,1.5], weak="fire", xp=1900, gold=1100,
 loot=[["w_crypt_great",1.0],["a_vigil_legs",0.5],["a_vigil_helm",0.5],["r_iron",0.3]], music="combat_b", arena="crypt",
 intro="He buried every king of this line. He does not intend to bury another.",
 rig=dict(scale=1.5,bulk=1.3,metal="#48564e",cloth="#1c2624",weapon="greatsword",eye="#7affc8",helm="great",crest="none",cape=True,lantern=True),
 punish=A("U",0.5,28,swing=0.25,kind="thrust"),
 phases=[
  dict(at=1.0, speed=1.0, combos=[
   C("sweep_l",3,[A("L",1.1,28)],1.4),
   C("sweep_r",3,[A("R",1.1,28)],1.4),
   C("spade",3,[A("D",1.3,36,guard=90,kind="slam")],1.6,tags=("anti_block",)),
   C("bury",2,[A("D",2.0,42,swing=0.25,kind="slam")],1.7,tags=("anti_parry",)),
   C("rise_fall",3,[A("U",1.0,26),A("D",0.9,34,kind="slam")],1.7,tags=("anti_dodge",)),
  ]),
  dict(at=0.5, speed=1.12, roar="The water rises to your knees. The dead are holding it up.", combos=[
   C("sweep_l",2,[A("L",1.0,30)],1.3),
   C("sweep_r",2,[A("R",1.0,30)],1.3),
   C("spade",3,[A("D",1.2,36,guard=100,kind="slam")],1.5,tags=("anti_block",)),
   C("bury",3,[A("D",2.2,46,swing=0.24,kind="slam")],1.7,tags=("anti_parry",)),
   C("four",3,[A("L",1.0,26),A("R",0.75,26),A("U",0.75,26),A("D",1.0,38,kind="slam")],2.1,tags=("anti_dodge",)),
   C("tide",2,[A("R",1.5,40,unblockable=True,dodge="none",kind="sweep")],1.8,tags=("anti_block","anti_dodge")),
  ])]))
# ---------------------------------------------------------------- 5 Frostbound King
B.append(dict(id="frostbound_king", name="The Frostbound King", title="Sovereign of the Frozen Citadel", region="citadel", boss=True,
 hp=2100, armor=0.2, posture=150, patience=3, adapt=1.0, idle=[0.9,1.5], weak="fire", xp=2600, gold=1500,
 loot=[["w_frost_great",1.0],["s_rime",0.6],["x_tear",0.7],["a_frost_chest",0.6],["r_frost",0.5]], music="combat_b", arena="citadel",
 intro="He ordered the gates frozen shut so that nothing could come in. Nothing has gone out either.",
 rig=dict(scale=1.6,bulk=1.3,metal="#8fb0c0",cloth="#243848",weapon="greatsword",weapon_glow="#7fd4ff",eye="#9fe4ff",helm="crown",cape=True,frost=True),
 punish=A("U",0.5,30,swing=0.25,kind="thrust",element="frost"),
 phases=[
  dict(at=1.0, speed=1.0, combos=[
   C("sweep_l",3,[A("L",1.15,30,element="frost")],1.4),
   C("sweep_r",3,[A("R",1.15,30,element="frost")],1.4),
   C("verdict",3,[A("D",1.5,42,swing=0.32,kind="slam",element="frost")],1.8),
   C("two",3,[A("DL",1.1,28,element="frost"),A("DR",0.8,28,element="frost")],1.6,tags=("anti_dodge",)),
   C("sceptre",2,[A("U",1.0,24,guard=100,kind="thrust")],1.3,tags=("anti_block",)),
  ]),
  dict(at=0.66, speed=1.1, roar="Frost climbs the walls. Your breath hangs in front of you and stays there.", combos=[
   C("sweep_l",2,[A("L",1.05,32,element="frost")],1.3),
   C("sweep_r",2,[A("R",1.05,32,element="frost")],1.3),
   C("held_verdict",3,[A("D",2.2,48,swing=0.24,kind="slam",element="frost")],1.8,tags=("anti_parry",)),
   C("three",3,[A("DL",1.05,28,element="frost"),A("DR",0.75,28,element="frost"),A("U",0.8,30,element="frost")],1.8,tags=("anti_dodge",)),
   C("sceptre",2,[A("U",0.95,24,guard=110,kind="thrust")],1.3,tags=("anti_block",)),
   C("glacier",2,[A("L",1.5,44,unblockable=True,dodge="none",kind="sweep",element="frost")],1.8,tags=("anti_block","anti_dodge")),
  ]),
  dict(at=0.33, speed=1.2, roar="The crown cracks. Winter is no longer something he commands. It is something he is.", combos=[
   C("sweep_l",2,[A("L",0.95,34,element="frost")],1.2),
   C("sweep_r",2,[A("R",0.95,34,element="frost")],1.2),
   C("held_verdict",3,[A("D",2.4,52,swing=0.22,kind="slam",element="frost")],1.8,tags=("anti_parry",)),
   C("blizzard",3,[A("L",1.0,28,element="frost"),A("R",0.7,28,element="frost"),A("DL",0.7,28,element="frost"),A("DR",0.7,28,element="frost"),A("D",1.1,44,kind="slam",element="frost")],2.3,tags=("anti_dodge",)),
   C("glacier2",3,[A("L",1.4,44,unblockable=True,dodge="none",kind="sweep",element="frost"),A("D",1.3,46,unblockable=True,parry=False,dodge="any",kind="slam",element="frost")],2.0,tags=("anti_block","anti_dodge")),
   C("sceptre",2,[A("U",0.9,26,guard=120,kind="thrust")],1.2,tags=("anti_block",)),
  ])]))
# ---------------------------------------------------------------- 6 Forgotten Monarch
B.append(dict(id="forgotten_monarch", name="The Forgotten Monarch", title="Last Ruler of the Hollow Reign", region="throne", boss=True,
 hp=2800, armor=0.15, posture=160, patience=2, adapt=1.4, idle=[0.6,1.2], weak=None, xp=5000, gold=3000,
 loot=[["w_monarch",1.0],["r_crown",1.0],["a_regal_chest",0.7],["a_regal_helm",0.7]], music="final", arena="throne",
 intro="You knelt to this crown once. It remembers. You do not.",
 rig=dict(scale=1.5,bulk=1.1,metal="#b89b5e",cloth="#3a0e0e",weapon="sword",weapon_glow="#ffd98a",eye="#ffffff",helm="crown",cape=True,skirt=True,regal=True),
 punish=A("R",0.42,30,swing=0.22),
 phases=[
  dict(at=1.0, speed=1.0, combos=[
   C("cut_l",2,[A("L",0.95,30)],1.2),
   C("cut_r",2,[A("R",0.95,30)],1.2),
   C("decree",3,[A("D",1.3,40,kind="slam")],1.5),
   C("court",3,[A("L",0.9,26),A("R",0.65,26),A("U",0.7,30)],1.6,tags=("anti_dodge",)),
   C("patience",3,[A("DL",2.0,44,swing=0.22)],1.5,tags=("anti_parry",)),
   C("gavel",2,[A("U",0.95,24,guard=110,kind="thrust")],1.2,tags=("anti_block",)),
  ]),
  dict(at=0.66, speed=1.12, roar="The Monarch rises from the throne at last. The hall remembers how to kneel.", combos=[
   C("court",3,[A("L",0.85,28),A("R",0.6,28),A("DL",0.6,28),A("DR",0.6,32)],1.7,tags=("anti_dodge",)),
   C("patience",3,[A("DR",2.2,46,swing=0.2)],1.4,tags=("anti_parry",)),
   C("stutter",3,[A("L",0.8,26),A("D",1.5,40,swing=0.22,kind="slam")],1.5,tags=("anti_parry",)),
   C("gavel",2,[A("U",0.9,24,guard=120,kind="thrust")],1.2,tags=("anti_block",)),
   C("edict",3,[A("R",1.3,44,unblockable=True,dodge="none",kind="sweep")],1.6,tags=("anti_block","anti_dodge")),
   C("withdraw",2,[A("L",0.7,24)],0.4,retreat=True),
   C("advance",3,[A("U",0.8,36,kind="lunge")],1.3,range="far"),
  ]),
  dict(at=0.33, speed=1.22, roar="The crown burns white. Every king this hall has ever held stands up inside him.", combos=[
   C("court",3,[A("L",0.8,30),A("R",0.55,30),A("DL",0.55,30),A("DR",0.55,30),A("D",0.9,44,kind="slam")],1.9,tags=("anti_dodge",)),
   C("patience",3,[A("D",2.5,54,swing=0.2,kind="slam")],1.5,tags=("anti_parry",)),
   C("stutter2",3,[A("L",0.75,28),A("R",1.4,34,swing=0.2),A("U",0.6,32)],1.6,tags=("anti_parry",)),
   C("edict2",3,[A("R",1.2,44,unblockable=True,dodge="none",kind="sweep"),A("L",0.9,44,unblockable=True,dodge="none",kind="sweep")],1.8,tags=("anti_block","anti_dodge")),
   C("abdicate",2,[A("D",1.3,50,unblockable=True,parry=False,dodge="any",kind="slam")],1.7,tags=("anti_block","anti_parry")),
   C("gavel",2,[A("U",0.85,26,guard=130,kind="thrust")],1.1,tags=("anti_block",)),
   C("withdraw",2,[A("R",0.65,26)],0.4,retreat=True),
   C("advance",3,[A("U",0.7,40,kind="lunge")],1.2,range="far"),
  ])]))
# ---------------------------------------------------------------- optional: Pale Huntsman
B.append(dict(id="pale_huntsman", name="The Pale Huntsman", title="He Who Follows", region="blackwood", boss=True,
 hp=820, armor=0.05, posture=90, patience=2, adapt=1.0, idle=[0.6,1.2], weak="fire", xp=800, gold=520,
 loot=[["w_pilgrim_blades",1.0],["a_black_legs",0.6],["a_black_gauntlets",0.6]], music="combat_a", arena="blackwood",
 intro="You heard him three trees back. He let you.",
 rig=dict(scale=1.2,bulk=0.85,metal="#5a6058",cloth="#c8c4b4",weapon="axe",eye="#e8ffe0",helm="hood",cape=True,antlers=True),
 punish=A("R",0.45,20,swing=0.22),
 phases=[dict(at=1.0, speed=1.0, combos=[
   C("hew_l",3,[A("DL",0.85,20)],1.2),
   C("hew_r",3,[A("DR",0.85,20)],1.2),
   C("stalk",3,[A("U",0.9,26,kind="lunge")],1.2,range="far"),
   C("fade",3,[A("L",0.7,18)],0.4,retreat=True),
   C("wait",2,[A("D",1.9,32,swing=0.22,kind="slam")],1.5,tags=("anti_parry",)),
   C("snare",2,[A("U",0.9,16,guard=80,kind="thrust"),A("DL",0.7,22)],1.4,tags=("anti_block",)),
   C("hew3",2,[A("DL",0.8,18),A("DR",0.6,18),A("DL",0.6,20)],1.5,tags=("anti_dodge",)),
 ])]))
os.makedirs("data", exist_ok=True)
for f in B:
    f["hp"] = round(f["hp"] * (2.3 if f["boss"] else 1.5))
json.dump({"bosses": B}, open("data/bosses.json","w"), indent=1)
print(len(B), "foes")
