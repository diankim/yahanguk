import glob
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

REALMS = [
    ('pado', '파도너울성', ['pado'], ['coconut_fiber', 'blue_salt', 'kelp_scale_shell']),
    ('bulssi', '불씨들녘', ['bulssi'], ['volcanic_glass', 'chili_seed_oil', 'cold_ember_filings']),
    ('jaebit', '잿빛그늘숲', ['jaebit'], ['fragrant_blade_leaf', 'turmeric_root', 'inkrain_bark']),
    ('nunmaru', '눈마루', ['nunmaru'], ['ice_salt', 'highland_barley', 'yak_wool']),
    ('dalmaji', '달맞이성', ['dalmaji', 'goimteo'], ['red_spice_pod', 'bamboo_shoot_husk', 'pooled_light_shard']),
    ('haeoreum', '해오름성', ['haeoreum'], ['lotus_seed', 'palm_sugar', 'dawn_scale']),
]
STAGES = [(1, '길손', 0), (2, '손님', 300), (3, '이웃', 800), (4, '벗', 1600), (5, '한식구', 3000)]
GAIN = dict(request=20, win=1, explore=0.3, gather=0.3, exp_min=20, exp_max=24, trade_gil=100, donate_gil=50)
DAY = dict(realm=120, all=300)
PERKS = {'2': {'shop_pct': -5}, '3': {'gather_qty_pct': 5}, '4': {'travel_pct': -8}, '5': {'healing_pct': 10, 'rescue_half': 1}}
SAFE_ONLY = ['healing_pct']
PERK_TEXT = {'2': '그 권역 상점 값 −5%', '3': '그 권역 채집량 +5%', '4': '그 권역 안 이동 −8%', '5': '그 권역 안전지대 휴식 회복 +10% · 쓰러지면 그 권역 구조대 반값'}
REQ_N = 3
DELIVER_N = 5
TRADE_BASE = 300
VAULT = [
    ('title', 'rb_{k}_guest', 2, 150, '{n}의 손님', True),
    ('item', 'of_top_rb_{k}', 3, 200, '{n} 윗옷', True),
    ('item', 'of_bottom_rb_{k}', 3, 200, '{n} 아랫옷', True),
    ('item', 'hf_rb_{k}_1', 3, 150, '{n} 가구 하나', True),
    ('item', 'hf_rb_{k}_2', 3, 150, '{n} 가구 둘', True),
    ('name_style', 'ns:rb_{k}', 4, 350, '{n} 이름 색', False),
    ('mount', 'rb_mount_{k}', 5, 600, '{n} 탈것', True),
    ('cosmetic', 'pt_rb_{k}', 5, 300, '{n} 바탕 무늬', True),
    ('cosmetic', 'sl_rb_{k}', 5, 300, '{n} 낙관', True),
]
QUEST_LV = 50
OPEN_AFTER = {'pado': 'hwq_3', 'bulssi': 'hwq_7', 'jaebit': 'hwq_8', 'nunmaru': 'hwq_8', 'dalmaji': 'hwq_9', 'haeoreum': 'hwq_14'}
SPEAKER_LIKE = re.compile(r'^[가-힣A-Za-z0-9 ·]{1,24}\s?[:：]')
TITLE_CAT = '권역 인연'
QUEST_CAT = '권역 인연·'


