lock table public.world_characters in access exclusive mode;

do $$
begin
  execute format('create or replace function public.world_boss_rules() returns jsonb language sql immutable set search_path = '''' as $f$ select %L::jsonb $f$',
    (public.world_boss_rules() - 'ttangul') || jsonb_build_object('ttangul', $j${
  "name": "땅울이", "fight": "울리는 고임터", "place": "고임터", "arc": "도해록", "region": "dm_pool", "lv": 55,
  "quest": "hwq_13", "quest_name": "본편 「도해록」 13장", "item": "pooled_light_shard", "item_name": "고인 빛 부스러기", "item_where": "고임터에서 채집해 얻습니다.",
  "min": 18, "hp_min": 9000, "hp_n": [1, 1.1, 1, 1], "raw_n": [0.6, 0.91, 0.8, 0.85], "raw": [34, 3], "enrage": 0.25,
  "first": {"gil": 3500, "xp": 0.5}, "again": {"gil": 200, "xp": 0.05}, "fail": {"dur": 10, "er": 10, "cd": 30}, "falls": 10, "xp_cap_lv": 55,
  "hard_quest": "hwq_13", "hard_quest_name": "본편 「도해록」 13장",
  "hard_min": 2, "modes": {"story": "이야기판", "hard": "깊은 고임터"},
  "phases": ["땅울음", "산사태", "끌개", "판 깎기"],
  "mech_names": {"thrash": "땅울음", "slide": "산사태 밀기", "weight": "땅의 무게", "pull": "끌개", "wedge": "쐐기돌", "fist": "돌주먹", "boulder": "굴러오는 바위", "shave": "판 깎기", "final": "마지막 몸부림"},
  "dps": {"ref": {"analyst": 584, "spearman": 525, "exorcist": 495, "formation": 495, "medic": 494, "sealmaster": 494, "scout": 480, "tamer": 480, "bloodknight": 447, "artificer": 422},
    "hp_k": 75, "cuts": [21, 44, 66], "cut_enrage": 1, "spec": "Lv55 · 9단계 무기 +10 · 9단계 방어구 한 벌"},
  "story": {"phases": ["땅울음", "산사태", "땅울음과 산사태", "마지막 몸부림"], "min": 30, "round_s": 60, "hp_min": 2600, "hp_k": 9, "raw": [12, 2], "first": {"gil": 1200},
    "board": {"mech_mul": 1, "fall_hp": 40, "slide": {"every": 4, "off": 2, "left": 3, "push": 1, "raw": 14}, "final": {"rounds": 2},
      "seq": [{"at": 100, "m": ["thrash"]}, {"at": 66, "m": ["thrash", "slide"]}, {"at": 25, "m": ["slide", "shave"]}]}},
  "board": {
    "cells": [[0,-2],[1,-2],[2,-2],[-1,-1],[0,-1],[1,-1],[2,-1],[-2,0],[-1,0],[0,0],[1,0],[2,0],[-2,1],[-1,1],[0,1],[1,1],[-2,2],[-1,2],[0,2]],
    "center": 10, "start": [5, 9, 11, 15], "pulls": [3, 8, 12, 17],
    "mech_mul": 0.45, "fall_hp": null, "aoe_every": 4,
    "slide": {"every": 4, "off": 2, "left": 3, "push": 1, "raw": 30},
    "weight": {"every": 5, "off": 4, "left": 3, "cells": 3, "hole": 2, "perm_max": 3},
    "pull": {"every": 5, "left": 4, "heal_pct": 1, "stop": 6, "hit_mul": 6},
    "fist": {"every": 6, "off": 3, "left": 2, "raw": 80, "push": 1},
    "boulder": {"every": 5, "off": 1, "left": 3, "raw": 35, "push": 1},
    "shave": {"left": 3},
    "final": {"rounds": 3, "push": 1},
    "seq": [{"at": 100, "m": ["thrash"]}, {"at": 87.5, "m": ["thrash", "slide"]}, {"at": 75, "m": ["slide", "weight", "pull"]},
      {"at": 50, "m": ["slide", "weight", "pull", "fist", "boulder"]}, {"at": 37.5, "m": ["thrash", "slide", "weight", "pull", "fist", "boulder"]},
      {"at": 25, "m": ["shave", "slide", "fist", "boulder"]}],
    "low_pct": 10}
}$j$::jsonb));
end $$;
