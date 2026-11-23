create or replace function public.world_tourney_rules() returns jsonb language sql immutable as $f$
 select '{"exchange_s": 3, "between_s": 8, "rest_s": 20,
  "stance": {"attack": {"dealt": 1.15, "taken": 1.1, "evade": 0}, "balanced": {"dealt": 1, "taken": 1, "evade": 0}, "defense": {"dealt": 0.85, "taken": 0.8, "evade": 5}},
  "skill_at": {"mid": 0.6, "finish": 0.35}, "heal_at": 0.4,
  "hp_mul": 2, "red_cap": 80, "rounds": {"solo": 20, "team": 27},
  "job": {"artificer": {"dealt": 0.97, "taken": 1.03}, "scout": {"dealt": 1.09, "taken": 0.91}, "exorcist": {"dealt": 1.10, "taken": 0.91},
          "medic": {"dealt": 1.10, "taken": 0.91}, "sealmaster": {"dealt": 0.94, "taken": 1.07}, "analyst": {"dealt": 0.99, "taken": 1.01},
          "tamer": {"dealt": 1.03, "taken": 0.97}, "bloodknight": {"dealt": 1.09, "taken": 0.92}, "spearman": {"dealt": 0.87, "taken": 1.15},
          "formation": {"dealt": 1.12, "taken": 0.89}},
  "spar": {"stance": "balanced", "skill": "mid", "items": []},
  "signup_end_day": 5, "solo_day": 5, "team_day": 6, "start_h": 21, "absent_min": 10, "min_entries": 4}'::jsonb
$f$;

create or replace function public.world_duel_run(p_ids uuid[], p_sides int[], p_tactics jsonb[]) returns jsonb
language plpgsql security definer set search_path = '' as $f$
declare
  ids uuid[] := '{}'; side int[] := '{}'; nm text[] := '{}'; lv numeric[] := '{}'; atk numeric[] := '{}'; crit numeric[] := '{}'; cm numeric[] := '{}'; eva numeric[] := '{}'; red numeric[] := '{}';
  pres numeric[] := '{}'; agi numeric[] := '{}'; hp numeric[] := '{}'; mx numeric[] := '{}'; stance text[] := '{}'; skw text[] := '{}'; job text[] := '{}'; sts jsonb[] := '{}';
  items jsonb[] := '{}'; used boolean[] := '{}'; stun int[] := '{}'; focus int[] := '{}'; focus_mul numeric[] := '{}'; sk jsonb; skd jsonb; pierce boolean := false; fell boolean[] := '{}';
  hits int[] := '{}'; crits int[] := '{}'; whistle boolean[] := '{}';
  uid uuid; st jsonb; ch public.world_characters%rowtype; tac jsonb; n int; i int; x int; maxx int; ps jsonb;
  oc text := current_setting('request.jwt.claims', true); os text := current_setting('request.jwt.claim.sub', true);
  lg jsonb := '[]'::jsonb; avg_lv numeric; m_atk numeric; m_crit numeric; m_eva numeric; m_red numeric; base_hp numeric; ord int[]; tgt int; w numeric; best numeric; dmg numeric; mul numeric;
  is_crit boolean; tr jsonb := public.world_tourney_rules(); heal numeric; win int; it text; opp_lv numeric; alive int[]; sum_r numeric[]; lastx int := 0; jm jsonb := tr -> 'job';
  rcap numeric := coalesce((tr ->> 'red_cap')::numeric, 60);
