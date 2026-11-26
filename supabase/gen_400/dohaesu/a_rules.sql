lock table public.world_characters in access exclusive mode;

do $$
begin
  execute format('create or replace function public.world_boss_rules() returns jsonb language sql immutable set search_path = '''' as $f$ select %L::jsonb $f$',
    (public.world_boss_rules() - 'dohaesu') || jsonb_build_object('dohaesu', $j${
  "name": "도해수", "fight": "뒤집힌 물목", "place": "뒤집힌 물목", "arc": "도해록", "region": "pd_rift", "lv": 51,
  "quest": "hwq_5", "quest_name": "본편 「도해록」 5장", "item": "kelp_scale_shell", "item_name": "해초 비늘 껍질", "item_where": "뒤집힌 물목에서 채집해 얻습니다.",
  "min": 18, "hp_min": 9000, "hp_n": [1, 1, 1, 1], "raw_n": [0.6, 0.7, 0.8, 0.85], "raw": [32, 3], "enrage": 0.25,
  "first": {"gil": 3000, "xp": 0.5}, "again": {"gil": 180, "xp": 0.05}, "fail": {"dur": 10, "er": 10, "cd": 30}, "falls": 10, "xp_cap_lv": 55,
  "hard_quest": "hwq_5", "hard_quest_name": "본편 「도해록」 5장",
  "modes": {"story": "이야기판", "hard": "깊은 물목"},
  "phases": ["해류", "물보라", "뒤집힌 물살", "틈의 숨"],
  "mech_names": {"thrash": "몸부림", "current": "해류", "surge": "해류 뒤집힘", "spray": "물보라 덮침", "tentacle": "촉수 감기", "whirl": "소용돌이 기둥", "wet": "젖은 몸", "breath": "틈의 숨", "head": "머리 들기"},
  "dps": {"ref": {"analyst": 584, "spearman": 525, "exorcist": 495, "formation": 495, "medic": 494, "sealmaster": 494, "scout": 480, "tamer": 480, "bloodknight": 447, "artificer": 422},
    "hp_k": 155, "cuts": [40, 80, 120], "cut_enrage": 1, "spec": "Lv55 · 9단계 무기 +10 · 9단계 방어구 한 벌"},
  "story": {"phases": ["해류", "물보라", "몸부림", "틈의 숨"], "min": 30, "round_s": 60, "hp_min": 2400, "hp_k": 8, "raw": [12, 2], "first": {"gil": 1200},
    "board": {"mech_mul": 1, "fall_hp": 40,
      "current": {"every": 3, "off": 1, "left": 2},
      "spray": {"every": 4, "off": 2, "left": 3, "cells": 2, "raw": 14},
      "head": {"every": 6, "off": 5, "left": 3, "hit_pct": 3},
      "seq": [{"at": 100, "m": ["current"]}, {"at": 66, "m": ["current", "spray"]}, {"at": 33, "m": ["current", "spray", "head"]}]}},
  "board": {
    "rift": [6, 7, 10, 11], "rift_hurt": 20, "start": [1, 4, 13, 16], "corner": [1, 4, 16, 13],
    "mech_mul": 0.45, "fall_hp": null, "aoe_every": 4,
    "current": {"every": 3, "off": 1, "left": 2},
    "surge": {"every": 6, "off": 4, "left": 2, "push": 2},
    "spray": {"every": 4, "off": 2, "left": 3, "cells": 3, "raw": 40},
    "tentacle": {"every": 6, "off": 3, "left": 3, "dist": 4, "raw": 45},
    "whirl": {"every": 5, "off": 0, "life": 4, "raw": 20},
    "wet": {"max": 3, "extra_at": 3},
    "head": {"every": 5, "off": 3, "left": 3, "hit_pct": 4, "stun": 2, "stun_pct": 30},
    "breath": {"every": 6, "off": 5, "left": 4, "pull": 1},
    "seq": [{"at": 100, "m": ["current", "thrash", "head"]}, {"at": 87.5, "m": ["current", "thrash", "head", "spray"]}, {"at": 75, "m": ["current", "head", "surge", "tentacle", "spray"]},
      {"at": 50, "m": ["current", "thrash", "head", "spray", "tentacle", "whirl"]}, {"at": 37.5, "m": ["current", "head", "surge", "spray", "tentacle", "wet", "whirl"]},
      {"at": 25, "m": ["current", "head", "breath", "surge", "spray", "tentacle", "wet", "whirl"]}],
    "low_pct": 10},
  "solo": {"artificer": {"solo_dmg": -25, "solo_guard": -24}, "scout": {"solo_dmg": -25, "solo_guard": -15}, "exorcist": {"solo_dmg": -26, "solo_guard": -16},
    "medic": {"solo_dmg": 20, "solo_guard": -55}, "sealmaster": {"solo_dmg": -28, "solo_guard": -10}, "analyst": {"solo_dmg": -25, "solo_guard": -36},
    "tamer": {"solo_dmg": -25, "solo_guard": 0}, "bloodknight": {"solo_dmg": -25, "solo_guard": -24}, "spearman": {"solo_dmg": -25, "solo_guard": -30}, "formation": {"solo_dmg": -20, "solo_guard": -40}}
}$j$::jsonb));
end $$;
