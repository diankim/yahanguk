# 7.4.4 퀘스트 대사 다듬기(사용자 요청): 어색한 대사, 다음 할 일을 앞 장면에서 맡기지 않던 것.
# data/*.json(검토 결과: edits·inserts·deletes·goals·epi_edits, 번호는 고치기 전 배열 번호)을 묶어
# python3 gen.py → ../migrations/20261103234000_world_7_4_4_quest_lines.sql
# 고치는 줄은 old가 DB와 같을 때만 바꾸고 하나라도 다르면 전부 되돌린다. 옛 생성기(gen611·gen70·gen71·quest/gen)나
# gen740을 다시 돌리면 이 수정이 덮이므로 그 뒤에는 이것도 다시 돌린다(이미 적용됐으면 world_app_meta quest_lines_744로 건너뜀).
import os, json, collections, hashlib

h = lambda t: hashlib.md5(t.encode('utf-8')).hexdigest()  # 고치기 전 줄은 md5로만 맞춘다(파일을 줄이려고)

D = os.path.join(os.path.dirname(__file__), 'data')
FILES = ['main', 'side_a', 'side_b', 'side_c', 'side_d', 'faction']

def lit(s):
    return "'" + s.replace("'", "''") + "'"

steps = collections.defaultdict(lambda: {'e': {}, 'd': {}, 'ins': collections.defaultdict(list)})
epis = collections.defaultdict(lambda: {'e': {}, 'd': {}, 'ins': collections.defaultdict(list)})
scenes = collections.defaultdict(lambda: {'e': {}, 'd': {}, 'ins': collections.defaultdict(list)})
goals, sgoals = {}, {}
for f in FILES:
    d = json.load(open(os.path.join(D, f + '.json'), encoding='utf-8'))
    for x in d.get('edits', []):
        o = scenes[x['scene']] if 'scene' in x else steps[f"{x['q']}/{x['step']}"]
        o['e'][str(x['i'])] = {'old': h(x['old']), 't': x['t']}
    for x in d.get('deletes', []):
        o = scenes[x['scene']] if 'scene' in x else steps[f"{x['q']}/{x['step']}"]
        o['d'][str(x['i'])] = h(x['old'])
    for x in d.get('inserts', []):
        o = scenes[x['scene']] if 'scene' in x else steps[f"{x['q']}/{x['step']}"]
        o['ins'][str(x['after'])].append({'s': x.get('s'), 't': x['t']})
    for x in d.get('epi_edits', []):
        epis[x['q']]['e'][str(x['i'])] = {'old': h(x['old']), 't': x['t']}
    for x in d.get('goals', []):
        if 'scene' in x: sgoals[x['scene']] = x['goal']
        else: goals[f"{x['q']}/{x['step']}"] = x['goal']

j = lambda o: json.dumps(o, ensure_ascii=False, separators=(',', ':'))
# 할 일 조건을 바꾼 장면(needs.json: 제련품 채집을 생재료로)과 인물 이름(npcs.json)
needs, npcs = {}, []
if os.path.exists(os.path.join(D, 'needs.json')):
    for x in json.load(open(os.path.join(D, 'needs.json'), encoding='utf-8')):
        needs[f"{x['q']}/{x['step']}"] = {'new': x['need'], 'old': x['old_need']}
if os.path.exists(os.path.join(D, 'npcs.json')):
    npcs = json.load(open(os.path.join(D, 'npcs.json'), encoding='utf-8'))
ST = j(steps); EP = j(epis); SC = j(scenes); GO = j(goals); SG = j(sgoals); NE = j(needs); NP = j(npcs)
n_e = sum(len(v['e']) for g in (steps, epis, scenes) for v in g.values())
n_i = sum(len(l) for g in (steps, scenes) for v in g.values() for l in v['ins'].values())
n_d = sum(len(v['d']) for g in (steps, scenes) for v in g.values())

