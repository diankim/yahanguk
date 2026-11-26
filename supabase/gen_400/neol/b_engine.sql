create or replace function public.world_neol_cnt(p_raid uuid, p_owner uuid, p_key text, p_n int default 1)
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
begin
  update public.world_raid_members set fx = jsonb_set(fx, '{ncnt}', coalesce(fx -> 'ncnt', '{}'::jsonb) || jsonb_build_object(p_key, coalesce((fx -> 'ncnt' ->> p_key)::int, 0) + p_n))
   where raid_id = p_raid and owner_id = p_owner;
end $f$;

create or replace function public.world_neol_active(p_raid uuid)
 returns table (owner_id uuid, name text, level int, job_key text, pres numeric, ng jsonb, health int, acted timestamptz, fx jsonb)
 language sql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
  select x.owner_id, x.name, x.level, x.job_key, public.world_shadow_pres('world', x.job_key, x.stats, x.fx), x.fx -> 'ng', ch.health, x.last_action_at, x.fx
    from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id join public.world_raids r on r.raid_id = x.raid_id
   where x.raid_id = p_raid and x.out_until is null and x.left_at is null and public.world_raid_here(x.owner_id, r.region_id)
     and x.last_action_at > now() - interval '120 seconds' and ch.health > 1
$f$;

create or replace function public.world_neol_phase_line(p_name text, p_phase int)
 returns text language sql immutable set search_path to 'pg_catalog', 'public'
as $f$ select case when p_phase = 2 then p_name || '이(가) 출렁이며 굳은 물살을 사방으로 흘립니다(2단계). 이제 덮친 물에 맞은 이는 마르기 시작합니다.'
  else p_name || '의 한가운데에 고인 심이 비칩니다(3단계). 심이 드러나면 여럿이 함께 쳐서 물길을 트세요.' end $f$;

create or replace function public.world_neol_dry_on(p_raid uuid, p_bt int)
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare mk jsonb := public.world_neol_rules() -> 'mk2' -> 'dry'; m record; names text := '';
begin
  for m in select a.owner_id, a.name from public.world_neol_active(p_raid) a where not (a.fx ? 'dry') order by random() limit (mk ->> 'pick')::int loop
    update public.world_raid_members set fx = fx || jsonb_build_object('dry', jsonb_build_object('n', (mk ->> 'beats')::int, 'b', p_bt)) where raid_id = p_raid and owner_id = m.owner_id;
    names := names || m.name || ', ';
  end loop;
  if names <> '' then
    perform public.world_raid_say(p_raid, 'boss', '물살에 쓸린 ' || regexp_replace(names, ', $', '') || '의 몸이 마르기 시작합니다. 체력을 ' || (mk ->> 'line') || ' 넘게 채워 적셔 주세요!');
  end if;
end $f$;

create or replace function public.world_neol_core_add(p_raid uuid, p_fx jsonb, p_uid uuid, p_dmg int)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare mk jsonb := public.world_neol_rules() -> 'mk2' -> 'core'; fx jsonb := p_fx; c jsonb := p_fx -> 'nc'; bym jsonb; k text; v numeric; hn int;
begin
  if c is null or coalesce(p_dmg, 0) <= 0 or extract(epoch from now()) >= (c ->> 'until')::numeric then return fx; end if;
  bym := coalesce(c -> 'by', '{}'::jsonb);
  bym := bym || jsonb_build_object(p_uid::text, coalesce((bym ->> p_uid::text)::numeric, 0) + p_dmg);
  c := c || jsonb_build_object('got', (c ->> 'got')::numeric + p_dmg, 'by', bym);
  hn := (select count(*) from jsonb_object_keys(bym));
  if (c ->> 'got')::numeric >= (c ->> 'need')::numeric and hn >= (mk ->> 'hits')::int then
    for k, v in select key, value::numeric from jsonb_each_text(bym) loop
      perform public.world_raid_credit(p_raid, k::uuid, v * (mk ->> 'boost')::numeric, 'boost');
      perform public.world_neol_cnt(p_raid, k::uuid, 'c');
    end loop;
    perform public.world_raid_say(p_raid, 'good', hn || '명이 함께 쳐 고임 심이 트였습니다! ' || (mk ->> 'open_s') || '초 동안 너울이 받는 피해가 ' || (mk ->> 'open_pct') || '% 늘어납니다.');
    return (fx - 'nc') || jsonb_build_object('nopen', jsonb_build_object('until', round(extract(epoch from now())::numeric + (mk ->> 'open_s')::numeric, 2), 'pct', (mk ->> 'open_pct')::numeric));
  end if;
  return fx || jsonb_build_object('nc', c);
