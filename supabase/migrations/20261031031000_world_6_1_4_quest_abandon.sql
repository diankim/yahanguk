-- 6.1.4 보조 퀘스트 포기하기(제보 16 요청): 보조·직업·소속 퀘스트(kind side)의 진행을 지워 처음부터 다시 받을 수 있게 한다.
-- 주 이야기는 포기할 수 없다. 포기 전에 보상을 받은 장면(world_quest_abandons.paid_step까지)은 다시 보고해도 보상이 없어
-- 포기·재수락으로 같은 보상을 되풀이해 받을 수 없다(넘길 물품은 다시 넘긴다).
lock table public.world_characters in access exclusive mode;

create table if not exists public.world_quest_abandons (
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  quest_id text not null,
  paid_step int not null default 0,
  times int not null default 1,
  abandoned_at timestamptz not null default now(),
  primary key (owner_id, quest_id)
);
alter table public.world_quest_abandons enable row level security;
revoke all on public.world_quest_abandons from public, anon, authenticated;
grant select, insert, update on public.world_quest_abandons to fn_owner_field;
grant delete on public.world_quest_progress to fn_owner_field;

create or replace function public.world_quest_abandon(p_quest text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $f$
declare uid uuid := public.fn_owner_auth_uid(); q public.world_quests%rowtype; g public.world_quest_progress%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select * into q from public.world_quests where quest_id = p_quest;
  if not found then raise exception '알 수 없는 퀘스트입니다.'; end if;
  if q.kind <> 'side' then raise exception '주 이야기는 포기할 수 없습니다.'; end if;
  select * into g from public.world_quest_progress where owner_id = uid and quest_id = p_quest for update;
  if not found or coalesce(g.step, 0) < 1 then raise exception '진행 중인 퀘스트가 아닙니다.'; end if;
  if g.done_at is not null then raise exception '이미 마친 퀘스트입니다.'; end if;
  insert into public.world_quest_abandons(owner_id, quest_id, paid_step) values (uid, p_quest, g.step)
  on conflict (owner_id, quest_id) do update set paid_step = greatest(public.world_quest_abandons.paid_step, excluded.paid_step),
    times = public.world_quest_abandons.times + 1, abandoned_at = now();
  delete from public.world_quest_progress where owner_id = uid and quest_id = p_quest;
  return jsonb_build_object('ok', true, 'quest_id', p_quest,
    'content', '「' || q.title || '」을(를) 포기했습니다. 다시 받으면 처음부터 진행합니다(이미 보상을 받은 장면은 보상이 없습니다).');
end $f$;
alter function public.world_quest_abandon(text) owner to fn_owner_field;
do $$ begin
  if not pg_has_role('postgres', 'fn_owner_field', 'usage') then grant fn_owner_field to postgres with inherit true, set true; end if;
end $$;
set role fn_owner_field;
revoke all on function public.world_quest_abandon(text) from public, anon;
grant execute on function public.world_quest_abandon(text) to authenticated;
reset role;

-- 보고: 포기 전에 보상을 받은 장면은 보상 없이 넘긴다
do $$ declare d text; a text; n int;
begin
  d := pg_get_functiondef('public.world_quest_report(text)'::regprocedure);
  if position('world_quest_abandons' in d) = 0 then
    a := E'  inv := coalesce(c.inventory, ''{}''::jsonb);\n  -- 넘길 물품';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 퀘스트 보고(%)', n; end if;
    execute replace(d, a, E'  inv := coalesce(c.inventory, ''{}''::jsonb);\n'
      || E'  if s.step <= coalesce((select ab.paid_step from public.world_quest_abandons ab where ab.owner_id = uid and ab.quest_id = p_quest), 0) then\n'
      || E'    s.reward := ''{}''::jsonb; msg := ''포기 전에 보상을 받은 장면이라 보상은 없습니다 · '';\n'
      || E'  end if;\n  -- 넘길 물품');
  end if;
end $$;

update public.world_patch_notes set body = body || E'- **보조 퀘스트 포기하기**: 일지 › 보조 퀘스트에서 진행 중인 퀘스트를 「포기하기」로 내려놓을 수 있습니다. 진행이 처음으로 돌아가고 다시 받아 처음부터 할 수 있습니다(포기 전에 보상을 받은 장면은 다시 보고해도 보상이 없습니다). 주 이야기는 포기할 수 없습니다.\n'
 where note_id = '6.1.0' and position('보조 퀘스트 포기하기' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261031031000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