out = f"""-- 7.4.4 퀘스트 대사 다듬기(사용자 요청): 어색한·맥락이 안 맞는 대사를 고치고, 다음 장면에서 할 일(어디서·무엇을·왜)을
-- 앞 장면 끝에서 인물이 게임 속 이름으로 맡기게 했다. 퀘스트 장면·주 이야기 결말·세력 퀘스트 장면.
-- 고친 줄 {n_e} · 넣은 줄 {n_i} · 지운 줄 {n_d} · 할 일 문구 {len(goals) + len(sgoals)}. 원본 supabase/gen744(data/*.json, gen.py).
-- 고칠 줄이 DB와 다르면(old) 전부 되돌린다. 할 일 조건·보상·장면 수는 그대로.
create or replace function pg_temp.yh744_rebuild(src jsonb, ops jsonb, tag text) returns jsonb
language plpgsql as $f$
declare out jsonb := '[]'::jsonb; el jsonb; x jsonb; i int; n int := jsonb_array_length(src);
begin
  for x in select value from jsonb_array_elements(coalesce(ops #> '{{ins,-1}}', '[]')) loop out := out || jsonb_build_array(x); end loop;
  for i in 0 .. n - 1 loop
    el := src -> i;
    if ops -> 'd' ? i::text then
      if md5(el ->> 't') is distinct from ops -> 'd' ->> i::text then raise exception '% %번 줄(지우기)이 DB와 다름', tag, i; end if;
    else
      if ops -> 'e' ? i::text then
        if md5(el ->> 't') is distinct from ops -> 'e' -> i::text ->> 'old' then raise exception '% %번 줄이 DB와 다름: %', tag, i, el ->> 't'; end if;
        el := el || jsonb_build_object('t', ops -> 'e' -> i::text ->> 't');
      end if;
      out := out || jsonb_build_array(el);
    end if;
    for x in select value from jsonb_array_elements(coalesce(ops -> 'ins' -> i::text, '[]')) loop out := out || jsonb_build_array(x); end loop;
  end loop;
  for x in select key from jsonb_each(ops -> 'e') union select key from jsonb_each(ops -> 'd') union select key from jsonb_each(ops -> 'ins') loop
    if (x #>> '{{}}')::int >= n then raise exception '% %번 줄이 없음', tag, x #>> '{{}}'; end if;
  end loop;
  return out;
end $f$;

do $do$
declare st jsonb := {lit(ST)}::jsonb; ep jsonb := {lit(EP)}::jsonb; sc jsonb := {lit(SC)}::jsonb;
  go jsonb := {lit(GO)}::jsonb; sg jsonb := {lit(SG)}::jsonb; ne jsonb := {lit(NE)}::jsonb; np jsonb := {lit(NP)}::jsonb;
  e record; p text[]; k int; bad text;
begin
  if exists (select 1 from public.world_app_meta where key = 'quest_lines_744') then raise notice '이미 적용됨'; return; end if;
  for e in select key, value from jsonb_each(st) loop
    p := string_to_array(e.key, '/');
    update public.world_quest_steps set lines = pg_temp.yh744_rebuild(lines, e.value, e.key) where quest_id = p[1] and step = p[2]::int;
    get diagnostics k = row_count; if k <> 1 then raise exception '장면 없음 %', e.key; end if;
  end loop;
  for e in select key, value from jsonb_each(ep) loop
    update public.world_quests set epilogue = pg_temp.yh744_rebuild(epilogue, e.value, e.key || '/결말') where quest_id = e.key;
    get diagnostics k = row_count; if k <> 1 then raise exception '퀘스트 없음 %', e.key; end if;
  end loop;
  for e in select key, value from jsonb_each(sc) loop
    update public.world_faction_scenes set lines = pg_temp.yh744_rebuild(lines, e.value, e.key) where scene_key = e.key;
    get diagnostics k = row_count; if k <> 1 then raise exception '세력 장면 없음 %', e.key; end if;
  end loop;
  for e in select key, value #>> '{{}}' as v from jsonb_each(go) loop
    p := string_to_array(e.key, '/');
    update public.world_quest_steps set goal = e.v where quest_id = p[1] and step = p[2]::int;
    get diagnostics k = row_count; if k <> 1 then raise exception '장면 없음(goal) %', e.key; end if;
  end loop;
  for e in select key, value #>> '{{}}' as v from jsonb_each(sg) loop
    update public.world_faction_scenes set goal = e.v where scene_key = e.key;
    get diagnostics k = row_count; if k <> 1 then raise exception '세력 장면 없음(goal) %', e.key; end if;
  end loop;
  for e in select key, value from jsonb_each(ne) loop
    p := string_to_array(e.key, '/');
    update public.world_quest_steps set need = e.value -> 'new' where quest_id = p[1] and step = p[2]::int and need = e.value -> 'old';
    get diagnostics k = row_count; if k <> 1 then raise exception '할 일 조건이 DB와 다름 %', e.key; end if;
  end loop;
  for e in select value from jsonb_array_elements(np) loop
    update public.world_quest_npcs set npc_name = e.value ->> 'npc_name', bio = coalesce(e.value ->> 'bio', bio) where npc_key = e.value ->> 'npc_key';
    get diagnostics k = row_count; if k <> 1 then raise exception '인물 없음 %', e.value ->> 'npc_key'; end if;
  end loop;
  -- 말하는 이: 서술(null)이거나 아는 인물만, 주인공('me')은 없음
  select string_agg(distinct l ->> 's', ', ') into bad from (
      select jsonb_array_elements(lines) l from public.world_quest_steps
      union all select jsonb_array_elements(lines) from public.world_faction_scenes
      union all select jsonb_array_elements(epilogue) from public.world_quests where jsonb_typeof(epilogue) = 'array') x
    where l ->> 's' is not null and l ->> 's' not in (select npc_key from public.world_quest_npcs union select npc_key from public.world_faction_npcs);
  if bad is not null then raise exception '모르는 말하는 이: %', bad; end if;
  insert into public.world_app_meta(key, value) values ('quest_lines_744', now()::text);
end $do$;
"""
p = os.path.join(os.path.dirname(__file__), '..', 'migrations', '20261103234000_world_7_4_4_quest_lines.sql')
open(p, 'w', encoding='utf-8').write(out)
print(n_e, n_i, n_d, len(goals) + len(sgoals), '→', os.path.normpath(p), len(out.encode()), 'bytes')
