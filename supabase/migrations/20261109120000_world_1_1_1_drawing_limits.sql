create table if not exists public.world_drawing_made (
  id bigint generated always as identity primary key,
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  kind text not null default 'draw' check (kind in ('draw', 'give')),
  made_at timestamptz not null default now()
);
create index if not exists world_drawing_made_owner_idx on public.world_drawing_made (owner_id, kind, made_at);
alter table public.world_drawing_made enable row level security;
revoke all on table public.world_drawing_made from public, anon, authenticated;
grant select, insert on table public.world_drawing_made to fn_owner_field;

insert into public.world_drawing_made (owner_id, kind, made_at)
select d.author_id, 'draw', d.created_at from public.world_drawings d
 where d.giver_id is null and d.created_at >= public.world_drawing_day_start()
   and exists (select 1 from public.world_characters c where c.owner_id = d.author_id)
   and not exists (select 1 from public.world_drawing_made m where m.owner_id = d.author_id and m.kind = 'draw' and m.made_at = d.created_at);
insert into public.world_drawing_made (owner_id, kind, made_at)
select d.giver_id, 'give', d.created_at from public.world_drawings d
 where d.giver_id is not null and d.created_at >= public.world_drawing_day_start()
   and exists (select 1 from public.world_characters c where c.owner_id = d.giver_id)
   and not exists (select 1 from public.world_drawing_made m where m.owner_id = d.giver_id and m.kind = 'give' and m.made_at = d.created_at);

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[], p_n int) returns void language plpgsql as $f$
declare d text; i int;
begin
  select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    if (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]) <> p_n then raise exception '함수 % 모양이 예상과 다릅니다', p_name; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

select pg_temp.yh_fix('world_drawing_save', array[
$q$  perform public.world_seal_guard();$q$,
$q$  perform public.world_seal_guard();
  perform pg_advisory_xact_lock(hashtext('drawing:' || uid::text));$q$,
$q$(select count(*) from public.world_drawings where author_id = uid and giver_id is null and created_at >= public.world_drawing_day_start())$q$,
$q$(select count(*) from public.world_drawing_made m where m.owner_id = uid and m.kind = 'draw' and m.made_at >= public.world_drawing_day_start())$q$,
$q$    update public.world_drawings set origin = nid where id = nid;$q$,
$q$    update public.world_drawings set origin = nid where id = nid;
    insert into public.world_drawing_made (owner_id, kind) values (uid, 'draw');$q$], 1);

select pg_temp.yh_fix('world_drawing_give', array[
$q$  perform public.world_seal_guard();$q$,
$q$  perform public.world_seal_guard();
  perform pg_advisory_xact_lock(hashtext('drawing:' || least(uid, coalesce(p_target, uid))::text));
  perform pg_advisory_xact_lock(hashtext('drawing:' || greatest(uid, coalesce(p_target, uid))::text));$q$,
$q$(select count(*) from public.world_drawings where giver_id = uid and created_at >= public.world_drawing_day_start())$q$,
$q$(select count(*) from public.world_drawing_made m where m.owner_id = uid and m.kind = 'give' and m.made_at >= public.world_drawing_day_start())$q$,
$q$  values (p_target, coalesce(d.origin, d.id), d.author_id, d.author_name, d.title, d.size, d.px, uid, nm) returning id into nid;$q$,
$q$  values (p_target, coalesce(d.origin, d.id), d.author_id, d.author_name, d.title, d.size, d.px, uid, nm) returning id into nid;
  insert into public.world_drawing_made (owner_id, kind) values (uid, 'give');$q$], 1);

do $p$
declare d text := pg_get_functiondef('public.world_character_purge(uuid)'::regprocedure);
  a text := 'delete from public.world_drawing_hides where viewer_id = p_uid;';
begin
  if position('world_drawing_made' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '캐릭터 정리 함수 모양이 예상과 다릅니다'; end if;
  execute replace(d, a, a || E'\n  delete from public.world_drawing_made where owner_id = p_uid;');
end $p$;

update public.world_patch_notes set body = body || E'\n- 그림 액자: 새 그림·선물의 하루 장수를 그린·보낸 기록으로 셉니다(지운 그림도 그날 장수에 듭니다). 같은 사람의 요청이 한꺼번에 와도 하나씩 처리합니다.'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261109120000' where key = 'db_version';
