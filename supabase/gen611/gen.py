import json, sys
import os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from data_quests import QUESTS, JOB_LINES, AFFIL_LINES, xp_need
from data_lore import REGIONS, ITEMS, TITLES, LETTERS, WITNESS

J = lambda o: '$J$' + json.dumps(o, ensure_ascii=False) + '$J$::jsonb'
T = lambda s: '$T$' + s + '$T$'
lines = lambda ls: [{'s': s, 't': t} for s, t in ls]
out = []
w = out.append

w("""-- 6.1.1: 직업·소속 퀘스트 12개 · 직업/소속별 대사 · 소속 보급 편지 · 물품 내력 · 지역 첫 방문 글 · 요괴 목격담 · 숨김 칭호 유래 · 탈것 내리기
-- 6.1.0 화면 배포와 함께 돌린다. 끝에서 숨겨 둔 6.1.0 패치노트를 되살리고 서버 보스 예약을 다시 켠다.

-- 고치는 함수의 주인 역할을 postgres가 쓸 수 있게(6.0.0과 같은 방식)
do $$ declare o text; begin
  for o in select distinct pg_get_userbyid(proowner) from pg_proc where oid in ('public.world_quest_board()'::regprocedure, 'public.world_quest_journal()'::regprocedure,
             'public.world_quest_report(text)'::regprocedure, 'public.world_quest_scene(text,integer)'::regprocedure, 'public.world_claim_faction_supply()'::regprocedure) loop
    if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  end loop;
end $$;

-- ① 직업·소속 전용 퀘스트: world_quests에 조건 열(캐릭터 표가 아니라 퀘스트 표)
alter table public.world_quests add column if not exists job_key text, add column if not exists faction_key text;

do $$ declare d text; a text; b text; f text;
begin
  -- 퀘스트 칸·일지 목록은 조건이 맞는 퀘스트만 센다
  foreach f in array array['public.world_quest_board()', 'public.world_quest_journal()'] loop
    d := pg_get_functiondef(f::regprocedure);
    a := 'where x.active order by';
    b := 'where x.active and (x.job_key is null or x.job_key = c.job_key) and (x.faction_key is null or x.faction_key = c.faction_key) order by';
    if position('x.job_key is null' in d) = 0 then
      if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '고칠 자리 없음: %', f; end if;
      execute replace(d, a, b);
    end if;
  end loop;
  -- 보고도 조건을 확인한다
  d := pg_get_functiondef('public.world_quest_report(text)'::regprocedure);
  a := 'if public.world_quest_done(uid, p_quest) then raise exception ''이미 마친 퀘스트입니다.''; end if;';
  b := a || ' if (q.job_key is not null and q.job_key <> c.job_key) or (q.faction_key is not null and q.faction_key <> c.faction_key) then raise exception ''다른 직업·소속의 퀘스트입니다.''; end if;';
  if position('다른 직업·소속의 퀘스트' in d) = 0 then
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '고칠 자리 없음: 보고 조건'; end if;
    execute replace(d, a, b);
  end if;
end $$;

-- ② 대사 줄에 job·affil이 있으면 그 직업·소속에게만 보인다
create or replace function public.world_quest_lines_for(p_lines jsonb, p_job text, p_affil text)
returns jsonb language sql immutable set search_path to 'pg_catalog' as $$
  select coalesce(jsonb_agg(x order by o), '[]'::jsonb) from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) with ordinality t(x, o)
   where (not x ? 'job' or x ->> 'job' = p_job) and (not x ? 'affil' or x ->> 'affil' = p_affil)
$$;
alter function public.world_quest_lines_for(jsonb, text, text) owner to fn_owner_field;
revoke all on function public.world_quest_lines_for(jsonb, text, text) from public, anon, authenticated;

do $$ declare d text; a text; b text;
begin
  d := pg_get_functiondef('public.world_quest_report(text)'::regprocedure);
  a := '''lines'', s.lines,'; b := '''lines'', public.world_quest_lines_for(s.lines, c.job_key, c.faction_key),';
  if position('world_quest_lines_for' in d) = 0 then
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '고칠 자리 없음: 보고 대사'; end if;
    execute replace(d, a, b);
  end if;
  d := pg_get_functiondef('public.world_quest_scene(text,integer)'::regprocedure);
  if position('world_quest_lines_for' in d) = 0 then
    a := '''lines'', s.lines,'; b := '''lines'', public.world_quest_lines_for(s.lines, c.job_key, c.faction_key),';
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '고칠 자리 없음: 장면 대사'; end if;
    d := replace(d, a, b);
    a := '''lines'', ln,'; b := '''lines'', public.world_quest_lines_for(ln, c.job_key, c.faction_key),';
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '고칠 자리 없음: 결말 대사'; end if;
    execute replace(d, a, b);
  end if;
end $$;
""")