end $f$;

create or replace function public.world_neol_after(p_raid uuid, p_uid uuid, p_act text, p_healed boolean)
 returns void language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare line int := (public.world_neol_rules() -> 'mk2' -> 'dry' ->> 'line')::int; m record; n int := 0;
begin
  update public.world_raid_members set fx = fx || jsonb_build_object('ng', jsonb_build_object('t', case when p_act = 'guard' then round(extract(epoch from now())::numeric, 2) else coalesce((fx -> 'ng' ->> 't')::numeric, 0) end, 'on', p_act = 'guard'))
   where raid_id = p_raid and owner_id = p_uid;
  for m in select x.owner_id, x.name from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id
            where x.raid_id = p_raid and x.fx ? 'dry' and ch.health >= line loop
    update public.world_raid_members set fx = fx - 'dry' where raid_id = p_raid and owner_id = m.owner_id;
    if p_healed and m.owner_id <> p_uid then n := n + 1; end if;
    perform public.world_raid_say(p_raid, 'good', m.name || ' — 몸이 다시 젖어 마름이 풀렸습니다.');
  end loop;
  if n > 0 then perform public.world_neol_cnt(p_raid, p_uid, 'd', n); end if;
end $f$;

create or replace function public.world_neol_beat(p_raid uuid, p_fx jsonb, p_tick boolean, p_bt int, p_now numeric, p_ph numeric, p_phase int)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare mk jsonb := public.world_neol_rules() -> 'mk2'; bf jsonb := p_fx; m record; pick uuid; nm text; t0 numeric; n numeric; ppl int; tot numeric; d int;
  tanks jsonb := public.world_shadow_rules() -> 'tank_pres' -> 'jobs'; w jsonb := mk -> 'weight'; ti jsonb := mk -> 'tide'; dr jsonb := mk -> 'dry'; co jsonb := mk -> 'core';
  hpadd int := 0; need numeric; maxhp int; g boolean; cnt int;
