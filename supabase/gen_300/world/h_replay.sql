create or replace function public.world_quest_replay_rules() returns jsonb
language sql immutable as $$ select '{"pct": 20, "min": 5, "max_active": 3}'::jsonb $$;
grant execute on function public.world_quest_replay_rules() to public;

create table if not exists public.world_quest_replays (
  owner_id uuid not null references public.world_characters(owner_id) on delete cascade,
  quest_id text not null references public.world_quests(quest_id) on delete cascade,
  step int not null default 0,
  step_started_at timestamptz not null default now(),
  started_at timestamptz not null default now(),
  primary key (owner_id, quest_id)
);
create index if not exists idx_world_quest_replays_quest on public.world_quest_replays(quest_id);
alter table public.world_quest_replays enable row level security;
revoke all on table public.world_quest_replays from public, anon, authenticated;
grant select, insert, update, delete on table public.world_quest_replays to fn_owner_field;

select pg_temp.yh_patch('public.world_character_purge(uuid)',
  '  delete from public.world_meisho_alerts where owner_id = p_uid;',
  '  delete from public.world_meisho_alerts where owner_id = p_uid;
  delete from public.world_quest_replays where owner_id = p_uid;');

select pg_temp.yh_patch('public.world_quest_step_state(uuid,text)',
  'nsteps int; since timestamptz;', 'nsteps int; since timestamptz; rp public.world_quest_replays%rowtype;');
select pg_temp.yh_patch('public.world_quest_step_state(uuid,text)',
  '  select * into g from public.world_quest_progress where owner_id = p_uid and quest_id = p_quest;',
  '  select * into g from public.world_quest_progress where owner_id = p_uid and quest_id = p_quest;
  select * into rp from public.world_quest_replays where owner_id = p_uid and quest_id = p_quest;
  if rp.quest_id is not null then g.owner_id := p_uid; g.step := rp.step; g.step_started_at := rp.step_started_at; end if;');

select pg_temp.yh_patch('public.world_quest_report(text)',
  'gained int := 0; gx jsonb; mt jsonb := ''{}''::jsonb;', 'gained int := 0; gx jsonb; mt jsonb := ''{}''::jsonb; rp public.world_quest_replays%rowtype;');
select pg_temp.yh_patch('public.world_quest_report(text)',
  '  if public.world_quest_done(uid, p_quest) then raise exception',
  '  select * into rp from public.world_quest_replays where owner_id = uid and quest_id = p_quest for update;
  if rp.quest_id is null and public.world_quest_done(uid, p_quest) then raise exception');
select pg_temp.yh_patch('public.world_quest_report(text)',
  '  select * into g from public.world_quest_progress where owner_id = uid and quest_id = p_quest for update;',
  '  select * into g from public.world_quest_progress where owner_id = uid and quest_id = p_quest for update;
  if rp.quest_id is not null then g.owner_id := uid; g.step := rp.step; g.step_started_at := rp.step_started_at; end if;');
select pg_temp.yh_patch('public.world_quest_report(text)',
  '    s.reward := ''{}''::jsonb; msg := ''포기 전에 보상을 받은 장면이라 보상은 없습니다 · '';
  end if;',
  '    s.reward := ''{}''::jsonb; msg := ''포기 전에 보상을 받은 장면이라 보상은 없습니다 · '';
  end if;
  if rp.quest_id is not null then
    s.reward := case when s.step >= nsteps then jsonb_build_object(''gil'', greatest((public.world_quest_replay_rules() ->> ''min'')::int,
      ceil(coalesce((select sum((x.reward ->> ''gil'')::int) from public.world_quest_steps x where x.quest_id = p_quest), 0) * (public.world_quest_replay_rules() ->> ''pct'')::numeric / 100)::int))
      else ''{}''::jsonb end;
    msg := ''다시하기 · '';
  end if;');
select pg_temp.yh_patch('public.world_quest_report(text)',
  '  is_done := q.kind = ''side'' and s.step >= nsteps;
  insert into public.world_quest_progress(owner_id, quest_id, step, started_at, step_started_at, done_at)
  values (uid, p_quest, s.step, now(), now(), case when is_done then now() end)
  on conflict (owner_id, quest_id) do update set step = excluded.step, step_started_at = now(), done_at = excluded.done_at;
  if is_done then',
  '  is_done := q.kind = ''side'' and s.step >= nsteps;
  if rp.quest_id is not null then
    is_done := s.step >= nsteps;
    if is_done then delete from public.world_quest_replays where owner_id = uid and quest_id = p_quest;
    else update public.world_quest_replays set step = s.step, step_started_at = now() where owner_id = uid and quest_id = p_quest; end if;
  else
  insert into public.world_quest_progress(owner_id, quest_id, step, started_at, step_started_at, done_at)
  values (uid, p_quest, s.step, now(), now(), case when is_done then now() end)
  on conflict (owner_id, quest_id) do update set step = excluded.step, step_started_at = now(), done_at = excluded.done_at;
  end if;
  if is_done and rp.quest_id is null then');
select pg_temp.yh_patch('public.world_quest_report(text)',
  '''clues_open'', q.kind = ''main'' and s.step >= nsteps,',
  '''clues_open'', q.kind = ''main'' and s.step >= nsteps and rp.quest_id is null, ''replay'', rp.quest_id is not null,');

select pg_temp.yh_patch('public.world_quest_board()',
  '  end loop;
  select coalesce(jsonb_agg(
    case when jsonb_typeof(a.a1)',
  '  end loop;
  for q in select x.quest_id, x.kind, x.cat, x.title, x.summary from public.world_quest_replays r join public.world_quests x on x.quest_id = r.quest_id
            where r.owner_id = uid and x.active order by r.started_at loop
    st := public.world_quest_step_state(uid, q.quest_id);
    acts := acts || (jsonb_build_object(''quest_id'', q.quest_id, ''kind'', q.kind, ''cat'', q.cat, ''title'', q.title, ''summary'', q.summary, ''phase'', ''step'', ''replay'', true)
      || coalesce(st, ''{}''::jsonb) || jsonb_build_object(''title'', q.title, ''step_title'', st ->> ''title''));
  end loop;
  select coalesce(jsonb_agg(
    case when jsonb_typeof(a.a1)');

select pg_temp.yh_patch('public.world_quest_journal()',
  '''cur'', case when st is not null then st - ''title'' end);',
  '''cur'', case when st is not null then st - ''title'' end,
      ''replay'', case when done then (select jsonb_build_object(''step'', rp.step, ''cur'', public.world_quest_step_state(uid, q.quest_id) - ''title'')
                                        from public.world_quest_replays rp where rp.owner_id = uid and rp.quest_id = q.quest_id) end);');

create or replace function public.world_quest_replay_start(p_quest text) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); ru jsonb := public.world_quest_replay_rules(); q public.world_quests%rowtype; c public.world_characters%rowtype; tot int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  perform public.world_travel_guard('퀘스트 다시하기');
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select * into q from public.world_quests where quest_id = p_quest and active;
  if not found then raise exception '알 수 없는 퀘스트입니다.'; end if;
  if (q.job_key is not null and q.job_key <> c.job_key) or (q.faction_key is not null and q.faction_key <> c.faction_key) then raise exception '다른 직업·소속의 퀘스트입니다.'; end if;
  if not public.world_quest_done(uid, p_quest) then raise exception '마친 퀘스트만 다시 할 수 있습니다.'; end if;
  if exists (select 1 from public.world_quest_replays where owner_id = uid and quest_id = p_quest) then raise exception '이미 다시 하는 중입니다.'; end if;
  if (select count(*) from public.world_quest_replays where owner_id = uid) >= (ru ->> 'max_active')::int then
    raise exception '다시하기는 한 번에 %편까지입니다. 하던 것을 마치거나 포기한 뒤 다시 누르세요.', ru ->> 'max_active'; end if;
  insert into public.world_quest_replays(owner_id, quest_id) values (uid, p_quest);
  tot := greatest((ru ->> 'min')::int, ceil(coalesce((select sum((x.reward ->> 'gil')::int) from public.world_quest_steps x where x.quest_id = p_quest), 0) * (ru ->> 'pct')::numeric / 100)::int);
  return jsonb_build_object('ok', true, 'quest_id', p_quest, 'gil', tot, 'content', '「' || q.title || '」을(를) 처음부터 다시 합니다. 다 마치면 ' || tot || '전을 받습니다.');
end $$;
revoke all on function public.world_quest_replay_start(text) from public, anon;
grant execute on function public.world_quest_replay_start(text) to authenticated;

create or replace function public.world_quest_replay_abandon(p_quest text) returns jsonb
language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  delete from public.world_quest_replays where owner_id = uid and quest_id = p_quest;
  if not found then raise exception '다시 하는 중인 퀘스트가 아닙니다.'; end if;
  return jsonb_build_object('ok', true, 'content', '다시하기를 그만두었습니다. 처음 마친 기록은 그대로입니다.');
end $$;
revoke all on function public.world_quest_replay_abandon(text) from public, anon;
grant execute on function public.world_quest_replay_abandon(text) to authenticated;

grant create on schema public to fn_owner_field;
alter function public.world_quest_replay_start(text) owner to fn_owner_field;
alter function public.world_quest_replay_abandon(text) owner to fn_owner_field;
revoke create on schema public from fn_owner_field;
