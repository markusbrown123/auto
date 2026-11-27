# Shield clipping pass: vertex counts before and after

Measured with `src/dev/pose_review.gd` (headless, `--fixed-fps 30`, `--noshots`). Each cell is the worst frame of the state: the number of the wearer's own skinned vertices inside the shield board (slab from 3 cm in front of the board's middle to 6 mm behind it, within its oval footprint). `fa` forearm, `ua` upper arm and shoulder, `hip` pelvis, `th` thighs and shins (all four from the new `sh_*` stats), `arm` upper-arm and forearm vertices on the face side (old `sh_arm`), `sh` any other body part in the slab (old `shield`). `before` is `--oldshield`. `.` is zero. Starting kit (Wayfarer's Blade, Splintered Heater `s_plank`), Gatehouse Round `s_round`, Tower `s_tower`, bodies m and f.

Totals (all 14 states, both bodies, per shield; before -> after):

- s_plank `sh_fa`: 246 -> 7
- s_plank `sh_ua`: 0 -> 0
- s_plank `sh_hip`: 0 -> 0
- s_plank `sh_th`: 279 -> 19
- s_plank `sh_arm`: 31 -> 0
- s_plank `shield`: 62 -> 0

- s_round `sh_fa`: 230 -> 0
- s_round `sh_ua`: 1 -> 0
- s_round `sh_hip`: 0 -> 0
- s_round `sh_th`: 312 -> 0
- s_round `sh_arm`: 3 -> 0
- s_round `shield`: 2 -> 0

- s_tower `sh_fa`: 186 -> 8
- s_tower `sh_ua`: 0 -> 0
- s_tower `sh_hip`: 0 -> 0
- s_tower `sh_th`: 273 -> 24
- s_tower `sh_arm`: 22 -> 0
- s_tower `shield`: 41 -> 0


## body m, s_plank

| state | before (fa ua hip th arm sh) | after (fa ua hip th arm sh) |
|---|---|---|
| guard | . . . . . . | . . . . . . |
| road | 2 . . 4 . . | . . . . . . |
| block | 9 . . . . . | . . . . . . |
| brace | 9 . . . . . | . . . . . . |
| cut_R | 9 . . . . . | . . . . . . |
| cut_L | 15 . . . . . | . . . . . . |
| cut_UR | 9 . . . . . | . . . . . . |
| cut_DL | 7 . . . . . | . . . . . . |
| cut_D | 8 . . . . . | . . . . . . |
| fin_Heavy | 9 . . . . . | . . . . . . |
| dodge_r | 8 . . 68 . . | . . . . . . |
| dodge_l | 8 . . . . . | . . . . . . |
| roll_r | 3 . . 69 . . | . . . . . . |
| roll_l | . . . 24 . . | . . . . . . |

## body m, s_round

| state | before (fa ua hip th arm sh) | after (fa ua hip th arm sh) |
|---|---|---|
| guard | . . . . . . | . . . . . . |
| road | . . . 3 . . | . . . . . . |
| block | 5 . . . . . | . . . . . . |
| brace | 5 . . . . . | . . . . . . |
| cut_R | 6 . . . . . | . . . . . . |
| cut_L | 12 . . . . . | . . . . . . |
| cut_UR | 6 . . . . . | . . . . . . |
| cut_DL | 2 . . . . . | . . . . . . |
| cut_D | 5 . . . . . | . . . . . . |
| fin_Heavy | 6 . . . . . | . . . . . . |
| dodge_r | 10 . . 89 . . | . . . . . . |
| dodge_l | 6 . . 75 . . | . . . . . . |
| roll_r | 10 1 . 18 1 2 | . . . . . . |
| roll_l | . . . 75 . . | . . . . . . |

## body m, s_tower

| state | before (fa ua hip th arm sh) | after (fa ua hip th arm sh) |
|---|---|---|
| guard | . . . . . . | . . . . . . |
| road | 3 . . 4 . . | . . . . . . |
| block | 10 . . . . . | . . . . . . |
| brace | 10 . . . . . | . . . . . . |
| cut_R | 11 . . . . . | . . . . . . |
| cut_L | 17 . . . . . | . . . . . . |
| cut_UR | 10 . . . . . | . . . . . . |
| cut_DL | 6 . . . . . | . . . . . . |
| cut_D | 8 . . . . . | . . . . . . |
| fin_Heavy | 12 . . . . . | . . . . . . |
| dodge_r | 10 . . 71 . . | . . . . . . |
| dodge_l | 10 . . . . . | . . . . . . |
| roll_r | 3 . . 53 . . | . . . . . . |
| roll_l | . . . 29 . . | . . . . . . |

## body f, s_plank

| state | before (fa ua hip th arm sh) | after (fa ua hip th arm sh) |
|---|---|---|
| guard | 10 . . . 1 . | . . . . . . |
| road | 11 . . 22 2 . | . . . 19 . . |
| block | 8 . . . . . | . . . . . . |
| brace | 8 . . . . . | . . . . . . |
| cut_R | 11 . . 4 4 . | 1 . . . . . |
| cut_L | 11 . . . 4 . | 3 . . . . . |
| cut_UR | 12 . . 4 4 . | 1 . . . . . |
| cut_DL | 12 . . . 4 . | 1 . . . . . |
| cut_D | 11 . . . 2 . | . . . . . . |
| fin_Heavy | 11 . . 5 4 . | 1 . . . . . |
| dodge_r | 12 . . 15 2 . | . . . . . . |
| dodge_l | 12 . . . 2 . | . . . . . . |
| roll_r | 11 . . 54 2 46 | . . . . . . |
| roll_l | 10 . . 10 . 16 | . . . . . . |

## body f, s_round

| state | before (fa ua hip th arm sh) | after (fa ua hip th arm sh) |
|---|---|---|
| guard | 9 . . . . . | . . . . . . |
| road | 12 . . 10 . . | . . . . . . |
| block | 10 . . . . . | . . . . . . |
| brace | 10 . . . . . | . . . . . . |
| cut_R | 12 . . . . . | . . . . . . |
| cut_L | 13 . . . 2 . | . . . . . . |
| cut_UR | 11 . . . . . | . . . . . . |
| cut_DL | 12 . . . . . | . . . . . . |
| cut_D | 11 . . . . . | . . . . . . |
| fin_Heavy | 12 . . . . . | . . . . . . |
| dodge_r | 11 . . 10 . . | . . . . . . |
| dodge_l | 12 . . 11 . . | . . . . . . |
| roll_r | 11 . . 10 . . | . . . . . . |
| roll_l | 11 . . 11 . . | . . . . . . |

## body f, s_tower

| state | before (fa ua hip th arm sh) | after (fa ua hip th arm sh) |
|---|---|---|
| guard | 4 . . . . . | . . . . . . |
| road | 4 . . 24 1 . | . . . 24 . . |
| block | 1 . . . . . | . . . . . . |
| brace | 1 . . . . . | . . . . . . |
| cut_R | 7 . . 2 3 . | 1 . . . . . |
| cut_L | 12 . . 1 3 . | 3 . . . . . |
| cut_UR | 7 . . 2 3 . | 1 . . . . . |
| cut_DL | 7 . . . 3 . | 1 . . . . . |
| cut_D | 4 . . . 1 . | 1 . . . . . |
| fin_Heavy | 7 . . 4 3 . | 1 . . . . . |
| dodge_r | 7 . . 33 1 . | . . . . . . |
| dodge_l | 7 . . . 2 . | . . . . . . |
| roll_r | 4 . . 36 2 26 | . . . . . . |
| roll_l | 4 . . 14 . 15 | . . . . . . |
