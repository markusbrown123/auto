# Presentation pass: concept images (2026-11-28)

Concepts only. Nothing here is in the game; no game code or `assets/` were changed. All designs are original prompts; the owner's references (an emblem-and-serif title mood, an equipment screen, an item shop, a merchant's workshop) were used for mood only, and no names, symbols or typography from them were asked for.

**Spend:** 10 images on GPT Image 2.6 at 2k: 3 logos at quality *medium* (1.75 each, for cleaner lettering) + 7 at the default *low* (1.25 each) = **14.00 credits** (ceiling 17). No job failed or was refused; two creates were turned away by the plan's 8-concurrent-job limit before a job existed (no charge, re-submitted once the others finished). Job ids are below and in `_jobs.log`.

## Quick review
| Sheet | What |
|---|---|
| `sheet_logos.jpg` | the three logo directions |
| `sheet_icons.jpg` | the three icons, full art + 180 px + 60 px (iOS corner mask approximated) + home-screen mock |
| `sheet_merchant.jpg` | the two merchant images |
| `sheet_monarch.jpg` | the two Monarch images |
| `home_screen_mock_3x.png` / `_1x.png` | one home-screen row per icon option, between plain neutral placeholder tiles; the 1x file is the real pixel size of a 60 pt icon on a non-retina grid |
| `icon_previews/` | each icon at 180 and 60 px, square and rounded |
| `in_game_state/` | captures of what the game shows today (see the end) |

## 1. Logos
Letter check, read from crops of the full-resolution files: **all three wordmarks read H-O-L-L-O-W R-E-I-G-N correctly**, no missing, doubled or malformed letters. Even so, the lettering is a generated imitation of a classical Roman-capital serif; for any real use the wordmark should be set in a real, licensed font (the game already ships Cinzel and EB Garamond under the OFL, `assets/fonts/`). The emblem is what is being chosen.

- **A, Broken crown** (`logo_a_broken_crown.png`): five-point line-art crown, empty centre, cracked down the middle with ember light and a few embers rising. Works: the simplest to read, ties directly to the title (a hollow crown, a broken reign), the ember crack gives one point of colour. Weakness: a crown is a common fantasy mark, so it is the least distinctive of the three; the fine filigree will not survive small sizes.
- **B, Blade and seal** (`logo_b_blade_seal.png`): a sword driven down through a small crown inside a thin circle broken at the top. Works: tells the game (sword duels, a fallen crown) in one mark, very calm and premium on the black, strong vertical for a title screen. Weakness: sword-through-crown is a familiar heraldic idea; the crown sits a little low on the blade.
- **C, Shattered crown / machine halo** (`logo_c_machine_halo.png`): crown broken into floating shards round a lit empty centre, inside a thin notched ring that hints at machinery. Works: the only one that carries the "far-future under the medieval surface" idea, most atmospheric. Weakness: busiest and least legible small; the shards read as "explosion" as much as "crown" at a glance.

## 2. App icons
Generated separately from the logos, so they are matching *directions*, not exact simplifications of the logo emblems; whichever is chosen should be redrawn as a clean flat mark from the chosen logo.

- **A** (`icon_a_broken_crown.png`): reads instantly at 60 px (chunky crown, red-glow crack), but the three-point crown is heavier and more "mobile game" than logo A's thin five-point crown; the red stone ground is warmer than the near-black brief.
- **B** (`icon_b_blade_seal.png`): closest to its logo and the most premium at 180 px; at 60 px the sword and crown merge into a small gold knot inside a ring, still recognisable as a sigil but detail is lost. The ring became a crescent, which with the crossguard can read a little like a trident or anchor.
- **C** (`icon_c_machine_halo.png`): the strongest small silhouette (bright, symmetric, high contrast) but the crown idea is mostly gone, it reads as an abstract star/compass, and it is the brightest and least "dark and mysterious".
The home-screen mock uses plain coloured squares for the neighbouring apps; corner radius is an approximation of the iOS mask, not Apple's exact curve.

