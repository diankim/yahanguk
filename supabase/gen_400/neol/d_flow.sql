create or replace function public.world_raid_settle(p_raid uuid, p_won boolean)
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare rd public.world_raids%rowtype; m record; tot numeric; share numeric; rw_gil int; xp int; items jsonb; inv jsonb; lim int; k text; v int; room int; xg text;
  got text; lost text; cleared boolean; top uuid; revenge boolean; nxt timestamptz; reg text; sr jsonb := public.world_raid_boss_rules(p_raid); t0 timestamptz; stay numeric; lvm numeric;
  nl boolean; nd jsonb; ng jsonb;
begin
  select * into rd from public.world_raids where raid_id = p_raid for update;
  if rd.status in ('won', 'failed') then return; end if;
  nl := rd.kind = 'world' and rd.boss_key = 'neol'; nd := sr -> 'drop'; ng := sr -> 'gear';
  perform public.world_raid_recontrib(p_raid);
  t0 := coalesce(rd.signup_until, rd.created_at);
  update public.world_raids set status = case when p_won then 'won' else 'failed' end, ended_at = now(), intent = null, updated_at = now() where raid_id = p_raid;
  select coalesce(sum(contrib), 0) into tot from public.world_raid_members where raid_id = p_raid;
  select owner_id into top from public.world_raid_members where raid_id = p_raid order by contrib desc limit 1;
  revenge := rd.kind = 'world' and not nl and p_won and exists (select 1 from public.world_raid_locks where until > now() and kind = 'lock');
  for m in select x.*, ch.level clv from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id where x.raid_id = p_raid loop
    share := case when tot > 0 then m.contrib / tot else 0 end;
    stay := least(1, greatest(0, extract(epoch from now() - greatest(m.joined_at, t0))) / greatest(1, extract(epoch from now() - t0)) / (sr ->> 'stay_full')::numeric);
    lvm := least(1, m.clv / (sr ->> 'gil_lv')::numeric);
    rw_gil := 0; xp := 0; items := '{}'::jsonb;
    if nl then
      if share >= 0.01 and m.acts > 0 then
        if p_won then
        rw_gil := round(least((sr ->> 'gil_cap')::numeric, 300 * stay + 1700 * share) * lvm); xp := round(public.world_xp_need(m.clv) * least(0.35, 0.10 * stay + 0.6 * share));
        items := jsonb_build_object(nd ->> 'item', least((nd ->> 'win_max')::int, (nd ->> 'win_min')::int + floor((nd ->> 'win_k')::numeric * share)::int));
        if random() < (ng ->> 'p')::numeric + (ng ->> 'p_share')::numeric * share then
          items := items || jsonb_build_object(ng -> 'items' ->> floor(random() * jsonb_array_length(ng -> 'items'))::int, 1); end if;
        else
        rw_gil := round((80 * stay + 300 * share) * lvm); xp := round(public.world_xp_need(m.clv) * 0.03 * stay);
        items := jsonb_build_object(nd ->> 'item', (nd ->> 'fail_min')::int + (share >= (nd ->> 'fail_share')::numeric)::int);
        end if;
      end if;
    elsif rd.kind = 'world' then
      if share >= 0.01 and m.acts > 0 then
        if p_won then
        rw_gil := round(least(1800, 300 * stay + 1700 * share) * lvm); xp := round(public.world_xp_need(m.clv) * least(0.35, 0.10 * stay + 0.6 * share));
        items := jsonb_build_object('seal_shard', 3 + floor(12 * share)::int);
        if random() < 0.45 then items := items || jsonb_build_object('spirit_core', 1 + (random() < 0.4)::int); end if;
        if random() < 0.25 then items := items || jsonb_build_object('heavenly_dew', 1); end if;
        if random() < 0.04 + 0.08 * share then items := items || jsonb_build_object((array['raid_norigae', 'raid_amulet', 'raid_mask'])[1 + floor(random() * 3)::int], 1); end if;
        else
        rw_gil := round((80 * stay + 300 * share) * lvm); xp := round(public.world_xp_need(m.clv) * 0.03 * stay); items := '{"seal_shard":1}'::jsonb;
        end if;
      end if;
    else
      cleared := exists (select 1 from public.world_raid_members y join public.world_raids z on z.raid_id = y.raid_id
        where y.owner_id = m.owner_id and z.kind = 'final' and z.status = 'won' and z.raid_id <> p_raid);
      if p_won and m.acts > 0 then
        if cleared then rw_gil := 100; items := '{"seal_shard":2}'::jsonb;
        else rw_gil := 400; xp := round(public.world_xp_need(m.clv) * 0.5); items := '{"spirit_core":3,"heavenly_dew":2,"seal_shard":5}'::jsonb; end if;
      end if;
    end if;
    got := ''; lost := '';
    if rw_gil > 0 or items <> '{}'::jsonb then
      select inventory into inv from public.world_characters where owner_id = m.owner_id for update;
      inv := coalesce(inv, '{}'::jsonb); lim := public.world_bag_limit(m.owner_id);
      for k, v in select key, value::int from jsonb_each_text(items) loop
        room := least(v, public.world_bag_room(inv, k, lim));
        if room > 0 then inv := public.world_inv_add(inv, k, room); got := got || (select item_name from public.world_item_catalog where item_id = k) || ' ×' || room || ' · '; end if;
        if room < v then lost := lost || (select item_name from public.world_item_catalog where item_id = k) || ' ×' || (v - room) || ' · '; end if;
      end loop;
      update public.world_characters set inventory = inv, gil = gil + rw_gil, updated_at = now() where owner_id = m.owner_id;
    end if;
    xg := '0'; if xp > 0 then xg := public.world_grant_xp_got(m.owner_id, xp) ->> 'xp'; end if;
    update public.world_raid_members set reward = jsonb_build_object('share', round(share * 100, 1), 'gil', rw_gil, 'xp', xp, 'items', items,
      'top', m.owner_id = top, 'revenge', revenge, 'lost', nullif(lost, '')) || case when nl then jsonb_build_object('nc', coalesce(m.fx -> 'ncnt', '{}'::jsonb)) else '{}'::jsonb end
     where raid_id = p_raid and owner_id = m.owner_id;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (m.owner_id, 'raid_result', case when nl then rd.boss_name || case when p_won then ' 흩어 보냄' else ' 놓침' end when p_won then rd.boss_name || ' 토벌 성공' else rd.boss_name || ' 토벌 실패' end,
      '기여도 ' || round(share * 100, 1) || '%' || case when rw_gil > 0 then ' · ' || rw_gil || '전' else '' end || case when xp > 0 then ' · 경험치 ' || xg else '' end
      || case when got <> '' then ' · ' || regexp_replace(got, ' · $', '') else '' end
      || case when lost <> '' then ' (가방이 모자라 두고 옴: ' || regexp_replace(lost, ' · $', '') || ')' else '' end
      || case when share < 0.01 and rd.kind = 'world' then ' · 기여도 1% 미만이라 보상이 없습니다' else '' end,
      jsonb_build_object('raid_id', p_raid));
    perform public.world_title_award_check(m.owner_id, 'raid');
  end loop;
  if nl then
    nxt := public.world_raid_schedule_next();
    select region_name into reg from public.world_map_regions where region_id = rd.region_id;
    delete from public.world_raid_locks where kind in ('flow', 'dry');
    insert into public.world_raid_locks(region_id, raid_id, until, kind)
    values (rd.region_id, p_raid, nxt + make_interval(hours => (sr ->> 'gap_h')::int) + interval '3 hours', case when p_won then 'flow' else 'dry' end)
    on conflict (region_id) do update set raid_id = excluded.raid_id, until = excluded.until, kind = excluded.kind;
    perform public.world_raid_chat_k('neol', case when p_won
      then '「' || rd.boss_name || '」을(를) 흩어 보냈습니다! 고였던 요기가 ' || reg || '의 땅과 물로 돌아가 흐름이 살아납니다(채집·귀한 것이 늘어남).'
      else '「' || rd.boss_name || '」을(를) 흩어 보내지 못했습니다. 너울이 다른 곳으로 흘러가고, ' || reg || ' 둘레가 말라 갑니다(채집·회복이 줄고 요괴가 늘어남). 다음 너울을 흩어 보내면 풀립니다.' end);
  elsif rd.kind = 'world' then
    nxt := public.world_raid_schedule_next();
    if p_won then
      delete from public.world_raid_locks where kind = 'lock';
      perform public.world_raid_chat('「' || rd.boss_name || '」을(를) 물리쳤습니다! 봉연의 기운이 걷힙니다.' || case when revenge then ' 잠겼던 땅도 풀려납니다.' else '' end);
    else
      select region_name into reg from public.world_map_regions where region_id = rd.region_id;
      insert into public.world_raid_locks(region_id, raid_id, until) values (rd.region_id, p_raid, nxt + interval '3 hours'
        + case when (select r.boss_key from public.world_raids r where r.kind = 'world' and r.status = 'announced' order by r.created_at desc limit 1) = 'neol'
               then make_interval(hours => (public.world_neol_rules() ->> 'gap_h')::int) else interval '0' end)
      on conflict (region_id) do update set raid_id = excluded.raid_id, until = excluded.until;
      perform public.world_raid_chat('「' || rd.boss_name || '」을(를) 막지 못했습니다. ' || reg || '이(가) 봉연에 잠겼습니다. 그 둘레의 침식과 요괴가 짙어집니다. 다음 그림자를 물리치면 풀립니다.');
    end if;
  end if;
