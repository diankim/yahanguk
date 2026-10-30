-- ── 기존 함수 고치기(7.5.0, 앵커 바꾸기) ─────────────────────────────────────

-- 기록 트리거: 채집 기술 경험은 채집(foraging)·채광(mining), 제작은 그 제작법 분야 계열(요리 포함)
select pg_temp.yh_patch('public.world_event_char_apply()',
  $o$when k = 'gather' and coalesce(p ->> 'node', '') = 'herb' then 'herbalism'$o$,
  $n$when k = 'gather' and p ? 'line' then p ->> 'line'$n$);
select pg_temp.yh_patch('public.world_event_char_apply()',
  $o$when k = 'gather' and coalesce(p ->> 'node', '') = 'shrine' then 'spirit_gathering'$o$,
  $n$when k = 'gather' and coalesce(p ->> 'category', '') = 'relics' then 'mining'$n$);
select pg_temp.yh_patch('public.world_event_char_apply()',
  $o$select coalesce(required_skill, case craft_field when 'sealing' then 'wardcraft' when 'alchemy' then 'alchemy' when 'cooking' then '-' else 'smithing' end)$o$,
  $n$select public.world_craft_line_of(craft_field)$n$);

-- 물품 쓰기: 우수품(<id>_hq)은 기본 물품과 같은 효과에 회복 ×1.15(올림)·붙는 기운 지속 ×1.2
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$cures text[] := '{}'; cleared int := 0;$o$,
  $n$cures text[] := '{}'; v_base text := public.world_item_base(p_item_id); v_hq numeric := case when p_item_id like '%\_hq' then 1.15 else 1 end; v_dur numeric := 1; v_meal numeric := 1; cleared int := 0;$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$IF p_item_id <> 'revival_charm' THEN$o$, $n$IF v_base <> 'revival_charm' THEN$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$UPDATE public.world_characters SET inventory = inv, health = 50, mental = least(100, mental + 20), spiritual_power = least(100, spiritual_power + 15),$o$,
  $n$UPDATE public.world_characters SET inventory = inv, health = ceil(50 * v_hq)::int, mental = least(100, mental + ceil(20 * v_hq)::int), spiritual_power = least(100, spiritual_power + ceil(15 * v_hq)::int),$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$'회생 부적이 타올라 다시 일어섰습니다. 체력 50')$o$, $n$'회생 부적이 타올라 다시 일어섰습니다. 체력 ' || ceil(50 * v_hq)::int)$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$IF p_item_id = 'revival_charm' THEN RAISE EXCEPTION$o$, $n$IF v_base = 'revival_charm' THEN RAISE EXCEPTION$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$AND i.tradeable AND i.item_id !~ '^exg_'$o$, $n$AND i.tradeable AND i.item_id !~ '^exg_' AND i.base_item_id IS NULL$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$IF p_item_id NOT IN ('tonic', 'herbal_extract',$o$, $n$IF v_base NOT IN ('tonic', 'herbal_extract',$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$CASE p_item_id$o$, $n$CASE v_base$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$hp := round(hp * mul); mn := round(mn * mul); spg := round(spg * mul);$o$,
  $n$hp := round(ceil(hp * v_hq) * mul); mn := round(ceil(mn * v_hq) * mul); spg := round(ceil(spg * v_hq) * mul); er := ceil(er * v_hq)::int;
  v_dur := case when v_hq > 1 then 1.2 else 1 end;
  -- 든든한 한 끼(요리 43b)·칭호 food_dur_pct: 내가 먹은 음식 기운이 더 오래 간다
  v_meal := (case when 'cooking_c43b' = any (public.world_skill_procs(uid)) then 1.5 else 1 end) * (1 + public.world_title_bonus('food_dur_pct') / 100.0);$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$make_interval(mins => (SELECT duration_minutes FROM public.world_status_catalog WHERE status_key = buff))$o$,
  $n$make_interval(mins => ceil((SELECT duration_minutes FROM public.world_status_catalog WHERE status_key = buff) * v_dur * (CASE WHEN buff IN ('well_fed', 'warm_belly', 'vigor', 'sea_luck') THEN v_meal ELSE 1 END))::int)$n$, 2);

-- 현장 토벌 물품
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$IF it NOT IN ('tonic', 'herbal_extract', 'herb', 'ward_talisman', 'spirit_tea',$o$,
  $n$IF public.world_item_base(it) NOT IN ('tonic', 'herbal_extract', 'herb', 'ward_talisman', 'spirit_tea',$n$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$IF it IN ('spirit_tea', 'clear_spirit_pill', 'spirit_qi_pill', 'moonlight_essence', 'heavenly_dew') THEN$o$,
  $n$IF public.world_item_base(it) IN ('spirit_tea', 'clear_spirit_pill', 'spirit_qi_pill', 'moonlight_essence', 'heavenly_dew') THEN$n$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$heal := CASE it WHEN 'spirit_tea' THEN 10 WHEN 'clear_spirit_pill' THEN 20 WHEN 'spirit_qi_pill' THEN 35 WHEN 'moonlight_essence' THEN 55 ELSE 80 END;$o$,
  $n$heal := ceil((CASE WHEN it LIKE '%\_hq' THEN 1.15 ELSE 1 END) * CASE public.world_item_base(it) WHEN 'spirit_tea' THEN 10 WHEN 'clear_spirit_pill' THEN 20 WHEN 'spirit_qi_pill' THEN 35 WHEN 'moonlight_essence' THEN 55 ELSE 80 END)::int;$n$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$ELSIF it = 'ward_talisman' THEN$o$, $n$ELSIF public.world_item_base(it) = 'ward_talisman' THEN$n$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$mn := least(100, mn + 8);$o$, $n$mn := least(100, mn + ceil(8 * (CASE WHEN it LIKE '%\_hq' THEN 1.15 ELSE 1 END))::int);$n$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$heal := CASE it WHEN 'tonic' THEN 35 WHEN 'herbal_extract' THEN 22 WHEN 'rejuv_pill' THEN 60 WHEN 'grand_pill' THEN 100$o$,
  $n$heal := ceil((CASE WHEN it LIKE '%\_hq' THEN 1.15 ELSE 1 END) * CASE public.world_item_base(it) WHEN 'tonic' THEN 35 WHEN 'herbal_extract' THEN 22 WHEN 'rejuv_pill' THEN 60 WHEN 'grand_pill' THEN 100$n$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$ELSE CASE WHEN 'combo_first_aid_herbalism' = ANY (sk) THEN 22 ELSE 12 END END;$o$,
  $n$ELSE CASE WHEN 'combo_first_aid_herbalism' = ANY (sk) THEN 22 ELSE 12 END END)::int;$n$);

-- 동료 돌보기
select pg_temp.yh_patch('public.world_party_use_item(uuid,text)',
  $o$case p_item_id$o$, $n$case public.world_item_base(p_item_id)$n$);
select pg_temp.yh_patch('public.world_party_use_item(uuid,text)',
  $o$hp := round(hp * mul); mn := round(mn * mul);$o$,
  $n$hp := round(ceil(hp * (case when p_item_id like '%\_hq' then 1.15 else 1 end)) * mul); mn := round(ceil(mn * (case when p_item_id like '%\_hq' then 1.15 else 1 end)) * mul); er := ceil(er * (case when p_item_id like '%\_hq' then 1.15 else 1 end))::int;$n$);

-- 귀허의 주인·비무회 회복품
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text)',
  $o$coalesce(p_item, '') not in ('tonic',$o$, $n$public.world_item_base(coalesce(p_item, '')) not in ('tonic',$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$hv := case a ->> 'i' when 'tonic' then 35 when 'herbal_extract' then 22 when 'rejuv_pill' then 60 when 'grand_pill' then 100 when 'banyo_salve' then 70 else 0 end$o$,
  $n$hv := ceil((case when a ->> 'i' like '%\_hq' then 1.15 else 1 end) * case public.world_item_base(a ->> 'i') when 'tonic' then 35 when 'herbal_extract' then 22 when 'rejuv_pill' then 60 when 'grand_pill' then 100 when 'banyo_salve' then 70 else 0 end)$n$);
select pg_temp.yh_patch('public.world_tourney_tactic(text,text,text[],text)',
  $o$x <> all (ok_items)$o$, $n$public.world_item_base(x) <> all (ok_items)$n$);
select pg_temp.yh_patch('public.world_tourney_duel(uuid,uuid,uuid)',
  $o$heal := round(mx[i] * case it when 'grand_pill'$o$,
  $n$heal := round(mx[i] * (case when it like '%\_hq' then 1.15 else 1 end) * case public.world_item_base(it) when 'grand_pill'$n$);

-- 원정 보급품: 기본 + 우수품을 함께 세고 우수품을 먼저 챙겨 먼저 쓴다
select pg_temp.yh_patch('public.world_expedition_start(uuid,integer,text)',
  $o$q := least(20, coalesce((inv ->> k)::int, 0),$o$, $n$q := least(20, coalesce((inv ->> k)::int, 0) + coalesce((inv ->> (k || '_hq'))::int, 0),$n$);
select pg_temp.yh_patch('public.world_expedition_start(uuid,integer,text)',
  $o$IF q > 0 THEN sup := sup || jsonb_build_object(k, q); inv := public.world_inv_add(inv, k, -q); END IF;$o$,
  $n$IF q > 0 AND coalesce((inv ->> (k || '_hq'))::int, 0) > 0 THEN
      sup := sup || jsonb_build_object(k || '_hq', least(q, (inv ->> (k || '_hq'))::int));
      inv := public.world_inv_add(inv, k || '_hq', -least(q, (inv ->> (k || '_hq'))::int));
      q := q - (sup ->> (k || '_hq'))::int;
    END IF;
    IF q > 0 THEN sup := sup || jsonb_build_object(k, q); inv := public.world_inv_add(inv, k, -q); END IF;$n$);
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$if er >= 50 and coalesce((sup ->> 'ward_talisman')::int, 0) > 0 then$o$,
  $n$if er >= 50 and coalesce((sup ->> 'ward_talisman_hq')::int, 0) > 0 then
      sup := jsonb_set(sup, '{ward_talisman_hq}', to_jsonb((sup ->> 'ward_talisman_hq')::int - 1)); er := er - 18; mn := mn + 6;
      seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '정화 부적 (우수)을 태웠습니다. 침식 -18 · 정신 +6');
    elsif er >= 50 and coalesce((sup ->> 'ward_talisman')::int, 0) > 0 then$n$);
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$item := case when coalesce((sup ->> 'tonic')::int, 0) > 0 then 'tonic' when coalesce((sup ->> 'herbal_extract')::int, 0) > 0 then 'herbal_extract'$o$,
  $n$item := case when coalesce((sup ->> 'tonic_hq')::int, 0) > 0 then 'tonic_hq' when coalesce((sup ->> 'tonic')::int, 0) > 0 then 'tonic'
                   when coalesce((sup ->> 'herbal_extract_hq')::int, 0) > 0 then 'herbal_extract_hq' when coalesce((sup ->> 'herbal_extract')::int, 0) > 0 then 'herbal_extract'$n$);
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$heal := case item when 'tonic' then 35 when 'herbal_extract' then 22 else 12 end;$o$,
  $n$heal := case item when 'tonic' then 35 when 'tonic_hq' then 41 when 'herbal_extract' then 22 when 'herbal_extract_hq' then 26 else 12 end;$n$);
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$if coalesce((sup ->> 'revival_charm')::int, 0) > 0 then$o$,
  $n$if coalesce((sup ->> 'revival_charm_hq')::int, 0) > 0 then
        sup := jsonb_set(sup, '{revival_charm_hq}', to_jsonb((sup ->> 'revival_charm_hq')::int - 1)); hp := 35;
        lg := lg || jsonb_build_array('쓰러지기 직전 회생 부적 (우수)이 타올라 몸을 일으켰습니다.');
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '쓰러지기 직전 회생 부적 (우수)이 타올라 몸을 일으켰습니다. 체력 35');
      elsif coalesce((sup ->> 'revival_charm')::int, 0) > 0 then$n$);
