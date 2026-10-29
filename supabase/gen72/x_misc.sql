
-- 알림 설정에 「별채」 갈래(발걸음·방명록·가구·손님이 동무와 놀아 줌)
select pg_temp.yh_patch('public.world_notify_prefs_set(text[])', '''faction'', ''raid'')', '''faction'', ''raid'', ''housing'')');

-- ─────────────────────────────────────────────────────────────
-- 함수 주인·권한: 행동 함수는 fn_owner_field가 갖고, 화면이 부르는 것만 authenticated에 연다
-- ─────────────────────────────────────────────────────────────
do $$ declare fn text; begin
  foreach fn in array array['world_housing_married(uuid,uuid)', 'world_housing_blocked(uuid,uuid)', 'world_housing_friends(uuid,uuid)', 'world_housing_can_view(uuid,uuid,text)',
    'world_housing_edit_block(uuid)', 'world_housing_grant(uuid,text,integer,text,boolean)', 'world_housing_grant_once(uuid,text,text)', 'world_housing_roll(uuid,text,numeric,text)',
    'world_housing_event_trg()', 'world_housing_title_trg()', 'world_housing_raid_trg()', 'world_housing_open(uuid)', 'world_housing_quest_trg()', 'world_housing_snapshot(uuid)',
    'world_housing_save(uuid,jsonb)', 'world_housing_store_move(text,integer,text)', 'world_housing_expand()', 'world_housing_gate(text)', 'world_housing_guest_write(uuid,text)',
    'world_housing_guest_delete(bigint)', 'world_housing_owned_kinds(uuid)',
    'world_pet_grant(uuid,text,text,boolean)', 'world_pet_grant_source(uuid,text)', 'world_pet_adopt(text)', 'world_pet_nickname(text,text)', 'world_pet_place(text)',
    'world_pet_walk(boolean)', 'world_pet_act(uuid,text,text)', 'world_pet_snapshot()', 'world_pet_room(uuid)', 'world_pet_quest_trg()', 'world_home_rule_count(uuid,jsonb)'] loop
    execute format('alter function public.%s owner to fn_owner_field', fn);
  end loop;
end $$;
revoke all on function public.world_housing_cap(int), public.world_housing_store_cap(int), public.world_housing_kind_cap(int), public.world_housing_item(text, text),
  public.world_housing_today(), public.world_housing_counts(jsonb, jsonb, text, text), public.world_housing_store_count(jsonb), public.world_housing_default_set() from public, anon, authenticated;
grant execute on function public.world_housing_cap(int), public.world_housing_store_cap(int), public.world_housing_kind_cap(int), public.world_housing_item(text, text),
  public.world_housing_today(), public.world_housing_counts(jsonb, jsonb, text, text), public.world_housing_store_count(jsonb), public.world_housing_default_set() to fn_owner_field;
do $$ begin
  set role fn_owner_field;
  revoke all on function public.world_housing_married(uuid, uuid), public.world_housing_blocked(uuid, uuid), public.world_housing_friends(uuid, uuid), public.world_housing_can_view(uuid, uuid, text),
    public.world_housing_edit_block(uuid), public.world_housing_grant(uuid, text, integer, text, boolean), public.world_housing_grant_once(uuid, text, text), public.world_housing_roll(uuid, text, numeric, text),
    public.world_housing_event_trg(), public.world_housing_title_trg(), public.world_housing_raid_trg(), public.world_housing_open(uuid), public.world_housing_quest_trg(), public.world_housing_owned_kinds(uuid),
    public.world_pet_grant(uuid, text, text, boolean), public.world_pet_grant_source(uuid, text), public.world_pet_room(uuid), public.world_pet_quest_trg(), public.world_home_rule_count(uuid, jsonb)
    from public, anon, authenticated;
  revoke all on function public.world_housing_snapshot(uuid), public.world_housing_save(uuid, jsonb), public.world_housing_store_move(text, integer, text), public.world_housing_expand(),
    public.world_housing_gate(text), public.world_housing_guest_write(uuid, text), public.world_housing_guest_delete(bigint),
    public.world_pet_adopt(text), public.world_pet_nickname(text, text), public.world_pet_place(text), public.world_pet_walk(boolean), public.world_pet_act(uuid, text, text), public.world_pet_snapshot()
    from public, anon;
  grant execute on function public.world_housing_snapshot(uuid), public.world_housing_save(uuid, jsonb), public.world_housing_store_move(text, integer, text), public.world_housing_expand(),
    public.world_housing_gate(text), public.world_housing_guest_write(uuid, text), public.world_housing_guest_delete(bigint),
    public.world_pet_adopt(text), public.world_pet_nickname(text, text), public.world_pet_place(text), public.world_pet_walk(boolean), public.world_pet_act(uuid, text, text), public.world_pet_snapshot()
    to authenticated;
  reset role;
end $$;

-- ─────────────────────────────────────────────────────────────
-- 소급: 7.2 전에 이미 마친 이야기 장·칭호·결전·외전·퀘스트 → 가구는 곳간, 동무는 도감(알림이 간다)
-- ─────────────────────────────────────────────────────────────
do $$ declare r record; begin
  for r in select distinct e.actor_id uid, 'chapter:' || (e.payload ->> 'chapter_id') src from public.world_events e
            where e.event_type = 'story' and e.payload ? 'chapter_id' and e.actor_id is not null
              and exists (select 1 from public.world_furniture_sources f where f.source = 'chapter:' || (e.payload ->> 'chapter_id'))
              and exists (select 1 from public.world_characters c where c.owner_id = e.actor_id) loop
    perform public.world_housing_grant_once(r.uid, r.src, '이야기 장 보상');
  end loop;
  for r in select distinct t.owner_id uid, f.source src from public.world_character_titles t
             join public.world_furniture_sources f on f.source = 'title:' || t.title_key
                  or (f.source = 'raid_final' and t.title_key = 'final_clear') or (f.source = 'gw_first' and t.title_key = 'gw_kill1') loop
    perform public.world_housing_grant_once(r.uid, r.src, '지난 기록 보상');
  end loop;
  for r in select distinct g.owner_id uid, s.source src from public.world_quest_progress g join public.world_pet_sources s on s.source = 'quest:' || g.quest_id where g.done_at is not null
           union select distinct t.owner_id, s.source from public.world_character_titles t join public.world_pet_sources s on s.source = 'title:' || t.title_key or (s.source = 'gw_first' and t.title_key = 'gw_kill1') loop
    perform public.world_pet_grant_source(r.uid, r.src);
  end loop;
end $$;
