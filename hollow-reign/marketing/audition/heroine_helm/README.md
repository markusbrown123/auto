# Female knight: original voice (Victoria) with helmet treatment (2026-11-27)
Owner: keep the original voice, add a helmet echo, maybe filtered like a space helmet. No generation: the shipped take w_talk_return_01_f.ogg run through three filter chains.
1. light: same helmet reflections as the male knight.
2. visor: narrower band, stronger close reflections.
3. spacehelm: comms-style band (260 Hz to 4.6 kHz), compression, close reflections plus a faint room.
Cost: nothing. Nobody has listened to these yet.

Final (owner chose "3 but slightly less"): applied to all 45 female knight lines (40 player, 5 Kept) in assets/audio/vo/; the chain is HELM_F in tools/voices.py. Originals kept in art/vo_masters/player_f_pre_helm/ (not in git). Listening copy: victoria_helm__FINAL_3_softer.mp3.