# 1장 첫 장면에 직업·소속별 한 줄: 연서희 첫인사(두 번째 줄) 바로 뒤에
extra = [{'s': 'q:m_yeon', 't': t, 'job': k} for k, t in JOB_LINES.items()] + [{'s': 'q:m_yeon', 't': t, 'affil': k} for k, t in AFFIL_LINES.items()]
w(f"""update public.world_quest_steps s set lines = (
    select jsonb_agg(v order by o) from (
      select v, o::numeric o from jsonb_array_elements(s.lines) with ordinality t(v, o)
      union all select v, 2 + o / 100.0 from jsonb_array_elements({J(extra)}) with ordinality e(v, o)) z)
 where s.quest_id = 'mq_red_seal' and s.step = 1 and position('"job"' in s.lines::text) = 0;
""")

# ③ 퀘스트 12개
for i, q in enumerate(QUESTS):
    L = q['L']; tot = round(0.4 * xp_need(L)); task_steps = [k for k, st in enumerate(q['steps']) if st[2].get('tasks') or st[2].get('give')]
    per = tot // max(1, len(task_steps)); gil = 5 + 4 * L
    w(f"""insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ({T(q['id'])}, 'side', {T(q['cat'])}, {T(q['title'])}, {T(q['summary'])}, {T(q['region'])}, {L}, '{{}}', null, {900 + i}, '[]'::jsonb, true, {T(q['job']) if q.get('job') else 'null'}, {T(q['affil']) if q.get('affil') else 'null'})
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level,
  sort = excluded.sort, active = true, job_key = excluded.job_key, faction_key = excluded.faction_key;""")
    for k, (title, goal, need, ls) in enumerate(q['steps']):
        rw = {}
        if k in task_steps: rw['xp'] = per
        if k == len(q['steps']) - 1:
            rw['gil'] = gil; rw['items'] = q['items']
        w(f"""insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ({T(q['id'])}, {k + 1}, {T(title)}, {T(goal)}, {J(need)}, {J(lines(ls))}, {J(rw)})
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;""")

# ④ 세계관 글 표: 화면은 함수로만 읽는다(표에 직접 읽기 정책 없음)
w("""
create table if not exists public.world_item_lore (item_id text primary key, lore text not null);
create table if not exists public.world_region_lore (region_id text primary key, lines jsonb not null);
create table if not exists public.world_region_visits (owner_id uuid not null, region_id text not null, visited_at timestamptz not null default now(), primary key (owner_id, region_id));
create table if not exists public.world_kind_witness (kind_key text not null, need int not null, speaker text, line text not null, primary key (kind_key, need));
create table if not exists public.world_title_lore (title_key text primary key, lines jsonb not null);
create table if not exists public.world_affil_letters (faction_key text not null, seq int not null, min_chapters int not null default 0, sender text not null, lines jsonb not null, primary key (faction_key, seq));
alter table public.world_item_lore enable row level security;
alter table public.world_region_lore enable row level security;
alter table public.world_region_visits enable row level security;
alter table public.world_kind_witness enable row level security;
alter table public.world_title_lore enable row level security;
alter table public.world_affil_letters enable row level security;
revoke all on public.world_item_lore, public.world_region_lore, public.world_region_visits, public.world_kind_witness, public.world_title_lore, public.world_affil_letters from anon, authenticated;
grant select on public.world_item_lore, public.world_region_lore, public.world_kind_witness, public.world_title_lore, public.world_affil_letters to fn_owner_field;
grant select, insert on public.world_region_visits to fn_owner_field;
""")
for k, v in ITEMS.items():
    w(f"insert into public.world_item_lore values ({T(k)}, {T(v)}) on conflict (item_id) do update set lore = excluded.lore;")
for k, v in REGIONS.items():
    w(f"insert into public.world_region_lore values ({T(k)}, {J(lines([(None, t) for t in v]))}) on conflict (region_id) do update set lines = excluded.lines;")
for k, arr in WITNESS.items():
    for need, s, t in arr:
        w(f"insert into public.world_kind_witness values ({T(k)}, {need}, {T(s)}, {T(t)}) on conflict (kind_key, need) do update set speaker = excluded.speaker, line = excluded.line;")
for k, ls in TITLES.items():
    w(f"insert into public.world_title_lore values ({T(k)}, {J(lines(ls))}) on conflict (title_key) do update set lines = excluded.lines;")
for f, arr in LETTERS.items():
    for i, (mc, sender, ls) in enumerate(arr):
        w(f"insert into public.world_affil_letters values ({T(f)}, {i + 1}, {mc}, {T(sender)}, {J(lines([(None, t) for t in ls]))}) on conflict (faction_key, seq) do update set min_chapters = excluded.min_chapters, sender = excluded.sender, lines = excluded.lines;")

w(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'funcs.sql')).read())
print('\n'.join(out))
