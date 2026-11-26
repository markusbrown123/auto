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
# Four archetypes, re-skinned and re-tuned per region, so the road to each
# guardian teaches the things that guardian will test.
def _base(id, name, region, hp, rig, combos, punish, speed, xp, gold, patience=3, adapt=0.4, posture=60, idle=(0.9,1.6), weak=None, cls="Humanoid"):
    return dict(id=id, name=name, title="", cls=cls, region=region, boss=False, hp=hp, armor=0.0, posture=posture, patience=patience, adapt=adapt,
        idle=list(idle), weak=weak, xp=xp, gold=gold, loot=[], rig=rig, music="combat_a", punish=punish,
        phases=[dict(at=1.0, speed=speed, combos=combos)])
def soldier(id, name, region, hp, dmg, rig, speed=1.0, el=None, xp=60, gold=40):
    return _base(id, name, region, hp, rig, [
        C("cut_l",3,[A("L",0.85,dmg,element=el)],1.3),
        C("cut_r",3,[A("R",0.85,dmg,element=el)],1.3),
        C("chop",2,[A("D",1.0,round(dmg*1.3),element=el)],1.5),
        C("one_two",2,[A("L",0.8,dmg),A("R",0.6,dmg)],1.5,tags=("anti_dodge",)),
        C("shove",1,[A("U",0.9,round(dmg*0.8),guard=dmg*3,kind="thrust")],1.2,tags=("anti_block",)),
    ], A("D",0.5,dmg,swing=0.25), speed, xp, gold)
def duelist(id, name, region, hp, dmg, rig, speed=1.0, el=None, xp=80, gold=55):
    # quick, light, never stands still: teaches rapid parries and the lunge
    d = round(dmg*0.75)
    return _base(id, name, region, round(hp*0.85), rig, [
        C("flick_l",2,[A("L",0.7,d,swing=0.22,element=el)],1.0),
        C("flick_r",2,[A("R",0.7,d,swing=0.22,element=el)],1.0),
        C("cross",3,[A("DL",0.7,d,swing=0.22),A("DR",0.5,d,swing=0.22)],1.2),
        C("three",3,[A("L",0.7,d,swing=0.22),A("R",0.5,d,swing=0.22),A("U",0.55,d,swing=0.22)],1.3,tags=("anti_dodge",)),
        C("skip_back",2,[A("R",0.65,d,swing=0.22)],0.45,retreat=True),
        C("lunge",3,[A("U",0.8,round(dmg*1.1),swing=0.2,kind="lunge")],1.2,range="far"),
    ], A("L",0.42,d,swing=0.2), speed, xp, gold, patience=2, adapt=0.6, posture=50, idle=(0.5,1.0), cls="Twin-Bladed" if rig.get("weapon") == "dual" else "Humanoid")
def brute(id, name, region, hp, dmg, rig, speed=1.0, el=None, xp=110, gold=75):
    # slow, heavy, breaks guards: teaches patience, dodging and delayed blows
    h = round(dmg*1.5)
    return _base(id, name, region, round(hp*1.5), rig, [
        C("haul_l",3,[A("L",1.2,h,element=el)],1.6),
        C("haul_r",3,[A("R",1.2,h,element=el)],1.6),
        C("held",3,[A("D",1.9,round(h*1.25),swing=0.26,kind="slam",element=el)],1.8,tags=("anti_parry",)),
        C("breaker",3,[A("D",1.25,dmg,guard=dmg*4,kind="slam")],1.5,tags=("anti_block",)),
        C("quake",2,[A("D",1.5,round(h*1.2),unblockable=True,parry=False,dodge="any",kind="slam")],1.9,tags=("anti_block","anti_parry")),
    ], A("U",0.55,dmg,swing=0.26,kind="thrust"), speed, xp, gold, posture=85, idle=(1.0,1.7), cls="Heavy")
def giant(id, name, region, hp, dmg, rig, speed=1.0, el=None, xp=200, gold=130):
    # towering: every blow is slow and enormous. Stomps cannot be blocked or parried; grabs must be sidestepped.
    h = round(dmg*1.8)
    return _base(id, name, region, round(hp*2.1), rig, [
        C("fell_l",3,[A("L",1.4,h,swing=0.36,kind="sweep",element=el)],1.9),
        C("fell_r",3,[A("R",1.4,h,swing=0.36,kind="sweep",element=el)],1.9),
        C("hammer",3,[A("D",1.7,round(h*1.2),swing=0.36,kind="slam",element=el)],2.1),
        C("hammer_held",2,[A("D",2.4,round(h*1.3),swing=0.28,kind="slam",element=el)],2.0,tags=("anti_parry",)),
        C("stomp",3,[A("D",1.3,round(h*0.9),unblockable=True,parry=False,dodge="any",kind="slam")],1.8,tags=("anti_block","anti_parry")),
        C("grab",2,[A("U",1.3,h,unblockable=True,parry=False,dodge="L",kind="thrust")],1.9,tags=("anti_block","anti_parry")),
        C("fell_fell",2,[A("L",1.35,h,swing=0.36,kind="sweep"),A("R",1.0,h,swing=0.36,kind="sweep")],2.2,tags=("anti_dodge",)),
    ], A("D",0.6,dmg,swing=0.28,kind="slam"), speed, xp, gold, patience=4, adapt=0.5, posture=120, idle=(1.1,1.9), cls="Giant")