def rules(R, ports):
    regions, realms = {}, {}
    for k, nm, terrs, specials in REALMS:
        mine = [r for r in R if r['terr'] in terrs]
        for r in mine:
            regions[r['id']] = k
        realms[k] = dict(name=nm, terrs=terrs, hubs=[r['id'] for r in mine if r.get('safe')], regions=[r['id'] for r in mine if not r.get('safe')],
                         ports=[p for p in ports if p in regions and regions[p] == k], specials=specials)
    reqs = {}
    for k, v in realms.items():
        r = v['regions']
        ls = [dict(key='hunt', title='권역 토벌', tasks=[dict(t='win', n=4, r=r)]),
              dict(key='gather', title='권역 채집', tasks=[dict(t='gather', n=4, r=r)]),
              dict(key='deliver', title='특산 납품', tasks=[], pick=v['specials'], give_n=DELIVER_N),
              dict(key='exped', title='권역 원정', tasks=[dict(t='expedition', n=1, r=r)])]
        if v['ports']:
            ls.append(dict(key='trade', title='항구 교역', tasks=[dict(t='tradesale', n=TRADE_BASE, r=v['ports'], by='gil')]))
        reqs[k] = ls
    vault = []
    for k, nm, _, _ in REALMS:
        for o, (kind, iid, st, price, label, ready) in enumerate(VAULT):
            vault.append(dict(id=iid.format(k=k), realm=k, kind=kind, stage=st, price=price, name=label.format(n=nm), ready=ready, sort=o + 1))
    titles = []
    for k, nm, _, _ in REALMS:
        titles.append(dict(key=f'rb_{k}_kin', name=f'{nm}의 한식구', grade=3, rule=dict(realm_bond='stage', realm=k, n=5),
                           desc=f'{nm} 사람들이 집안 식구처럼 맞아 줍니다.', cond=f'{nm} 권역 인연 5단계(한식구)에 닿는다'))
    titles.append(dict(key='rb_all_neighbor', name='건넛누리의 이웃', grade=3, rule=dict(realm_bond='realms', stage=3, n=6),
                       desc='건넛누리 여섯 권역 어디를 가도 아는 얼굴이 있습니다.', cond='여섯 권역 모두 권역 인연 3단계(이웃)에 닿는다'))
    titles.append(dict(key='rb_all_kin', name='한울땅 한식구', grade=4, rule=dict(realm_bond='realms', stage=5, n=6),
                       desc='건넛누리 여섯 권역이 모두 제 집처럼 문을 열어 줍니다.', cond='여섯 권역 모두 권역 인연 5단계(한식구)에 닿는다'))
    quests = {f'rb_{k}_{s}': [k, s] for k, _, _, _ in REALMS for s in range(2, 6)}
    if set(OPEN_AFTER) != {k for k, _, _, _ in REALMS}:
        raise SystemExit('OPEN_AFTER 권역이 REALMS와 다름')
    return dict(realms=realms, order=[k for k, _, _, _ in REALMS], regions=regions,
                stages=[dict(n=n, name=nm, need=need) for n, nm, need in STAGES], gain=GAIN, day=DAY,
                perks=PERKS, safe_only=SAFE_ONLY, perk_text=PERK_TEXT, requests=dict(n=REQ_N, list=reqs),
                vault=vault, vault_titles=[dict(key=v['id'], name=v['name'], realm=v['realm']) for v in vault if v['kind'] == 'title'],
                titles=titles, title_cat=TITLE_CAT, quests=quests, quest_cat=QUEST_CAT, quest_lv=QUEST_LV)


def npc_key(name):
    return 'q:rb_' + hashlib.md5(name.encode()).hexdigest()[:6]


def parse_script(path, k, SQ, errors):
    text = open(path, encoding='utf-8').read()
    npcs, quests = {}, []
    sec = None
    cur = None
    for raw in text.splitlines():
        line = raw.rstrip()
        m = re.match(r'^##\s+(rb_[a-z]+_[2-5])\s*[·|:\-]\s*(.+)$', line)
        if m:
            cur = dict(id=m.group(1), title=m.group(2).strip(), summary='', steps=[])
            quests.append(cur)
            sec = 'quest'
            continue
        if re.match(r'^##\s*인물', line):
            sec, cur = 'npc', None
            continue
        if sec == 'npc':
            if line.startswith('#'):
                sec = None
                continue
            mm = re.match(r'^-\s*([^:]+):\s*(.+)$', line.strip())
            if mm:
                npcs[mm.group(1).strip()] = mm.group(2).strip()
            continue
        if cur is None:
            continue
        mm = re.match(r'^###\s+(?:장면\s*)?(\d+)\s*[·|:\-]\s*(.+)$', line)
        if mm:
            cur['steps'].append(dict(title=mm.group(2).strip(), need={}, text=[]))
            continue
        if line.startswith('요약:') and not cur['steps']:
            cur['summary'] = line[3:].strip()
            continue
        if line.startswith('need:') and cur['steps']:
            try:
                cur['steps'][-1]['need'] = json.loads(line[5:].strip())
            except ValueError:
                errors.append(f'권역 이야기 {cur["id"]} need JSON 오류')
            continue
        if cur['steps']:
            cur['steps'][-1]['text'].append(line)
    for q in quests:
        if not q['id'].startswith(f'rb_{k}_'):
            errors.append(f'권역 이야기 {q["id"]}: 파일 권역({k})과 다름')
        if not q['steps']:
            errors.append(f'권역 이야기 {q["id"]}: 장면 없음')
    return npcs, quests


