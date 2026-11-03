create table if not exists public.world_quest_label_cache (k text primary key, label text not null);
alter table public.world_quest_label_cache enable row level security;
revoke all on table public.world_quest_label_cache from public, anon, authenticated;
grant select, insert, delete on table public.world_quest_label_cache to fn_owner_field;

do $w$
declare d text; a text; b text;
begin
  d := replace(pg_get_functiondef('public.world_quest_task_label(jsonb)'::regprocedure), E'\r\n', E'\n');
  a := $a$  return (select * from (select case$a$;
  b := $a$) yhq limit 1);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 or (length(d) - length(replace(d, b, ''))) / length(b) <> 1 then raise exception '1.0.2 world_quest_task_label 기준 문구가 없습니다'; end if;
  d := replace(d, a, $x$  return coalesce((select l.label from public.world_quest_label_cache l where l.k = md5(p_task::text)), (select * from (select case$x$);
  d := replace(d, b, $x$) yhq limit 1));$x$);
  execute d;
end $w$;

create or replace function public.world_quest_label_refresh() returns integer
language plpgsql security definer set search_path = '' as $f$
declare n int;
begin
  delete from public.world_quest_label_cache where true;
  insert into public.world_quest_label_cache (k, label)
  select md5(t::text), public.world_quest_task_label(t)
    from (select distinct t from (select jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) t from public.world_quest_steps s
                                  union all select jsonb_array_elements(coalesce(f.need -> 'tasks', '[]'::jsonb)) from public.world_faction_scenes f) z) y
   where public.world_quest_task_label(t) is not null
  on conflict (k) do nothing;
  get diagnostics n = row_count;
  return n;
end $f$;
revoke all on function public.world_quest_label_refresh() from public, anon, authenticated;
alter function public.world_quest_label_refresh() owner to fn_owner_field;
select public.world_quest_label_refresh();

drop function if exists public.world_me(boolean, boolean);
create or replace function public.world_me(p_hud boolean default true, p_field boolean default false, p_inv boolean default false)
returns jsonb language plpgsql volatile security invoker set search_path = '' as $f$
declare c jsonb; h jsonb; f jsonb; i jsonb;
begin
  select to_jsonb(x) into c from public.world_characters x where x.owner_id = auth.uid();
  if c is null then return jsonb_build_object('character', null); end if;
  if p_hud then begin h := public.world_hud_snapshot(); exception when others then h := null; end; end if;
  if p_field then begin f := public.world_field_snapshot(); exception when others then f := null; end; end if;
  if p_inv then begin i := public.world_inventory_state(); exception when others then i := null; end; end if;
  return jsonb_build_object('character', c, 'hud', h, 'field', f, 'inv', i);
end $f$;
revoke all on function public.world_me(boolean, boolean, boolean) from public, anon;
grant execute on function public.world_me(boolean, boolean, boolean) to authenticated;

update public.world_patch_notes set body = body || $pn$

## 1.0.2 · 서버 요청 줄이기
- 퀘스트 칸이 할 일 문구(어느 채집터에서 나오는지 등)를 볼 때마다 새로 계산하던 것을 미리 만들어 두고 꺼내 씁니다. 지금 있는 지역과 상관없는 행동 뒤에는 퀘스트 칸을 다시 읽지 않습니다.
- 가방·캐릭터 화면을 보고 있을 때는 행동 결과에 가방 상태를 함께 받아 따로 다시 묻지 않습니다.
- 현장 파티 칸·여기 있는 이들은 2분마다(자리·파티가 바뀌는 행동 뒤에는 바로) 새로 읽습니다. 낚시터가 없는 곳에서는 제작·상점 뒤에 낚시터를 다시 묻지 않습니다.
$pn$
where note_id = '1.0.0' and position('## 1.0.2' in body) = 0;

update public.world_app_meta set value = '20261105090000' where key = 'db_version';
