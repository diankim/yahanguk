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

do $d$
declare j jsonb := public.world_domain_rules();
begin
  j := jsonb_set(j, '{mukjeok,regions}', '{"mukchang_ferry": "+mkq_1", "blank_field": "+mkq_1", "meokbi_forest": "mkq_2", "myeongbu_tower": "mkq_3", "nine_court": "mkq_4"}'::jsonb);
  execute format('create or replace function public.world_domain_rules() returns jsonb language sql immutable as %L', format('select %L::jsonb', j::text));
end $d$;

select pg_temp.yh_patch('public.world_region_open(uuid,text)',
  $q$  return q = any (public.world_quest_done_ids(p_uid));$q$,
  $q$  if left(q, 1) = '+' then
    return exists (select 1 from public.world_quest_progress p where p.owner_id = p_uid and p.quest_id = substr(q, 2)) or substr(q, 2) = any (public.world_quest_done_ids(p_uid));
  end if;
  return q = any (public.world_quest_done_ids(p_uid));$q$);

select pg_temp.yh_patch('public.world_meisho_seen(uuid,text)',
  $q$  if rg is null then return false; end if;$q$,
  $q$  if rg is null or not public.world_region_open(p_uid, rg) then return false; end if;$q$);

select pg_temp.yh_patch('public.world_commission_board()',
  $q$min_level >= c.level - 10
      ORDER BY$q$,
  $q$min_level >= c.level - 10 AND public.world_region_open(uid, region_id)
      ORDER BY$q$);

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
         where not public.world_region_open(c2.owner_id, r.region_id)) z
 where c.owner_id = z.owner_id and z.safe_name is not null;

update public.world_patch_notes set body = body || $N$
- 묵적 봉쇄령도 이야기를 따라 지역이 하나씩 열립니다. 묵창 나루·빈칸 벌판은 「묵적록」 1장을 받으면, 먹비 숲은 2장, 명부 탑은 3장, 아홉 칸 뜰은 4장을 마치면 열립니다.
- 일일 의뢰의 요괴 토벌이 아직 열리지 않은 지역(꺼진 관아 터 등)으로 나오던 것을 고쳤습니다. 오늘 그렇게 받은 의뢰는 열린 지역으로 바꿔 두었습니다.$N$
 where note_id = '3.0.0' and position('묵적 봉쇄령도 이야기를 따라' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261119080000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
