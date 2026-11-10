#!/usr/bin/env python3
"""화면·도움말이 쓰는 수치를 서버 DB에서 읽어 assets/js/gamedata.js로 쓴다.

손으로 옮겨 적던 수(동무 수·직업 기본 능력치·협동 기술·세력 가입 장소 등)가
새 콘텐츠를 넣을 때마다 어긋나지 않게, 이 파일 하나로 다시 만든다.

    python3 tools/gamedata/gen.py                       # 로컬 복제 DB(기본값)
    python3 tools/gamedata/gen.py --dsn "postgresql://…"  # 다른 DB(읽기 전용 SELECT만 한다)

psql이 PATH에 있어야 한다. 기본 접속은 로컬 복제 DB
(host /var/tmp/yhpg, port 5433, user postgres, db yh_play)이고,
YH_GAMEDATA_DSN 환경 변수로도 바꿀 수 있다. SELECT만 하므로 운영 DB에도 안전하지만
복제 DB에서 돌리는 것을 기본으로 한다.
"""
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets' / 'js' / 'gamedata.js'
JOB_KEYS = ['artificer', 'scout', 'exorcist', 'medic', 'sealmaster', 'analyst']
FACTION_KEYS = ['night_office', 'red_moon_cult', 'black_lotus', 'north_league',
                'river_alliance', 'southern_remnant', 'mandate_court']
HOSTILE_AT = -40  # world_faction_stance: base −40 이하 = 적대


def q(dsn, sql):
    """SQL 하나를 돌려 JSON 한 값으로 받는다."""
    cmd = ['psql', '-X', '-At', '-v', 'ON_ERROR_STOP=1']
    cmd += [dsn] if dsn.startswith('postgres') else dsn.split()
    cmd += ['-c', 'set transaction read only; ' + sql]
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode:
        sys.exit(f'psql 실패: {out.stderr.strip()}\n{sql}')
    lines = [l for l in out.stdout.splitlines() if l.strip() and l.strip() != 'SET']
    return json.loads(lines[-1])


def jarr(keys):
    return 'array[' + ','.join(f"'{k}'" for k in keys) + ']'


