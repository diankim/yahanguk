import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
VER = '20261125080000'
OUT = os.path.join(ROOT, 'supabase', 'migrations', f'{VER}_world_3_7_0_kin4.sql')
NEW4 = ['mogaram', 'yeonseohui', 'kangducheol', 'yeoseotjjae']
NPCS = {
    'mogaram': {'token': '대나무 서표', 'reward': 'moss_porridge'},
    'yeonseohui': {'token': '무명 약낭', 'reward': 'herb_rice'},
    'kangducheol': {'token': '연무 토시', 'reward': 'cod_soup'},
    'yeoseotjjae': {'token': '맡긴 이름패', 'reward': 'dark_eye_drops'},
}
GIFT_KINDS = {'loot': '요괴 전리품 재료', 'armor': '몸 방어구·관모·신 제작품', 'heal': '체력 회복약', 'sp': '영력 회복약',
              'weapon': '원거리 무기면 그 탄, 아니면 영력 회복약'}
NOTE_LINE = '- 네 사람과도 다섯째 이야기를 마치면 백년지기를 맺을 수 있습니다. 네 사람은 저마다 맡은 싸움 기술에 맞는 물품을 선물로 반깁니다.'

subprocess.run([sys.executable, os.path.join(HERE, 'parse.py')], check=True)
talk = json.load(open(os.path.join(HERE, 'talk.json'), encoding='utf-8'))


def q(s):
    return "'" + s.replace("'", "''") + "'"


HEAD = r'''lock table public.world_characters, public.world_kin, public.world_kin_lines, public.world_patch_notes in access exclusive mode;

create or replace function pg_temp.kn_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function pg_temp.kn_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;

create or replace function pg_temp.kn_own(p_fn text, p_role text) returns void language plpgsql as $f$
declare g boolean := not has_schema_privilege(p_role, 'public', 'CREATE');
begin
  if g then execute format('grant create on schema public to %I', p_role); end if;
  execute format('alter function %s owner to %I', p_fn, p_role);
  if g then execute format('revoke create on schema public from %I', p_role); end if;
end $f$;

create or replace function pg_temp.kn_setjson(p_fn regprocedure, p_j jsonb) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); body text := (select prosrc from pg_proc where oid = p_fn);
begin
  if position(body in src) = 0 then raise exception 'kn_setjson %: 본문을 못 찾음', p_fn; end if;
  execute replace(src, body, ' select ' || quote_literal(p_j::text) || '::jsonb ');
end $f$;

do $c$
declare x text;
begin
  foreach x in array array[%REWARDS%] loop
    if not exists (select 1 from public.world_item_catalog i where i.item_id = x) then raise exception '답례 물품이 없습니다: %', x; end if;
  end loop;
end $c$;

select pg_temp.kn_setjson('public.world_kin_rules()'::regprocedure,
  jsonb_set(public.world_kin_rules(), '{npcs}', (public.world_kin_rules() -> 'npcs') || %NPCS%::jsonb)
  || jsonb_build_object('gift_kinds', %GIFT%::jsonb));

create or replace function public.world_kin_in_field(p_uid uuid, p_npc text, p_item text)
 returns boolean
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r jsonb := public.world_regular_rules(); n jsonb := public.world_regular_rule(p_npc); l text := n ->> 'line'; kind text; a text;
begin
  if n is null or p_item is null then return false; end if;
  if n ->> 'kind' = 'combat' then
    kind := r -> 'combat' -> 'item' -> l ->> 0;
    if kind = 'loot' then
      return exists (select 1 from public.world_item_catalog i where i.item_id = p_item and i.category = 'material')
         and exists (select 1 from public.world_region_monsters m where m.drops ? p_item);
    end if;
    if kind = 'weapon' then
      a := public.world_ammo_of(p_uid);
      if a is not null then return p_item = a; end if;
    end if;
    return exists (select 1 from public.world_crafting_recipes w join public.world_item_catalog i on i.item_id = w.output_item
                    where w.output_item = p_item
                      and public.world_regular_ckind_ok(kind, w.craft_field, i.category, i.use_fx));
  end if;
  if l = 'fishing' then
    return exists (select 1 from public.world_fish_species f where f.fish_id = p_item);
  elsif r -> 'lines' ? l then
    return exists (select 1 from public.world_gathering_spots s where p_item = any (s.loot_items)
                     and s.category = any (array(select jsonb_array_elements_text(r -> 'lines' -> l))));
  end if;
  return exists (select 1 from public.world_crafting_recipes w where w.output_item = p_item and public.world_craft_line_of(w.craft_field) = l);
end $function$;

create or replace function public.world_kin_field_name(p_uid uuid, p_npc text)
 returns text
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare n jsonb := public.world_regular_rule(p_npc); kind text; a text;
begin
  if n is null then return null; end if;
  if n ->> 'kind' is distinct from 'combat' then return public.world_line_name(n ->> 'line'); end if;
  kind := public.world_regular_rules() -> 'combat' -> 'item' -> (n ->> 'line') ->> 0;
  if kind = 'weapon' then
    a := public.world_ammo_of(p_uid);
    if a is not null then return public.world_regular_line_name(p_uid, p_npc) || ' · ' || coalesce((select i.item_name from public.world_item_catalog i where i.item_id = a), a); end if;
    kind := 'sp';
  end if;
  return public.world_regular_line_name(p_uid, p_npc) || ' · ' || coalesce(public.world_kin_rules() -> 'gift_kinds' ->> kind, '');
end $function$;

select pg_temp.kn_fix('world_kin_gift(text)', array[
$q$infield := public.world_kin_in_field(nr ->> 'line', base);$q$,
$q$infield := public.world_kin_in_field(uid, k.npc, base);$q$]);

select pg_temp.kn_fix('world_kin_view(text)', array[
$q$'line_name', nr ->> 'line_name',$q$,
$q$'line_name', public.world_kin_field_name(uid, n),$q$]);

select pg_temp.kn_fix('world_kin_home(uuid, uuid)', array[
$q$'line_name', case when k.owner_id = p_viewer then public.world_kin_npc(k.npc) ->> 'line_name' end,$q$,
$q$'line_name', case when k.owner_id = p_viewer then public.world_kin_field_name(k.owner_id, k.npc) end,$q$]);

select pg_temp.kn_fix('world_kin_brief(uuid, boolean)', array[
$q$'line_name', nr ->> 'line_name', 'made_at'$q$,
$q$'line_name', public.world_kin_field_name(p_owner, k.npc), 'made_at'$q$]);

select pg_temp.kn_fix('world_kin_talk()', array[
$q$    idle_avoid := array(select (v)::int from jsonb_array_elements_text(coalesce(m -> 'idle', '[]'::jsonb)) v);$q$,
$q$    if jsonb_typeof(m -> 'idle') is distinct from 'array' then m := m || jsonb_build_object('idle', '[]'::jsonb); end if;
    idle_avoid := array(select (v)::int from jsonb_array_elements_text(m -> 'idle') v);$q$,
$q$    m := m || jsonb_build_object('idle', (select coalesce(jsonb_agg(v), '[]'::jsonb) from (
           select v from jsonb_array_elements(coalesce(m -> 'idle', '[]'::jsonb) || to_jsonb((ln ->> 'n')::int)) v) z
           offset greatest(0, jsonb_array_length(coalesce(m -> 'idle', '[]'::jsonb)) + 1 - (r ->> 'idle_recent')::int)));$q$,
$q$    m := m || jsonb_build_object('idle', (select coalesce(jsonb_agg(z.v order by z.o), '[]'::jsonb) from (
           select t.v, t.o from jsonb_array_elements(m -> 'idle' || to_jsonb((ln ->> 'n')::int)) with ordinality t(v, o)
           order by t.o offset greatest(0, jsonb_array_length(m -> 'idle') + 1 - (r ->> 'idle_recent')::int)) z));$q$]);

drop function if exists public.world_kin_in_field(text, text);

do $g$
declare f text;
begin
  foreach f in array array['world_kin_in_field(uuid, text, text)', 'world_kin_field_name(uuid, text)'] loop
    perform pg_temp.kn_share('public.' || f);
    perform pg_temp.kn_own('public.' || f, 'fn_owner_field');
  end loop;
end $g$;

'''

