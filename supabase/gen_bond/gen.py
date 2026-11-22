import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'supabase', 'migrations', '20261124170000_world_3_6_0_kinship.sql')
VER = '20261124170000'

subprocess.run([sys.executable, os.path.join(HERE, 'parse.py')], check=True)
NEW4 = ['mogaram', 'yeonseohui', 'kangducheol', 'yeoseotjjae']
talk = {k: {key: v for key, v in d.items() if key not in ['mate_' + x for x in NEW4]}
        for k, d in json.load(open(os.path.join(HERE, 'talk.json'), encoding='utf-8')).items() if k not in NEW4}


def q(s):
    return "'" + s.replace("'", "''") + "'"


HEAD = r'''lock table public.world_characters in access exclusive mode;

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

'''

FNS = ['world_kin_rules()', 'world_kin_npc(text)', 'world_kin_on(uuid)', 'world_kin_in_field(text, text)',
       'world_kin_line(text, text, int)', 'world_kin_view(text)', 'world_kin_make(text)', 'world_kin_break()',
       'world_kin_wear(boolean)', 'world_kin_ctx(uuid, public.world_kin)', 'world_kin_talk()', 'world_kin_gift(text)',
       'world_kin_room_set(int)', 'world_kin_home(uuid, uuid)', 'world_kin_greet(uuid)', 'world_kin_brief(uuid, boolean)']
RPC = ['world_kin_view(text)', 'world_kin_make(text)', 'world_kin_break()', 'world_kin_wear(boolean)', 'world_kin_talk()',
       'world_kin_gift(text)', 'world_kin_room_set(int)', 'world_kin_greet(uuid)']

TAIL = r'''
grant select, insert, update, delete on public.world_kin to fn_owner_field;
grant select on public.world_kin_lines to fn_owner_field;

select pg_temp.kn_fix('world_bond_bonus(uuid, text)', array[
$q$when not public.world_bond_together(p_owner) then 0$q$,
$q$when not public.world_bond_together(p_owner) and not public.world_kin_on(p_owner) then 0$q$]);

select pg_temp.kn_fix('world_bond_set(boolean, boolean)', array[
$q$return jsonb_build_object('ok', true, 'content', case when p_wear is not null$q$,
$q$if coalesce(p_wear, false) then update public.world_kin set wear = false where owner_id = uid; end if;
  return jsonb_build_object('ok', true, 'content', case when p_wear is not null$q$]);

select pg_temp.kn_fix('world_housing_snapshot', array[
$q$'furns', public.world_furn_room($q$,
$q$'kin', public.world_kin_home(own, uid), 'furns', public.world_furn_room($q$]);

select pg_temp.kn_fix('world_bond_snapshot', array[
$q$'bond', res,$q$,
$q$'bond', res, 'kin', public.world_kin_brief(uid, true),$q$]);

select pg_temp.kn_fix('world_character_card(uuid)', array[
$q$'nameless', public.world_name_lost(c.owner_id),$q$,
$q$'nameless', public.world_name_lost(c.owner_id), 'kin', public.world_kin_brief(c.owner_id, false),$q$]);

select pg_temp.kn_fix('world_character_purge(uuid)', array[
$q$  delete from public.world_regular_day where owner_id = p_uid;$q$,
$q$  delete from public.world_regular_day where owner_id = p_uid;
  delete from public.world_kin where owner_id = p_uid;$q$]);

do $g$
declare f text;
begin
  foreach f in array array[%FNS%] loop
    perform pg_temp.kn_share('public.' || f);
    perform pg_temp.kn_own('public.' || f, 'fn_owner_field');
  end loop;
end $g$;
%GRANTS%
grant execute on function public.world_kin_rules() to anon, authenticated;
'''


def main():
    rows = []
    for npc, keys in talk.items():
        for key, bs in keys.items():
            for i, b in enumerate(bs, 1):
                rows.append(f"({q(npc)}, {q(key)}, {i}, {q(json.dumps(b, ensure_ascii=False))}::jsonb)")
    lines = ('delete from public.world_kin_lines;\ninsert into public.world_kin_lines(npc, key, n, lines) values\n'
             + ',\n'.join(rows) + ';\n')
    eng = open(os.path.join(HERE, 'engine.sql'), encoding='utf-8').read()
    note = open(os.path.join(HERE, 'patch_note.sql'), encoding='utf-8').read() if os.path.exists(os.path.join(HERE, 'patch_note.sql')) else ''
    tail = TAIL.replace('%FNS%', ', '.join(q(f) for f in FNS)).replace(
        '%GRANTS%', '\n'.join(f'grant execute on function public.{f} to authenticated;' for f in RPC))
    meta = (f"\ninsert into public.world_app_meta(key, value, changed_at) values ('db_version', '{VER}', now())\n"
            "on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;\n")
    open(OUT, 'w', encoding='utf-8').write(HEAD + eng + '\n' + lines + tail + note + meta)
    print(OUT, len(rows), '줄')


main()