begin
  select max_hp into maxhp from public.world_raids where raid_id = p_raid;
  if bf ? 'nopen' and p_now >= (bf -> 'nopen' ->> 'until')::numeric then bf := bf - 'nopen'; end if;

  if bf ? 'nw' and p_now >= (bf -> 'nw' ->> 'at')::numeric then
    t0 := (bf -> 'nw' ->> 'at')::numeric;
    update public.world_raid_members set fx = fx - 'nw' where raid_id = p_raid and fx ? 'nw';
    select a.owner_id, a.name into pick, nm from public.world_neol_active(p_raid) a where a.owner_id = (bf -> 'nw' ->> 'tgt')::uuid;
    if pick is null then select a.owner_id, a.name into pick, nm from public.world_neol_active(p_raid) a order by a.pres desc, random() limit 1; end if;
    if pick is not null then
      select coalesce(sum(case when tanks ? a.job_key then (w ->> 'tank_n')::numeric else 1 end), 0), count(*) into n, ppl
        from public.world_neol_active(p_raid) a where a.owner_id = pick or coalesce((a.ng ->> 't')::numeric, 0) >= t0 - (w ->> 'window')::numeric;
      perform public.world_raid_say(p_raid, 'boss', '고인 무게가 ' || nm || '에게 떨어집니다' || case when ppl > 1 then '(' || ppl || '명이 나눠 짐)' else '(혼자 받음)' end || '!');
      for m in select a.owner_id, a.level, a.job_key, coalesce((a.ng ->> 't')::numeric, 0) >= t0 - (w ->> 'window')::numeric as gd
                 from public.world_neol_active(p_raid) a where a.owner_id = pick or coalesce((a.ng ->> 't')::numeric, 0) >= t0 - (w ->> 'window')::numeric
                 order by a.owner_id loop
        tot := public.world_raid_boss_base(p_raid, 'world', m.level) * p_ph * (w ->> 'mul')::numeric * coalesce((bf -> 'nw' ->> 'mul')::numeric, 1)
             * case when ppl = 1 then (w ->> 'solo')::numeric else 1 end * case when tanks ? m.job_key then (w ->> 'tank_n')::numeric else 1 end / greatest(1, n);
        if m.gd then update public.world_raid_members set fx = fx || '{"guard": 1}'::jsonb where raid_id = p_raid and owner_id = m.owner_id; end if;
        d := public.world_raid_hit(p_raid, m.owner_id, tot, 'weight');
        if m.gd and d > 0 then perform public.world_raid_credit(p_raid, m.owner_id, d * case when ppl = 1 then (w ->> 'hold')::numeric else 1 end, 'guard'); end if;
        if ppl >= (w ->> 'team')::int then perform public.world_neol_cnt(p_raid, m.owner_id, 'w'); end if;
      end loop;
    end if;
    bf := bf - 'nw';
  elsif p_tick and not (bf ? 'nw') and p_bt % (case when p_phase >= 3 then w ->> 'every3' else w ->> 'every' end)::int = (w ->> 'off')::int then
    select a.owner_id, a.name into pick, nm from public.world_neol_active(p_raid) a order by a.pres desc, random() limit 1;
    if pick is not null then
      bf := bf || jsonb_build_object('nw', jsonb_build_object('at', round(p_now + (w ->> 'delay')::numeric, 2), 'tgt', pick, 'mul', coalesce((bf ->> 'relock')::numeric, 1))) - 'relock';
      update public.world_raid_members set fx = fx || '{"nw": true}'::jsonb where raid_id = p_raid and owner_id = pick;
      perform public.world_raid_say(p_raid, 'boss', nm || '의 머리 위로 물이 고여 무거워집니다. ' || (w ->> 'delay') || '초 뒤 떨어집니다 — 곁에서 방어해 함께 지세요!');
    end if;
  end if;

  if bf ? 'nt' then
    if bf -> 'nt' ->> 's' = 'tell' and p_now >= (bf -> 'nt' ->> 'at')::numeric then
      perform public.world_raid_say(p_raid, 'boss', '첫 물이 덮칩니다! 곧 되밀려 옵니다 — 이번엔 방어를 푸세요!');
      for m in select a.owner_id, a.level from public.world_neol_active(p_raid) a order by a.owner_id loop
        perform public.world_raid_hit(p_raid, m.owner_id, public.world_raid_boss_base(p_raid, 'world', m.level) * p_ph * (ti ->> 'first')::numeric, 'slam');
      end loop;
      bf := bf || jsonb_build_object('nt', jsonb_build_object('s', 'ebb', 'at', round(p_now + (ti ->> 'gap')::numeric, 2), 't1', round(p_now, 2)));
    elsif bf -> 'nt' ->> 's' = 'ebb' and p_now >= (bf -> 'nt' ->> 'at')::numeric then
      cnt := 0;
      for m in select a.owner_id, a.level, coalesce((a.ng ->> 'on')::boolean, false) as on_g, a.acted from public.world_neol_active(p_raid) a order by a.owner_id loop
        if m.on_g then
          update public.world_raid_members set fx = fx - 'guard' where raid_id = p_raid and owner_id = m.owner_id;
          perform public.world_raid_hit(p_raid, m.owner_id, public.world_raid_boss_base(p_raid, 'world', m.level) * p_ph * (ti ->> 'first')::numeric * (ti ->> 'ebb')::numeric, 'ebb');
          cnt := cnt + 1;
        elsif extract(epoch from m.acted) >= (bf -> 'nt' ->> 't1')::numeric then
          perform public.world_neol_cnt(p_raid, m.owner_id, 'e');
        end if;
      end loop;
      perform public.world_raid_say(p_raid, case when cnt > 0 then 'boss' else 'good' end, '물이 거꾸로 되밀려 옵니다' || case when cnt > 0 then ' — 방어하던 ' || cnt || '명이 휩쓸렸습니다.' else ' — 모두 비켜섰습니다.' end);
      bf := bf - 'nt';
    end if;
  elsif p_tick and p_bt % (ti ->> 'every')::int = (ti ->> 'off')::int then
    bf := bf || jsonb_build_object('nt', jsonb_build_object('s', 'tell', 'at', round(p_now + (ti ->> 'tell')::numeric, 2)));
    perform public.world_raid_say(p_raid, 'boss', '물이 빠져 나갑니다. ' || (ti ->> 'tell') || '초 뒤 해일 — 첫 물은 방어, 되밀려 오는 물은 방어를 푸세요!');
  end if;

  if p_tick then
    for m in select x.owner_id, x.name, (x.fx -> 'dry' ->> 'n')::int as n from public.world_raid_members x
              where x.raid_id = p_raid and x.fx ? 'dry' and x.out_until is null and x.left_at is null and coalesce((x.fx -> 'dry' ->> 'b')::int, -1) < p_bt order by x.owner_id loop
      perform public.world_raid_hit(p_raid, m.owner_id, (dr ->> 'dmg')::numeric, 'dry');
      if m.n <= 1 then
        update public.world_raid_members set fx = (fx - 'dry') || jsonb_build_object('stiff', jsonb_build_object('n', least((dr ->> 'stiff_cap')::int, coalesce((fx -> 'stiff' ->> 'n')::int, 0) + 1), 'pct', (dr ->> 'stiff')::numeric))
         where raid_id = p_raid and owner_id = m.owner_id;
        perform public.world_raid_say(p_raid, 'boss', m.name || ' — 끝내 마른 몸이 굳었습니다(이 싸움 동안 주는 피해 −' || (dr ->> 'stiff') || '%, 겹침).');
      else
        update public.world_raid_members set fx = jsonb_set(fx, '{dry}', jsonb_build_object('n', m.n - 1, 'b', p_bt)) where raid_id = p_raid and owner_id = m.owner_id and fx ? 'dry';
      end if;
    end loop;
  end if;

  if bf ? 'nc' then
    if p_now >= (bf -> 'nc' ->> 'until')::numeric then
      hpadd := ceil(maxhp * (co ->> 'regrow')::numeric / 100.0)::int;
      bf := (bf - 'nc') || jsonb_build_object('relock', (co ->> 'relock')::numeric);
      perform public.world_raid_say(p_raid, 'boss', '고임 심을 트지 못했습니다. 물이 다시 고여 너울이 되살아납니다(체력 +' || (co ->> 'regrow') || '%) — 다음 고임 무게가 더 무겁습니다.');
    end if;
  elsif p_tick and p_phase >= (co ->> 'from_phase')::int and p_bt % (co ->> 'every')::int = (co ->> 'off')::int then
    select coalesce(sum(greatest(1, coalesce((x.stats ->> 'attack')::numeric, 0))), 0) into need
      from public.world_raid_members x join public.world_neol_active(p_raid) a on a.owner_id = x.owner_id where x.raid_id = p_raid;
    need := greatest((co ->> 'min')::numeric, round(need * (co ->> 'mul')::numeric));
    bf := bf || jsonb_build_object('nc', jsonb_build_object('until', round(p_now + (co ->> 'secs')::numeric, 2), 'need', need, 'got', 0, 'by', '{}'::jsonb));
    perform public.world_raid_say(p_raid, 'boss', '너울이 고임 심을 드러냅니다! ' || (co ->> 'secs') || '초 안에 ' || (co ->> 'hits') || '명 넘게 함께 ' || need || ' 넘게 몰아쳐 물길을 트세요!');
  end if;

  if hpadd > 0 then bf := bf || jsonb_build_object('_hp', hpadd); end if;
  return bf;