## 3. Armour merchant (Orren)
- `merchant_workshop_wide.png` (16:9): a full workshop as asked: forge glow, candles on every ledge, swords on racks, helms and breastplates on stands, a half-built suit, grindstone, ore crates, an anvil, and a blue-lit dark-metal panel (salvaged old technology) as a workbench. The smith is the right age and build with burn-scarred forearms. Weak: the image has a heavy over-processed HDR look; his expression is a broad grin rather than the dry, sceptical look of the character bible; the anvil is oversized and the room is so dense the figure competes with it.
- `merchant_counter_portrait.png` (4:5): the stronger of the two for personality: lined face, soot smudge, guarded appraising look with a small dry smile, loupe on a strap, helm under repair, ledger, coins and a small glowing relic on the counter, armour and swords behind. Weak: the "line that kept scraps of old engineering" shows only in the loupe and the relic; he could pass for any fantasy smith. Usable as a reference for a model or a portrait card.

## 4. Forgotten Monarch
- `monarch_full_body.png` (3:4): consistent with the current model's language (tarnished gold and black, long tapered plates, spiked hollow crown fused to a blank white-gold faceplate with white eye slits) and adds what the story bible asks for and the model lacks: a tattered faded-crimson mantle, a thin ceremonial sword, and a machine ring behind the crown (the steward of the machines). Reads intimidating and still. Weak: the mantle and long plate skirt hide the legs and the hands are clasped, so this is *not* a usable image-to-3D source as is (that would need a separate A-pose version without the cloak, as `tools/concepts.py` frames them); the faceplate is long and alien, which may read less human/tragic than "a steward who counted the price".
- `monarch_throne_hall.png` (16:9): the Monarch enthroned before a huge ring machine with cables running into the floor, crimson mantle pooled on the steps, a shaft of light. Matches the in-game throne-hall layout (ring halo behind the throne) and could guide its lighting. Weak: the figure is small and dark in frame; the ring can read like a portal gate.

## Current in-game state (captures in `in_game_state/`, taken with `tools/shoot.sh`)
- **Merchant: there is no character at all.** Orren exists only as a name over subtitles and voice (`merchant_shop_tab_now.png`, `merchant_forge_tab_now.png`: Shop and Forge tabs of the sanctuary, "ORREN: So you're what she woke up. Hm."). There is no model in `assets/models`; the only 3D trace is a placeholder anvil of grey boxes with an orange work light (`src/world/backdrop.gd`, `forge_spot()`). The shop shows flat line-icon placeholders for armour pieces (boots, pauldrons) rather than models.
- **Monarch: a real textured model exists** (`assets/models/forgotten_monarch.glb`, Tripo from `art/concept/forgotten_monarch_v1.png`, copied here as `monarch_concept_v1_source_of_current_model.png`), used in the duel and in the prologue, second-fall and aftermath cutscenes (`src/cine/*.gd`, built through `FighterRig`). Placeholder-looking points: one uniform gold material with no black or crimson, no mantle or cloth of any kind, very thin limbs and a spindly silhouette that reads as a gold mannequin in the duel (`monarch_duel_now.png`); in the prologue throne shot he is a tiny gold figure on the throne (`monarch_prologue_throne_now.png`), the hall itself built from untextured block walls. The player knight in this `--demo` duel capture also renders untextured grey; cause not investigated (outside this task).

## Prompts and costs
### logo_a_broken_crown.png
Job `a6a4715e-d97b-4394-b8a1-60c56ca1e032` · gpt_image_2_6 · 2k · 1:1 · quality medium · **1.75 credits**

> Premium dark fantasy video game logo on a near-black background, centred composition with generous empty space. Below the emblem, the title HOLLOW REIGN spelled exactly H-O-L-L-O-W R-E-I-G-N in one line of elegant, widely letter-spaced classical serif capitals, thin and refined, warm pale gold. Mysterious, restrained, luxurious, subtle film grain. Entirely original design, not resembling any existing game or brand logo. No other text, no letters except the title, no watermark, no signature. The emblem: a hollow crown drawn in thin warm-gold line art, five tall slender points, its centre completely empty, split down the middle by a single jagged crack where a faint ember-orange glow leaks through; a few tiny embers drift up from the break. Symmetric, minimal, engraved-metal feel.

