#!/usr/bin/env python3
"""7.5.0 생산 기술 개편 마이그레이션 생성기.

원본: skills_draft.json(사용자 확정 시안 5, decisions_5가 최종) + 이 폴더의 f_*.sql·m_*.sql.
출력: ../migrations/20261104000000_world_7_5_0.sql
"""
import json, os, re

D = os.path.dirname(os.path.abspath(__file__))
S = json.load(open(os.path.join(D, 'skills_draft.json'), encoding='utf-8'))
OUT = os.path.join(D, '..', 'migrations', '20261104000000_world_7_5_0.sql')


def q(s):
    return "'" + str(s).replace("'", "''") + "'"


def jq(o):
    return q(json.dumps(o, ensure_ascii=False)) + '::jsonb'


def part(name):
    return open(os.path.join(D, name), encoding='utf-8').read()


CRAFT_LINES = ['smithing', 'carpentry', 'artifice', 'weaving', 'leatherwork', 'wardcraft', 'alchemy', 'cooking']
GATHER_LINES = ['foraging', 'mining', 'fishing']
# 지금 있는 기본 기술(3·8단계)의 id — 그대로 둔다
OLD_BASE = {
    ('smithing', 3): 'smithing_forge', ('smithing', 8): 'smithing_master',
    ('alchemy', 3): 'alchemy_mix', ('alchemy', 8): 'alchemy_potent',
    ('wardcraft', 3): 'wardcraft_fine', ('wardcraft', 8): 'wardcraft_master',
    ('foraging', 3): 'forage_select', ('foraging', 8): 'forage_preserve',
    ('mining', 3): 'mining_vein', ('mining', 8): 'mining_refine',
}
SLOT_LABEL = {'extra': '추가 기술', 'a': '택일 기술', 'b': '택일 기술', 'master': '숙달 기술'}


def sid(line, rank, slot):
    if slot == 'base':
        return OLD_BASE.get((line, rank), f'{line}_t{rank}')
    if slot == 'extra':
        return f'{line}_x{rank}'
    if slot in ('a', 'b'):
        return f'{line}_c{rank}{slot}'
    return f'{line}_m{rank}'


def clean(eff):
    """시안 설명에서 결정 과정 메모(「지금 …」 등 괄호)를 빼고 화면 설명으로."""
    t = eff
    t = re.sub(r'\s*\((?:지금|그대로|옛|약초|셋째|둘째|이름만)[^()]*(?:\([^()]*\)[^()]*)*\)', '', t)
    t = re.sub(r'\s*지금 「[^」]*」[^.]*\.?$', '', t)
    t = re.sub(r'\s*지금 「[^」]*」\([^)]*\)은 뺌\.?', '', t)
    t = t.strip()
    if t.endswith('.'):
        t = t[:-1]
    return t


def effect_of(line, s):
    """기본 기술 수치(passive_effect)."""
    if s['slot'] != 'base':
        return {}
    e = s['effect']
    out = {}
    if line in CRAFT_LINES:
        m = re.search(r'품질 \+(\d+)', e)
        if m:
            out['craft_quality'] = int(m.group(1))
    elif line in ('foraging', 'mining'):
        m = re.search(r'채집량 \+(\d+)%', e)
        if m:
            out['gather_qty_pct'] = int(m.group(1))
        m = re.search(r'희귀품 \+(\d+)%', e)
        if m:
            out['rare_loot_pct'] = int(m.group(1))
    elif line == 'fishing':
        m = re.search(r'입질 \+(\d+)%p', e)
        if m:
            out['fish_bite_pct'] = int(m.group(1))
        m = re.search(r'크기 \+(\d+)%', e)
        if m:
            out['fish_size_pct'] = int(m.group(1))
        m = re.search(r'희귀 어종 \+(\d+)%', e)
        if m:
            out['fish_rare_pct'] = int(m.group(1))
    if not out:
        raise SystemExit(f'수치를 못 읽음: {line} {s}')
    return out


