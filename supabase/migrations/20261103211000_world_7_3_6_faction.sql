-- 7.3.6 대세력 기본 혜택: 야행국 정통파·흑련회는 가입만으로 받는 혜택이 없었다(「보급과 법적 권한」「정보·암시장」은 글뿐, 등급 효과만 있음).
-- 다른 다섯 세력(원정 피해 −20%·강행 전리품 +15%·원정 채집 +15%·답사 +20%·가방 +6칸)과 비슷한 크기로 수치를 단다.
--   정통파: 공인 조사 수당 — 원정을 마치고 돌아오면 경험치·숙련 경험·전 +15%
--           법적 권한 — 본부 구조대가 어디서든 소속 세력 구조대로 온다(비용 반값·경험치 손실 없음·체력 50)
--   흑련회: 정보망 — 희귀품 발견 +5%(등급 효과 +1%씩과 더함) · 암시장 줄 — 상점 하루 판매 한도 +500전(그림자 장부 +300전씩과 더함)

create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $f$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
  execute replace(d, p_old, p_new);
end $f$;

-- 정통파 원정 보상 +15%(완주·조기 귀환 모두, 경험치는 완주했을 때만 있다)
select pg_temp.yh_patch('public.world_expedition_complete(boolean)',
  '  cap := c.bag_capacity + case when c.major_faction_id',
  '  -- 정통파 공인 조사 수당(7.3.6): 원정 경험치·숙련 경험·전 +15%
  if c.major_faction_id = ''night_office'' then
    xp := round(xp * 1.15); cxp := round(cxp * 1.15); gxp := round(gxp * 1.15); ixp := round(ixp * 1.15); gil_gain := round(gil_gain * 1.15);
  end if;
  cap := c.bag_capacity + case when c.major_faction_id');

-- 정통파 법적 권한: 어디서든 소속 세력 구조대
select pg_temp.yh_patch('public.world_call_rescue()',
  'own := s.control_faction_id is not null and s.control_faction_id = c.major_faction_id;',
  'own := (s.control_faction_id is not null and s.control_faction_id = c.major_faction_id) or c.major_faction_id = ''night_office'';');

-- 흑련회 암시장 줄: 판매 한도 +500전
select pg_temp.yh_patch('public.world_affil_cap()',
  '  select (case when c.faction_key = ''headquarters'' then 500 else 0 end',
  '  select (case when c.faction_key = ''headquarters'' then 500 else 0 end
        + case when c.major_faction_id = ''black_lotus'' then 500 else 0 end');

-- 흑련회 정보망: 희귀품 +5%(가입만으로, 가입 퀘스트와 상관없이)
select pg_temp.yh_patch('public.world_faction_rank_effect(text)',
  E'), 0)::numeric\n) yhq limit 1);',
  E'), 0)::numeric\n    + coalesce((select case when c2.major_faction_id = ''black_lotus'' and p_key = ''rare_loot_pct'' then 5 else 0 end\n                  from public.world_characters c2 where c2.owner_id = public.fn_owner_auth_uid()), 0)\n) yhq limit 1);');

update public.world_app_meta set value = '20261103211000' where key = 'db_version';
