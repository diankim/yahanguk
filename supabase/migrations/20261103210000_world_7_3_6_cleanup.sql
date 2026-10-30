-- 7.3.6 점검 정리: 조사원(authenticated)·비로그인(anon)이 직접 부를 필요가 없는 함수의 실행 권한을 거둔다.
-- 함수는 지우지 않는다. 다른 security definer 함수·트리거 안에서는 함수 주인 권한으로 부르므로 그대로 돈다.
-- 화면(assets/js)이 부르는 이름은 건드리지 않았고, 부른 쪽 권한으로 도는(security invoker) 함수가 부르는 것
-- (world_shop_sell_unit·world_river_boat_member·world_gwiheo_open)은 남겼다.
-- 주인이 fn_owner_* 역할인 함수의 권한은 그 역할이 준 것이라 그 역할로 바꿔서 거둔다(CLAUDE.md §16).
do $do$
declare
  r record; o text; had_set boolean;
  -- ① 비로그인도 부를 수 있던 도우미(효과 합계·지역 이웃 등): anon에서만 거둔다
  anon_only text[] := array['world_bond_self','world_erosion_effect','world_erosion_pct_self','world_faction_rank_effect','world_gear_self',
    'world_idle_skill_for','world_job_effect','world_level_gap_effect','world_raid_lock_effect','world_region_danger','world_region_neighbors',
    'world_shop_sell_unit','world_skill_effect','world_title_bonus_of','world_title_extra','world_trail_effect'];
  -- ② 화면이 부르지 않는 안쪽 도우미·트리거 함수·옛 판(v1): 조사원·비로그인 모두에서 거둔다
  inner_fns text[] := array['world_affil_effect','world_allocate_stat','world_bond_active','world_bond_block_reason','world_bond_bonus',
    'world_bond_on_block','world_bond_on_event','world_bond_on_whisper','world_bond_partner','world_bond_self','world_bond_together',
    'world_dismantle_yield','world_enhance_cleanup','world_enhance_level','world_erosion_effect','world_erosion_pct_self',
    'world_exploration_snapshot','world_faction_rel','world_gear_self','world_idle_skill_for','world_invite_admin','world_island_effect',
    'world_job_effect','world_letter_unread','world_level_gap_effect','world_on_island','world_raid_lock_effect','world_region_danger',
    'world_region_neighbors','world_river_boat_rank','world_set_life_profession','world_set_profile','world_shop_sell_status',
    'world_skill_effect','world_social_effect','world_title_bonus_of','world_title_extra','world_trail_effect','world_travel_party_respond',
    'world_wedding_here'];
begin
  for r in select p.oid, p.proname, pg_get_userbyid(p.proowner) owner, pg_get_function_identity_arguments(p.oid) args
             from pg_proc p where p.pronamespace = 'public'::regnamespace and (p.proname = any(anon_only) or p.proname = any(inner_fns)) loop
    o := r.owner; had_set := true;
    if o <> current_user then
      select coalesce(bool_or(am.set_option), false) into had_set from pg_auth_members am where am.roleid = o::regrole and am.member = current_user::regrole;
      if not had_set then execute format('grant %I to %I with set true', o, current_user); end if;
      execute format('set role %I', o);
    end if;
    -- PUBLIC로 열려 있던 함수는 PUBLIC을 거두기 전에 다른 함수 주인 역할(fn_owner_*)·postgres·service_role에 직접 준다
    -- (그 역할들이 주인인 함수가 안에서 부르는 길이 끊기지 않게)
    if exists (select 1 from aclexplode(coalesce((select proacl from pg_proc where oid = r.oid), acldefault('f', (select proowner from pg_proc where oid = r.oid)))) a where a.grantee = 0) then
      execute (select format('grant execute on function public.%I(%s) to %s', r.proname, r.args, string_agg(quote_ident(rolname), ', '))
                 from pg_roles where rolname like 'fn\_owner\_%' or rolname in ('postgres', 'service_role'));
    end if;
    execute format('revoke execute on function public.%I(%s) from public, anon', r.proname, r.args);
    if r.proname = any(inner_fns) then execute format('revoke execute on function public.%I(%s) from authenticated', r.proname, r.args); end if;
    execute 'reset role';
    if not had_set then execute format('grant %I to %I with set false', o, current_user); end if;
  end loop;
end $do$;

update public.world_app_meta set value = '20261103210000' where key = 'db_version';