# 설명을 손으로 고칠 것(시안 문구에 결정 메모가 섞인 것)
DESC_FIX = {
    'carpentry_c43b': '가구를 만들면 25% 확률로 재료 한 종류를 하나 돌려받는다(가구는 언제나 하나만 만든다)',
    'foraging_c43b': '약초 채집터에서 10% 확률로 농축 약초액, 영기 채집터에서 5% 확률로 응축 영핵 하나',
    'leatherwork_c43b': '가죽 공예로 만든 장비를 분해하면 돌려받는 재료 가운데 하나를 하나 더',
    'wardcraft_c24b': '부적(정화·회생 부적 같은 봉인 공예 소모품)을 만들면 만드는 개수 +25%(올림)',
    'wardcraft_c43b': '봉인 공예로 만든 장비를 분해하면 돌려받는 재료 가운데 하나를 하나 더',
}


def skill_rows():
    lines = {L['key']: L for L in S['lines']}
    for L in S['gathering']['lines']:
        lines[L['key']] = L
    rows = []
    for line in CRAFT_LINES + GATHER_LINES:
        L = lines[line]
        for s in L['skills']:
            i = sid(line, s['rank'], s['slot'])
            pe = effect_of(line, s)
            d = DESC_FIX.get(i) or clean(s['effect'])
            if s['slot'] != 'base':
                d = SLOT_LABEL[s['slot']] + ' · ' + d
            else:
                d = d + '.'
            rows.append(dict(skill_id=i, skill_name=s['name'], category=line, description=d, passive_effect=pe,
                             unlock_rank=s['rank'], slot=s['slot']))
    t = S['tracking_36']['skill']
    rows.append(dict(skill_id='tracking_x36', skill_name=t['name'], category='tracking',
                     description='추가 기술 · 위험도 7 이상 지역에서 탐색하거나 조사 지점을 살필 때 0.2% 확률로 귀령초 하나(한 번 얻으면 72시간 다시 나오지 않음)',
                     passive_effect={}, unlock_rank=36, slot='extra'))
    return rows


COMBOS = [
    # (id, 이름, requires, 설명)
    ('combo_analysis_spirit_gathering', '영맥 판독', {'analysis': 18, 'foraging': 18}, '조합 기술(분석·채집 둘 다 18단계) · 영기 채집터에서 거둔 채집터는 다시 쓰는 대기가 절반'),
    ('combo_first_aid_herbalism', '야전 약방', {'first_aid': 18, 'foraging': 18}, '조합 기술(응급 처치·채집 둘 다 18단계) · 약초를 쓰면 약초액만큼(체력 22) 회복'),
    ('combo_foraging_alchemy', '현장 조제', {'alchemy': 18, 'foraging': 18}, '조합 기술(채집·연금 둘 다 18단계) · 쉬기·야영 때 야령초 2개로 농축 약초액 하나를 저절로 만든다'),
    ('combo_guarding_mining', '바위 몸', {'mining': 18, 'guarding': 18}, '조합 기술(막기·채광 둘 다 18단계) · 방어한 턴에 받은 피해의 30%만큼 체력 회복'),
    ('combo_sealing_wardcraft', '겹봉인', {'sealing': 18, 'wardcraft': 18}, '조합 기술(봉인술·봉인 공예 둘 다 18단계) · 봉인술로 묶으면 2턴 동안 움직이지 못한다'),
    ('combo_mining_artifice', '영맥 세공', {'mining': 18, 'artifice': 18}, '조합 기술(채광·법구 공예 둘 다 18단계) · 유물 채집터에서 거두면 15% 확률로 하나 더'),
    ('combo_mining_leatherwork', '짐꾼의 요령', {'mining': 18, 'leatherwork': 18}, '조합 기술(채광·가죽 공예 둘 다 18단계) · 채집·채광 때 채집 도구가 닳지 않을 확률 50%'),
    ('combo_fishing_weaving', '그물 짓기', {'fishing': 18, 'weaving': 18}, '조합 기술(낚시·직조 둘 다 18단계) · 낚을 때 10% 확률로 같은 어종 하나 더(「두 마리」와 따로 굴리되 한 번에 하나만 더)'),
    ('combo_fishing_cooking', '갯가 주방', {'fishing': 18, 'cooking': 18}, '조합 기술(낚시·요리 둘 다 18단계) · 물고기를 낚으면 20% 확률로 손질한 생선 하나를 함께 얻는다'),
    ('combo_fishing_carpentry', '낚싯대 깎는 손', {'fishing': 18, 'carpentry': 18}, '조합 기술(낚시·목공 둘 다 18단계) · 낚싯대 단계 덤(입질 단계마다 +6%p·희귀 +3%)을 3단계까지 받는다'),
]