def quests_sql(RB, SQ, J, TA, known, RID, xp_need, fresh, errors):
    files = sorted(glob.glob(os.path.join(HERE, 'script_*.md')))
    if not files:
        return '', 0, 0
    npcs, quests = {}, []
    for f in files:
        k = os.path.basename(f)[7:-3]
        if k not in RB['realms']:
            errors.append(f'권역 이야기 파일 이름이 권역 키가 아님: {os.path.basename(f)}')
            continue
        n, qs = parse_script(f, k, SQ, errors)
        npcs.update(n)
        quests += qs
    import data_trade as TD
    PORTS = {p[0] for p in TD.PORTS}
    GOODS = {g[0] for g in TD.GOODS}
    miss = sorted(set(RB['quests']) - {q['id'] for q in quests})
    if miss:
        errors.append('권역 이야기 빠짐: ' + ', '.join(miss))
    speakers = {n: SQ.npc_key(n) for n in SQ.NPC}
    speakers.update({n: npc_key(n) for n in npcs})
    fresh('npcs', list(npcs), '인물')
    fresh('quest_ids', [q['id'] for q in quests], '퀘스트 id')
    qrows, srows = [], []
    L = RB['quest_lv']
    for i, q in enumerate(sorted(quests, key=lambda x: x['id'])):
        k, s = RB['quests'][q['id']]
        rv = RB['realms'][k]
        hub = rv['hubs'][0]
        steps = []
        for j, st in enumerate(q['steps']):
            lines, task = SQ.lines_of('\n'.join(st['text']), speakers)
            if j + 1 < len(q['steps']) and not task:
                errors.append(f"권역 이야기 {q['id']} 장면 {j + 1}: 할 일 줄 없음")
            if j > 0 and not st['need'].get('tasks') and not st['need'].get('give'):
                errors.append(f"권역 이야기 {q['id']} 장면 {j + 1}: need에 할 일이 없음")
            for ln in lines:
                if ln['s'] is None and SPEAKER_LIKE.match(ln['t']):
                    errors.append(f"권역 이야기 {q['id']} 장면 {j + 1}: 말하는 이로 안 잡힌 줄 — {ln['t'][:24]}")
                if ln['s'] is None and ln['t'][:3] in ('그런데', '그러나', '그러자', '그리고', '하지만'):
                    errors.append(f"권역 이야기 {q['id']} 장면 {j + 1}: 서술 첫머리 접속사")
                if any(x in ln['t'] for x in ('형님', '누님', '라는 것이었다', '라고 일렀다', '라고 일러')):
                    errors.append(f"권역 이야기 {q['id']} 장면 {j + 1}: 금지 표현 — {ln['t'][:20]}")
            for t in st['need'].get('tasks', []):
                for rg in t.get('r', []):
                    if rg not in RID:
                        errors.append(f"권역 이야기 {q['id']} 지역 없음: {rg}")
                if t.get('t') in ('tradesale', 'hfeast', 'lantern'):
                    for rg in t.get('r', []):
                        if rg not in PORTS:
                            errors.append(f"권역 이야기 {q['id']} {t['t']} 항구 아님: {rg}")
                if t.get('t') in ('tradesale', 'hfeast', 'lantern') and not isinstance(t.get('n'), int):
                    errors.append(f"권역 이야기 {q['id']} {t['t']} n이 개수(정수)가 아님")
                for it in t.get('items', []):
                    if t.get('t') == 'tradesale':
                        if it not in GOODS:
                            errors.append(f"권역 이야기 {q['id']} 교역품 없음: {it}")
                        continue
                    if it not in known:
                        errors.append(f"권역 이야기 {q['id']} 물품 없음: {it}")
            for it in st['need'].get('give', {}):
                if it not in known:
                    errors.append(f"권역 이야기 {q['id']} 넘길 물품 없음: {it}")
            steps.append(dict(step=j + 1, title=st['title'], goal=st['title'], need=st['need'], lines=lines))
        task_steps = [x['step'] for x in steps if x['need'].get('tasks') or x['need'].get('give')]
        per = round(0.4 * xp_need(L) * 0.25) // max(1, len(task_steps))
        need = next(x['need'] for x in RB['stages'] if x['n'] == s)
        qrows.append(dict(quest_id=q['id'], cat=RB['quest_cat'] + rv['name'], title=q['title'], summary=q['summary'], region_id=hub, min_level=L,
                          after=[OPEN_AFTER[k]] + ([f'rb_{k}_{s - 1}'] if s > 2 else []), sort=3900 + i, epilogue=[], open_req={'realm_bond': k, 'pts': need}))
        for x in steps:
            rw = {'xp': per} if x['step'] in task_steps else {}
            if x['step'] == len(steps):
                rw['gil'] = 5 + 4 * L
            srows.append(dict(quest_id=q['id'], step=x['step'], title=x['title'], goal=x['goal'], need=x['need'], lines=x['lines'], reward=rw))
    out = []
    if npcs:
        rows = [dict(npc_key=speakers[n], npc_name=n, bio=b) for n, b in npcs.items()]
        out.append(f"""insert into public.world_quest_npcs(npc_key, npc_name, bio) select x.npc_key, x.npc_name, x.bio from jsonb_to_recordset({J(rows)}) as x(npc_key text, npc_name text, bio text)
on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio;""")
    out.append(f"""insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, sort, epilogue, active, open_req)
select x.quest_id, 'side', x.cat, x.title, x.summary, x.region_id, x.min_level, {TA('after')}, x.sort, x.epilogue, true, x.open_req
from jsonb_to_recordset({J(qrows)}) as x(quest_id text, cat text, title text, summary text, region_id text, min_level int, after jsonb, sort int, epilogue jsonb, open_req jsonb)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level,
  after = excluded.after, sort = excluded.sort, epilogue = excluded.epilogue, active = excluded.active, open_req = excluded.open_req;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward)
select x.quest_id, x.step, x.title, x.goal, x.need, x.lines, x.reward from jsonb_to_recordset({J(srows)}) as x(quest_id text, step int, title text, goal text, need jsonb, lines jsonb, reward jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;""")
    return '\n'.join(out), len(qrows), len(srows)