-- 원정 채집 몫에 채집 계열 기본 기술 채집량
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$qty := 1 + floor(random() * (1 + least(tt, 3)))::int + coalesce(c.gathering_rank, 1) / 20;$o$,
  $n$qty := 1 + floor(random() * (1 + least(tt, 3)))::int + coalesce(c.gathering_rank, 1) / 20;
        qty := floor(qty * (1 + least(30, public.world_line_base(c.skill_progress, 'foraging', 'gather_qty_pct')) / 100.0) + random())::int;$n$);

-- 납품(퀘스트 넘김·의뢰): 우수품도 받고 기본을 먼저 가져간다
select pg_temp.yh_patch('public.world_quest_step_state(uuid,text)',
  $o$have := coalesce((c.inventory ->> k)::int, 0);$o$, $n$have := coalesce((c.inventory ->> k)::int, 0) + coalesce((c.inventory ->> (k || '_hq'))::int, 0);$n$);
select pg_temp.yh_patch('public.world_quest_report(text)',
  $o$  for k, v in select key, value::int from jsonb_each_text(coalesce(s.need -> 'give', '{}'::jsonb)) loop
    if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = k) then raise exception '잠근 물품은 넘길 수 없습니다. 잠금을 푼 뒤 다시 보고하세요.'; end if;
    if coalesce((inv ->> k)::int, 0) - v < (select count(*) from public.world_character_equipment e where e.owner_id = uid and e.item_id = k) then
      raise exception '장착 중인 물품은 넘길 수 없습니다.'; end if;
    inv := public.world_inv_add(inv, k, -v);
    if (inv ->> k)::int <= 0 then inv := inv - k; end if;
    msg := msg || '넘김: ' || (select item_name from public.world_item_catalog where item_id = k) || ' ×' || v || ' · ';
  end loop;$o$,
  $n$  for a, v in select key, value::int from jsonb_each_text(coalesce(s.need -> 'give', '{}'::jsonb)) loop
   -- 기본 물품 먼저, 모자란 만큼 우수품(7.5.0)
   for k, lim in select x.k, x.q from (select a as k, least(v, greatest(0, coalesce((inv ->> a)::int, 0))) as q, 0 as o
                                        union all select a || '_hq', v - least(v, greatest(0, coalesce((inv ->> a)::int, 0))), 1) x where x.q > 0 order by x.o loop
    if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = k) then raise exception '잠근 물품은 넘길 수 없습니다. 잠금을 푼 뒤 다시 보고하세요.'; end if;
    if coalesce((inv ->> k)::int, 0) - lim < (select count(*) from public.world_character_equipment e where e.owner_id = uid and e.item_id = k) then
      raise exception '장착 중인 물품은 넘길 수 없습니다.'; end if;
    if coalesce((inv ->> k)::int, 0) < lim then raise exception '넘길 물품이 모자랍니다.'; end if;
    inv := public.world_inv_add(inv, k, -lim);
    if (inv ->> k)::int <= 0 then inv := inv - k; end if;
    msg := msg || '넘김: ' || (select item_name from public.world_item_catalog where item_id = k) || ' ×' || lim || ' · ';
   end loop;
  end loop;
  lim := null;$n$);