begin
  for k in 1..cardinality(p_ids) loop
    uid := p_ids[k];
    select * into ch from public.world_characters where owner_id = uid;
    tac := coalesce(p_tactics[k], '{}'::jsonb);
    perform set_config('request.jwt.claim.sub', uid::text, true);
    perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
    st := public.world_combat_stats(uid);
    ids := ids || uid; side := side || p_sides[k]; nm := nm || ch.character_name; lv := lv || coalesce(ch.level, 1)::numeric; job := job || ch.job_key; sts := sts || st;
    atk := atk || greatest(1, coalesce((st ->> 'attack')::numeric, 10)); crit := crit || least(60, coalesce((st ->> 'crit_pct')::numeric, 5));
    cm := cm || coalesce((st ->> 'crit_mult')::numeric, 150) / 100; eva := eva || least(40, coalesce((st ->> 'evasion_pct')::numeric, 0));
    red := red || least(rcap, coalesce((st ->> 'reduction_pct')::numeric, 0)); pres := pres || greatest(1, coalesce((st ->> 'presence')::numeric, 30));
    agi := agi || coalesce(ch.agility, 5)::numeric + random(); stance := stance || coalesce(tac ->> 'stance', 'balanced'); skw := skw || coalesce(tac ->> 'skill', 'mid');
    items := items || coalesce(tac -> 'items', '[]'::jsonb); used := used || false; stun := stun || 0; focus := focus || 0; fell := fell || false;
    hits := hits || 0; crits := crits || 0; whistle := whistle || false;
  end loop;
  perform set_config('request.jwt.claims', coalesce(oc, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(os, ''), true);
  n := cardinality(ids);
  select avg(v) into avg_lv from unnest(lv) v; select avg(v) into m_atk from unnest(atk) v; select avg(v) into m_crit from unnest(crit) v;
  select avg(v) into m_eva from unnest(eva) v; select avg(v) into m_red from unnest(red) v;
  base_hp := round((100 + 8 * avg_lv) * coalesce((tr ->> 'hp_mul')::numeric, 1));
  for i in 1..n loop
    atk[i] := m_atk + (atk[i] - m_atk) * 0.5; crit[i] := m_crit + (crit[i] - m_crit) * 0.5; eva[i] := m_eva + (eva[i] - m_eva) * 0.5; red[i] := m_red + (red[i] - m_red) * 0.5;
    hp := hp || base_hp; mx := mx || base_hp;
  end loop;
  select array_agg(o order by agi[o] desc) into ord from generate_series(1, n) o;
  maxx := coalesce((tr -> 'rounds' ->> case when n > 2 then 'team' else 'solo' end)::int, case when n > 2 then 16 else 12 end);
  lg := lg || jsonb_build_array(jsonb_build_object('x', 0, 'k', 'start', 't',
    (select string_agg(nm[o], '·') from generate_series(1, n) o where side[o] = 1) || ' 대 ' || (select string_agg(nm[o], '·') from generate_series(1, n) o where side[o] = 2) || ' — 비무대에 올랐다. 기세 ' || base_hp || '씩.'));
  <<duel>>
  for x in 1..maxx loop
    lastx := x;
    foreach i in array ord loop
      continue when hp[i] <= 0;
      if not exists (select 1 from generate_series(1, n) o where side[o] <> side[i] and hp[o] > 0) then exit duel; end if;
      if stun[i] > 0 then stun[i] := stun[i] - 1; lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'stun', 'w', side[i], 't', nm[i] || '이(가) 봉인에 묶여 움직이지 못했다.')); continue; end if;
      if hp[i] < mx[i] * (tr ->> 'heal_at')::numeric and jsonb_array_length(items[i]) > 0 then
        it := items[i] ->> 0; items[i] := items[i] - 0;
        heal := round(mx[i] * (case when public.world_item_base(it) <> it then (public.world_battle_item_rules() #>> '{tourney,hq_mul}')::numeric else 1 end) * coalesce((public.world_battle_item_rules() -> 'tourney' -> 'heal' ->> public.world_item_base(it))::numeric, 0.1));
        hp[i] := least(mx[i], hp[i] + heal);
        lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'heal', 'w', side[i], 't', nm[i] || '이(가) ' || coalesce((select item_name from public.world_item_catalog where item_id = it), '회복품') || '을(를) 써 기세 ' || heal || '을(를) 되찾았다.'));
        continue;
      end if;
      tgt := null; best := -1;
      for o in 1..n loop
        if side[o] <> side[i] and hp[o] > 0 then
          w := -ln(greatest(random(), 1e-9)) / power(pres[o], 1.3);
          if tgt is null or w < best then tgt := o; best := w; end if;
        end if;
      end loop;
      mul := 1; is_crit := false; pierce := false;
      if not used[i] and ((skw[i] = 'open') or (skw[i] = 'mid' and hp[i] < mx[i] * (tr #>> '{skill_at,mid}')::numeric) or (skw[i] = 'finish' and hp[tgt] < mx[tgt] * (tr #>> '{skill_at,finish}')::numeric)) then
        used[i] := true;
        sk := public.world_job_skill_rules() -> job[i]; skd := sk -> 'duel';
        if skd ->> 'kind' = 'heal' then
          heal := round(mx[i] * (skd ->> 'heal')::numeric); hp[i] := least(mx[i], hp[i] + heal);
          lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'skill', 'w', side[i], 't', replace(replace(sk ->> 'line', '{me}', nm[i]), '{n}', heal::text)));
          continue;
        elsif skd is not null then
          if skd ->> 'kind' = 'focus' then focus[i] := (skd ->> 'n')::int; focus_mul[i] := (skd ->> 'mul')::numeric; whistle[i] := job[i] = 'tamer';
          elsif skd ->> 'kind' = 'crit' then is_crit := true; mul := coalesce((skd ->> 'mul')::numeric, 1);
          elsif skd ->> 'kind' = 'pierce' then mul := (skd ->> 'mul')::numeric; pierce := true;
          elsif skd ->> 'kind' = 'bind' then mul := (skd ->> 'mul')::numeric; stun[tgt] := 1;
          else mul := coalesce((skd ->> 'mul')::numeric, 1); end if;
          lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'skill', 'w', side[i], 't', replace(replace(sk ->> 'line', '{me}', nm[i]), '{them}', nm[tgt])));
        end if;
      end if;
      if random() * 100 < eva[tgt] + coalesce((tr -> 'stance' -> stance[tgt] ->> 'evade')::numeric, 0) and not is_crit then
        lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'miss', 'w', side[i], 't', nm[tgt] || '이(가) ' || nm[i] || '의 공격을 흘려 피했다.'));
        continue;
      end if;
      select avg(lv[o]) into opp_lv from generate_series(1, n) o where side[o] <> side[i];
      dmg := atk[i] * (0.85 + random() * 0.3) * mul
             * coalesce((tr -> 'stance' -> stance[i] ->> 'dealt')::numeric, 1)
             * coalesce((tr -> 'stance' -> stance[tgt] ->> 'taken')::numeric, 1)
             * coalesce((jm -> job[i] ->> 'dealt')::numeric, 1) * coalesce((jm -> job[tgt] ->> 'taken')::numeric, 1)
             * (1 + greatest(-0.2, least(0.2, 0.02 * (lv[i] - opp_lv))))
             * (1 - case when pierce then 0 else red[tgt] end / 100.0);
      if focus[i] > 0 then dmg := dmg * coalesce(focus_mul[i], 1.4); focus[i] := focus[i] - 1; end if;
      if is_crit or random() * 100 < crit[i] then dmg := dmg * cm[i]; is_crit := true; end if;
      dmg := greatest(1, round(dmg));
      hp[tgt] := greatest(0, hp[tgt] - dmg); hits[i] := hits[i] + 1; if is_crit then crits[i] := crits[i] + 1; end if;
      lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', case when is_crit then 'crit' else 'hit' end, 'w', side[i], 'd', dmg,
        't', nm[i] || case when is_crit then '의 일격이 빈틈을 꿰뚫었다! ' else '이(가) ' || nm[tgt] || '에게 ' end || dmg || ' 피해'));
      if hp[tgt] > 0 and jsonb_typeof(sts[i] -> 'pet') = 'object' then
        ps := public.world_cb_pet_strike(jsonb_set(sts[i], '{attack}', to_jsonb(atk[i])), '{}'::jsonb, '{}'::jsonb, ids[i], whistle[i]);
        whistle[i] := false;
        if ps is not null then
          heal := greatest(1, round((ps ->> 'd')::numeric
                  * coalesce((tr -> 'stance' -> stance[i] ->> 'dealt')::numeric, 1) * coalesce((tr -> 'stance' -> stance[tgt] ->> 'taken')::numeric, 1)
                  * coalesce((jm -> job[i] ->> 'dealt')::numeric, 1) * coalesce((jm -> job[tgt] ->> 'taken')::numeric, 1)
                  * (1 - red[tgt] / 100.0)));
          hp[tgt] := greatest(0, hp[tgt] - heal);
          lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'hit', 'pet', true, 'w', side[i], 'd', heal, 't', (ps ->> 'name') || '이(가) ' || nm[tgt] || '을(를) 덮쳤다! ' || heal || ' 피해'));
        end if;
      end if;
      if hp[tgt] > 0 and n > 2 and random() < 0.1 then
        for o in 1..n loop
          if o <> i and side[o] = side[i] and hp[o] > 0 then
            heal := greatest(1, round(atk[o] * 0.4 * coalesce((jm -> job[o] ->> 'dealt')::numeric, 1) * coalesce((jm -> job[tgt] ->> 'taken')::numeric, 1) * (1 - red[tgt] / 100.0))); hp[tgt] := greatest(0, hp[tgt] - heal);
            lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'coop', 'w', side[i], 'd', heal, 't', nm[o] || '이(가) 틈을 놓치지 않고 이어 쳤다! ' || heal || ' 피해'));
            exit;
          end if;
        end loop;
      end if;
      if hp[tgt] <= 0 then fell[tgt] := true; lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'down', 'w', side[i], 't', nm[tgt] || '이(가) 무릎을 꿇었다.')); end if;
    end loop;
  end loop;
  select array_agg(cnt order by sd) into alive from (select g.sd, count(*) filter (where side[o] = g.sd and hp[o] > 0) cnt from generate_series(1, 2) g(sd), generate_series(1, n) o group by g.sd) z;
  select array_agg(rr order by sd) into sum_r from (select g.sd, coalesce(sum(hp[o] / mx[o]) filter (where side[o] = g.sd), 0) rr from generate_series(1, 2) g(sd), generate_series(1, n) o group by g.sd) z;
  win := case when alive[1] > 0 and alive[2] = 0 then 1 when alive[2] > 0 and alive[1] = 0 then 2 when sum_r[1] >= sum_r[2] then 1 else 2 end;
  lg := lg || jsonb_build_array(jsonb_build_object('x', lastx + 1, 'k', 'end', 'w', win, 't',
    (select string_agg(nm[o], '·') from generate_series(1, n) o where side[o] = win) || case when alive[3 - win] = 0 then '이(가) 상대를 모두 꺾었다.' else '이(가) 판정으로 이겼다.' end));
  return jsonb_build_object('winner', win, 'log', lg, 'exchanges', lastx + 1, 'ko', alive[3 - win] = 0,
    'hp', to_jsonb(hp), 'max', to_jsonb(mx), 'hits', to_jsonb(hits), 'crits', to_jsonb(crits), 'names', to_jsonb(nm),
    'flawless', (select bool_and(not fell[o]) and sum(hp[o] / mx[o]) / count(*) >= 0.5 from generate_series(1, n) o where side[o] = win));
