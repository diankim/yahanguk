-- 제작 숙련 조건 문구: 「필요 숙련도: 단조 R5」 → 「단조 기술 5단계가 필요합니다(지금 2단계).」
grant fn_owner_18452 to postgres with inherit true;
do $$
declare d text;
  a text := $q$raise exception '필요 숙련도: % R%',case r.required_skill when 'alchemy' then '연금' when 'smithing' then '단조' when 'spirit_gathering' then '영기 채집' when 'wardcraft' then '결계 각인' else r.required_skill end,r.required_skill_rank;$q$;
begin
  d := pg_get_functiondef('public.world_craft_item(text)'::regprocedure);
  if position(a in d) = 0 then
    if position('기술 %단계가 필요합니다' in d) > 0 then return; end if;
    raise exception '제작 함수에서 숙련 조건 문구를 찾지 못했습니다';
  end if;
  execute replace(d, a, $q$raise exception '% 기술 %단계가 필요합니다(지금 %단계). 캐릭터 › 기술에서 확인하세요.',case r.required_skill when 'alchemy' then '연금' when 'smithing' then '단조' when 'spirit_gathering' then '영기 채집' when 'wardcraft' then '결계 각인' else r.required_skill end,r.required_skill_rank,coalesce((c.skill_progress->r.required_skill->>'rank')::int,1);$q$);
end $$;
grant fn_owner_18452 to postgres with inherit false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028091000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