### logo_b_blade_seal.png
Job `b0269091-406a-4243-92e7-cb4984366208` · gpt_image_2_6 · 2k · 1:1 · quality medium · **1.75 credits**

> Premium dark fantasy video game logo on a near-black background, centred composition with generous empty space. Below the emblem, the title HOLLOW REIGN spelled exactly H-O-L-L-O-W R-E-I-G-N in one line of elegant, widely letter-spaced classical serif capitals, thin and refined, warm pale gold. Mysterious, restrained, luxurious, subtle film grain. Entirely original design, not resembling any existing game or brand logo. No other text, no letters except the title, no watermark, no signature. The emblem: a vertical sigil. A long slender sword points straight down through the empty centre of a small, simple crown; behind them a single thin perfect circle like a wax seal outline, the circle broken by a small gap at the top. Fine engraved gold lines on blackened steel, quiet and solemn.

### logo_c_machine_halo.png
Job `13adc6c9-761d-4a44-9f34-8de3aa4bb355` · gpt_image_2_6 · 2k · 1:1 · quality medium · **1.75 credits**

> Premium dark fantasy video game logo on a near-black background, centred composition with generous empty space. Below the emblem, the title HOLLOW REIGN spelled exactly H-O-L-L-O-W R-E-I-G-N in one line of elegant, widely letter-spaced classical serif capitals, thin and refined, warm pale gold. Mysterious, restrained, luxurious, subtle film grain. Entirely original design, not resembling any existing game or brand logo. No other text, no letters except the title, no watermark, no signature. The emblem: a crown made of separate angular shards floating apart around an empty dark centre, as if shattered and frozen in mid-air; around it a thin halo ring traced with tiny geometric circuit-like notches, hinting at ancient forgotten technology under medieval craft. Pale gold lines with a cold white-gold glow at the core.

### icon_a_broken_crown.png
Job `f41afb54-083b-4a56-ac61-38aa8c0cab18` · gpt_image_2_6 · 2k · 1:1 · quality low · **1.25 credits**

> Square iOS app icon artwork, full bleed to the edges, no rounded corners, no border, no text, no letters. One bold, simple emblem centred and filling about 70 percent of the square, thick confident shapes that stay readable at very small sizes, strong silhouette, high contrast against the background. Premium dark fantasy game, original design, not resembling any existing game or brand. The emblem: a hollow five-pointed crown in warm burnished gold, empty in the centre, split by one jagged glowing ember-orange crack. Background: deep near-black with a soft dark ember-red glow behind the crown and a subtle stone texture.

### icon_b_blade_seal.png
Job `6cf0559e-d9ad-4762-bf5a-4a4a4be55c3f` · gpt_image_2_6 · 2k · 1:1 · quality low · **1.25 credits**

> Square iOS app icon artwork, full bleed to the edges, no rounded corners, no border, no text, no letters. One bold, simple emblem centred and filling about 70 percent of the square, thick confident shapes that stay readable at very small sizes, strong silhouette, high contrast against the background. Premium dark fantasy game, original design, not resembling any existing game or brand. The emblem: a sword pointing straight down through the empty centre of a small crown, inside a thick broken gold ring open at the top. Engraved gold on blackened steel. Background: near-black with a faint cold grey vignette.

### icon_c_machine_halo.png
Job `f991dedb-1110-44b5-9057-56c967e191eb` · gpt_image_2_6 · 2k · 1:1 · quality low · **1.25 credits**

> Square iOS app icon artwork, full bleed to the edges, no rounded corners, no border, no text, no letters. One bold, simple emblem centred and filling about 70 percent of the square, thick confident shapes that stay readable at very small sizes, strong silhouette, high contrast against the background. Premium dark fantasy game, original design, not resembling any existing game or brand. The emblem: a crown of a few large angular gold shards floating apart around a glowing white-gold empty centre, ringed by a thick notched halo. Background: deep near-black blue-grey with a soft white-gold core light.

### merchant_workshop_wide.png
Job `5c81eecb-3c97-43c2-b38a-4f70c7c20899` · gpt_image_2_6 · 2k · 16:9 · quality low · **1.25 credits**

