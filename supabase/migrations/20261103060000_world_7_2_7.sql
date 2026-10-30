-- 7.2.7
-- 제보 22: 안전지대 사이를 잠깐 옮겨 다녀도 도착할 때마다 상태 굴림(나쁜 상태 약 24%)이 돌아 디버프가 붙던 것.
-- 안전지대에 도착한 이동은 상태를 굴리지 않고, 바깥 지역 도착도 굴림 값을 3배로 해 확률을 3분의 1로(나쁜 상태 약 24% → 약 8%, 사용자 결정).

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

select pg_temp.yh_patch('public.world_status_roll(text,jsonb)',
  $o$ roll:=random();$o$,
  $o$ roll:=random();
 if p_activity='travel' then roll := roll * 3; end if;$o$);
select pg_temp.yh_patch('public.world_status_roll(text,jsonb)',
  $o$ if p_activity='explore' and coalesce(p_context->>'kind','')='field_search' then return$o$,
  $o$ if p_activity='travel' and exists (select 1 from public.world_map_regions m where m.region_id = p_context->>'region_id' and m.is_safe_zone) then return jsonb_build_object('ok',true,'activity',p_activity,'applied',applied,'max_active',status_cap); end if;
 if p_activity='explore' and coalesce(p_context->>'kind','')='field_search' then return$o$);

update public.world_patch_notes set body = body || $n$

## 7.2.7
- 채팅 얼굴의 테두리를 프로필 카드의 테두리 그대로 작게 줄여 보여 줍니다(모서리 문양까지).
- 안전지대에 도착하는 이동에서는 상태이상이 붙지 않습니다(안전지대 사이를 오가기만 해도 디버프가 생기던 것, 제보 22). 바깥 지역에 도착할 때 상태이상이 붙을 확률도 3분의 1로 줄였습니다(약 24% → 약 8%).
$n$ where note_id = '7.2.0' and position('## 7.2.7' in body) = 0;

update public.world_app_meta set value = '20261103060000' where key = 'db_version';
