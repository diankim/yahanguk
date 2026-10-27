-- 희귀도 이름을 칭호 등급과 같게: 범품·양품·진품·명품·신품(낚시 알림 문구)
do $$
declare d text; a text := $q$rname := case sp.rarity when 'uncommon' then '고급' when 'rare' then '희귀' when 'epic' then '영웅' when 'legendary' then '전설' else '' end;$q$;
begin
  d := pg_get_functiondef('public.world_fish()'::regprocedure);
  if position(a in d) = 0 then
    if position('''신품''' in d) > 0 then return; end if;
    raise exception '낚시 함수에서 희귀도 이름 줄을 찾지 못했습니다';
  end if;
  execute replace(d, a, $q$rname := case sp.rarity when 'uncommon' then '양품' when 'rare' then '진품' when 'epic' then '명품' when 'legendary' then '신품' else '' end;$q$);
end $$;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028090000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