select pg_temp.yh_patch('public.world_commission_claim(integer)',
  $o$IF coalesce((inv ->> m.target_item)::int, 0) < m.need THEN RAISE EXCEPTION '납품할 물품이 모자랍니다.'; END IF;$o$,
  $n$IF coalesce((inv ->> m.target_item)::int, 0) + coalesce((inv ->> (m.target_item || '_hq'))::int, 0) < m.need THEN RAISE EXCEPTION '납품할 물품이 모자랍니다.'; END IF;$n$);
-- (이 함수는 줄 끝이 CRLF라 한 줄 앵커로) 기본을 먼저, 모자란 만큼 우수품
select pg_temp.yh_patch('public.world_commission_claim(integer)',
  $o$inv := public.world_inv_add(inv, m.target_item, -m.need);$o$,
  $n$inv := CASE WHEN coalesce((inv ->> m.target_item)::int, 0) >= m.need THEN public.world_inv_add(inv, m.target_item, -m.need)
      ELSE public.world_inv_add(public.world_inv_add(inv, m.target_item || '_hq', -(m.need - greatest(0, coalesce((inv ->> m.target_item)::int, 0)))), m.target_item, -greatest(0, coalesce((inv ->> m.target_item)::int, 0))) END;$n$);
select pg_temp.yh_patch('public.world_commission_board()',
  $o$least(m.need, coalesce((c.inventory ->> m.target_item)::int, 0))$o$,
  $n$least(m.need, coalesce((c.inventory ->> m.target_item)::int, 0) + coalesce((c.inventory ->> (m.target_item || '_hq'))::int, 0))$n$);

