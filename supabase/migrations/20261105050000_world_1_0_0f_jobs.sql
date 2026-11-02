-- 1.0.0f — 퇴마관·월궁 사수 역할 맞바꿈(사용자 결정 2026-11-02): 술법은 한 방, 활은 꾸준히
--  · 퇴마진: ×1.7 → ×1.4 + 반드시 치명타(×1.5, 숙달 「멸마」면 ×2.0) — 한 방 2.1배(멸마 2.8배). 부적 퇴마진 ×2.1 → ×1.7(2.55배).
--  · 급소 사격: ×1.8 → ×1.4, 반드시 치명타 표시 없앰(원래 배율도 안 붙었음), 표식 2 → 3번(맞을 때마다 +25%) — 표식이 늘 걸려 꾸준히.
--  · 치명타: 퇴마관 술법 +6 없앰, 월궁 사수 원거리 +4.
--  · 퇴마관 기본 회피 4+레벨×0.3(영기·의지에는 회피가 안 붙어, 봉인술사 기본 방어처럼 — Lv5 약 10·Lv15 13·Lv35 19, 민첩을 찍는 월궁 사수 14·19·29의 2/3쯤)·달아나기 +8.
--  세 턴 한 바퀴(기술+평타 둘) 기대 피해: 퇴마관 약 +3%, 월궁 사수 약 ±0(표식이 다음 기술까지 이어짐).
lock table public.world_characters in access exclusive mode;