TITLE_DESC = {
    'ct_smithing_15': '쇳물의 빛깔로 온도를 읽는다.', 'ct_smithing_35': '백 번을 접어 두드린 쇠는 휘지 않는다.', 'ct_smithing_50': '이 손이 두드린 쇠는 이름을 얻는다.',
    'ct_carpentry_15': '나뭇결을 거스르지 않는다.', 'ct_carpentry_35': '못 하나 없이 집을 세운다.', 'ct_carpentry_50': '천 년 묵은 나무도 이 손에서 다시 산다.',
    'ct_artifice_15': '방울 하나에도 영문을 새긴다.', 'ct_artifice_35': '하늘의 길을 법구에 옮긴다.', 'ct_artifice_50': '만든 법구가 스스로 운다.',
    'ct_weaving_15': '씨실과 날실이 어긋나지 않는다.', 'ct_weaving_35': '비단 한 필이 한 해 농사 값이다.', 'ct_weaving_50': '바늘땀이 보이지 않는 옷을 짓는다.',
    'ct_leatherwork_15': '가죽이 손에서 부드러워진다.', 'ct_leatherwork_35': '가벼운 경갑이 쇠보다 질기다.', 'ct_leatherwork_50': '야행국의 발은 모두 이 손을 거쳤다.',
    'ct_wardcraft_15': '획 하나 떨리지 않는 부적.', 'ct_wardcraft_35': '결계의 줄기를 미리 그린다.', 'ct_wardcraft_50': '먹 한 방울에 만 가지 법이 담긴다.',
    'ct_alchemy_15': '약탕관의 불을 끄지 않는다.', 'ct_alchemy_35': '아홉 번 달여 한 알을 빚는다.', 'ct_alchemy_50': '금빛 단약이 이 손에서 났다.',
    'ct_cooking_15': '간을 보면 사람을 안다.', 'ct_cooking_35': '수라간에 서도 부끄럽지 않다.', 'ct_cooking_50': '팔도의 밥상이 이 솥에서 났다.',
    'gt_foraging_25': '산과 들이 내어 줄 때를 안다.', 'gt_foraging_50': '거둔 것이 산을 이룬다.',
    'gt_mining_25': '돌 속의 맥을 손끝으로 짚는다.', 'gt_mining_50': '땅의 맥이 길을 내어 준다.',
    'gt_fishing_25': '찌가 움직이기 전에 안다.', 'gt_fishing_50': '용왕이 벗이라 부른다.',
    'ct_all_50': '여덟 갈래 손재주를 끝까지 닦았다.', 'gt_all_50': '산과 땅과 물을 모두 거두었다.',
}


def title_rows():
    rows = []
    for i, t in enumerate(S['titles']['list']):
        kind = t['kind']
        cat = '성장' if '전 계열' in kind else ('제작' if kind.startswith('제작') else '채집')
        icon = 'hammer' if kind.startswith('제작') else 'leaf'
        if t['id'] in ('ct_all_50', 'gt_all_50'):
            icon = 'spark'
        rows.append(dict(title_key=t['id'], title_name=t['name'], icon=icon, description=TITLE_DESC[t['id']],
                         condition_text=t['condition'], bonus=t['bonus'], rule=t['rule'], sort=300 + i, category=cat, grade=t['grade']))
    return rows


