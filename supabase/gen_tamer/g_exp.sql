select pg_temp.yh_fix('world_expedition_settle', array[
$q$v_fkey text; fk text; pfd jsonb;$q$,
$q$ptn jsonb; ptr jsonb := public.world_pet_partner_rules() -> 'exp'; ppw float8 := 0; v_fkey text; fk text; pfd jsonb;$q$,

$q$  skf := public.world_exp_skill_fx(e.owner_id); power := power * (1 + coalesce((skf ->> 'atk')::float8, 0) / 100.0);$q$,
$q$  skf := public.world_exp_skill_fx(e.owner_id); power := power * (1 + coalesce((skf ->> 'atk')::float8, 0) / 100.0);
  ptn := case when c.job_key = 'tamer' then public.world_pet_partner_of(e.owner_id) end;
  if ptn is not null then
    ppw := (ptn ->> 'pow')::float8;
    power := power * (1 + (ptr ->> 'atk')::float8 / 100.0 * ppw);
    if ptn ->> 'grp' = 'charm' then g_ml := g_ml - (ptr ->> 'charm_ml')::float8 * ppw; end if;
  end if;$q$,

$q$  disc_mul := disc_mul * (1 + coalesce((skf ->> 'find')::float8, 0) / 100.0);$q$,
$q$  disc_mul := disc_mul * (1 + coalesce((skf ->> 'find')::float8, 0) / 100.0);
  if ptn is not null then disc_mul := disc_mul * (1 + (ptr ->> 'find')::float8 / 100.0 * (0.5 + 0.5 * ppw)); loot_mul := loot_mul * (1 + (ptr ->> 'loot')::float8 / 100.0); end if;$q$,

$q$        threat := threat / power(public.world_kind_mult(m.kind, wtype, c.job_key)::float8, 0.6);$q$,
$q$        threat := threat / power(public.world_kind_mult(m.kind, wtype, c.job_key)::float8, 0.6);
        if ptn is not null and ptn ->> 'grp' = 'peck' and m.kind in ('bird', 'sky') then threat := threat * (1 - (ptr ->> 'peck_threat')::float8 / 100.0 * ppw); end if;$q$,

$q$        if c.job_key = 'analyst' and random() < 0.25 then$q$,
$q$        if ptn is not null then
          win_p := win_p + (ptr ->> 'win')::float8 * ppw + case when ptn ->> 'grp' = 'bite' then (ptr ->> 'bite_win')::float8 * ppw else 0 end;
          if random() < 0.3 then
            jobn := jobn + 1;
            seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[동무의 코] ' || (ptn ->> 'name') || '이(가) ' || foe
              || case ptn ->> 'grp' when 'guard' then '의 기척을 먼저 알아채고 앞을 막아섰습니다.' when 'bite' then '의 발목을 물고 늘어졌습니다.' when 'peck' then '의 눈앞을 쪼아 댔습니다.' else '의 기세를 흐려 놓았습니다.' end);
          end if;
        end if;
        if c.job_key = 'analyst' and random() < 0.25 then$q$,

$q$ * (1 - coalesce((skf ->> 'guard')::float8, 0) / 100.0));
        my_taken := 0;$q$,
$q$ * (1 - coalesce((skf ->> 'guard')::float8, 0) / 100.0) * case when ptn ->> 'grp' = 'guard' then 1 - (ptr ->> 'guard_dmg')::float8 / 100.0 * ppw else 1 end);
        my_taken := 0;$q$,

$q$      finds := finds + 1; xp := xp + 6; ixp := ixp + 10;$q$,
$q$      finds := finds + 1; xp := xp + 6; ixp := ixp + 10;
      if ptn is not null and random() < 0.2 then
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[동무의 코] ' || (ptn ->> 'name') || '이(가) 풀숲 밑 갈림길을 먼저 찾아냈습니다.');
      end if;$q$
]);
