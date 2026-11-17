select pg_temp.yh_patch('public.world_battle_open(uuid,text,uuid,integer,integer)',
  $o$VALUES (p_owner, p_region, m.monster_id, hp, hp, false, false, now(), now(), 0, 0, 0, p_node, lv, v_atk, df, rk, v_intent, '{}', '{}',$o$,
  $n$VALUES (p_owner, p_region, m.monster_id, hp, hp, false, false, now(), now(), 0, 0, 0, p_node, lv, v_atk, df, rk, v_intent, '{}', CASE WHEN m.region_id <> p_region THEN '{"borrowed": true}'::jsonb ELSE '{}'::jsonb END,$n$);
select pg_temp.yh_patch('public.world_battle_open(uuid,text,uuid,integer,integer)',
  $o$intent = excluded.intent, fx = '{}', pfx = '{}', log = excluded.log,$o$,
  $n$intent = excluded.intent, fx = '{}', pfx = excluded.pfx, log = excluded.log,$n$);

select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$    mt := public.world_mentor_bonus(uid, CASE WHEN nullif(current_setting('yh.pf_n', true), '') IS NULL THEN 'win' ELSE 'pfight' END, xp + 12);$o$,
  $n$    mt := CASE WHEN coalesce((a.pfx ->> 'borrowed')::boolean, false) THEN '{}'::jsonb ELSE public.world_mentor_bonus(uid, CASE WHEN nullif(current_setting('yh.pf_n', true), '') IS NULL THEN 'win' ELSE 'pfight' END, xp + 12) END;$n$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$    IF loot = '{}'::jsonb THEN loot := public.world_inv_add(loot, CASE WHEN random() < 0.5 THEN 'spirit_dust' ELSE 'beast_bone' END, 1); END IF;$o$,
  $n$    IF loot = '{}'::jsonb THEN loot := public.world_inv_add(loot, CASE WHEN random() < 0.5 THEN 'spirit_dust' ELSE 'beast_bone' END, 1); END IF;
    IF coalesce((a.pfx ->> 'borrowed')::boolean, false) THEN
      loot := '{}'::jsonb; xp := -12; gil_gain := 0;
      lines := lines || jsonb_build_array('이야기를 따라 흘러든 요괴라 거둘 것이 남지 않았다.');
    END IF;$n$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$        'rank', a.rank, 'level', a.mlevel, 'loot', loot, 'turns', turn, 'wick', coalesce(loot ? 'lamp_wick_core', false),$o$,
  $n$        'rank', a.rank, 'level', a.mlevel, 'loot', loot, 'turns', turn, 'wick', coalesce(loot ? 'lamp_wick_core', false), 'borrowed', coalesce((a.pfx ->> 'borrowed')::boolean, false),$n$);

select pg_temp.yh_patch('public.world_event_char_apply()',
  $o$  if uid is null then return new; end if;$o$,
  $n$  if uid is null then return new; end if;
  if k = 'combat' and coalesce((p ->> 'borrowed')::boolean, false) then return new; end if;$n$);
select pg_temp.yh_patch('public.world_gwiryeong_roll()',
  $o$  if new.actor_id is null then return new; end if;$o$,
  $n$  if new.actor_id is null or coalesce((new.payload ->> 'borrowed')::boolean, false) then return new; end if;$n$);
select pg_temp.yh_patch('public.world_housing_event_trg()',
  $o$  if new.actor_id is null then return new; end if;$o$,
  $n$  if new.actor_id is null or coalesce((p ->> 'borrowed')::boolean, false) then return new; end if;$n$);
