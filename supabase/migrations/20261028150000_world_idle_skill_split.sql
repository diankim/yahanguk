-- 자율 활동이 올리는 기술 계열을 캐릭터에 맞게 나눈다.
--   자율 수련: 장착한 무기 종류 — 근접(melee)·원거리(ranged)·술법(magic → 봉인술 sealing). 무기가 없으면 근접.
--   장비 정비: 생활 전문화의 제작 분야 — 봉인 공예 → 결계 각인, 연금 → 연금, 그 밖 → 단조.
--   자료 조사: 추적(그대로).
-- 정비 기술 단계도 다른 기술처럼 100마다 한 단계로 맞춘다(전에는 수령할 때만 120으로 계산).

create or replace function public.world_idle_skill_for(p_owner uuid, p_activity text)
returns text language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select case p_activity
    when 'training' then coalesce((
      select case i.equipment_traits ->> 'weapon_type' when 'ranged' then 'ranged' when 'magic' then 'sealing' else 'melee' end
        from public.world_character_equipment e join public.world_item_catalog i on i.item_id = e.item_id
       where e.owner_id = p_owner and e.slot = 'weapon' limit 1), 'melee')
    when 'research' then 'tracking'
    when 'maintenance' then coalesce((
      select case c.crafting_profession when 'sealing' then 'wardcraft' when 'alchemy' then 'alchemy' else 'smithing' end
        from public.world_characters c where c.owner_id = p_owner), 'smithing')
    else null end
$$;
alter function public.world_idle_skill_for(uuid, text) owner to fn_owner_field;
revoke all on function public.world_idle_skill_for(uuid, text) from public;
grant execute on function public.world_idle_skill_for(uuid, text) to fn_owner_19181;

grant fn_owner_19181 to postgres with inherit true;
do $$
declare d text;
  a1 text := $q$v_skill:=case v.activity_type when 'training' then 'melee' when 'research' then 'tracking' when 'maintenance' then 'wardcraft' else null end;$q$;
  a2 text := $q$'rank',least(50,1+floor(least(600000,v_old_skill_xp+v_skill_xp)/120.0)::integer)$q$;
begin
  d := pg_get_functiondef('public.world_claim_idle_activity()'::regprocedure);
  if position('world_idle_skill_for' in d) > 0 then return; end if;
  if position(a1 in d) = 0 then raise exception '자율 활동 수령 함수에서 기술 줄을 찾지 못했습니다'; end if;
  d := replace(d, a1, $q$v_skill:=public.world_idle_skill_for(v.owner_id, v.activity_type);$q$);
  d := replace(d, a2, $q$'rank',least(50,1+floor(least(600000,v_old_skill_xp+v_skill_xp)/100.0)::integer)$q$);
  execute d;
end $$;
grant fn_owner_19181 to postgres with inherit false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028150000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
