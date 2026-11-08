create or replace function public.world_guide_rules()
 returns jsonb
 language sql
 immutable
as $function$
  select jsonb_build_object('ch1_quest', 'mq_red_seal', 'ch1_max_lv', 10, 'ch1_at', '야행국 본부 정청', 'er_at', 25, 'er_max_lv', 15,
    'calm', '본부 정청·본부 객사', 'calm_mn', 18, 'calm_er', 10, 'calm_cd', 15, 'ward_er', 18)
$function$;
revoke all on function public.world_guide_rules() from public, anon, authenticated;
grant execute on function public.world_guide_rules() to service_role;

create or replace function public.world_guide_note(p_uid uuid, p_tip text, p_er int default null)
 returns void
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r jsonb := public.world_guide_rules(); f text := 'guide_' || p_tip;
begin
  if p_uid is null or p_tip not in ('ch1', 'erosion') then return; end if;
  if exists (select 1 from public.world_tutorial_state t where t.owner_id = p_uid and t.flags ? f) then return; end if;
  insert into public.world_tutorial_state(owner_id, flags, updated_at) values (p_uid, jsonb_build_object(f, true), now())
  on conflict (owner_id) do update set flags = world_tutorial_state.flags || jsonb_build_object(f, true), updated_at = now();
  if p_tip = 'ch1' then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_uid, 'guide', '주 이야기 1장을 받아 주세요',
      '주 이야기 1장 「붉은 인장의 실종」은 ' || (r->>'ch1_at') || '에서 받습니다. 정청으로 가서 현장의 퀘스트 칸에서 「받기」를 누르세요. 이야기를 따라가면 길을 잃지 않고, 가방 칸과 경험치도 넉넉히 얻습니다.',
      jsonb_build_object('tip', 'ch1', 'location', r->>'ch1_at'));
  else
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (p_uid, 'guide', '침식이 쌓이고 있습니다',
      '지금 침식이 ' || coalesce(p_er, 0) || '입니다. 30부터 회복이 줄고, 더 오르면 받는 피해가 늘어납니다. '
      || (r->>'calm') || '에서 「마음 다잡기」(정신 +' || (r->>'calm_mn') || '·침식 −' || (r->>'calm_er') || ', ' || (r->>'calm_cd') || '분마다)를 하거나, 「정화 부적」(침식 −' || (r->>'ward_er') || ')을 써서 낮추세요. 둘 다 캐릭터 › 상태에서 할 수 있고, 정화 부적은 상점에서 삽니다.',
      jsonb_build_object('tip', 'erosion', 'erosion', p_er));
  end if;
end $function$;
revoke all on function public.world_guide_note(uuid, text, int) from public, anon, authenticated;
grant execute on function public.world_guide_note(uuid, text, int) to service_role;

create or replace function public.world_guide_on_travel()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r jsonb := public.world_guide_rules(); lv int;
begin
  if new.actor_id is null then return new; end if;
  if exists (select 1 from public.world_tutorial_state t where t.owner_id = new.actor_id and t.flags ? 'guide_ch1') then return new; end if;
  select level into lv from public.world_characters where owner_id = new.actor_id;
  if lv is null or lv > (r->>'ch1_max_lv')::int then return new; end if;
  if exists (select 1 from public.world_quest_progress p where p.owner_id = new.actor_id and p.quest_id = r->>'ch1_quest') then return new; end if;
  perform public.world_guide_note(new.actor_id, 'ch1');
  return new;
end $function$;
revoke all on function public.world_guide_on_travel() from public, anon, authenticated;
drop trigger if exists trg_world_guide_travel on public.world_events;
create trigger trg_world_guide_travel after insert on public.world_events for each row when (new.event_type = 'travel') execute function public.world_guide_on_travel();

create or replace function public.world_guide_on_erosion()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare r jsonb := public.world_guide_rules(); at int := (r->>'er_at')::int;
begin
  if old.erosion < at and new.erosion >= at and new.level <= (r->>'er_max_lv')::int then
    perform public.world_guide_note(new.owner_id, 'erosion', new.erosion);
  end if;
  return new;
end $function$;
revoke all on function public.world_guide_on_erosion() from public, anon, authenticated;
drop trigger if exists trg_world_guide_erosion on public.world_characters;
create trigger trg_world_guide_erosion after update of erosion on public.world_characters for each row
 when (new.erosion > old.erosion)
 execute function public.world_guide_on_erosion();

select public.world_guide_note(c.owner_id, 'ch1')
  from public.world_characters c
 where c.level <= (public.world_guide_rules()->>'ch1_max_lv')::int
   and not exists (select 1 from public.world_staff s where s.owner_id = c.owner_id)
   and not exists (select 1 from public.world_quest_progress p where p.owner_id = c.owner_id and p.quest_id = public.world_guide_rules()->>'ch1_quest');
select public.world_guide_note(c.owner_id, 'erosion', c.erosion)
  from public.world_characters c
 where c.level <= (public.world_guide_rules()->>'er_max_lv')::int and c.erosion >= (public.world_guide_rules()->>'er_at')::int
   and not exists (select 1 from public.world_staff s where s.owner_id = c.owner_id);

update public.world_patch_notes set body = body || E'\n- 처음 시작한 조사원이 주 이야기 1장을 받지 않고 나가면, 정청에서 받으라는 안내가 한 번 뜹니다. Lv15까지는 침식이 25를 넘으면 「마음 다잡기」·「정화 부적」으로 낮추는 법도 한 번 알려 드립니다.'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261108220000' where key = 'db_version';