def twin(id, name, region, hp, dmg, rig, speed=1.0, el=None, xp=120, gold=80):
    # two blades, never the same side twice: long alternating strings that demand direction changes
    d = round(dmg*0.7)
    f = lambda dir, w: A(dir, w, d, swing=0.2, element=el)
    return _base(id, name, region, round(hp*0.9), rig, [
        C("pair",3,[f("L",0.7),f("R",0.45)],1.1),
        C("cross",3,[f("DL",0.7),f("DR",0.45)],1.1),
        C("four",3,[f("L",0.68),f("R",0.45),f("DL",0.45),f("DR",0.45)],1.4,tags=("anti_dodge",)),
        C("five",2,[f("R",0.68),f("L",0.45),f("UR",0.45),f("UL",0.45),A("D",0.7,round(dmg*1.1),swing=0.22)],1.6,tags=("anti_dodge",)),
        C("stall",2,[f("L",0.65),A("R",1.3,dmg,swing=0.18)],1.2,tags=("anti_parry",)),
        C("whirl",2,[A("L",0.9,dmg,unblockable=True,dodge="L",parry=False,kind="sweep")],1.3,tags=("anti_block","anti_parry")),
        C("slip",2,[f("R",0.6)],0.4,retreat=True),
        C("dart",3,[A("U",0.75,dmg,swing=0.2,kind="lunge")],1.1,range="far"),
    ], A("R",0.4,d,swing=0.18), speed, xp, gold, patience=2, adapt=0.8, posture=50, idle=(0.45,0.9), cls="Twin-Bladed")
def double(id, name, region, hp, dmg, rig, speed=1.0, el=None, xp=140, gold=90):
    # a blade at each end of the haft: every cut is answered at once from the opposite side
    a = lambda dir, w, **k: A(dir, w, dmg, element=el, **k)
    return _base(id, name, region, round(hp*1.1), rig, [
        C("there_back",4,[a("L",0.9),a("R",0.5)],1.3),
        C("back_there",4,[a("R",0.9),a("L",0.5)],1.3),
        C("rise_fall",3,[a("U",0.9),a("D",0.5,kind="slam")],1.4),
        C("fall_rise",3,[a("D",0.95,kind="slam"),a("U",0.5)],1.4),
        C("mill",2,[a("DL",0.85),a("UR",0.5),a("DR",0.5),a("UL",0.5)],1.7,tags=("anti_dodge",)),
        C("butt",2,[A("U",0.9,round(dmg*0.7),guard=dmg*4,kind="thrust")],1.2,tags=("anti_block",)),
        C("held_spin",2,[a("L",1.8,swing=0.22),a("R",0.5)],1.4,tags=("anti_parry",)),
        C("vault_back",2,[a("U",0.7)],0.45,retreat=True),
        C("vault",3,[A("D",0.9,round(dmg*1.2),kind="lunge")],1.3,range="far"),
    ], A("L",0.45,dmg,swing=0.22), speed, xp, gold, patience=3, adapt=0.7, posture=70, idle=(0.7,1.3), cls="Double-Weapon")
def beast(id, name, region, hp, dmg, rig, speed=1.0, el=None, xp=150, gold=95):
    # not a soldier at all: it pounces, rakes and worries. Nothing it does is polite enough to block for long.
    return _base(id, name, region, round(hp*1.3), rig, [
        C("rake_l",3,[A("L",0.85,dmg,kind="sweep",element=el)],1.2),
        C("rake_r",3,[A("R",0.85,dmg,kind="sweep",element=el)],1.2),
        C("rakes",3,[A("L",0.85,dmg,kind="sweep"),A("R",0.55,dmg,kind="sweep"),A("L",0.55,dmg,kind="sweep")],1.5,tags=("anti_dodge",)),
        C("worry",3,[A("U",1.0,round(dmg*0.8),guard=dmg*3,kind="thrust"),A("U",0.6,round(dmg*0.8),guard=dmg*3,kind="thrust")],1.4,tags=("anti_block",)),
        C("crush",2,[A("D",1.4,round(dmg*1.6),unblockable=True,parry=False,dodge="any",kind="slam")],1.8,tags=("anti_block","anti_parry")),
        C("spring_back",3,[A("U",0.75,dmg,kind="sweep")],0.45,retreat=True),
        C("pounce",4,[A("D",0.95,round(dmg*1.3),kind="lunge",guard=dmg*3)],1.4,range="far"),
        C("feint_pounce",2,[A("D",1.8,round(dmg*1.4),swing=0.22,kind="lunge")],1.4,range="far",tags=("anti_parry",)),
    ], A("L",0.45,dmg,swing=0.22,kind="sweep"), speed, xp, gold, patience=2, adapt=0.7, posture=75, idle=(0.6,1.2), cls="Monstrosity")