def emit(R, ports, SQ, J, TA, known, RID, xp_need, fresh, errors):
    RB = rules(R, ports)
    for k, v in RB['realms'].items():
        if not v['hubs']:
            errors.append(f'권역 {k}: 안전지대 없음')
        for it in v['specials']:
            if it not in known:
                errors.append(f'권역 {k}: 특산 재료 없음 {it}')
    fresh('titles', [t['name'] for t in RB['titles']] + [t['name'] for t in RB['vault_titles']], '칭호')
    fresh('title_keys', [t['key'] for t in RB['titles']] + [t['key'] for t in RB['vault_titles']], '칭호 키')
    out = [f"""create or replace function public.world_realm_bond_rules() returns jsonb language sql immutable set search_path to '' as $f$ select {J(RB)} $f$;
revoke all on function public.world_realm_bond_rules() from public, anon;
grant execute on function public.world_realm_bond_rules() to authenticated, service_role, postgres;
do $$ declare x text; begin
  for x in select rolname from pg_roles where rolname like 'fn\\_owner%' loop
    execute format('grant execute on function public.world_realm_bond_rules() to %I', x);
  end loop;
end $$;"""]
    for f in ('b_tables.sql', 'c_funcs.sql', 'd_hooks.sql'):
        out.append(open(os.path.join(HERE, f), encoding='utf-8').read())
    qs, nq, ns = quests_sql(RB, SQ, J, TA, known, RID, xp_need, fresh, errors)
    if qs:
        out.append(qs)
    import outfits_rb
    osql, no = outfits_rb.emit(RB, J, errors)
    out.append(osql)
    sys.stderr.write(f"권역 인연: 권역 {len(RB['realms'])} · 칭호 {len(RB['titles'])}+비고 {len(RB['vault_titles'])} · 비고 품목 {len(RB['vault'])} · 옷 {no} · 이야기 {nq}편 {ns}장면\n")
    return '\n'.join(out)
