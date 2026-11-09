select pg_temp.yh_fix('world_raid_action', array[
$q$bt int; tick boolean := true; bnow numeric; cbr jsonb; cbc jsonb;$q$,
$q$bt int; tick boolean := true; bnow numeric; cbr jsonb; cbc jsonb; pk jsonb; pd int; psolo numeric := 1;$q$,

$q$      f := f || public.world_cb_buff('crit_next', sk.effect, uid);$q$,
$q$      f := f || public.world_cb_buff(coalesce(sk.effect ->> 'type', 'crit_next'), sk.effect, uid);$q$,

$q$      mul := mul * (1 + coalesce((public.world_solo_aid(c.job_key) ->> 'final_dmg')$q$,
$q$      psolo := (1 + coalesce((public.world_solo_aid(c.job_key) ->> 'final_dmg')$q$,

$q$    elsif rd.kind = 'final' then mul := mul * (1 + coalesce((public.world_solo_aid(c.job_key) ->> 'final_all')::numeric, 0) / 100.0); end if;$q$,
$q$    elsif rd.kind = 'final' then psolo := (1 + coalesce((public.world_solo_aid(c.job_key) ->> 'final_all')::numeric, 0) / 100.0); end if;
    mul := mul * psolo;$q$,

$q$    perform public.world_raid_say_n(p_raid, case when crit then 'crit' else 'atk' end, mb.name || ' — ' || dmg || '의 피해' || case when crit then '(치명타)' else '' end || '.', mb.name, dmg);$q$,
$q$    perform public.world_raid_say_n(p_raid, case when crit then 'crit' else 'atk' end, mb.name || ' — ' || dmg || '의 피해' || case when crit then '(치명타)' else '' end || '.', mb.name, dmg);
    pk := public.world_cb_pet_strike(st, f, rfx, uid, false);
    if pk is not null and rd.hp > 0 then
      f := pk -> 'fx'; rfx := pk -> 'bfx';
      pd := greatest(1, round((pk ->> 'd')::numeric * psolo))::int;
      rd.hp := greatest(case when rd.fx ? 'last_night' then ceil(rd.max_hp * 0.03)::int else 0 end, rd.hp - pd); mb.dmg := mb.dmg + pd; credit := credit + pd;
      if rfx ? 'charge' then rfx := jsonb_set(rfx, '{charge,got}', to_jsonb((rfx -> 'charge' ->> 'got')::int + pd * case when (pk ->> 'charm')::boolean then 2 else 1 end)); end if;
      perform public.world_raid_say_n(p_raid, 'atk', mb.name || ' — [동무] ' || (pk ->> 'line') || ': ' || pd || '의 피해.', mb.name, pd);
    end if;$q$,

$q$    k := sk.effect ->> 'type'; v := sk.effect;$q$,
$q$    k := sk.effect ->> 'type'; v := sk.effect;
    if c.job_key = 'tamer' and v ? 'pct' then
      v := v || jsonb_build_object('pct', round((v ->> 'pct')::numeric * ((public.world_pet_partner_rules() ->> 'coop_base')::numeric + (public.world_pet_partner_rules() ->> 'coop_k')::numeric * coalesce((st -> 'pet' ->> 'pow')::numeric, 0))));
    end if;$q$
]);

select pg_temp.yh_fix('world_raid_begin_fight', array[
$q$coalesce(sum((stats ->> 'attack')::numeric), 0), coalesce(avg((stats ->> 'attack')::numeric), 0)$q$,
$q$coalesce(sum(coalesce((stats ->> 'hp_atk')::numeric, (stats ->> 'attack')::numeric)), 0), coalesce(avg(coalesce((stats ->> 'hp_atk')::numeric, (stats ->> 'attack')::numeric)), 0)$q$]);

select pg_temp.yh_fix('world_raid_join', array[
$q$hp_add := round(coalesce((public.world_raid_stats(uid) ->> 'attack')::numeric, 0)$q$,
$q$hp_add := round(coalesce((select coalesce((z.s ->> 'hp_atk')::numeric, (z.s ->> 'attack')::numeric) from (select public.world_raid_stats(uid) as s) z), 0)$q$]);

select pg_temp.yh_fix('world_gw_start', array[
$q$sa := sa + coalesce((s ->> 'attack')::numeric, 50);$q$,
$q$sa := sa + coalesce((s ->> 'hp_atk')::numeric, (s ->> 'attack')::numeric, 50);$q$]);

select pg_temp.yh_fix('world_gw_resolve', array[
$q$v_mb text; v_mp numeric; v_eb text; v_ep numeric; v_cb text; v_cp numeric; v_cn text; v_brk uuid;$q$,
$q$v_mb text; v_mp numeric; v_eb text; v_ep numeric; v_cb text; v_cp numeric; v_cn text; v_brk uuid; pk jsonb; pd numeric;$q$,

$q$    e := sk.effect;
$q$,
$q$    e := sk.effect;
    if m.job_key = 'tamer' and e ? 'pct' then
      e := e || jsonb_build_object('pct', round((e ->> 'pct')::numeric * ((public.world_pet_partner_rules() ->> 'coop_base')::numeric + (public.world_pet_partner_rules() ->> 'coop_k')::numeric * coalesce((m.stats -> 'pet' ->> 'pow')::numeric, 0))));
    end if;
$q$,

$q$      when 'delay' then vbfx := vbfx ||$q$,
$q$      when 'pet_strike' then update public.world_gw_members set fx = fx || public.world_cb_buff('pet_strike', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'delay' then vbfx := vbfx ||$q$,

$q$        perform public.world_gw_say(p_fight, r, 'atk', m.name || ' — ' || round(d) || case when cr then '의 치명타.' else '의 피해.' end);$q$,
$q$        perform public.world_gw_say(p_fight, r, 'atk', m.name || ' — ' || round(d) || case when cr then '의 치명타.' else '의 피해.' end);
        pk := public.world_cb_pet_strike(m.stats, vfx, vbfx, m.owner_id, false);
        if pk is not null then
          vfx := pk -> 'fx'; vbfx := pk -> 'bfx';
          update public.world_gw_members set fx = vfx where fight_id = p_fight and owner_id = m.owner_id;
          pd := (pk ->> 'd')::numeric * d / greatest(1, (cbr ->> 'd')::numeric);
          if k = 'vortex' and m.owner_id::text <> f.mech ->> 'tank' then vsum := vsum + pd * case when (pk ->> 'charm')::boolean then 2 else 1 end; end if;
          boss_dmg := boss_dmg + pd;
          update public.world_gw_members set dmg = dmg + round(pd)::int where fight_id = p_fight and owner_id = m.owner_id;
          perform public.world_gw_credit(p_fight, m.owner_id, pd, 'dmg');
          perform public.world_gw_say(p_fight, r, 'atk', m.name || ' — [동무] ' || (pk ->> 'line') || ': ' || round(pd) || '의 피해.');
        end if;$q$
]);
