-- 7.2.1 보안: 화면이 부르지 않는 옛 함수·안쪽 도우미를 조사원이 직접 부르지 못하게 한다.
--  · world_bond_gain   아무 연리에 인연도를 하루 100까지 더할 수 있었다(혼례 조건을 바로 채움)
--  · world_bond_note   아무에게나 원하는 알림을 보낼 수 있었다
--  · world_bond_expire 연리 신청 만료 정리(world_bond_propose·snapshot이 안에서 부른다)
--  · world_travel_region 옛 이동(운임 없이 이동) — 지금은 world_travel_route
--  · world_travel_party_invite 옛 동승 신청 — 지금은 _v2
--  · world_region_encounter·world_case_combine 옛 조우·옛 사건 조합 — 화면에서 뺀 기능
-- 함수는 지우지 않는다. 주인이 fn_owner_* 역할이면 그 역할로 거둬야 하므로 주인마다 set role.
-- postgres가 SET 권한 없이 ADMIN만 가진 주인 역할은 잠깐 SET을 켜고 끝나면 다시 끈다.
-- 안에서 부르는 함수(같은 주인 fn_owner_field)는 주인 권한으로 그대로 부른다.
do $$
declare r record; need_set boolean;
begin
  for r in
    select p.oid::regprocedure sig, pg_get_userbyid(p.proowner) owner
      from pg_proc p
     where p.pronamespace = 'public'::regnamespace
       and p.proname in ('world_bond_gain','world_bond_note','world_bond_expire','world_travel_region',
                         'world_travel_party_invite','world_region_encounter','world_case_combine')
  loop
    need_set := r.owner <> 'postgres' and not exists (
      select 1 from pg_auth_members am where am.roleid = r.owner::regrole and am.member = 'postgres'::regrole and am.set_option);
    if need_set then execute format('grant %I to postgres with set true', r.owner); end if;
    if r.owner <> 'postgres' then execute format('set role %I', r.owner); end if;
    execute format('revoke all on function %s from public, anon, authenticated', r.sig);
    -- 옛 동승 기록(world_record_mount_passengers, 주인 fn_owner_19208)이 world_travel_region을 부른다
    if r.sig::text like 'world_travel_region(%' then execute format('grant execute on function %s to fn_owner_19208', r.sig); end if;
    reset role;
    if need_set then execute format('grant %I to postgres with set false', r.owner); end if;
  end loop;
end $$;

update public.world_patch_notes set body = body || $N$

## 7.2.1
- 안전지대 화면에도 탐색력과 다음 회복까지 남은 시간을 보입니다(쉬어서 채운 뒤 떠날 때를 정하기 쉽게).
- 가방 소지품 목록과 제작법 카드에 먹거나 쓰면 오르는 양(체력·정신·영력·상태)을 바로 적습니다.
- 서버 점검: 쓰이지 않던 옛 기능 몇 가지를 조사원이 직접 부를 수 없게 막았습니다(게임 진행에는 영향 없음).
$N$
 where note_id = '7.2.0' and body not like '%## 7.2.1%';

update public.world_app_meta set value = '20261103010000' where key = 'db_version';