end $function$;

create or replace function public.world_raid_schedule_next()
 returns timestamptz language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare cnt int; lo int; hi int; pick text; cands text[]; at timestamptz; last text; nr jsonb := public.world_neol_rules(); base timestamptz;
begin
  if exists (select 1 from public.world_raids where kind = 'world' and status in ('announced', 'signup', 'fight')) then
    return (select spawn_at from public.world_raids where kind = 'world' and status in ('announced', 'signup', 'fight') order by spawn_at limit 1);
  end if;
  if public.world_long_night_stage(now()) between 1 and 4 then
    if exists (select 1 from public.world_raids where kind = 'world' and fx ? 'last_night') or now() >= timestamptz '2026-11-01 20:00+09' then return timestamptz '2026-11-02 00:00+09'; end if;
    insert into public.world_raids(kind, boss_name, region_id, status, candidates, spawn_at, fx)
    values ('world', '사슬 벗은 그림자', 'hq_training', 'announced', array['hq_training', 'field_outskirts', 'shrine_ruins'],
            timestamptz '2026-11-01 20:00+09', '{"last_night": true}');
    return timestamptz '2026-11-01 20:00+09';
  end if;
  base := greatest(now(), coalesce((select m.value::timestamptz from public.world_app_meta m where m.key = 'open_at'), now()));
  select boss_key into last from public.world_raids where kind = 'world' order by created_at desc limit 1;
  if last = 'shadow' then
    with act as (select c.owner_id from public.world_characters c where not coalesce(c.is_dead, false) and c.updated_at > now() - make_interval(days => (nr ->> 'active_days')::int)
                    and not exists (select 1 from public.world_staff s where s.owner_id = c.owner_id)),
         w as (select r.region_id, (select count(*) from act where public.world_region_open(act.owner_id, r.region_id)) n
                 from public.world_map_regions r where r.active and not coalesce(r.is_safe_zone, false) and r.region_id in (select jsonb_array_elements_text(nr -> 'regions')))
    select array_agg(z.region_id order by z.k) into cands from (select w.region_id, -ln(greatest(1e-9, random())) / greatest(1, w.n) as k from w where w.n >= (nr ->> 'min_open')::int order by 2 limit 3) z;
    if cands is not null and array_length(cands, 1) > 0 then
      pick := cands[1];
      at := public.world_raid_evening_k(base + make_interval(hours => (nr ->> 'gap_h')::int) + random() * make_interval(hours => (nr ->> 'jitter_h')::int), 'neol');
      insert into public.world_raids(kind, boss_key, boss_name, region_id, status, candidates, spawn_at)
      values ('world', 'neol', nr ->> 'name', pick, 'announced', (select array_agg(x order by random()) from unnest(cands) x), at);
      return at;
    end if;
  end if;
  select count(*) into cnt from public.world_raids where kind = 'world' and boss_key = 'shadow';
  lo := case cnt % 3 when 0 then 1 when 1 then 11 else 21 end; hi := case cnt % 3 when 0 then 10 when 1 then 20 else 30 end;
  select array_agg(region_id order by random()) into cands from (
    select region_id from public.world_map_regions where active and not coalesce(is_safe_zone, false) and not public.world_domain_flag(territory_id, 'no_shadow') and coalesce(min_level, 1) between lo and hi
     order by random() limit 3) z;
  if cands is null or array_length(cands, 1) = 0 then
    select array_agg(region_id) into cands from (select region_id from public.world_map_regions where active and not coalesce(is_safe_zone, false) and not public.world_domain_flag(territory_id, 'no_shadow') order by random() limit 3) z;
  end if;
  pick := cands[1];
  if last = 'neol' then
    at := public.world_raid_evening_k(base + make_interval(hours => (nr ->> 'gap_h')::int) + random() * make_interval(hours => (nr ->> 'jitter_h')::int), 'shadow');
  else
    at := public.world_raid_evening(base + interval '72 hours');
  end if;
  insert into public.world_raids(kind, boss_name, region_id, status, candidates, spawn_at)
  values ('world', '사슬 벗은 그림자', pick, 'announced', (select array_agg(x order by random()) from unnest(cands) x), at);
  return at;