-- 칭호 규칙 'skill' {skill, n}·'skill_all' {skill_all:[…], n}
select pg_temp.yh_patch('public.world_title_rule_ok(uuid,jsonb)',
  $o$ELSIF p_rule ? 'survey_full' THEN$o$,
  $n$ELSIF p_rule ? 'skill' THEN
    SELECT coalesce((ch.skill_progress -> (p_rule ->> 'skill') ->> 'rank')::int, 1) INTO v FROM public.world_characters ch WHERE ch.owner_id = p_owner;
    RETURN coalesce(v, 0) >= n;
  ELSIF p_rule ? 'skill_all' THEN
    SELECT count(*) INTO v FROM public.world_characters ch, jsonb_array_elements_text(p_rule -> 'skill_all') s(k)
     WHERE ch.owner_id = p_owner AND coalesce((ch.skill_progress -> s.k ->> 'rank')::int, 1) >= n;
    RETURN v >= jsonb_array_length(p_rule -> 'skill_all');
  ELSIF p_rule ? 'survey_full' THEN$n$);
select pg_temp.yh_patch('public.world_title_rule_progress(uuid,jsonb)',
  $o$elsif p_rule ? 'survey_full' then$o$,
  $n$elsif p_rule ? 'skill' then
    select coalesce((ch.skill_progress -> (p_rule ->> 'skill') ->> 'rank')::int, 1) into v from public.world_characters ch where ch.owner_id = p_owner;
  elsif p_rule ? 'skill_all' then
    select count(*) into v from public.world_characters ch, jsonb_array_elements_text(p_rule -> 'skill_all') s(k)
     where ch.owner_id = p_owner and coalesce((ch.skill_progress -> s.k ->> 'rank')::int, 1) >= n;
    n := jsonb_array_length(p_rule -> 'skill_all');
  elsif p_rule ? 'survey_full' then$n$);