def supply_rows():
    sup = S['quality']['supply']
    m = {}
    for r in sup['consumables'] + sup['materials']:
        m[r['recipe']] = r['new_base']
    m['synth_spirit_core'] = 3  # decisions_5
    m['tonic_recipe'] = 2       # decisions_5
    return m


def main():
    o = []
    w = o.append
    w("""-- 7.5.0 생산 기술 개편(생성기 supabase/gen750/gen.py — 이 파일을 손으로 고치지 말고 생성기를 고친다)
-- 제작 여덟 계열(단조·목공·법구 공예·봉인 공예·직조·가죽 공예·연금·요리), 채집 셋(채집·채광·낚시), 우수품, 기본 생산량,
-- 분해 경험·경험만 분해, 생활 전문화 정리, 조사 36 「영초 감별」, 기술 칭호 32, 조합 기술, 택일 무료 다시 고르기, 쌓은 경험 이주.
lock table public.world_characters in access exclusive mode;
set local check_function_bodies = off;

create or replace function pg_temp.yh_own(p_fn text) returns void language plpgsql as $f$
declare o text;
begin
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
end $f$;

create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $f$
declare d text; o text; k int;
begin
  d := replace(pg_get_functiondef(p_fn::regprocedure), E'\\r\\n', E'\\n'); -- 줄 끝이 CRLF인 함수도 있다
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  perform pg_temp.yh_own(p_fn);
  execute replace(d, p_old, p_new);
end $f$;
""")
    # ── 표 바꾸기
    w("""
-- ── 표 ──────────────────────────────────────────────────────────────────
alter table public.world_item_catalog add column if not exists base_item_id text;
alter table public.world_item_catalog add column if not exists quality_grade smallint not null default 0;
create index if not exists world_item_catalog_base_idx on public.world_item_catalog(base_item_id) where base_item_id is not null;
alter table public.world_skill_picks add column if not exists free_repick text[] not null default '{}';
alter table public.world_characters alter column crafting_profession set default 'smithing';
""")
    # 바꾸는 기존 함수의 주인 역할을 postgres가 쓸 수 있게(create or replace)
    replaced = ['public.world_craft_item(text)', 'public.world_dismantle_need(integer)', 'public.world_dismantle_yield(text)',
                'public.world_dismantle_item(text)', 'public.world_field_gather(uuid)', 'public.world_fish()',
                'public.world_skill_effect(text)', 'public.world_skill_sync()', 'public.world_skill_choose(text,integer,text)',
                'public.world_skill_snapshot()', 'public.world_idle_skill_for(uuid,text)', 'public.world_set_life_profession_v2(text,text)',
                'public.world_craft_tool_bonus(uuid,text)', 'public.world_tool_covers(text,text)', 'public.world_item_max_durability(text)']
    w('\n'.join(f"select pg_temp.yh_own({q(f)});" for f in replaced) + '\n')
    # world_dismantle_need: sql → plpgsql 로 바뀌므로 지우고 다시(언어가 달라도 create or replace는 됨)
    w(part('f_helpers.sql'))
    w(part('f_skill.sql'))
    w(part('f_craft.sql'))
    w(part('f_dismantle.sql'))
    w(part('f_gather.sql'))
    w(part('f_fish.sql'))
    w(part('f_quickslot.sql'))

    # ── 기술 표
    w('\n-- ── 기술 표 ─────────────────────────────────────────────────────────────\n')
    w("delete from public.world_skill_catalog where category in ('herbalism', 'spirit_gathering');")
    w("delete from public.world_exp_skill_def where skill_id ~ '^(herbalism|spirit_gathering|smithing|alchemy|wardcraft)_';")
    # 이름이 칸끼리 자리를 바꾸는 계열(봉인 공예·연금 등)이 (계열, 이름) 겹침에 걸리지 않게 잠깐 다른 이름으로
    w("update public.world_skill_catalog set skill_name = skill_name || '#' || skill_id where category in ('smithing','carpentry','artifice','weaving','leatherwork','wardcraft','alchemy','cooking','foraging','mining','fishing');")
    for r in skill_rows():
        w("insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ("
          f"{q(r['skill_id'])}, {q(r['skill_name'])}, {q(r['category'])}, {q(r['description'])}, {jq(r['passive_effect'])}, {r['unlock_rank']}, {q(r['slot'])})"
          " on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description,"
          " passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;")
    for i, n, req, d in COMBOS:
        w("insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot, requires) values ("
          f"{q(i)}, {q(n)}, 'combo', {q(d)}, '{{}}'::jsonb, 18, 'combo', {jq(req)})"
          " on conflict (skill_id) do update set skill_name = excluded.skill_name, description = excluded.description, requires = excluded.requires;")
    # 조합 기술 설명 문구의 옛 계열 이름
    w("update public.world_skill_catalog set description = replace(replace(description, '결계 각인', '봉인 공예'), '일반 채집', '채집') where category = 'combo';")
    # 기술표에 없는 옛 줄(같은 계열·같은 칸인데 id가 다른 것)은 없어야 한다
    w("""do $c$ begin
  if exists (select 1 from public.world_skill_catalog where category in ('smithing','carpentry','artifice','weaving','leatherwork','wardcraft','alchemy','cooking','foraging','mining','fishing')
             group by category, unlock_rank, slot having count(*) > 1) then raise exception '기술표 칸이 겹칩니다'; end if;
end $c$;""")
    # 제작법 기술 조건: 영기 채집 → 채집
    w("update public.world_crafting_recipes set required_skill = 'foraging' where required_skill in ('spirit_gathering', 'herbalism');")

    # ── 장비 계열 표(제작법 없는 장비)
    w('\n-- ── 제작법이 없는 장비의 계열(새 장비를 넣을 때도 한 줄) ─────────────────────\n')
    w("""insert into public.world_gear_line_map(item_id, line)
select i.item_id, case
    when i.category = 'weapon' then case i.equipment_traits ->> 'weapon_type' when 'ranged' then 'carpentry' when 'magic' then 'artifice' else 'smithing' end
    when i.category = 'armor' then case when i.item_name ~ '(갑|찰|미늘|투구)' then 'smithing' when i.item_name like '%야행복%' then 'leatherwork' else 'weaving' end
    when i.category = 'hat' then case when i.item_name like '%투구%' then 'smithing' else 'weaving' end
    when i.category = 'shoes' then 'leatherwork'
    when i.category = 'norigae' then 'weaving'
    when i.category in ('amulet', 'mask') then 'wardcraft'
    when i.category = 'tool' then case (select tl.line from public.world_tool_lines tl where tl.item_id = i.item_id) when 'lantern' then 'artifice' when 'rod' then 'carpentry' else 'smithing' end
    else 'smithing' end
  from public.world_item_catalog i
 where i.category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool')
   and not exists (select 1 from public.world_crafting_recipes r where r.output_item = i.item_id)
on conflict (item_id) do nothing;""")

    # ── 기본 생산량
    w('\n-- ── 기본 생산량(소모품·재료, 가구·장비는 1) ─────────────────────────────────\n')
    sm = supply_rows()
    w("update public.world_crafting_recipes r set output_qty = greatest(r.output_qty, v.n) from (values "
      + ', '.join(f"({q(k)}, {v})" for k, v in sorted(sm.items())) + ") v(id, n) where r.recipe_id = v.id;")
    w("""update public.world_crafting_recipes r set output_qty = ceil(r.output_qty * 1.5)::int
  from public.world_item_catalog i
 where i.item_id = r.output_item and i.category in ('consumable', 'material')
   and r.recipe_id not in (""" + ', '.join(q(k) for k in sorted(sm)) + ");")

    # ── 우수품 행
    w('\n-- ── 우수품(<id>_hq): 제작법이 있는 장비 + 수치 효과가 있는 소모품(탄·말린 생선포·노정 건량 제외) ──\n')
    w("""do $h$ begin
  if exists (select 1 from public.world_item_catalog where item_id like '%\\_hq' and base_item_id is null) then raise exception '이미 _hq로 끝나는 물품이 있습니다'; end if;
end $h$;
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, required_job, required_faction, minimum_level,
  rarity, acquisition_difficulty, drop_rate_modifier, equipment_traits, crafting_specialization, tradeable, reference_price, stack_size, base_item_id, quality_grade)
select i.item_id || '_hq', i.item_name || ' (우수)', i.category, i.tier, i.description || ' ' || public.world_item_hq_note(i.item_id, i.category), i.stackable,
  i.required_stats, i.required_job, i.required_faction, i.minimum_level, i.rarity, i.acquisition_difficulty, i.drop_rate_modifier,
  case when i.category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool') then public.world_item_hq_traits(i.equipment_traits) else i.equipment_traits end,
  i.crafting_specialization, i.tradeable, ceil(coalesce(i.reference_price, 0) * 1.3), i.stack_size, i.item_id, 1
  from public.world_item_catalog i
 where i.base_item_id is null
   and exists (select 1 from public.world_crafting_recipes r where r.output_item = i.item_id)
   and (i.category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool')
        or (i.category = 'consumable' and i.item_id not in ('ammo_arrow', 'ammo_bolt', 'ammo_dart', 'treat_fish', 'travel_ration')))
on conflict (item_id) do nothing;
-- 우수품 장비의 계열도 기본 물품을 따른다(world_gear_line이 base로 찾음)
insert into public.world_item_lore(item_id, lore)
select h.item_id, l.lore from public.world_item_catalog h join public.world_item_lore l on l.item_id = h.base_item_id
 where h.base_item_id is not null on conflict do nothing;
drop trigger if exists trg_world_item_hq_sync on public.world_item_catalog;
create trigger trg_world_item_hq_sync after update on public.world_item_catalog for each row execute function public.world_item_hq_sync();
""")

    # ── 칭호
    w('\n-- ── 기술 칭호 32 ──────────────────────────────────────────────────────────\n')
    for t in title_rows():
        w("insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ("
          f"{q(t['title_key'])}, {q(t['title_name'])}, {q(t['icon'])}, {q(t['description'])}, {q(t['condition_text'])}, {jq(t['bonus'])}, true, false, {jq(t['rule'])}, {t['sort']}, {q(t['category'])}, {t['grade']})"
          " on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text,"
          " bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;")
    w("""update public.world_title_catalog set rule = '{"titles": 23}'::jsonb, condition_text = '칭호 23개 획득' where title_key = 'title_collector';
update public.world_title_catalog set rule = '{"titles": 69}'::jsonb, condition_text = '칭호 69개 획득' where title_key = 'title_master';""")

    # ── 패치(앵커)
    w(part('f_patches.sql'))
    # ── 권한
    w(part('m_grants.sql'))
    # ── 캐릭터 이주
    w(part('m_migrate.sql'))
    # ── 패치노트
    w(part('m_note.sql'))
    # 마지막에 모든 plpgsql 함수의 문법을 검사한다(앵커를 둘로 나눠 고치는 사이에는 잠깐 괄호가 안 맞을 수 있어 중간에는 끔)
    w("""
set local check_function_bodies = on;
do $v$ declare f oid; begin
  for f in select p.oid from pg_proc p join pg_language l on l.oid = p.prolang where p.pronamespace = 'public'::regnamespace and l.lanname = 'plpgsql' loop
    perform plpgsql_validator(f);
  end loop;
end $v$;""")
    w("\nupdate public.world_app_meta set value = '20261104000000' where key = 'db_version';\n")
    open(OUT, 'w', encoding='utf-8').write('\n'.join(o))
    print('wrote', OUT, os.path.getsize(OUT), 'bytes')


if __name__ == '__main__':
    main()
