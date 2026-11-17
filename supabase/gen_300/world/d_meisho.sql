create or replace function public.world_meisho_seen(p_uid uuid, p_meisho text) returns boolean
language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare rg text; t text;
begin
  select m.region_id, r.territory_id into rg, t from public.world_meisho m join public.world_map_regions r on r.region_id = m.region_id where m.meisho_id = p_meisho;
  if rg is null then return false; end if;
  if not coalesce((public.world_domain_rules() -> t -> 'fx' ->> 'white_night')::boolean, false) then return true; end if;
  return public.world_deungdo_night(p_uid, rg);
end $$;
revoke all on function public.world_meisho_seen(uuid, text) from public, anon, authenticated;

do $d$
declare f text; o text;
begin
  foreach f in array array['public.world_field_search()', 'public.world_meisho_dig(text)', 'public.world_meisho_field(uuid,text,uuid)', 'public.world_meisho_alert_tick()',
    'public.world_field_snapshot()', 'public.world_meisho_soil(text)'] loop
    if to_regprocedure(f) is null then continue; end if;
    o := pg_get_userbyid((select proowner from pg_proc where oid = to_regprocedure(f)));
    if o like 'fn_owner%' then
      execute format('grant execute on function public.world_meisho_seen(uuid, text) to %I', o);
      execute format('grant execute on function public.world_deungdo_night(uuid, text) to %I', o);
    end if;
  end loop;
end $d$;

select pg_temp.yh_patch('public.world_field_search()',
  'AND NOT EXISTS (SELECT 1 FROM public.world_meisho_finds f WHERE f.owner_id = uid AND f.meisho_id = x.meisho_id)',
  'AND NOT EXISTS (SELECT 1 FROM public.world_meisho_finds f WHERE f.owner_id = uid AND f.meisho_id = x.meisho_id) AND public.world_meisho_seen(uid, x.meisho_id)');

select pg_temp.yh_patch('public.world_meisho_field(uuid,text,uuid)',
  'where x.node_id = p_node and x.active order by x.sort loop',
  'where x.node_id = p_node and x.active and public.world_meisho_seen(p_uid, x.meisho_id) order by x.sort loop');
select pg_temp.yh_patch('public.world_meisho_field(uuid,text,uuid)',
  'near := exists (select 1 from public.world_meisho x where x.node_id = p_node and x.active and lv >= x.min_level',
  'near := exists (select 1 from public.world_meisho x where x.node_id = p_node and x.active and lv >= x.min_level and public.world_meisho_seen(p_uid, x.meisho_id)');
select pg_temp.yh_patch('public.world_meisho_field(uuid,text,uuid)',
  'where x.region_id = p_region and x.active and coalesce((w2.w ->> ''open'')::boolean, false);',
  'where x.region_id = p_region and x.active and public.world_meisho_seen(p_uid, x.meisho_id) and coalesce((w2.w ->> ''open'')::boolean, false);');
select pg_temp.yh_patch('public.world_meisho_field(uuid,text,uuid)',
  'if not public.world_domain_open(p_uid, m.territory_id) then continue; end if;',
  'if not public.world_domain_open(p_uid, m.territory_id) or not public.world_meisho_seen(p_uid, m.meisho_id) then continue; end if;');

select pg_temp.yh_patch('public.world_meisho_alert_tick()',
  'and public.world_domain_open(c.owner_id, terr)',
  'and public.world_domain_open(c.owner_id, terr) and public.world_meisho_seen(c.owner_id, m.meisho_id)');

select pg_temp.yh_patch('public.world_meisho_dig(text)',
  'np numeric; ex int;', 'np numeric; lp numeric; ex int;');
select pg_temp.yh_patch('public.world_meisho_dig(text)',
  '  if f.dug_at is not null and f.dug_at = (w ->> ''open_at'')::timestamptz then',
  '  if not public.world_meisho_seen(uid, m.meisho_id) then
    raise exception ''흰 밤이 걷히지 않은 곳이라 명소가 보이지 않습니다. 이 구역의 밤을 먼저 되찾으세요.'' using hint = ''mz_closed''; end if;
  if f.dug_at is not null and f.dug_at = (w ->> ''open_at'')::timestamptz then');
select pg_temp.yh_patch('public.world_meisho_dig(text)',
  '    if random() * 100 < np then extra := extra || jsonb_build_object(k -> ''items'' ->> 2, 1); end if;
  end if;',
  '    if random() * 100 < np then extra := extra || jsonb_build_object(k -> ''items'' ->> 2, 1); end if;
  end if;
  if ru ? ''lamp'' and rank >= (ru #>> ''{lamp,rank}'')::int
     and (select r.territory_id from public.world_map_regions r where r.region_id = m.region_id) in (select jsonb_array_elements_text(ru -> ''lamp'' -> ''territory'')) then
    lp := least((ru #>> ''{lamp,pct,cap}'')::numeric, (ru #>> ''{lamp,pct,base}'')::numeric + public.world_meisho_gear(uid, ''mz_l_pct''));
    if random() * 100 < lp then extra := extra || jsonb_build_object(ru -> ''lamp'' -> ''items'' ->> m.kind, 1); end if;
  end if;');