end $f$;

create or replace function public.world_neol_intent(p_raid uuid, p_fx jsonb)
 returns text language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
declare t numeric := extract(epoch from now()); s int; nm text; n int;
begin
  if p_fx ? 'nt' then
    s := greatest(0, ceil((p_fx -> 'nt' ->> 'at')::numeric - t))::int;
    return case when p_fx -> 'nt' ->> 's' = 'tell' then '해일 — ' || s || '초 뒤 첫 물: 방어!' else '되밀려 오는 물 — ' || s || '초 뒤: 방어 풀기!' end;
  end if;
  if p_fx ? 'nw' then
    select x.name into nm from public.world_raid_members x where x.raid_id = p_raid and x.owner_id = (p_fx -> 'nw' ->> 'tgt')::uuid;
    select count(*) into n from public.world_neol_active(p_raid) a where coalesce((a.ng ->> 'on')::boolean, false);
    return '고임 무게 — ' || greatest(0, ceil((p_fx -> 'nw' ->> 'at')::numeric - t))::int || '초 뒤 ' || coalesce(nm, '누군가') || '에게 · 지금 방어 ' || n || '명';
  end if;
  if p_fx ? 'nc' then
    return '고임 심 — ' || greatest(0, ceil((p_fx -> 'nc' ->> 'until')::numeric - t))::int || '초 안에 여럿이 함께 몰아쳐라';
  end if;
  return null;