end
$f$;
revoke all on function public.world_duel_run(uuid[], int[], jsonb[]) from public, anon, authenticated;
grant create on schema public to fn_owner_field;
alter function public.world_duel_run(uuid[], int[], jsonb[]) owner to fn_owner_field;
revoke create on schema public from fn_owner_field;
set role fn_owner_field;
revoke all on function public.world_duel_run(uuid[], int[], jsonb[]) from public, anon, authenticated;
grant execute on function public.world_duel_run(uuid[], int[], jsonb[]) to service_role;
reset role;

create or replace function public.world_tourney_duel(p_t uuid, p_a uuid, p_b uuid) returns jsonb
language plpgsql security definer set search_path = '' as $f$
declare e public.world_tourney_entries%rowtype; uid uuid; ids uuid[] := '{}'; sides int[] := '{}'; tacs jsonb[] := '{}'; s int;
begin
  for s in 1..2 loop
    select * into e from public.world_tourney_entries where entry_id = case when s = 1 then p_a else p_b end;
    foreach uid in array e.members loop
      ids := ids || uid; sides := sides || s;
      tacs := tacs || coalesce((select tactic from public.world_tourney_entrants where t_id = p_t and owner_id = uid), '{}'::jsonb);
    end loop;
  end loop;
  return (select r - 'hp' - 'max' - 'hits' - 'crits' - 'names' - 'ko' from public.world_duel_run(ids, sides, tacs) r);