end $function$;

create or replace function public.world_raid_tick()
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare rd public.world_raids%rowtype; reg text; names text; hm text; nl boolean;
begin
  perform public.world_raid_schedule_next();
  for rd in select * from public.world_raids where kind = 'world' and status = 'announced' and spawn_at - interval '24 hours' <= now() for update skip locked loop
    select region_name into reg from public.world_map_regions where region_id = rd.region_id;
    hm := to_char(rd.spawn_at at time zone 'Asia/Seoul', 'MM"월" DD"일" HH24"시" MI"분"');
    nl := rd.boss_key = 'neol';
    if rd.spawn_at <= now() then
      update public.world_raids set status = 'signup', signup_until = now() + interval '30 minutes', notices = notices || '{spawn}', updated_at = now() where raid_id = rd.raid_id;
      if nl then
        perform public.world_raid_say(rd.raid_id, 'phase', rd.boss_name || '이(가) ' || reg || '에 고여 일어섰습니다. 30분 동안 모인 뒤 흩어 보내기가 시작되고, 그 중에도 그곳에서 합류할 수 있습니다.');
        perform public.world_raid_broadcast(rd.raid_id, rd.boss_name || ' 출현', rd.boss_name || '이(가) ' || reg || '에 고여 일어섰습니다! 30분 뒤 흩어 보내기가 시작되고, 끝나기 전까지 언제든 그곳에서 합류할 수 있습니다.');
      else
      perform public.world_raid_say(rd.raid_id, 'phase', '사슬 벗은 그림자가 ' || reg || '에 드러났습니다. 30분 동안 모인 뒤 토벌이 시작되고, 토벌 중에도 그곳에서 합류할 수 있습니다.');
      perform public.world_raid_broadcast(rd.raid_id, '사슬 벗은 그림자 출현', '사슬 벗은 그림자가 ' || reg || '에 드러났습니다! 30분 뒤 토벌이 시작되고, 끝나기 전까지 언제든 그곳에서 합류할 수 있습니다.');
      end if;
    elsif rd.spawn_at - interval '3 hours' <= now() and not ('3h' = any (rd.notices)) then
      update public.world_raids set notices = notices || '{3h,6h,12h,24h}' where raid_id = rd.raid_id;
      if nl then perform public.world_raid_broadcast(rd.raid_id, '너울 · 세 시간 전', '세 시간 뒤(' || hm || ') ' || reg || '에 ' || rd.boss_name || '이(가) 고여 일어섭니다.');
      else perform public.world_raid_broadcast(rd.raid_id, '그림자 · 세 시간 전', '세 시간 뒤(' || hm || ') ' || reg || '에 사슬 벗은 그림자가 드러납니다.'); end if;
    elsif rd.spawn_at - interval '6 hours' <= now() and not ('6h' = any (rd.notices)) then
      update public.world_raids set notices = notices || '{6h,12h,24h}' where raid_id = rd.raid_id;
      if nl then perform public.world_raid_broadcast(rd.raid_id, '너울 · 여섯 시간 전', '여섯 시간 뒤(' || hm || ') ' || reg || '에 ' || rd.boss_name || '이(가) 고여 일어섭니다. 준비하세요.');
      else perform public.world_raid_broadcast(rd.raid_id, '그림자 · 여섯 시간 전', '여섯 시간 뒤(' || hm || ') ' || reg || '에 사슬 벗은 그림자가 드러납니다. 준비하세요.'); end if;
    elsif rd.spawn_at - interval '12 hours' <= now() and not ('12h' = any (rd.notices)) then
      update public.world_raids set notices = notices || '{12h,24h}' where raid_id = rd.raid_id;
      if nl then perform public.world_raid_broadcast(rd.raid_id, '너울 · 출현지 확정', '흐르지 못한 요기가 한곳으로 고였습니다. ' || hm || '쯤 ' || reg || '에 ' || rd.boss_name || '이(가) 일어섭니다.');
      else perform public.world_raid_broadcast(rd.raid_id, '그림자 · 출현지 확정', '봉연의 기운이 한곳으로 모였습니다. ' || hm || '쯤 ' || reg || '에 사슬 벗은 그림자가 드러납니다.'); end if;
    elsif not ('24h' = any (rd.notices)) then
      select string_agg(x.region_name, ', ') into names from unnest(rd.candidates) c join public.world_map_regions x on x.region_id = c;
      update public.world_raids set notices = notices || '{24h}' where raid_id = rd.raid_id;
      if nl then perform public.world_raid_broadcast(rd.raid_id, '건넛누리에 요기가 고여 갑니다', '건넛누리 어딘가에 요기가 흐르지 못하고 고여 갑니다. 하루 안에 「' || rd.boss_name || '」이(가) ' || names || ' 가운데 한 곳에 일어설 듯합니다.');
      else perform public.world_raid_broadcast(rd.raid_id, '봉연의 기운이 짙어집니다', '봉연의 기운이 짙어집니다. 하루 안에 「사슬 벗은 그림자」가 ' || names || ' 가운데 한 곳에 드러날 듯합니다.'); end if;
    end if;
  end loop;
  for rd in select * from public.world_raids where status = 'signup' and signup_until <= now() for update skip locked loop
    perform public.world_raid_begin_fight(rd.raid_id);
  end loop;
  for rd in select * from public.world_raids where status = 'fight' and ends_at <= now() for update skip locked loop
    perform public.world_raid_say(rd.raid_id, 'phase', '시간이 다 되었습니다. ' || rd.boss_name || case when rd.boss_key = 'neol' then '이(가) 다른 곳으로 흘러갔습니다.' else '이(가) 봉연 속으로 물러납니다.' end);
    perform public.world_raid_settle(rd.raid_id, false);
  end loop;
  delete from public.world_raid_locks where until <= now();
  delete from public.world_raid_log l using public.world_raids r where r.raid_id = l.raid_id and r.ended_at < now() - interval '7 days';
end $function$;