end $f$;

create or replace function public.world_neol_view(p_raid uuid)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
declare rd public.world_raids%rowtype; t numeric := extract(epoch from now()); mk jsonb := public.world_neol_rules() -> 'mk2'; w jsonb := mk -> 'weight';
begin
  select * into rd from public.world_raids where raid_id = p_raid;
  if not found or rd.boss_key <> 'neol' then return null; end if;
  return jsonb_build_object('line', (mk -> 'dry' ->> 'line')::int, 'hits', (mk -> 'core' ->> 'hits')::int,
    'weight', case when rd.fx ? 'nw' then jsonb_build_object('tgt', rd.fx -> 'nw' ->> 'tgt', 'secs', greatest(0, round((rd.fx -> 'nw' ->> 'at')::numeric - t, 1)), 'dur', (w ->> 'delay')::numeric,
      'guarding', (select count(*) from public.world_neol_active(p_raid) a where coalesce((a.ng ->> 'on')::boolean, false))) end,
    'core', case when rd.fx ? 'nc' then jsonb_build_object('need', (rd.fx -> 'nc' ->> 'need')::numeric, 'got', (rd.fx -> 'nc' ->> 'got')::numeric,
      'hit_n', (select count(*) from jsonb_object_keys(coalesce(rd.fx -> 'nc' -> 'by', '{}'::jsonb))), 'secs', greatest(0, round((rd.fx -> 'nc' ->> 'until')::numeric - t, 1)), 'dur', (mk -> 'core' ->> 'secs')::numeric) end,
    'tide', case when rd.fx ? 'nt' then jsonb_build_object('stage', rd.fx -> 'nt' ->> 's', 'secs', greatest(0, round((rd.fx -> 'nt' ->> 'at')::numeric - t, 1)),
      'dur', case when rd.fx -> 'nt' ->> 's' = 'tell' then (mk -> 'tide' ->> 'tell')::numeric else (mk -> 'tide' ->> 'gap')::numeric end) end,
    'open', case when rd.fx ? 'nopen' and (rd.fx -> 'nopen' ->> 'until')::numeric > t then jsonb_build_object('secs', round((rd.fx -> 'nopen' ->> 'until')::numeric - t, 1), 'pct', rd.fx -> 'nopen' -> 'pct') end);
end $f$;

do $$ declare f text; begin
  foreach f in array array['world_neol_cnt(uuid, uuid, text, integer)', 'world_neol_active(uuid)', 'world_neol_phase_line(text, integer)', 'world_neol_dry_on(uuid, integer)',
    'world_neol_core_add(uuid, jsonb, uuid, integer)', 'world_neol_after(uuid, uuid, text, boolean)', 'world_neol_beat(uuid, jsonb, boolean, integer, numeric, numeric, integer)',
    'world_neol_intent(uuid, jsonb)', 'world_neol_view(uuid)'] loop
    perform pg_temp.yh_share('public.' || f);
  end loop;
end $$;