def build(dsn):
    d = {}
    # 꼬마 동무: 등급별 종 수
    g = q(dsn, "select json_object_agg(grade, n) from (select grade, count(*) n from world_pet_species group by 1) x")
    d['pets'] = {'total': sum(g.values()), 'grades': {int(k): v for k, v in sorted(g.items())}}
    d['kinds'] = q(dsn, "select json_object_agg(kind_key, kind_name order by sort) from world_monster_kinds")
    # 직업: 기본 능력치(world_job_base) · 혼자 도전 보정(world_solo_aid)
    d['jobBase'] = q(dsn, f"select json_object_agg(j, world_job_base(j)) from unnest({jarr(JOB_KEYS)}) j")
    d['soloAid'] = q(dsn, f"select json_object_agg(j, world_solo_aid(j)) from unnest({jarr(JOB_KEYS)}) j")
    # 협동 기술(world_coop_skills)
    d['coop'] = q(dsn, """select json_agg(json_build_object('id', skill_id, 'job', job_key, 'rank', unlock_rank,
        'name', skill_name, 'desc', description, 'target', target, 'cost', cost, 'cd', cooldown_s)
        order by job_key, unlock_rank, sort) from world_coop_skills""")
    # 파티 원정 규칙 수치(world_pexp_rules: 함께 물러나는 체력·동료 한 명마다 위협·함께 다녀온 덤)
    d['partyExp'] = q(dsn, "select world_pexp_rules()")
    d['agile'] = q(dsn, "select world_agile_rules()")
    d['questXp'] = q(dsn, "select world_quest_xp_rules()")
    d['factionSpread'] = q(dsn, "select world_faction_spread_rules()")
    d['factionPerk'] = q(dsn, "select world_faction_perk_rules()")
    d['battleItems'] = q(dsn, "select world_battle_item_rules()")
    d['busy'] = q(dsn, "select world_busy_rules()")
    d['gwiryeong'] = q(dsn, "select world_gwiryeong_rules()")
    d['contrib'] = q(dsn, "select world_contrib_rules()")
    d['shadow'] = q(dsn, "select world_shadow_rules()")
    d['coopRules'] = q(dsn, "select world_coop_rules()")
    d['expXp'] = q(dsn, "select world_expedition_xp_rules()")
    d['idle'] = q(dsn, "select world_idle_rules()")
    d['rescue'] = q(dsn, "select world_rescue_rules()")
    d['rate'] = q(dsn, "select world_rate_rules()")
    d['weakSafe'] = q(dsn, "select world_weak_safe_rules()")
    d['fishRules'] = q(dsn, "select world_fish_rules()")
    d['names'] = q(dsn, "select world_name_rules()")
    d['jobSkills'] = q(dsn, "select jsonb_object_agg(k, jsonb_build_object('name', v ->> 'name', 'desc', v ->> 'desc')) from jsonb_each(world_job_skill_rules()) e(k, v)")
    # 대세력: 가입 받는 곳·세력 안전지대·관계 기준값
    d['factionJoin'] = q(dsn, f"select json_object_agg(f, world_faction_join_regions(f)) from unnest({jarr(FACTION_KEYS)}) f")
    d['factionHome'] = q(dsn, f"select json_object_agg(f, world_faction_home(f)) from unnest({jarr(FACTION_KEYS)}) f")
    rel = q(dsn, "select json_agg(json_build_array(faction_a, faction_b, base) order by faction_a, faction_b) from world_faction_relations")
    d['factionRel'] = [[a, b, float(v)] for a, b, v in rel]
    hostile = {f: [] for f in FACTION_KEYS}
    for a, b, v in d['factionRel']:
        if v <= HOSTILE_AT:
            hostile.setdefault(a, []).append(b)
            hostile.setdefault(b, []).append(a)
    d['factionHostile'] = {f: sorted(set(v), key=FACTION_KEYS.index) for f, v in hostile.items()}
    ids = sorted({r for v in list(d['factionJoin'].values()) + list(d['factionHome'].values()) for r in v})
    d['regionNames'] = q(dsn, f"select json_object_agg(region_id, region_name) from world_map_regions where region_id = any({jarr(ids)})")
    # 가방·창고 칸
    bag = q(dsn, "select to_json(column_default) from information_schema.columns where table_schema = 'public' and table_name = 'world_characters' and column_name = 'bag_capacity'")
    src = q(dsn, "select to_json(prosrc) from pg_proc where proname = 'world_storage_capacity'")
    base = int(re.search(r"'base',\s*(\d+)", src).group(1))
    prices = [int(x) for x in re.search(r"array\[([\d,\s]+)\]\)\[b\.n", src).group(1).split(',')]
    late = q(dsn, "select count(*) from world_story_chapters where seq between 6 and 10")
    # 전 넓히기 단계마다 +4 · 이야기 6~10장 +2씩 · 평판 300/600/1000 +2씩 · 완전 답사 10/20/30곳 +2씩
    d['bag'] = {'base': int(re.match(r'\d+', bag).group(0))}
    d['storage'] = {'base': base, 'max': base + 4 * len(prices) + 2 * late + 6 + 6, 'prices': prices}
    # 칭호 수
    t = q(dsn, """select json_build_object('total', count(*), 'public', count(*) filter (where not hidden),
        'skill', count(*) filter (where title_key ~ '^(ct|gt)_'),
        'cat', (select json_object_agg(category, n) from (select category, count(*) n from world_title_catalog
                 where active and category is not null group by 1) c)) from world_title_catalog where active""")
    d['titles'] = t
    # 낚시: 어종·낚시터
    d['fish'] = q(dsn, "select json_build_object('species', (select count(*) from world_fish_species where active), 'grounds', (select count(*) from world_fish_grounds))")
    return d


def write(d):
    def dump(v):
        return json.dumps(v, ensure_ascii=False, separators=(',', ':'))

    def entry(k, v):
        if isinstance(v, list) and v and isinstance(v[0], dict):  # 목록은 한 줄에 하나
            return f'  {dump(k)}: [\n' + ',\n'.join('    ' + dump(x) for x in v) + '\n  ]'
        if isinstance(v, dict) and all(isinstance(x, (dict, list)) for x in v.values()):  # 키마다 한 줄
            return f'  {dump(k)}: {{\n' + ',\n'.join(f'    {dump(a)}: {dump(b)}' for a, b in v.items()) + '\n  }'
        return f'  {dump(k)}: {dump(v)}'
    body = '{\n' + ',\n'.join(entry(k, v) for k, v in d.items()) + '\n}'
    OUT.write_text(
        f'export const GAMEDATA = {body};\n'
        'export default GAMEDATA;\n', encoding='utf-8')
    print(f'{OUT.relative_to(ROOT)} 씀: 동무 {d["pets"]["total"]}종 · 협동 기술 {len(d["coop"])} · 칭호 {d["titles"]["total"]} · 어종 {d["fish"]["species"]}')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--dsn', default=os.environ.get('YH_GAMEDATA_DSN', '-h /var/tmp/yhpg -p 5433 -U postgres -d yh_play'))
    write(build(ap.parse_args().dsn))