def drake(id, name, region, hp, dmg, rig, speed=1.0, el="fire", xp=300, gold=190, weak="frost"):
    return _base(id, name, region, round(hp*1.4), rig, [
        C("snap_l",3,[A("L",0.9,dmg,kind="bite")],1.3),
        C("snap_r",3,[A("R",0.9,dmg,kind="bite")],1.3),
        C("lunge_bite",3,[A("U",1.0,round(dmg*1.2),kind="lunge")],1.4),
        C("claw",3,[A("DL",0.9,dmg,kind="sweep"),A("DR",0.7,dmg,kind="sweep")],1.5,tags=("anti_dodge",)),
        C("spit",3,[A("D",1.4,round(dmg*1.35),unblockable=True,parry=False,dodge="any",kind="breath",element=el)],1.7,tags=("anti_block","anti_parry")),
    ], A("U",0.5,dmg,swing=0.24,kind="bite"), speed, xp, gold, posture=80, weak=weak, cls="Monstrosity")
def eater(id, name, region, hp, dmg, rig, speed=1.0, xp=130, gold=90):
    # soul-eater: its grasp feeds it. Block and it still drinks; parry or dodge.
    return _base(id, name, region, hp, rig, [
        C("rake_l",3,[A("L",0.9,dmg,kind="sweep")],1.2),
        C("rake_r",3,[A("R",0.9,dmg,kind="sweep")],1.2),
        C("grasp",4,[A("U",1.15,round(dmg*0.9),drain=True,kind="thrust",guard=dmg*2)],1.4,tags=("anti_block",)),
        C("long_grasp",2,[A("U",2.0,dmg,drain=True,swing=0.24,kind="thrust",guard=dmg*2)],1.5,tags=("anti_parry","anti_block")),
        C("fade",2,[A("R",0.8,dmg,kind="sweep")],0.5,retreat=True),
        C("swoop",3,[A("D",0.95,round(dmg*1.1),drain=True,kind="lunge")],1.3,range="far"),
        C("rake_grasp",2,[A("L",0.85,dmg,kind="sweep"),A("U",0.8,dmg,drain=True,kind="thrust")],1.5,tags=("anti_dodge",)),
    ], A("U",0.5,dmg,drain=True,swing=0.24,kind="thrust"), speed, xp, gold, patience=2, adapt=0.8, posture=55, idle=(0.7,1.3), cls="Soul-Eater")
def R(metal, cloth, weapon, eye, helm, scale=1.0, **k):
    d = dict(scale=scale, metal=metal, cloth=cloth, weapon=weapon, eye=eye, helm=helm); d.update(k); return d
