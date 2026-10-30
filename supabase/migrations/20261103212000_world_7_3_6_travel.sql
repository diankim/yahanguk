-- 7.3.6 이동 중에 제작·분해·강화·수리·상점·거래소가 되던 것(사용자 제보): 원정·자율 활동 중에는 막혔지만 이동 중에는 막는 곳이 없었다.
-- 행동 기록(world_events) 앞에서 도는 world_guard_action_context에서 이동 중(travel_arrives_at이 남아 있음)이면 거절한다.
-- 물품 사용·장비 바꾸기·채팅·서신 글은 이동 중에도 된다(지금과 같음).
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

select pg_temp.yh_patch('public.world_guard_action_context()',
  '  IF r.region_id IS NOT NULL AND r.is_safe_zone AND k IN (''encounter'', ''combat'') THEN',
  '  -- 이동 중에는 제작·분해·강화·수리·상점·거래소를 할 수 없다(7.3.6)
  IF (k IN (''craft'', ''dismantle'', ''enhance'', ''repair'', ''shop_buy'', ''shop_sell'') OR (k = ''trade'' AND (p ? ''unit_price'' OR p ? ''gil'')))
     AND EXISTS (SELECT 1 FROM public.world_characters wc WHERE wc.owner_id = new.actor_id AND wc.travel_arrives_at IS NOT NULL) THEN
    RAISE EXCEPTION ''이동 중에는 할 수 없습니다. 도착한 뒤 다시 시도하세요.'';
  END IF;
  IF r.region_id IS NOT NULL AND r.is_safe_zone AND k IN (''encounter'', ''combat'') THEN');

update public.world_app_meta set value = '20261103212000' where key = 'db_version';