> Cinematic concept art for an original dark sci-fantasy game, realistic and grounded. Interior of an old armourer's forge-workshop built inside the ruin of a medieval stone hall, low timber beams, a glowing coal forge, a heavy worn anvil, candle stubs on every ledge, warm orange forge light and candlelight against deep shadow. Every wall crowded with the craftsman's life's work: racks of swords, axes and spears, helms on pegs, breastplates on wooden stands, a half-finished suit of armour, tongs, hammers, files, a grindstone, leather aprons, crates of ore. Hidden among the medieval clutter, small salvaged relics of a forgotten advanced civilisation: a dark metal panel with faint blue circuit lines used as a workbench, a glass lens on an arm, cable bundles patched with leather. At the anvil stands the smith: a broad-shouldered man in his late sixties, weathered lined face, short grey beard, burn scars on his forearms, heavy leather apron over a patched wool shirt, spectacles pushed up on his forehead, inspecting a sword edge with a sceptical, dryly amused expression. Lived-in, believable, years of work in one place. Wide shot, 35mm lens, shallow depth of field, film grain. No text, no logos, no watermark.

### merchant_counter_portrait.png
Job `c8c42160-3f88-423b-912f-545f2610d817` · gpt_image_2_6 · 2k · 4:5 · quality low · **1.25 credits**

> Cinematic character portrait for an original dark sci-fantasy game, realistic and grounded. An old master armourer behind his scarred wooden counter, medium close shot from the waist up, leaning on both hands, looking straight at the viewer with a guarded, appraising stare and the faint start of a dry smile. Late sixties, deep-set eyes, lined weathered face, short grey beard, thinning hair tied back, a soot smudge on his cheek, an old burn scar on one hand, a thick leather apron, a brass and dark-metal magnifier loupe on a strap round his neck. On the counter: a helm under repair, a whetstone, a ledger, coins, a small glowing salvaged relic. Behind him, out of focus, walls of hung swords, shields and armour lit by a glowing forge and many candles. Warm amber key light from the forge, cool shadow, 85mm lens, film grain. No text, no logos, no watermark.

### monarch_full_body.png
Job `0e9f7292-4cbc-48ca-815b-7712ea772bef` · gpt_image_2_6 · 2k · 3:4 · quality low · **1.25 credits**

> Original character concept art for a dark sci-fantasy action game, realistic materials, high detail. The Forgotten Monarch: a towering gaunt ruler who was never born a king, a steward who kept a dying civilisation's machines running and paid for it. Full body, standing upright and still, facing the camera, hands resting on the pommel of a long thin ceremonial sword planted point-down before him. Elegant sleek armour of tarnished gold and black steel with long tapered plates, the gold worn through to dark metal at the edges, a long armoured skirt of narrow gold plates, a heavy tattered royal mantle in faded deep crimson hanging from the shoulders, its hem frayed. His head: a hollow crown of tall thin spikes with an empty centre, fused to a smooth blank white-gold faceplate with two narrow glowing white eye slits, fine cracks in the faceplate, and behind the crown a thin ring of dark machine metal with faint white-gold light in its channels. Intimidating, tragic, regal, weary, controlled. Dark grey studio background, dramatic soft top light. No text, no logos, no watermark.

### monarch_throne_hall.png
Job `b8a24376-4f51-4fb7-ad36-a9bdfec9d4ad` · gpt_image_2_6 · 2k · 16:9 · quality low · **1.25 credits**

> Cinematic concept art for an original dark sci-fantasy game, realistic and grounded. The last throne hall of a dead empire: black marble pillars with thin white-gold light lines, dust in a single shaft of pale light. On a towering throne of black metal and gold sits the Forgotten Monarch, a gaunt figure in tarnished gold and black armour with a faded crimson mantle pooled on the steps, a hollow spiked crown fused to a blank white-gold faceplate with glowing white eye slits, one hand resting on a long thin ceremonial sword across his knees. Behind the throne rises a huge ring-shaped machine halo of dark metal, glowing faint white-gold, cables running from it into the floor as if the throne itself keeps something alive. Low wide angle from the foot of the stairs, the ruler small but dominant, still and patient, tragic and intimidating. Film grain. No text, no logos, no watermark.
