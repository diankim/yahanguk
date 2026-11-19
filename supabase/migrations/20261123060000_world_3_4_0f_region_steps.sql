create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  if position(p_new in d) > 0 then return; end if;
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute replace(d, p_old, p_new);
end $$;

create or replace function public.world_quest_gate_reached(p_uid uuid, p_q text)
 returns boolean
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare q text := p_q; n int;
begin
  if p_q is null then return true; end if;
  if p_uid is null then return false; end if;
  if left(p_q, 1) = '+' then
    q := substr(p_q, 2);
    return exists (select 1 from public.world_quest_progress p where p.owner_id = p_uid and p.quest_id = q) or q = any (public.world_quest_done_ids(p_uid));
  end if;
  if position(':' in p_q) > 0 then
    q := split_part(p_q, ':', 1);
    n := split_part(p_q, ':', 2)::int;
    return exists (select 1 from public.world_quest_progress p where p.owner_id = p_uid and p.quest_id = q and (p.step >= n or p.done_at is not null)) or q = any (public.world_quest_done_ids(p_uid));
  end if;
  return q = any (public.world_quest_done_ids(p_uid));
end $function$;
revoke all on function public.world_quest_gate_reached(uuid, text) from public, anon, authenticated;
grant execute on function public.world_quest_gate_reached(uuid, text) to fn_owner_field;

select pg_temp.yh_patch('public.world_region_open(uuid,text)',
  $q$  if left(q, 1) = '+' then
    return exists (select 1 from public.world_quest_progress p where p.owner_id = p_uid and p.quest_id = substr(q, 2)) or substr(q, 2) = any (public.world_quest_done_ids(p_uid));
  end if;
  return q = any (public.world_quest_done_ids(p_uid));$q$,
  $q$  return public.world_quest_gate_reached(p_uid, q);$q$);

select pg_temp.yh_patch('public.world_domain_open(uuid,text)',
  $q$  if d ? 'open_quest' and not ((d ->> 'open_quest') = any (public.world_quest_done_ids(p_uid))) then return false; end if;$q$,
  $q$  if d ? 'open_quest' and not public.world_quest_gate_reached(p_uid, d ->> 'open_quest') then return false; end if;$q$);

do $d$
declare j jsonb := public.world_domain_rules();
begin
  j := jsonb_set(j, '{deungdo,open_quest}', '"mdq_5:2"'::jsonb);
  j := jsonb_set(j, '{jeongni,open_quest}', '"mdq_13:6"'::jsonb);
  j := jsonb_set(j, '{deungdo,regions}', '{"deungdo_landing": "mdq_5:2", "dark_yamen": "mdq_5:2", "martial_row": "mdq_5", "red_shrine_lane": "mdq_7", "old_ferry_market": "mdq_9", "lamp_rest": "mdq_9", "first_observatory": "mdq_11", "ash_palace": "mdq_14:6", "pact_court": "mdq_16:3"}'::jsonb);
  execute format('create or replace function public.world_domain_rules() returns jsonb language sql immutable as %L', format('select %L::jsonb', j::text));
end $d$;

update public.world_commissions m set target_region = x.region_id, title = x.region_name || ' 요괴 토벌', description = x.region_name || '에서 요괴를 쓰러뜨리세요.'
  from (select m2.owner_id, m2.day, m2.slot,
               coalesce((select r.region_id from public.world_map_regions r where r.active and not r.is_safe_zone and r.min_level <= c.level and r.min_level >= c.level - 10
                           and public.world_region_open(c.owner_id, r.region_id) order by md5(c.owner_id::text || m2.day::text || r.region_id) limit 1), 'field_outskirts') rid
          from public.world_commissions m2 join public.world_characters c on c.owner_id = m2.owner_id
         where m2.kind = 'hunt' and m2.day >= (now() at time zone 'Asia/Seoul')::date - 1 and m2.claimed_at is null and coalesce(m2.progress, 0) = 0
           and m2.target_region is not null and not public.world_region_open(m2.owner_id, m2.target_region)) z
  join public.world_map_regions x on x.region_id = z.rid
 where m.owner_id = z.owner_id and m.day = z.day and m.slot = z.slot;

update public.world_characters c set location = z.safe_name, current_exploration_node_id = null, travel_destination = null, travel_arrives_at = null, updated_at = now()
  from (select c2.owner_id,
               (select x.region_name from public.world_map_regions x
                 where x.is_safe_zone and x.active and x.min_level <= c2.level and public.world_region_open(c2.owner_id, x.region_id)
                 order by (x.territory_id is distinct from r.territory_id), (x.world_x - coalesce(r.world_x, 480)) ^ 2 + (x.world_y - coalesce(r.world_y, 360)) ^ 2 limit 1) safe_name
          from public.world_characters c2 join public.world_map_regions r on r.region_id = (public.world_field_region(c2.location)).region_id
         where c2.travel_arrives_at is null and not public.world_region_open(c2.owner_id, r.region_id)) z
 where c.owner_id = z.owner_id and z.safe_name is not null;

update public.world_patch_notes set body = body || $N$- 「명등기」의 땅과 지역이 이야기보다 먼저 지도에 보이던 것을 맞췄습니다. 이제 이야기가 그곳에 처음 가는 장면 바로 앞에서 열립니다(등도 옛터는 5장에서 거룻배를 고친 뒤).
$N$
 where note_id = '3.0.0' and position('이야기보다 먼저 지도에 보이던' in body) = 0;


update public.world_app_meta set value = '20261123060000' where key = 'db_version';