do $p$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_battle_action(text,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$CASE WHEN 'combo_exorcism_wardcraft' = ANY (sk) THEN 2.1 ELSE 1.7 END$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor exo'; end if;
  d := replace(d, a, $b$CASE WHEN 'combo_exorcism_wardcraft' = ANY (sk) THEN 1.7 ELSE 1.4 END$b$);
  a := $a$ELSIF skill_name = '급소 사격' THEN mul := mul * 1.8; v_fx := v_fx || jsonb_build_object('marked', 2);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor aim'; end if;
  d := replace(d, a, $b$ELSIF skill_name = '급소 사격' THEN mul := mul * 1.4; v_fx := v_fx || jsonb_build_object('marked', 3);$b$);
  a := $a$crit := skill_name = '급소 사격' OR force_crit OR random() < cc;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor crit'; end if;
  d := replace(d, a, $b$crit := skill_name = '퇴마진' OR force_crit OR random() < cc;$b$);
  a := $a$IF crit AND skill_name IS DISTINCT FROM '급소 사격' THEN mul := mul * crit_x; END IF;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor critx'; end if;
  d := replace(d, a, $b$IF crit THEN mul := mul * crit_x; END IF;$b$);
  execute d;

  d := replace(pg_get_functiondef('public.world_combat_stats(uuid,jsonb)'::regprocedure), E'\r\n', E'\n');
  a := $a$WHEN c.job_key = 'exorcist' AND style = 'magic' THEN 6 ELSE 0 END$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor cs crit'; end if;
  d := replace(d, a, $b$WHEN c.job_key = 'scout' AND style = 'ranged' THEN 4 ELSE 0 END$b$);
  a := $a$CASE WHEN c.job_key = 'scout' THEN 6 WHEN c.job_key = 'sealmaster' THEN 12 ELSE 0 END$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor cs eva'; end if;
  d := replace(d, a, $b$CASE WHEN c.job_key = 'scout' THEN 6 WHEN c.job_key = 'sealmaster' THEN 12 WHEN c.job_key = 'exorcist' THEN 4 + c.level * 0.3 ELSE 0 END$b$);
  a := $a$CASE WHEN c.job_key = 'scout' THEN 15 ELSE 0 END$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor cs flee'; end if;
  d := replace(d, a, $b$CASE WHEN c.job_key = 'scout' THEN 15 WHEN c.job_key = 'exorcist' THEN 8 ELSE 0 END$b$);
  execute d;
end $p$;

update public.world_skill_catalog set description = replace(description, '퇴마진의 피해가 ×1.7에서 ×2.1로', '퇴마진의 피해가 ×1.4에서 ×1.7로(반드시 치명타)')
 where skill_id = 'combo_exorcism_wardcraft';

-- 효과 점검(설명과 실제가 다른 것)
--  ① 응급 처방·「해독술」이 요화(나쁜 상태)를 「가장 먼저 끝나는 나쁜 상태」로 골라 끝내 버려 요화 단계를 앞당기던 것 — 요화·봉인은 빼고(해독 처방과 같게),
--     걷어 낸 것이 없으면 「걷어냈다」를 안 적음. 응급 처방 회복에 회복 보정(healing_pct)을 곱함(회복품·야전 처치와 같게).
--  ② 「약점 간파」 치명타 +10%가 세 번이 지나도 전투 끝까지 남던 것(focus > 0일 때만).
--  ③ 귀허: 「급소 드러내기」(암영 검객)가 「봉인 사슬」의 반격 막기·두 얼굴 묶기까지 걸던 것 — stagger 있는 기술(봉인 사슬)만.
--  ④ 귀허: 협동 회복 기술(응급 처치·맥 짚기·해독 침)에 응급 처치 단계 덤(봉연과 같게), 「파사 진언」 정신 +6(봉연과 같게).
--  ⑤ 귀허: 회복품을 동료에게 쓰면 의무관 ×1.4(현장 돌보기와 같게), 쓴 사람의 회복 보정(world_raid_stats.heal)도 곱함.
do $p$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_battle_action(text,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$          WHERE cs.owner_id = uid AND cs.expires_at > now() AND sc.polarity = 'negative' ORDER BY cs.expires_at LIMIT 1);
        IF FOUND THEN lines := lines || jsonb_build_array('「해독술」 나쁜 상태 하나를 풀었다.'); END IF;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor detox'; end if;
  d := replace(d, a, $b$          WHERE cs.owner_id = uid AND cs.expires_at > now() AND sc.polarity = 'negative' AND cs.status_key NOT IN ('yohwa', 'yohwa_seal') ORDER BY cs.expires_at LIMIT 1);
        IF FOUND THEN lines := lines || jsonb_build_array('「해독술」 나쁜 상태 하나를 풀었다.'); END IF;$b$);
  a := $a$    heal := least(40, 15 + c.vitality / 2 + c.willpower / 2); IF 'medicine_m50' = ANY (sk) THEN heal := round(heal * 1.5); END IF; IF 'combo_medicine_alchemy' = ANY (sk) THEN heal := heal + 10; END IF; hp := least(100, hp + heal);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor medheal'; end if;
  d := replace(d, a, $b$    heal := least(40, 15 + c.vitality / 2 + c.willpower / 2); IF 'medicine_m50' = ANY (sk) THEN heal := round(heal * 1.5); END IF; IF 'combo_medicine_alchemy' = ANY (sk) THEN heal := heal + 10; END IF;
    heal := round(heal * (1 + public.world_status_effect_total('healing_pct') / 100.0)); hp := least(100, hp + heal);$b$);
  a := $a$      WHERE cs.owner_id = uid AND cs.expires_at > now() AND sc.polarity = 'negative' ORDER BY cs.expires_at LIMIT 1);
    lines := lines || jsonb_build_array('응급 처방: 체력 ' || heal || ' 회복, 나쁜 상태 하나를 걷어냈다.');$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor medcure'; end if;
  d := replace(d, a, $b$      WHERE cs.owner_id = uid AND cs.expires_at > now() AND sc.polarity = 'negative' AND cs.status_key NOT IN ('yohwa', 'yohwa_seal') ORDER BY cs.expires_at LIMIT 1);
    lines := lines || jsonb_build_array('응급 처방: 체력 ' || heal || ' 회복' || CASE WHEN FOUND THEN ', 나쁜 상태 하나를 걷어냈다.' ELSE '.' END);$b$);
  a := $a$(CASE WHEN (v_pfx ? 'focus') THEN 0.1 ELSE 0 END)$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor focus'; end if;
  d := replace(d, a, $b$(CASE WHEN coalesce((v_pfx ->> 'focus')::int, 0) > 0 THEN 0.1 ELSE 0 END)$b$);
  execute d;

  d := replace(pg_get_functiondef('public.world_raid_stats(uuid)'::regprocedure), E'\r\n', E'\n');
  a := $a$  s := public.world_combat_stats(p_owner);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor rs'; end if;
  d := replace(d, a, $b$  s := public.world_combat_stats(p_owner) || jsonb_build_object('heal_pct', public.world_status_effect_total('healing_pct'));$b$);
  a := $a$'style', coalesce(s ->> 'style', 'melee'));$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor rs2'; end if;
  d := replace(d, a, $b$'style', coalesce(s ->> 'style', 'melee'), 'heal', coalesce((s ->> 'heal_pct')::numeric, 0));$b$);
  execute d;

  d := replace(pg_get_functiondef('public.world_gw_resolve(uuid)'::regprocedure), E'\r\n', E'\n');
  a := $a$, 'block', coalesce((vbfx ->> 'block')::int, 0) + 1, 'block_by', m.owner_id); sealed := true;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor gw expose'; end if;
  d := replace(d, a, $b$);
        if e ? 'stagger' then vbfx := vbfx || jsonb_build_object('block', coalesce((vbfx ->> 'block')::int, 0) + 1, 'block_by', m.owner_id); sealed := true; end if;$b$);
  -- 협동 회복: 0.65 × (1 + 응급 처치 단계/100)
  a := $a$    e := sk.effect;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor gw e'; end if;
  d := replace(d, a, $b$    e := sk.effect;
    if e ? 'amt' then
      e := e || jsonb_build_object('amt', round((e ->> 'amt')::int * (1 + coalesce((select (x.skill_progress -> 'first_aid' ->> 'rank')::int from public.world_characters x where x.owner_id = m.owner_id), 0) / 100.0)));
    end if;$b$);
  a := $a$      when 'gward' then update public.world_gw_members set fx = fx || public.world_cb_buff('gward', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor gw gward'; end if;
  d := replace(d, a, a || $b$
        if coalesce((e ->> 'mind')::int, 0) > 0 then
          update public.world_characters set mental = least(100, mental + (e ->> 'mind')::int), updated_at = now() where owner_id = tgt;
        end if;$b$);
  a := $a$* case when (a ->> 'i') like '%\_hq' then 1.15 else 1 end * case when m.job_key = 'medic' then 1.15 else 1 end;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor gw item'; end if;
  d := replace(d, a, $b$* case when (a ->> 'i') like '%\_hq' then 1.15 else 1 end * case when m.job_key = 'medic' then case when tgt = m.owner_id then 1.15 else 1.4 end else 1 end
             * (1 + coalesce((m.stats ->> 'heal')::numeric, 0) / 100.0);$b$);
  execute d;
end $p$;

update public.world_skill_catalog set description = '택일 기술 · 내가 구조한 동료가 체력 80으로 깨어난다(응급 처치 8단계 덤 +10은 따로)'
 where skill_id = 'first_aid_c43a';

update public.world_app_meta set value = '20261105050000' where key = 'db_version';