end
$f$;

do $m$
declare src text; a int; b int; mid text;
begin
  select prosrc into src from pg_proc where proname = 'world_spar_respond' and pronamespace = 'public'::regnamespace;
  a := position('-- 전투 능력은 각자' in src);
  b := position('update public.world_spars set status = ''done''' in src);
  if a = 0 or b = 0 or b < a then raise exception 'spar anchor'; end if;
  mid := $s$
 nm := array[a.character_name, b.character_name]; ids := array[a.owner_id, b.owner_id];
 sa := public.world_duel_run(ids, array[1, 2], array[public.world_tourney_rules() -> 'spar', public.world_tourney_rules() -> 'spar']);
 if public.fn_owner_auth_uid() is distinct from uid then raise exception '비무 계산 중 오류가 났습니다.'; end if;
 win := (sa ->> 'winner')::int;
 hp := array[(sa -> 'hp' ->> 0)::numeric, (sa -> 'hp' ->> 1)::numeric];
 hits := array[(sa -> 'hits' ->> 0)::int, (sa -> 'hits' ->> 1)::int]; crits := array[(sa -> 'crits' ->> 0)::int, (sa -> 'crits' ->> 1)::int];
 select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('kind', l ->> 'k', 'who', (l ->> 'w')::int, 'dmg', (l ->> 'd')::numeric,
   'text', case when l ->> 'k' = 'start' then nm[1] || '과(와) ' || nm[2] || '이(가) ' || coalesce(a.location, '그 자리') || '에서 마주 섰습니다. ' || substring(l ->> 't' from '기세 [0-9]+씩') || '.' else l ->> 't' end)) order by o), '[]'::jsonb)
   into lg from jsonb_array_elements(sa -> 'log') with ordinality q(l, o);
 summary := nm[win] || case when hp[3 - win] <= 0 then '이(가) 상대를 무릎 꿇렸습니다.' else '이(가) 판정으로 이겼습니다.' end
 || ' (남은 기세 ' || nm[1] || ' ' || hp[1] || ' · ' || nm[2] || ' ' || hp[2] || ')';
 $s$;
  src := substr(src, 1, a - 1) || mid || substr(src, b);
  execute regexp_replace(pg_get_functiondef('public.world_spar_respond(uuid, boolean)'::regprocedure), 'AS \$function\$.*\$function\$', '', 's') || ' AS $fn$' || src || '$fn$';
end $m$;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126160000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
