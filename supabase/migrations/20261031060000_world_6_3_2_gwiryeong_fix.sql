-- 6.3.2 귀령초 확률 바로잡기: world_gwiryeong_chance가 「금단 보스」를 요괴 역할 'main'으로 가렸는데,
-- 'main'은 지역마다 있는 대표 요괴(77종)라 위험도 7 이상 지역의 일반 토벌 대부분이 1%(위험도 10은 1.5%)를 받았다
-- (10-29 하루 위험도 7+ 토벌 승리 808번·평균 0.46%·귀령초 4개). 금단 보스는 구중 봉연의 우두머리로만 본다.
-- 그 밖의 확률(일반 0.06%·정예 0.2%·우두머리 0.6%·채집 0.08%·원정 완주 0.4%)은 그대로, 7.0에서 다시 정한다.
lock table public.world_characters in access exclusive mode;

do $$ declare d text; a text; n int;
begin
  d := pg_get_functiondef('public.world_gwiryeong_chance(text,jsonb)'::regprocedure);
  a := 'when exists (select 1 from public.world_region_monsters m where m.monster_id = p_payload ->> ''monster_id'' and m.role = ''main'') then 0.01';
  if position(a in d) > 0 then
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 귀령초(%)', n; end if;
    execute replace(d, a, 'when p_payload ->> ''region_id'' = ''sealed_abyss'' and p_payload ->> ''rank'' = ''guardian'' then 0.01');
  end if;
end $$;

update public.world_patch_notes set body = body || E'\n### 6.3.2\n- **귀령초 확률 바로잡기**: 위험도 높은 지역의 일반 요괴가 우두머리급 확률로 귀령초를 떨어뜨리던 오류를 고쳤습니다. 이제 처음 정한 확률대로 나옵니다(구중 봉연 우두머리만 가장 높은 확률).\n'
 where note_id = '6.3.0' and position('### 6.3.2' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261031060000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