select pg_temp.yh_patch('public.world_title_award_check(uuid,text)',
  $o$    IF public.world_title_rule_ok(p_owner_id, r) THEN$o$,
  $n$    IF (r ? 'skill' OR r ? 'skill_all') AND p_event_type IS NOT NULL AND p_event_type NOT IN ('craft', 'dismantle', 'gather', 'fish', 'idle', 'skill') THEN CONTINUE; END IF;
    IF public.world_title_rule_ok(p_owner_id, r) THEN$n$);
-- 자율 정비를 받으면 기술 칭호를 판정한다
select pg_temp.yh_patch('public.world_claim_idle_activity()',
  $o$update public.world_idle_activities set status='claimed'$o$,
  $n$perform public.world_title_award_check(public.fn_owner_auth_uid(), 'idle');
  update public.world_idle_activities set status='claimed'$n$);

-- 조사 계열 36단계 「영초 감별」: 위험도 7 이상 지역의 탐색·조사 지점 살피기에서 0.2% 귀령초(world_gwiryeong_reserve 거침)
select pg_temp.yh_patch('public.world_field_search()',
  $o$  -- 침식: 위험한 곳·삼경·어두운 곳에서 쌓이고$o$,
  $n$  IF 'tracking_x36' = ANY (sk) AND coalesce(r.danger_level, 0) >= 7 AND random() < 0.002 AND public.world_gwiryeong_reserve(uid, 'skill_tracking') THEN
    inv := public.world_inv_add(coalesce(inv, c.inventory, '{}'::jsonb), 'gwiryeong_cho', 1); txt := txt || ' 「영초 감별」 귀령초를 찾았다.'; payload := payload || jsonb_build_object('gwiryeong', 1);
  END IF;
  -- 침식: 위험한 곳·삼경·어두운 곳에서 쌓이고$n$);
select pg_temp.yh_patch('public.world_region_site_explore(text)',
  $o$ UPDATE public.world_characters SET inventory=inv,updated_at=now() WHERE owner_id=uid RETURNING * INTO c;$o$,
  $n$ IF 'tracking_x36' = ANY (public.world_skill_procs(uid)) AND coalesce(r.danger_level, 0) >= 7 AND random() < 0.002 AND public.world_gwiryeong_reserve(uid, 'skill_tracking') THEN
  inv := public.world_inv_add(inv, 'gwiryeong_cho', 1); result_text := result_text || ' 「영초 감별」 귀령초를 찾았다.';
 END IF;
 UPDATE public.world_characters SET inventory=inv,updated_at=now() WHERE owner_id=uid RETURNING * INTO c;$n$);

