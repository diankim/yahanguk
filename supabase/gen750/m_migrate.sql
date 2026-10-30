
-- ── 쌓은 경험 이주·생활 전문화 정리·택일 무료 다시 고르기·칭호 판정(한 번만) ──────────────
do $m$
declare ch record; sp jsonb; relic int; fishn int; f int; h int; sg int; mi int; nprof_c text; nprof_g text; note text; fr text[];
  cnt jsonb; ln text; nx int; got text;
begin
  if exists (select 1 from public.world_app_meta where key = 'skills_750_migrated') then return; end if;
  perform set_config('yh.rank_sync', 'all', true);

  -- 합쳐지는 채집 계열의 택일은 채집의 같은 칸이 비었을 때만 옮긴다
  update public.world_skill_picks pk set picks = pk.picks || coalesce((
      select jsonb_object_agg('foraging:' || split_part(e.key, ':', 2), e.value) from jsonb_each(pk.picks) e
       where e.key ~ '^(herbalism|spirit_gathering):(24|43)$' and not pk.picks ? ('foraging:' || split_part(e.key, ':', 2))), '{}'::jsonb),
    updated_at = now()
   where pk.picks ?| array['herbalism:24', 'herbalism:43', 'spirit_gathering:24', 'spirit_gathering:43'];
  -- 효과가 바뀐 택일 칸은 한 번 무료로 다시 고른다(기한 없음, 롤백 때 함께 사라짐)
  update public.world_skill_picks pk set free_repick = array(select e.key from jsonb_each(pk.picks) e where e.key ~ '^(smithing|wardcraft|alchemy|foraging):(24|43)$' order by e.key)
   where exists (select 1 from jsonb_each(pk.picks) e where e.key ~ '^(smithing|wardcraft|alchemy|foraging):(24|43)$');

  for ch in select c.owner_id, c.skill_progress, c.cooking_xp, c.crafting_profession, c.gathering_profession from public.world_characters c loop
    sp := coalesce(ch.skill_progress, '{}'::jsonb);
    -- 새 제작 계열 넷 = 12 × 그 분야 제작 기록(단조 경험은 깎지 않음)
    select coalesce(jsonb_object_agg(x.fld, x.n), '{}'::jsonb) into cnt from (
      select r.craft_field fld, count(*)::int n from public.world_events e join public.world_crafting_recipes r on r.recipe_id = e.payload ->> 'recipe'
       where e.actor_id = ch.owner_id and e.event_type = 'craft' group by 1) x;
    foreach ln in array array['carpentry', 'artifice', 'weaving', 'leatherwork'] loop
      nx := 12 * coalesce((cnt ->> ln)::int, 0);
      if nx > coalesce((sp -> ln ->> 'xp')::int, 0) then sp := sp || jsonb_build_object(ln, coalesce(sp -> ln, '{}'::jsonb) || jsonb_build_object('xp', nx)); end if;
    end loop;
    -- 요리 계열 = 요리 숙련 경험(1:1)
    nx := coalesce(ch.cooking_xp, 0);
    if nx > coalesce((sp -> 'cooking' ->> 'xp')::int, 0) then sp := sp || jsonb_build_object('cooking', coalesce(sp -> 'cooking', '{}'::jsonb) || jsonb_build_object('xp', nx)); end if;
    -- 채집 = 일반 + 약초 + 영기 − 유물 몫(셋 가운데 가장 컸던 값 아래로는 내리지 않음) · 채광 = 광맥 + 8 × 유물 기록 · 낚시 = 8 × 낚시 기록
    select count(*) filter (where e.event_type = 'gather' and e.payload ->> 'category' = 'relics')::int, count(*) filter (where e.event_type = 'fish')::int
      into relic, fishn from public.world_events e where e.actor_id = ch.owner_id and e.event_type in ('gather', 'fish');
    f := coalesce((sp -> 'foraging' ->> 'xp')::int, 0); h := coalesce((sp -> 'herbalism' ->> 'xp')::int, 0);
    sg := coalesce((sp -> 'spirit_gathering' ->> 'xp')::int, 0); mi := coalesce((sp -> 'mining' ->> 'xp')::int, 0);
    sp := sp || jsonb_build_object('foraging', coalesce(sp -> 'foraging', '{}'::jsonb) || jsonb_build_object('xp', greatest(f, h, sg, f + h + sg - 8 * relic)));
    sp := sp || jsonb_build_object('mining', coalesce(sp -> 'mining', '{}'::jsonb) || jsonb_build_object('xp', mi + 8 * relic));
    if 8 * fishn > coalesce((sp -> 'fishing' ->> 'xp')::int, 0) then sp := sp || jsonb_build_object('fishing', coalesce(sp -> 'fishing', '{}'::jsonb) || jsonb_build_object('xp', 8 * fishn)); end if;
    -- 생활 전문화: 종합 제작 → 단조, 약초학·영기 채취 → 채집(바뀐 사람은 72시간 잠금 없이 바로 다시 고를 수 있게)
    nprof_c := case when ch.crafting_profession in ('smithing', 'carpentry', 'artifice', 'sealing', 'weaving', 'leatherwork', 'alchemy', 'cooking') then ch.crafting_profession else 'smithing' end;
    nprof_g := case when ch.gathering_profession in ('fieldwork', 'mining', 'fishing') then ch.gathering_profession else 'fieldwork' end;
    update public.world_characters set skill_progress = sp, crafting_profession = nprof_c, gathering_profession = nprof_g,
      life_changed_at = case when nprof_c is distinct from crafting_profession or nprof_g is distinct from gathering_profession then null else life_changed_at end,
      updated_at = now()
     where owner_id = ch.owner_id;
    -- 알림 한 번
    select free_repick into fr from public.world_skill_picks where owner_id = ch.owner_id;
    note := '제작은 단조·목공·법구 공예·봉인 공예·직조·가죽 공예·연금·요리 여덟 계열, 채집은 채집·채광·낚시 세 계열로 나뉘었습니다. 지금까지 쌓은 경험을 옮겨 단계를 다시 매겼습니다. 캐릭터 › 기술에서 확인하세요.';
    if nprof_c is distinct from ch.crafting_profession then note := note || ' 종합 제작이 없어져 제작 분야가 단조로 정해졌습니다. 지금 한 번은 기다리지 않고 바로 바꿀 수 있습니다.';
    elsif nprof_g is distinct from ch.gathering_profession then note := note || ' 채집 분야가 「채집」으로 합쳐졌습니다. 지금 한 번은 기다리지 않고 바로 바꿀 수 있습니다.'; end if;
    if coalesce(cardinality(fr), 0) > 0 then note := note || ' 효과가 바뀐 택일 기술은 한 번 무료로 다시 고를 수 있습니다.'; end if;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (ch.owner_id, 'skill_rerank', '생산 기술이 바뀌었습니다(7.5.0)', note, jsonb_build_object('v', '7.5.0', 'free_repick', coalesce(to_jsonb(fr), '[]'::jsonb)));
  end loop;

  alter table public.world_characters add constraint world_characters_crafting_profession_chk
    check (crafting_profession is null or crafting_profession in ('smithing', 'carpentry', 'artifice', 'sealing', 'weaving', 'leatherwork', 'alchemy', 'cooking'));
  alter table public.world_characters add constraint world_characters_gathering_profession_chk
    check (gathering_profession is null or gathering_profession in ('fieldwork', 'mining', 'fishing'));

  -- 새 기술 칭호를 지금 단계로 한 번 판정하고, 이번에 생긴 칭호 알림은 한 사람에 한 번으로 묶는다
  for ch in select c.owner_id, c.character_name from public.world_characters c where not coalesce(c.is_dead, false) loop
    perform set_config('request.jwt.claim.sub', ch.owner_id::text, true);
    perform public.world_title_award_check(ch.owner_id, 'skill');
    select string_agg(n.content, ' ' order by n.id) into got from public.world_notifications n
     where n.user_id = ch.owner_id and n.kind = 'title' and n.created_at = now();
    if got is not null then
      delete from public.world_notifications n where n.user_id = ch.owner_id and n.kind = 'title' and n.created_at = now();
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (ch.owner_id, 'title', '기술 칭호를 얻었습니다', regexp_replace(got, ' · 캐릭터 › 칭호에서 장착할 수 있습니다\.', '', 'g') || ' · 캐릭터 › 칭호에서 장착할 수 있습니다.', '{}'::jsonb);
    end if;
  end loop;
  perform set_config('request.jwt.claim.sub', '', true);
  insert into public.world_app_meta(key, value) values ('skills_750_migrated', now()::text) on conflict (key) do nothing;
end $m$;