WR = dict(wraith=True, maw=True, cape=True)
B += [
 soldier("hollow_soldier","Hollow Soldier","courtyard",220,12,R("#7a7c80","#3a2a22","sword","#ffb060","kettle")),
 duelist("banneret","Banneret","courtyard",230,13,R("#8a8c90","#5a1616","sword","#ffb060","kettle",bulk=0.85,cape=True),xp=75,gold=50),
 brute("rampart_brute","Rampart Breaker","courtyard",240,13,R("#5c5a56","#2a1a14","axe","#ffb060","great",scale=1.22,bulk=1.4),xp=100,gold=70),

 soldier("blackwood_stalker","Blackwood Stalker","blackwood",300,16,R("#2e3a2c","#1c2418","axe","#b6ff7a","hood"),speed=1.1,xp=110,gold=70),
 duelist("thornblade","Thornblade","blackwood",310,17,R("#3a4434","#243018","dual","#b6ff7a","hood",bulk=0.82,cape=True),speed=1.05,xp=130,gold=85),
 brute("woodward","The Woodward","blackwood",320,17,R("#34302a","#1c1810","cleaver","#d8ff9a","hood",scale=1.28,bulk=1.5,antlers=True),speed=1.02,xp=160,gold=105),

 soldier("ash_acolyte","Ash Penitent","cathedral",380,21,R("#6a5a48","#5a1a14","sword","#ff7a3a","hood"),speed=1.12,el="fire",xp=170,gold=110),
 brute("censer_knight","Censer Knight","cathedral",400,22,R("#8c7a52","#4a1410","axe","#ff7a3a","great",scale=1.25,bulk=1.35,ember=True),speed=1.05,el="fire",xp=230,gold=150),
 eater("choir_wraith","Choir Wraith","cathedral",360,19,R("#3a3034","#1a1216","claws","#ffb0e0","hood",scale=1.1,bulk=0.8,**WR),xp=220,gold=140),

 brute("crypt_warden","Crypt Sentry","crypt",480,26,R("#48564e","#20282a","greatsword","#7affc8","great",scale=1.2,bulk=1.3),speed=1.08,xp=280,gold=180),
 duelist("drowned_squire","Drowned Squire","crypt",470,26,R("#5a6c66","#1c2a2c","sword","#7affc8","kettle",bulk=0.85),speed=1.1,xp=250,gold=160),
 eater("tomb_leech","Tomb Leech","crypt",460,24,R("#2a3432","#0e1614","claws","#7affc8","hood",scale=1.15,bulk=0.85,**WR),speed=1.05,xp=290,gold=185),

 soldier("scalebound","Scalebound Knight","roost",540,30,R("#7a4a34","#2a1410","axe","#ffa040","great",bulk=1.15,horns=True),speed=1.15,el="fire",xp=320,gold=200),
 duelist("ash_falconer","Ash Falconer","roost",540,30,R("#8a7460","#3a2418","dual","#ffa040","hood",bulk=0.82,cape=True),speed=1.15,el="fire",xp=340,gold=215),

 soldier("frost_thrall","Frost Thrall","citadel",600,33,R("#8aa6b4","#2a3a48","axe","#8fdcff","kettle"),speed=1.18,el="frost",xp=380,gold=235),
 duelist("rime_duelist","Rime Duelist","citadel",600,33,R("#a8c4d0","#243848","sword","#8fdcff","crown",bulk=0.85,cape=True,weapon_glow="#7fd4ff"),speed=1.18,el="frost",xp=400,gold=250),
 brute("glacier_brute","Glacier Hulk","citadel",620,34,R("#7a94a4","#1c2c3a","greatsword","#8fdcff","great",scale=1.3,bulk=1.45,frost=True),speed=1.1,el="frost",xp=460,gold=290),

 eater("soul_eater","Soul-Eater","deep",640,34,R("#2a2430","#120e18","claws","#c08aff","hood",scale=1.2,bulk=0.85,**WR),speed=1.12,xp=480,gold=300),
 duelist("husk","Emptied Husk","deep",660,36,R("#5a5660","#1a1620","sword","#c08aff","kettle",bulk=0.9),speed=1.2,xp=460,gold=290),
 brute("oath_eater","Eater of Oaths","deep",680,36,R("#342a3c","#140e1c","cleaver","#d8a8ff","hood",scale=1.4,bulk=1.3,**WR),speed=1.1,xp=540,gold=340),

 soldier("throne_guard","Throne Guard","throne",720,38,R("#8c7a52","#3a0e0e","greatsword","#ffd98a","great",scale=1.15),speed=1.22,xp=560,gold=350),
 duelist("kingsblade","Kingsblade","throne",720,39,R("#b89b5e","#3a0e0e","dual","#ffd98a","crown",bulk=0.85,cape=True),speed=1.22,xp=580,gold=365),
 eater("crownless","The Crownless","throne",740,38,R("#4a4038","#1c0808","claws","#ffe8b0","crown",scale=1.25,bulk=0.9,**WR),speed=1.18,xp=620,gold=390),
]
BEAST = dict(helm="beast", weapon="claws", hunch=0.45)
def D(hide, belly, eye, glow, size): return dict(kind="dragon", scale=1.0+size, size=size, hide=hide, belly=belly, eye=eye, glow=glow)
B += [
 # --- courtyard
 giant("gate_colossus","Gate Colossus","courtyard",230,13,R("#6a6860","#2a1a14","greatsword","#ffb060","great",scale=1.75,bulk=1.45),xp=160,gold=110),
 double("pike_sergeant","Pike Sergeant","courtyard",230,12,R("#8a8c90","#3a2a22","glaive","#ffb060","kettle"),xp=90,gold=60),
 # --- blackwood
 beast("maulbeast","Blackwood Maulbeast","blackwood",300,16,R("#3a3428","#2a2418","claws","#d8ff9a","beast",scale=1.35,bulk=1.5,hunch=0.5,antlers=True),speed=1.05,xp=170,gold=110),
 twin("veil_dancer","Veil Dancer","blackwood",300,17,R("#4a5040","#c8c4b4","dual","#e8ffe0","veil",bulk=0.8,cape=True,skirt=True),speed=1.05,xp=150,gold=95),
 # --- cathedral
 giant("bell_ringer","The Bell Ringer","cathedral",380,20,R("#6a5630","#3a1410","cleaver","#ff7a3a","hood",scale=1.85,bulk=1.5,apron=True),speed=1.03,el="fire",xp=300,gold=190),
 double("censer_adept","Thurible Adept","cathedral",380,20,R("#8c7a52","#5a1a14","glaive","#ff7a3a","hood",cape=True,weapon_glow="#ff8a3a"),speed=1.08,el="fire",xp=240,gold=150),
 # --- crypt
 beast("crypt_crawler","Crypt Crawler","crypt",470,25,R("#3a4844","#141c1a","claws","#7affc8","beast",scale=1.3,bulk=1.3,hunch=0.6),speed=1.1,xp=300,gold=190),
 twin("tomb_mummer","Tomb Mummer","crypt",470,26,R("#5a6c66","#d8d4c4","dual","#7affc8","veil",bulk=0.8,skirt=True),speed=1.1,xp=290,gold=185),
 # --- roost
 drake("cinder_whelp","Cinder Whelp","roost",540,30,D("#6a3a2a","#c8703a","#ffb040","#ff6a1a",0.62),speed=1.1,xp=420,gold=260),
 giant("brood_keeper","The Brood Keeper","roost",540,28,R("#7a4a34","#2a1410","axe","#ffa040","great",scale=1.8,bulk=1.4,horns=True,ember=True),speed=1.05,el="fire",xp=440,gold=280),
 # --- citadel
 double("rime_glaive","Rime Glaive","citadel",600,32,R("#a8c4d0","#243848","glaive","#8fdcff","crown",cape=True,weapon_glow="#7fd4ff"),speed=1.15,el="frost",xp=420,gold=260),
 beast("hoarbeast","Hoarbeast","citadel",600,33,R("#c8d8e0","#8aa6b4","claws","#8fdcff","beast",scale=1.45,bulk=1.5,hunch=0.5,horns=True,frost=True),speed=1.12,el="frost",xp=440,gold=275),
 drake("frost_drake","Kennel Drake","citadel",600,32,D("#8aa8b8","#d8e8f0","#9fe4ff","#7fd4ff",0.7),speed=1.12,el="frost",xp=460,gold=290,weak="fire"),
 # --- deep
 twin("name_thief","Name-Thief","deep",650,35,R("#3a3040","#120e18","dual","#c08aff","veil",bulk=0.8,cape=True,weapon_glow="#c08aff"),speed=1.18,xp=500,gold=310),
 giant("the_unburied","The Unburied","deep",660,34,R("#3c3444","#140e1c","cleaver","#d8a8ff","hood",scale=1.9,bulk=1.4,maw=True),speed=1.08,xp=600,gold=380),
 # --- throne
 double("herald","Herald of the Court","throne",720,37,R("#b89b5e","#3a0e0e","glaive","#ffd98a","crown",cape=True,skirt=True),speed=1.2,xp=600,gold=375),
 giant("throne_colossus","The King's Shadow","throne",740,37,R("#2a2620","#1c0808","greatsword","#ffd98a","crown",scale=1.9,bulk=1.4,cape=True),speed=1.12,xp=700,gold=440),
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
   # the gatekeeper's drill: formal, crossing cuts; a thrust to hold the line; a step back that sweeps
   C("drill_cross",2,[A("DL",1.15,20),A("DR",0.85,20)],1.6,tags=("anti_dodge",)),
   C("gate_thrust",2,[A("U",1.0,22,swing=0.22,kind="lunge")],1.4,range="far"),
   C("give_ground",2,[A("R",1.0,18,kind="sweep")],0.6,retreat=True),
  ]),
  dict(at=0.5, speed=1.08, roar="The Sentinel's armour splits. Embers pour from the seams.", combos=[
   C("ember_charge",3,[A("D",1.1,30,kind="lunge",element="fire")],1.6,range="far"),
   C("rising_cross",2,[A("UL",1.0,22),A("DR",0.8,24),A("U",0.8,20)],1.9,tags=("anti_dodge",)),
   C("give_ground",2,[A("L",0.95,20,kind="sweep",element="fire")],0.6,retreat=True),
   C("sweep_l",2,[A("L",1.15,22,element="fire")],1.4),
   C("sweep_r",2,[A("R",1.15,22,element="fire")],1.4),
   C("overhead",3,[A("D",1.4,32,swing=0.34,kind="slam",element="fire")],1.8),
   C("three",3,[A("L",1.1,20),A("R",0.85,20),A("D",1.0,30,kind="slam")],2.0,tags=("anti_dodge",)),
   C("delayed",2,[A("D",2.1,34,swing=0.26,kind="slam")],1.9,tags=("anti_parry",)),
   C("pommel",2,[A("U",0.95,16,guard=75,kind="thrust")],1.3,tags=("anti_block",)),
   C("cinder_wave",1,[A("L",1.5,30,unblockable=True,dodge="none",kind="sweep",element="fire")],1.8,tags=("anti_block","anti_dodge")),
  ]),
  # the last order: he stops giving ground, and every pattern is the drill at full speed
  dict(at=0.22, speed=1.16, roar="He plants the blade and speaks the oath of the gate one last time.", combos=[
   C("final_watch",3,[A("L",1.05,22),A("R",0.8,22),A("DL",0.8,24),A("D",0.95,34,kind="slam",element="fire")],2.3,tags=("anti_dodge",)),
   C("drill_cross",3,[A("DL",1.0,24),A("DR",0.75,24)],1.5,tags=("anti_dodge",)),
   C("ember_charge",3,[A("D",1.0,32,kind="lunge",element="fire")],1.5,range="far"),
   C("delayed",2,[A("D",2.0,38,swing=0.26,kind="slam")],1.9,tags=("anti_parry",)),
   C("pommel",2,[A("U",0.9,18,guard=80,kind="thrust")],1.3,tags=("anti_block",)),
   C("oath",1,[A("D",1.7,40,unblockable=True,kind="slam",element="fire")],2.2,tags=("anti_block",)),
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
 hp=2000, armor=0.18, posture=140, patience=3, adapt=0.9, idle=[0.9,1.5], weak="fire", xp=1900, gold=1100,
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
B.append(dict(id="forgotten_monarch", name="The Forgotten Monarch", title="Last Ruler of the Fallen Realm", region="throne", boss=True,
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
# ---------------------------------------------------------------- Vharn, the Cinder Wyrm
def breath(dir, windup, dmg, el="fire", **k):
    # a sweeping gout: cannot be blocked or parried, only stepped out of
    return A(dir, windup, dmg, unblockable=True, parry=False, kind="breath", element=el, swing=0.4, **k)
B.append(dict(id="cinder_wyrm", name="Veyrath, the Cinder Wyrm", title="Last of the Royal Brood", region="roost", boss=True,
 hp=1900, armor=0.22, posture=170, patience=3, adapt=0.9, idle=[0.9,1.6], weak="frost", xp=2400, gold=1400,
 loot=[["w_wyrmfang",1.0],["s_scale",0.7],["a_wyrm_chest",0.7],["a_wyrm_helm",0.6],["r_brood",0.5]], music="combat_b", arena="roost",
 intro="The kings rode her mother to war. She has had the sky to herself since, and she has not missed them.",
 rig=dict(kind="dragon",scale=2.3,size=1.25,hide="#5a2a20",belly="#b8602a",eye="#ffb040",glow="#ff5a14",wings=True),
 punish=A("U",0.5,30,swing=0.24,kind="bite"),
 phases=[
  dict(at=1.0, speed=1.0, combos=[
   C("snap_l",3,[A("L",1.0,30,kind="bite")],1.4),
   C("snap_r",3,[A("R",1.0,30,kind="bite")],1.4),
   C("maul",3,[A("D",1.4,42,kind="slam")],1.7),
   C("claws",3,[A("DL",1.0,28,kind="sweep"),A("DR",0.75,28,kind="sweep")],1.6,tags=("anti_dodge",)),
   C("gout_l",3,[breath("L",1.5,44)],1.8,tags=("anti_block","anti_parry")),
   C("gout_r",3,[breath("R",1.5,44)],1.8,tags=("anti_block","anti_parry")),
   C("tail",2,[A("R",1.2,34,guard=110,kind="sweep")],1.4,tags=("anti_block",)),
  ]),
  dict(at=0.6, speed=1.08, roar="She takes the air. The roost drops away beneath her and the wind turns hot.", combos=[
   C("stoop",4,[A("D",1.3,46,kind="lunge")],1.6,range="far"),
   C("strafe",3,[breath("L",1.6,46,dodge="L"),breath("R",1.1,46,dodge="R")],2.0,range="far",tags=("anti_block","anti_parry")),
   C("snap_snap",3,[A("L",0.95,30,kind="bite"),A("R",0.7,30,kind="bite"),A("U",0.8,36,kind="bite")],1.7,tags=("anti_dodge",)),
   C("maul_held",3,[A("D",2.1,50,swing=0.26,kind="slam")],1.7,tags=("anti_parry",)),
   C("gout_l",2,[breath("L",1.4,46)],1.7,tags=("anti_block","anti_parry")),
   C("gout_r",2,[breath("R",1.4,46)],1.7,tags=("anti_block","anti_parry")),
   C("take_wing",3,[A("U",0.9,30,kind="sweep")],0.5,retreat=True),
  ]),
  dict(at=0.28, speed=1.15, roar="Her wing is torn through. She will not fly again. She does not need to.", combos=[
   C("frenzy",3,[A("L",0.9,32,kind="bite"),A("R",0.65,32,kind="bite"),A("DL",0.65,30,kind="sweep"),A("DR",0.65,30,kind="sweep"),A("D",1.1,48,kind="slam")],2.2,tags=("anti_dodge",)),
   C("maul_held",3,[A("D",2.3,54,swing=0.24,kind="slam")],1.7,tags=("anti_parry",)),
   C("inferno",3,[breath("L",1.3,48,dodge="L"),breath("R",1.0,48,dodge="R"),breath("D",1.2,52,dodge="any")],2.2,tags=("anti_block","anti_parry")),
   C("tail",2,[A("R",1.1,36,guard=130,kind="sweep")],1.3,tags=("anti_block",)),
   C("snap_l",2,[A("L",0.9,34,kind="bite")],1.2),
   C("snap_r",2,[A("R",0.9,34,kind="bite")],1.2),
  ])]))
# ---------------------------------------------------------------- optional: the Rimewyrm
B.append(dict(id="rimewyrm", name="Skeldra, the White Ruin", title="What the King Kept Chained", region="citadel", boss=True,
 hp=1700, armor=0.2, posture=160, patience=3, adapt=0.9, idle=[0.9,1.5], weak="fire", xp=2600, gold=1500,
 loot=[["w_rime_sword",1.0],["a_frost_legs",0.6],["a_frost_gauntlets",0.6]], music="combat_b", arena="citadel",
 intro="The chain froze through an age ago. It stayed anyway. It had been told to.",
 rig=dict(kind="dragon",scale=2.2,size=1.15,hide="#8aa8b8",belly="#d8e8f0",eye="#9fe4ff",glow="#7fd4ff",wings=True),
 punish=A("U",0.5,30,swing=0.24,kind="bite",element="frost"),
 phases=[
  dict(at=1.0, speed=1.0, combos=[
   C("snap_l",3,[A("L",1.0,30,kind="bite",element="frost")],1.4),
   C("snap_r",3,[A("R",1.0,30,kind="bite",element="frost")],1.4),
   C("maul",3,[A("D",1.4,42,kind="slam",element="frost")],1.7),
   C("hoar_l",3,[breath("L",1.5,40,el="frost")],1.8,tags=("anti_block","anti_parry")),
   C("hoar_r",3,[breath("R",1.5,40,el="frost")],1.8,tags=("anti_block","anti_parry")),
   C("claws",3,[A("DL",1.0,28,kind="sweep"),A("DR",0.75,28,kind="sweep")],1.6,tags=("anti_dodge",)),
  ]),
  dict(at=0.5, speed=1.12, roar="The chain snaps. It looks at the broken link for a long moment, and then at you.", combos=[
   C("snap3",3,[A("L",0.9,30,kind="bite",element="frost"),A("R",0.65,30,kind="bite",element="frost"),A("U",0.75,36,kind="bite",element="frost")],1.7,tags=("anti_dodge",)),
   C("maul_held",3,[A("D",2.2,50,swing=0.25,kind="slam",element="frost")],1.7,tags=("anti_parry",)),
   C("whiteout",3,[breath("L",1.3,42,el="frost",dodge="L"),breath("R",1.0,42,el="frost",dodge="R")],2.0,tags=("anti_block","anti_parry")),
   C("stoop",3,[A("D",1.2,44,kind="lunge",element="frost")],1.5,range="far"),
   C("take_wing",2,[A("U",0.9,30,kind="sweep")],0.5,retreat=True),
   C("chain_lash",2,[A("R",1.1,30,guard=130,kind="sweep")],1.3,tags=("anti_block",)),
  ])]))
# ---------------------------------------------------------------- The Devourer of Names
B.append(dict(id="devourer", name="The Devourer of Names", title="First of the Soul-Eaters", region="deep", boss=True,
 hp=1500, armor=0.1, posture=140, patience=2, adapt=1.3, idle=[0.6,1.2], weak=None, xp=3600, gold=2200,
 loot=[["w_hunger",1.0],["x_name",1.0],["a_hollow_chest",0.6]], music="final", arena="deep",
 intro="It ate the kingdom's dead until none were left. Then it began on the living. It knows what you were called.",
 rig=dict(scale=1.7,bulk=1.0,metal="#2a2230",cloth="#0e0a14",weapon="claws",eye="#d8a8ff",helm="hood",wraith=True,maw=True,cape=True,horns=True),
 punish=A("U",0.45,26,drain=True,swing=0.22,kind="thrust"),
 phases=[
  dict(at=1.0, speed=1.0, combos=[
   C("rake_l",3,[A("L",0.9,30,kind="sweep")],1.2),
   C("rake_r",3,[A("R",0.9,30,kind="sweep")],1.2),
   C("grasp",4,[A("U",1.1,30,drain=True,kind="thrust",guard=80)],1.4,tags=("anti_block",)),
   C("long_grasp",3,[A("U",2.1,34,drain=True,swing=0.22,kind="thrust",guard=80)],1.5,tags=("anti_parry","anti_block")),
   C("rakes",3,[A("L",0.85,28,kind="sweep"),A("R",0.6,28,kind="sweep"),A("U",0.75,30,drain=True,kind="thrust")],1.7,tags=("anti_dodge",)),
   C("fade",2,[A("R",0.75,26,kind="sweep")],0.45,retreat=True),
   C("swoop",3,[A("D",0.9,34,drain=True,kind="lunge")],1.3,range="far"),
  ]),
  dict(at=0.5, speed=1.12, roar="It opens. Inside it is every face it has taken. Some of them know you.", combos=[
   C("rakes4",3,[A("L",0.8,28,kind="sweep"),A("R",0.55,28,kind="sweep"),A("DL",0.55,28,kind="sweep"),A("DR",0.55,30,kind="sweep")],1.7,tags=("anti_dodge",)),
   C("grasp2",3,[A("U",1.0,30,drain=True,kind="thrust",guard=90),A("U",0.9,30,drain=True,kind="thrust",guard=90)],1.6,tags=("anti_block",)),
   C("long_grasp",3,[A("U",2.3,38,drain=True,swing=0.2,kind="thrust",guard=90)],1.5,tags=("anti_parry","anti_block")),
   C("unmake",3,[A("D",1.4,46,unblockable=True,parry=False,dodge="any",drain=True,kind="slam")],1.8,tags=("anti_block","anti_parry")),
   C("fade",2,[A("L",0.7,26,kind="sweep")],0.4,retreat=True),
   C("swoop",3,[A("D",0.85,36,drain=True,kind="lunge")],1.2,range="far"),
  ]),
  # it dies. Then it remembers a name it has not used yet.
  dict(at=0.0, revive=0.45, speed=1.25, roar="It falls, and is still. Then it says your name — the one you had before — and stands.", combos=[
   C("rakes5",3,[A("L",0.75,30,kind="sweep"),A("R",0.5,30,kind="sweep"),A("DL",0.5,30,kind="sweep"),A("DR",0.5,30,kind="sweep"),A("U",0.7,34,drain=True,kind="thrust")],1.9,tags=("anti_dodge",)),
   C("long_grasp",3,[A("U",2.5,42,drain=True,swing=0.2,kind="thrust",guard=100)],1.5,tags=("anti_parry","anti_block")),
   C("stutter",3,[A("L",0.7,28,kind="sweep"),A("U",1.5,36,drain=True,swing=0.2,kind="thrust")],1.5,tags=("anti_parry",)),
   C("unmake2",3,[A("L",1.2,44,unblockable=True,dodge="none",kind="sweep"),A("D",1.2,48,unblockable=True,parry=False,dodge="any",drain=True,kind="slam")],2.0,tags=("anti_block","anti_dodge")),
   C("fade",2,[A("R",0.65,28,kind="sweep")],0.4,retreat=True),
   C("swoop",3,[A("D",0.8,38,drain=True,kind="lunge")],1.2,range="far"),
  ])]))
# How each foe moves between blows: how fast it circles (radians/second) and how far off it likes to stand (metres).
FOOT_BY_CLS = {"Humanoid": (0.10, 0.7), "Heavy": (0.05, 0.9), "Giant": (0.035, 1.1), "Twin-Bladed": (0.34, 0.55), "Double-Weapon": (0.18, 1.0),
               "Monstrosity": (0.26, 0.9), "Soul-Eater": (0.22, 1.0)}
FOOT_BY_ID = {"ashen_sentinel": (0.07, 0.9), "hollow_executioner": (0.05, 0.8), "crimson_widow": (0.46, 0.5), "cathedral_beast": (0.24, 1.0),
              "gravewarden": (0.04, 1.3), "frostbound_king": (0.08, 1.0), "pale_huntsman": (0.36, 1.3), "forgotten_monarch": (0.20, 0.8), "devourer": (0.30, 1.1)}
# What makes each guardian a different problem, beyond its patterns (rules in DuelSim.trait_v).
TRAITS = {
 "hollow_executioner": {"marks": 3, "mark_mult": 1.7},          # three wounds are a sentence; the next blow carries it out. A perfect parry acquits
 "crimson_widow": {"dodge_open": 0.55, "parry_open": 1.35},     # she flows past a sidestep; only meeting her blade stops her
 "cathedral_beast": {"frenzy": 0.3},                            # faster as it bleeds
 "gravewarden": {"block_tax": 1.8, "parry_open": 1.25},         # too heavy to hold a shield against; slow enough to turn
 "frostbound_king": {"block_tax": 1.4, "dodge_open": 1.3},      # punishes standing still, rewards movement
 "pale_huntsman": {"dodge_open": 0.7, "frenzy": 0.15},
 "forgotten_monarch": {"marks": 4, "mark_mult": 1.5, "parry_open": 1.15},
 "devourer": {"lifesteal": 0.25, "frenzy": 0.2},                # it feeds on what it takes
}
for f in B:
    if f["id"] in TRAITS:
        f["traits"] = TRAITS[f["id"]]
for f in B:
    c, k = FOOT_BY_ID.get(f["id"], FOOT_BY_CLS.get(f.get("cls", ""), (0.08, 0.7)))
    f["footwork"] = {"circle": c, "keep": k}
for f in B:
    if "cls" not in f:
        f["cls"] = "Wyrm" if f["rig"].get("kind") == "dragon" else ("Soul-Eater" if f["rig"].get("wraith") else "Guardian")
    f["hp"] = round(f["hp"] * (3.5 if f["boss"] else 2.0))
json.dump({"bosses": B}, open("data/bosses.json","w"), indent=1)
print(len(B), "foes")