-- 무기 강화: 일품 단조(근접)·백보천양(원거리)·법륜 단련(술법)
select pg_temp.yh_patch('public.world_weapon_enhance()',
  $o$case when 'smithing_c43a' = any (public.world_skill_procs(uid)) then 10 else 0 end$o$,
  $n$case when (case coalesce(it.equipment_traits ->> 'weapon_type', 'melee') when 'ranged' then 'carpentry_c43a' when 'magic' then 'artifice_c43a' else 'smithing_c43a' end) = any (public.world_skill_procs(uid)) then 10 else 0 end$n$);
select pg_temp.yh_patch('public.world_enhance_quote()',
  $o$case when 'smithing_c43a' = any (public.world_skill_procs(uid)) then 10 else 0 end$o$,
  $n$case when (case coalesce(it.equipment_traits ->> 'weapon_type', 'melee') when 'ranged' then 'carpentry_c43a' when 'magic' then 'artifice_c43a' else 'smithing_c43a' end) = any (public.world_skill_procs(uid)) then 10 else 0 end$n$);

-- 수리: 수리 도구 우수품 60%, 24b 「현장 수리」 등은 그 계열이 만든 장비만 전부, 대장간 단골(단조 43b)은 단조 장비만 반값
select pg_temp.yh_patch('public.world_equipment_repair(text,text)',
  $o$mx int; cur int; nxt int; cost int := 0; inv jsonb; msg text;$o$,
  $n$mx int; cur int; nxt int; cost int := 0; inv jsonb; msg text; kit text; gl text; full_fix boolean;$n$);
select pg_temp.yh_patch('public.world_equipment_repair(text,text)',
  $o$    IF coalesce((inv ->> 'repair_kit')::int, 0) < 1 THEN RAISE EXCEPTION '장비 수리 도구가 없습니다. 안전지대 상점에서 사거나 만들 수 있습니다.'; END IF;
    inv := public.world_inv_add(inv, 'repair_kit', -1);
    nxt := CASE WHEN 'smithing_c24b' = ANY (public.world_skill_procs(uid)) THEN mx ELSE least(mx, cur + ceil(mx * 0.5)::int) END;$o$,
  $n$    IF coalesce((inv ->> 'repair_kit')::int, 0) + coalesce((inv ->> 'repair_kit_hq')::int, 0) < 1 THEN RAISE EXCEPTION '장비 수리 도구가 없습니다. 안전지대 상점에서 사거나 만들 수 있습니다.'; END IF;
    gl := public.world_gear_line(p_item_id);
    full_fix := gl IN ('smithing', 'artifice', 'weaving', 'leatherwork') AND (gl || '_c24b') = ANY (public.world_skill_procs(uid));
    -- 전부 되살리는 기술이 있으면 보통 도구 먼저, 아니면 우수품(60%) 먼저
    kit := CASE WHEN full_fix THEN CASE WHEN coalesce((inv ->> 'repair_kit')::int, 0) > 0 THEN 'repair_kit' ELSE 'repair_kit_hq' END
                ELSE CASE WHEN coalesce((inv ->> 'repair_kit_hq')::int, 0) > 0 THEN 'repair_kit_hq' ELSE 'repair_kit' END END;
    inv := public.world_inv_add(inv, kit, -1);
    nxt := CASE WHEN full_fix THEN mx ELSE least(mx, cur + ceil(mx * CASE WHEN kit = 'repair_kit_hq' THEN 0.6 ELSE 0.5 END)::int) END;$n$);
select pg_temp.yh_patch('public.world_equipment_repair(text,text)',
  $o$IF 'smithing_c43b' = ANY (public.world_skill_procs(uid)) THEN cost := greatest(2, cost / 2); END IF;$o$,
  $n$IF 'smithing_c43b' = ANY (public.world_skill_procs(uid)) AND public.world_gear_line(p_item_id) = 'smithing' THEN cost := greatest(2, cost / 2); END IF;$n$);
select pg_temp.yh_patch('public.world_repair_quote()',
  $o$equipped, me.half$o$, $n$equipped, (me.half and public.world_gear_line(i.item_id) = 'smithing') as half$n$);

-- 얻는 곳: 우수품은 기본 물품의 제작법(품질 85 이상)
select pg_temp.yh_patch('public.world_item_sources(text)',
  $o$'craft', exists (select 1 from public.world_crafting_recipes where output_item = p_item),$o$,
  $n$'craft', exists (select 1 from public.world_crafting_recipes where output_item = public.world_item_base(p_item)), 'hq', p_item like '%\_hq',$n$);