TAIL = r'''
update public.world_patch_notes
   set body = case when position('## 싸움으로 채우는 주문' in body) > 0
                   then replace(body, E'\n\n## 싸움으로 채우는 주문', E'\n' || %NOTE% || E'\n\n## 싸움으로 채우는 주문')
                   else body || E'\n' || %NOTE% end
 where note_id = '3.7.0' and position(%NOTE% in body) = 0;
'''


def main():
    mates = ['mate_' + x for x in NEW4]
    rows = []
    for npc, keys in talk.items():
        for key, bs in keys.items():
            if npc not in NEW4 and key not in mates:
                continue
            for i, b in enumerate(bs, 1):
                rows.append(f"({q(npc)}, {q(key)}, {i}, {q(json.dumps(b, ensure_ascii=False))}::jsonb)")
    lines = ('delete from public.world_kin_lines where npc = any (array[' + ', '.join(q(x) for x in NEW4) + ']) or key = any (array['
             + ', '.join(q(x) for x in mates) + ']);\ninsert into public.world_kin_lines(npc, key, n, lines) values\n'
             + ',\n'.join(rows) + ';\n')
    head = (HEAD.replace('%REWARDS%', ', '.join(q(v['reward']) for v in NPCS.values()))
                .replace('%NPCS%', q(json.dumps(NPCS, ensure_ascii=False)))
                .replace('%GIFT%', q(json.dumps(GIFT_KINDS, ensure_ascii=False))))
    tail = TAIL.replace('%NOTE%', q(NOTE_LINE))
    meta = (f"\ninsert into public.world_app_meta(key, value, changed_at) values ('db_version', '{VER}', now())\n"
            "on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;\n")
    open(OUT, 'w', encoding='utf-8').write(head + lines + tail + meta)
    print(OUT, len(rows), '줄')


main()
