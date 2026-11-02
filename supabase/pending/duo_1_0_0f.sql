-- duo_1_0_0f.sql — 귀허의 주인 「둘」 난이도 다시 맞춤 (제안, 배포 안 함)
-- 기준 DB: 복제본 yh_fx9(운영 + 1.0.0e + 1.0.0f 후보) + supabase/pending/solo_aid_1_0_0f.sql. 세 함수 본문은 yh_fx9 본문에서
-- 「when 2 then 0.95」만 바꾼 것 — 운영 본문이 다르면 같은 자리만 옮길 것. 혼자(n=1)·셋·넷 값은 그대로.
-- 바꾸는 곳
--   world_gw_start   주인 체력 인원 배율 둘 0.95 → 1.7 (max_hp·hp 두 곳)
--   world_gw_resolve 주인 손길·물살 피해(raw) 인원 배율 둘 0.95 → 1.4
--   world_gw_k       기여 K의 요괴 한 대(같은 배율) 둘 0.95 → 1.4 (피해 배율과 맞춤, 승패와 무관)
--   10장 결전(world_raid_begin_fight {2.4,3.3,2.9,3.3})은 바꾸지 않음 — 아래 결과.
-- 함께 고칠 것(이 파일 밖): assets/js/views/guide.js 1500줄 「둘 0.95배」 → 체력 1.7배·공격 1.4배, CLAUDE.md §3.5 인원 배율 문장,
--   마이그레이션에 넣을 때 끝에 world_app_meta db_version 줄. 배포는 §17 11-1(버퍼 + owner_inherit_begin/end;
--   world_gw_start·world_gw_resolve 주인 fn_owner_field, world_gw_k 주인 postgres).
--
-- 시뮬(로컬 복제 PostgreSQL 16, 이전 혼자 시뮬과 같은 빌드·정석 플레이: 귀허 Lv38 · 결전 Lv36, 6단계 장비, 반요 고약)
--   둘 정석 행동 보강: 이름을 잃었는데 불러 줄 동료가 없으면(동료 물러남) 스스로 부르기(30%)·의무관은 해독 침,
--   소용돌이에 퇴마관은 퇴마 결계. 결전 둘: 2초마다 둘 다 행동, 의무관 야전 소생·낮은 쪽 회복, 호위 무사 대신 막기,
--   휘두르기 예고에 방어·끊지 못할 기운 모으기는 마지막 차례에 방어·사슬에 묶이면 기술.
--
-- 귀허 둘 걸음(15조 전부, 승/판 · 진 판 주인 남은 체력 평균)
--   체력·피해 0.95·0.95(지금)  45/45  (평균 3분, 쓰러짐 0)                       → 너무 쉬움
--   3.5·0.95                     4/45   (진 판 23~46%)                           → 너무 어려움
--   2.0·0.95                    44/60 (7.3/10)  의무·봉인 조 4/4, 물리 둘(호위+사수 등)·암영 조 1~2/4
--   2.4·0.95                    47/90 (5.2/10)  사수+암영 0/6·호위+사수 1/6 ~ 봉인 조 5/6 — 체력만 올리면 같은 얼굴 조가 오래 끌려 크게 벌어짐
--   3.0·0.8                     43/90 (4.8/10)  퇴마+암영 0/6 ~ 사수+의무 6/6
--   1.6·1.4                     59/90 (6.6/10)  봉인 조 6/6, 물리 둘 3~4/6 — 싸움이 짧아져 조 차이가 줄어듦
--   1.8·1.5                     32/90 (3.6/10)
--   1.7·1.4 (제안)             181/368 (4.9/10)  아래 표
--
-- 귀허 둘 조별(지금 0.95·0.95 → 제안 1.7·1.4; 제안은 8판 + 확인 12~20판)
--   조              | 지금      | 제안 승/판  (/10) | 진 판 남은 체력 평균
--   호위+사수       | 3/3       | 10/20  5.0         | 14%
--   호위+퇴마       | 3/3       | 14/28  5.0         | 25%
--   호위+의무       | 3/3       | 10/20  5.0         | 15~21%
--   호위+봉인       | 3/3       | 15/20  7.5         | 2~23%
--   호위+암영       | 3/3       |  7/28  2.5         | 26~31%
--   사수+퇴마       | 3/3       | 12/28  4.3         | 19~31%
--   사수+의무       | 3/3       | 15/20  7.5         | 17~22%
--   사수+봉인       | 3/3       | 16/28  5.7         | 14~24%
--   사수+암영       | 3/3       |  8/28  2.9         | 25~36%
--   퇴마+의무       | 3/3       | 17/28  6.1         | 8~26%
--   퇴마+봉인       | 3/3       | 12/20  6.0         | 7~8%
--   퇴마+암영       | 3/3       |  5/20  2.5         | 21~26%
--   의무+봉인       | 3/3       | 23/28  8.2         | 15~21%
--   의무+암영       | 3/3       | 10/28  3.6         | 16%
--   봉인+암영       | 3/3       |  7/20  3.5         | 11~17%
--   (n=20이면 95% 구간 대략 ±20%p, n=28이면 ±18%p) 암영 검객이 든 조가 2.5~3.6으로 낮고 의무+봉인이 8.2로 높음 —
--   인원 배율 하나로는 못 좁힘(암영은 혼자 보정도 +11/+20이 필요했던 직업: 둘에서도 약한 직업 쪽 문제).
-- 넷(제안 값, 넷 배율은 그대로): 호위+퇴마+의무+암영 10/10 · 사수+봉인+의무+호위 10/10 · 사수+퇴마+봉인+암영 10/10, 쓰러짐 0
-- 혼자: n=1 갈래(체력 1.2·피해 1·world_solo_aid)는 손대지 않음 — solo_aid_1_0_0f.sql 결과 그대로.
--
-- 10장 결전 둘(바꾸지 않음, 체력 배율 3.3; 승/판)
--   조              | 3.3          | 3.5   | 3.7
--   호위+사수       | 4/4          | 6/6   | 4/4
--   호위+퇴마       | 12/12        | 6/6   | 4/4
--   호위+의무       | 4/4          | 6/6   | 3/4
--   호위+봉인       | 4/4          | 6/6   | 4/4
--   호위+암영       | 12/12        | 5/6   | 2/4
--   사수+퇴마       | 12/12        | 6/6   | 4/4
--   사수+의무       | 4/4          | 6/6   | 4/4
--   사수+봉인       | 12/12        | 6/6   | 4/4
--   사수+암영       | 4/4          | 6/6   | 4/4
--   퇴마+의무       | 10/12        | 2/6   | 0/4
--   퇴마+봉인       | 4/4          | 5/6   | 2/4
--   퇴마+암영       | 1/4 (진 판 2~9%) | 1/6 | 0/4
--   의무+봉인       | 12/12        | 2/6   | 1/4
--   의무+암영       | 2/12 (진 판 3~16%, 20분 시간 끝) | 0/6 | 0/4
--   봉인+암영       | 5/12 (진 판 1~6%) | 1/6 | 0/4
--   합계            | 약 8.5/10    | 7.1   | 6.3
--   사수 조는 8~10분에 쓰러짐 1~8로 늘 이기고(사수는 혼자 결전 final_dmg −46이 필요했던 직업), 암영·의무가 든 조는 20분이 모자라 짐.
--   체력 배율을 올리면 이미 아슬아슬한 암영·의무 조만 0으로 떨어지고 사수 조는 그대로 10/10 → 인원 배율로는 5~8에 못 넣음.
--   3.3을 그대로 둠(조별 차이는 직업 쪽 — 사수 결전 화력·암영 결전 화력 — 으로 따로 다룰 일).

CREATE OR REPLACE FUNCTION public.world_gw_start(p_fight uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare f public.world_gw_fights%rowtype; x record; s jsonb; sa numeric := 0; n int := 0;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'wait' then return; end if;
  for x in select m.owner_id, c.inventory, c.health from public.world_gw_members m join public.world_characters c using (owner_id) where m.fight_id = p_fight for update of c loop
    if coalesce((x.inventory ->> 'gwiheo_charm')::int, 0) < 1 or x.health <= 0 then
      delete from public.world_gw_members where fight_id = p_fight and owner_id = x.owner_id;
      continue;
    end if;
    update public.world_characters set inventory = public.world_inv_add(inventory, 'gwiheo_charm', -1), updated_at = now() where owner_id = x.owner_id;
    s := public.world_raid_stats(x.owner_id);
    update public.world_gw_members set stats = s, hp = greatest(30, least(100, x.health)) where fight_id = p_fight and owner_id = x.owner_id;
    insert into public.world_gw_records(owner_id, tries) values (x.owner_id, 1) on conflict (owner_id) do update set tries = world_gw_records.tries + 1;
    sa := sa + coalesce((s ->> 'attack')::numeric, 50); n := n + 1;
  end loop;
  if n = 0 then
    update public.world_gw_fights set status = 'failed', ended_at = now(), updated_at = now() where fight_id = p_fight;
    return;
  end if;
  update public.world_gw_fights set status = 'fight', max_hp = round(greatest(6000, sa * 40) * case n when 1 then 1.2 when 2 then 1.7 when 3 then 0.8 else 0.85 end),
         hp = round(greatest(6000, sa * 40) * case n when 1 then 1.2 when 2 then 1.7 when 3 then 0.8 else 0.85 end), phase = 1, round = 0, cycle = 0,
         ends_at = now() + interval '15 minutes', updated_at = now() where fight_id = p_fight;
  if n = 1 then update public.world_gw_members m set stats = m.stats || public.world_solo_aid(m.job_key) where fight_id = p_fight; end if;
  perform public.world_gw_say(p_fight, 0, 'phase', '빈 왕좌 위로 물이 솟아 사람 꼴이 된다. 귀허의 주인이 두 얼굴을 번갈아 든다. 「사람의 얼굴에는 사람의 칼을, 요괴의 얼굴에는…」 말끝이 물에 녹는다.');
  perform public.world_gw_next_round(p_fight);
end $function$;

CREATE OR REPLACE FUNCTION public.world_gw_resolve(p_fight uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare cbr jsonb; f public.world_gw_fights%rowtype; m record; a jsonb; av text; d numeric; boss_dmg numeric := 0; boss_heal numeric := 0; physical boolean;
  k text; vsum numeric := 0; tank_ok boolean := false; freed uuid[] := '{}'; tgt uuid; raw numeric; r int; alive int; cr boolean;
  sk public.world_coop_skills%rowtype; csp int; vbfx jsonb; vfx jsonb; tn text; e jsonb; aoe boolean; mul numeric; n int; need numeric;
  delayed boolean := false; sealed boolean := false; broke boolean := false; cover_by uuid; hit_who uuid; v_n int; v_hands int; v_h int; v_hit uuid[] := '{}'; v_miss numeric;
  v_mb text; v_mp numeric; v_eb text; v_ep numeric; v_cb text; v_cp numeric; v_cn text; v_brk uuid;
begin
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if f.status <> 'fight' then return; end if;
  if now() < f.round_ends_at and exists (select 1 from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act is null) then return; end if;
  r := f.round; k := f.mech ->> 'k'; aoe := coalesce((f.mech ->> 'aoe')::boolean, false); vbfx := coalesce(f.bfx, '{}'::jsonb);
  for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and act ->> 'a' = 'coop' order by joined_at loop
    select * into sk from public.world_coop_skills where skill_id = m.act ->> 's';
    if sk.skill_id is null then continue; end if;
    select spiritual_power into csp from public.world_characters where owner_id = m.owner_id for update;
    if coalesce(csp, 0) < sk.cost then perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 영력이 모자라 「' || sk.skill_name || '」이(가) 흩어졌습니다.'); continue; end if;
    update public.world_characters set spiritual_power = spiritual_power - sk.cost, updated_at = now() where owner_id = m.owner_id;
    update public.world_gw_members set acts = acts + 1, cds = jsonb_set(cds, array[sk.skill_id], to_jsonb(r + greatest(1, ceil(sk.cooldown_s / 5.0)::int)))
     where fight_id = p_fight and owner_id = m.owner_id;
    perform public.world_gw_credit(p_fight, m.owner_id, 1, 'skill');
    tgt := case when sk.target = 'self' then m.owner_id else coalesce(nullif(m.act ->> 't', '')::uuid, m.owner_id) end;
    select name into tn from public.world_gw_members where fight_id = p_fight and owner_id = tgt;
    e := sk.effect;
    if e ? 'amt' then
      e := e || jsonb_build_object('amt', round((e ->> 'amt')::int * (1 + coalesce((select (x.skill_progress -> 'first_aid' ->> 'rank')::int from public.world_characters x where x.owner_id = m.owner_id), 0) / 100.0)));
    end if;
    case e ->> 'type'
      when 'ward' then update public.world_gw_members set fx = fx || public.world_cb_buff('ward', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'ward_all' then update public.world_gw_members set fx = fx || public.world_cb_buff('ward_all', e, m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'might' then update public.world_gw_members set fx = fx || public.world_cb_buff('might', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'might_all' then update public.world_gw_members set fx = fx || public.world_cb_buff('might_all', e, m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'rally' then update public.world_gw_members set fx = fx || public.world_cb_buff('rally', e, m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'resonance' then update public.world_gw_members set fx = fx || public.world_cb_buff('resonance', e, m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'expose' then vbfx := vbfx || jsonb_build_object('expose', jsonb_build_object('n', (e ->> 'n')::int, 'pct', (e ->> 'pct')::int, 'by', m.owner_id));
        if e ? 'stagger' then vbfx := vbfx || jsonb_build_object('block', coalesce((vbfx ->> 'block')::int, 0) + 1, 'block_by', m.owner_id); sealed := true; end if;
      when 'heal' then
        select least(round((e ->> 'amt')::int * 0.65), 100 - x.hp) into d from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt and x.out_rounds = 0;
        perform public.world_gw_credit(p_fight, m.owner_id, d, case when tgt = m.owner_id then 'heal_self' else 'heal' end);
        update public.world_gw_members set heal = heal + greatest(0, coalesce(d, 0))::int where fight_id = p_fight and owner_id = m.owner_id;
        update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.65)::int) where fight_id = p_fight and owner_id = tgt and out_rounds = 0;
      when 'heal_all' then
        select sum(least(round((e ->> 'amt')::int * 0.65), 100 - x.hp)) into d from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not rest;
        perform public.world_gw_credit(p_fight, m.owner_id, d, 'heal');
        update public.world_gw_members set heal = heal + greatest(0, coalesce(d, 0))::int where fight_id = p_fight and owner_id = m.owner_id;
        update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.65)::int) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'cleanse_heal' then
        select least(round((e ->> 'amt')::int * 0.65), 100 - x.hp) into d from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt and x.out_rounds = 0;
        perform public.world_gw_credit(p_fight, m.owner_id, d, case when tgt = m.owner_id then 'heal_self' else 'heal' end);
        update public.world_gw_members set heal = heal + greatest(0, coalesce(d, 0))::int where fight_id = p_fight and owner_id = m.owner_id;
        update public.world_gw_members set hp = least(100, hp + round((e ->> 'amt')::int * 0.65)::int), nameless = false where fight_id = p_fight and owner_id = tgt and out_rounds = 0;
        freed := freed || tgt;
      when 'revive' then
        if exists (select 1 from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt and x.out_rounds > 0) then
          perform public.world_gw_credit(p_fight, m.owner_id, (e ->> 'hp')::int, 'heal'); end if;
        update public.world_gw_members set out_rounds = 0, rest = true, hp = (e ->> 'hp')::int where fight_id = p_fight and owner_id = tgt and out_rounds > 0;
      when 'cover' then update public.world_gw_members set fx = fx || jsonb_build_object('cover', tgt) where fight_id = p_fight and owner_id = m.owner_id;
      when 'gward' then update public.world_gw_members set fx = fx || public.world_cb_buff('gward', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
        if coalesce((e ->> 'mind')::int, 0) > 0 then
          update public.world_characters set mental = least(100, mental + (e ->> 'mind')::int), updated_at = now() where owner_id = tgt;
        end if;
      when 'break' then broke := true; v_brk := m.owner_id;
      when 'taunt' then update public.world_gw_members set fx = fx || public.world_cb_buff('taunt', e, m.owner_id) where fight_id = p_fight and owner_id = m.owner_id;
      when 'crit_all' then update public.world_gw_members set fx = fx || public.world_cb_buff('crit_all', e, m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'evade' then update public.world_gw_members set fx = fx || public.world_cb_buff('evade', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'smoke' then vbfx := vbfx || jsonb_build_object('smoke', jsonb_build_object('n', (e ->> 'n')::int, 'miss', (e ->> 'miss')::int, 'by', m.owner_id));
      when 'crit_next' then update public.world_gw_members set fx = fx || public.world_cb_buff('crit_next', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'delay' then vbfx := vbfx || jsonb_build_object('block', coalesce((vbfx ->> 'block')::int, 0) + (e ->> 'n')::int, 'block_by', m.owner_id); delayed := true;
      when 'shield' then update public.world_gw_members set fx = fx || jsonb_build_object('shield', coalesce((fx ->> 'shield')::int, 0) + (e ->> 'amt')::int, 'shield_by', m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'sp' then
        if tgt <> m.owner_id then perform public.world_gw_credit(p_fight, m.owner_id, (select greatest(0, least((e ->> 'amt')::int, 100 - x.spiritual_power)) from public.world_characters x where x.owner_id = tgt)
          * coalesce((m.stats ->> 'attack')::numeric, 0) * 0.05, 'boost'); end if;
        update public.world_characters set spiritual_power = least(100, spiritual_power + (e ->> 'amt')::int), updated_at = now() where owner_id = tgt;
      else null;
    end case;
    perform public.world_gw_say(p_fight, r, 'skill', m.name || ' — 「' || sk.skill_name || '」' || case when sk.target = 'ally' and tgt <> m.owner_id then ' → ' || coalesce(tn, '') else '' end || ' · ' || sk.exp_text
      || case e ->> 'type' when 'cleanse_heal' then case when k = 'chain' then ' (사슬이 느슨해집니다)' when k = 'name' then ' (흐려진 이름이 또렷해집니다)' else '' end
                           when 'delay' then case when k = 'vortex' then ' (물살이 잠시 멎습니다)' else '' end
                           when 'expose' then case when k = 'face' then ' (주인의 입이 사슬에 묶입니다)' else '' end
                           when 'break' then ' (물의 기세가 꺾입니다)' else '' end || '.');
  end loop;
  for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest order by joined_at loop
    a := coalesce(m.act, '{"a":"guard"}'::jsonb); av := a ->> 'a';
    if av = 'coop' then continue; end if;
    if m.act is not null then update public.world_gw_members set acts = acts + 1 where fight_id = p_fight and owner_id = m.owner_id; end if;
    select coalesce(x.fx, '{}'::jsonb) into vfx from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = m.owner_id;
    if av = 'attack' then
      cbr := public.world_cb_attack(m.stats, vfx, vbfx, 0.9, 0.2);
      vfx := cbr -> 'fx'; vbfx := cbr -> 'bfx'; cr := (cbr ->> 'crit')::boolean;
      v_mb := cbr -> 'src' ->> 'mb'; v_mp := (cbr -> 'src' ->> 'mp')::numeric; v_eb := cbr -> 'src' ->> 'eb'; v_ep := (cbr -> 'src' ->> 'ep')::numeric;
      v_cb := cbr -> 'src' ->> 'cb'; v_cp := (cbr -> 'src' ->> 'cp')::numeric; v_cn := cbr -> 'src' ->> 'cn';
      update public.world_gw_members set fx = vfx where fight_id = p_fight and owner_id = m.owner_id;
      d := (cbr ->> 'd')::numeric * (1 + coalesce((m.stats ->> 'solo_dmg')::numeric, 0) / 100.0);
      physical := coalesce(m.stats ->> 'style', 'melee') in ('melee', 'ranged');
      if m.nameless then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 이름을 잃어 칼끝이 주인에게 닿지 않습니다.');
      elsif k = 'face' and ((f.mech ->> 'face' = 'human') <> physical) then
        if sealed then
          d := d * 0.5; boss_dmg := boss_dmg + d;
          update public.world_gw_members set dmg = dmg + round(d)::int where fight_id = p_fight and owner_id = m.owner_id;
          perform public.world_gw_credit_hit(p_fight, m.owner_id, d, cr, v_mb, v_mp, v_eb, v_ep, v_cb, v_cp, v_cn, coalesce((m.stats ->> 'crit')::numeric, 5));
          perform public.world_gw_say(p_fight, r, 'atk', m.name || ' — 사슬에 묶인 주인이 힘을 삼키지 못합니다. ' || round(d) || '의 피해.');
        else
          boss_heal := boss_heal + round(d * 0.5);
          perform public.world_gw_say(p_fight, r, 'bad', m.name || ' — ' || case when physical then '요괴의 얼굴에 칼을 대자' else '사람의 얼굴에 술법을 쓰자' end || ' 주인이 그 힘을 삼켜 ' || round(d * 0.5) || ' 회복합니다.');
        end if;
      else
        if k = 'vortex' and m.owner_id::text <> f.mech ->> 'tank' then vsum := vsum + d; end if;
        boss_dmg := boss_dmg + d;
        update public.world_gw_members set dmg = dmg + round(d)::int where fight_id = p_fight and owner_id = m.owner_id;
          perform public.world_gw_credit_hit(p_fight, m.owner_id, d, cr, v_mb, v_mp, v_eb, v_ep, v_cb, v_cp, v_cn, coalesce((m.stats ->> 'crit')::numeric, 5));
        perform public.world_gw_say(p_fight, r, 'atk', m.name || ' — ' || round(d) || case when cr then '의 치명타.' else '의 피해.' end);
      end if;
    elsif av in ('guard', 'brace') then
      if k = 'vortex' and (m.owner_id::text = f.mech ->> 'tank' or (av = 'brace' and vfx ? 'taunt')) then tank_ok := true;
        perform public.world_gw_say(p_fight, r, 'good', m.name || ' — ' || case when av = 'brace' then '몸을 낮춰 소용돌이를 정면으로 받아 냅니다.' else '방패를 세우고 물살을 버팁니다.' end);
      elsif av = 'brace' and m.act is not null then
        perform public.world_gw_say(p_fight, r, 'guard', m.name || ' — 몸을 낮추고 버팁니다.');
      end if;
    elsif av = 'item' then
      tgt := coalesce(nullif(a ->> 't', '')::uuid, m.owner_id);
      if coalesce(m.items_used, 0) >= 2 then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 이 싸움에서는 회복품을 더 꺼낼 수 없습니다.');
      elsif coalesce(((select x.inventory from public.world_characters x where x.owner_id = m.owner_id) ->> (a ->> 'i'))::int, 0) < 1 then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 꺼낼 회복품이 없습니다.');
      else
        d := coalesce((public.world_item_fx(public.world_item_base(a ->> 'i')) ->> 'hp')::numeric, 0)
             * case when (a ->> 'i') like '%\_hq' then 1.15 else 1 end * case when m.job_key = 'medic' then case when tgt = m.owner_id then 1.15 else 1.4 end else 1 end
             * (1 + coalesce((m.stats ->> 'heal')::numeric, 0) / 100.0);
        update public.world_characters set inventory = public.world_inv_add(inventory, a ->> 'i', -1), updated_at = now() where owner_id = m.owner_id;
        perform public.world_gw_credit(p_fight, m.owner_id, (select least(round(d), 100 - x.hp) from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt and x.out_rounds = 0),
          case when tgt = m.owner_id then 'heal_self' else 'heal' end);
        update public.world_gw_members set hp = least(100, hp + round(d)::int) where fight_id = p_fight and owner_id = tgt and out_rounds = 0;
        update public.world_characters set mental = least(100, mental + ceil(coalesce((public.world_item_fx(public.world_item_base(a ->> 'i')) ->> 'mn')::numeric, 0) * case when (a ->> 'i') like '%\_hq' then 1.15 else 1 end)::int)
         where owner_id = tgt and coalesce((public.world_item_fx(public.world_item_base(a ->> 'i')) ->> 'mn')::numeric, 0) > 0;
        update public.world_gw_members set heal = heal + round(d)::int, items_used = items_used + 1 where fight_id = p_fight and owner_id = m.owner_id;
        perform public.world_gw_say(p_fight, r, 'good', m.name || ' — ' || coalesce((select x.name from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = tgt), '') || '의 체력 +' || round(d)
          || ' (회복품 ' || (coalesce(m.items_used, 0) + 1) || '/2).');
      end if;
    elsif av = 'call' then
      tgt := nullif(a ->> 't', '')::uuid;
      select name into tn from public.world_gw_members where fight_id = p_fight and owner_id = tgt;
      if k <> 'name' or not exists (select 1 from public.world_gw_members where fight_id = p_fight and owner_id = tgt and nameless) then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — ' || coalesce(tn, '') || '을(를) 불렀지만 메아리만 돌아옵니다.');
      elsif tgt <> m.owner_id or random() < 0.3 then
        update public.world_gw_members set nameless = false where fight_id = p_fight and owner_id = tgt;
        perform public.world_gw_say(p_fight, r, 'good', m.name || ' — 「' || tn || '!」 부르는 소리에 물에 녹던 이름이 되돌아옵니다.');
      else
        perform public.world_gw_say(p_fight, r, 'bad', m.name || ' — 제 이름을 스스로 부르려 했지만 목소리가 물에 녹았습니다.');
      end if;
    elsif av = 'chain' then
      if k <> 'chain' then
        perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 끊을 사슬이 없습니다.');
      elsif a ->> 'c' = f.mech -> 'colors' ->> m.owner_id::text then
        freed := freed || m.owner_id;
        perform public.world_gw_say(p_fight, r, 'good', m.name || ' — 자기 사슬(' || (a ->> 'c') || ')을 끊었습니다.');
      else
        perform public.world_gw_hurt(p_fight, m.owner_id, 20, r, '남의 사슬(' || coalesce(a ->> 'c', '?') || ')을 쳐 되튕긴 사슬에');
      end if;
    end if;
  end loop;
  if k = 'chain' then
    for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and not (owner_id = any (freed)) and (f.mech -> 'colors') ? owner_id::text loop
      perform public.world_gw_hurt(p_fight, m.owner_id, 999, r, '끊지 못한 사슬에 끌려가');
    end loop;
    if exists (select 1 from public.world_gw_members where fight_id = p_fight and not (owner_id = any (freed)) and (f.mech -> 'colors') ? owner_id::text) then
      for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest loop
        if broke then perform public.world_gw_credit(p_fight, v_brk, 30 * 0.7, 'guard'); end if;
        perform public.world_gw_hit(p_fight, m.owner_id, 60 * case when broke then 0.5 else 1 end, r, '사슬이 끌어당긴 물살에', true);
      end loop;
    end if;
  elsif k = 'name' then
    for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and nameless loop
      perform public.world_gw_hurt(p_fight, m.owner_id, 999, r, '이름을 끝내 찾지 못해');
    end loop;
  elsif k = 'vortex' then
    need := coalesce((f.mech ->> 'need')::numeric, 0) * case when delayed then 0.5 else 1 end;
    if tank_ok and vsum >= need then
      boss_dmg := boss_dmg + round(vsum * 0.5);
      perform public.world_gw_say(p_fight, r, 'good', '소용돌이를 끊었습니다! 흩어진 물살이 주인에게 되돌아가 ' || round(vsum * 0.5) || '의 피해를 더 줍니다.');
    else
      perform public.world_gw_say(p_fight, r, 'bad', case when not tank_ok then '쏠린 물살을 받아 낸 사람이 없었습니다. ' else '왕좌를 몰아친 힘이 모자랐습니다. ' end
        || '소용돌이가 모두를 삼키고 주인이 더 사나워집니다.' || case when broke then ' (퇴마 결계가 물살을 절반으로 꺾었습니다)' else '' end);
      if broke then perform public.world_gw_credit(p_fight, v_brk, (select sum(x.hp * 0.25) from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not rest), 'guard'); end if;
      update public.world_gw_members x set hp = greatest(1, (x.hp * case when broke or x.fx ? 'gward' then 0.75 else 0.5 end)::int), fx = x.fx - 'gward'
       where x.fight_id = p_fight and x.out_rounds = 0 and not rest;
      update public.world_gw_fights set enrage = enrage + 1 where fight_id = p_fight;
      f.enrage := f.enrage + 1;
    end if;
  end if;
  update public.world_gw_fights set hp = least(max_hp, greatest(0, hp - round(boss_dmg)::int + round(boss_heal)::int)), updated_at = now() where fight_id = p_fight returning * into f;
  if f.hp <= 0 then update public.world_gw_fights set bfx = vbfx where fight_id = p_fight; perform public.world_gw_settle(p_fight, true); return; end if;
  if k in ('face', 'normal') then
    -- 인원 배율(7.7.4, 1.0.0f 둘 다시 맞춤 — 정석 플레이 시뮬: 넷 거의 다 이김 · 둘 절반 · 혼자 드물게): 1명 1 · 2명 1.4 · 3명 0.8 · 4명 0.85(주인 체력 1.2 · 1.7 · 0.8 · 0.85, world_gw_start)
    raw := (35 + 4 * f.phase) * (1 + 0.15 * f.enrage)
           * (select case count(*) when 1 then 1 when 2 then 1.4 when 3 then 0.8 else 0.85 end from public.world_gw_members where fight_id = p_fight);
    if aoe then
      perform public.world_gw_say(p_fight, r, 'boss', '모아 둔 기운이 터집니다. 왕좌 아래의 물이 한꺼번에 쏟아집니다!' || case when broke then ' (퇴마 결계가 물살을 절반으로 꺾었습니다)' else '' end);
      if broke then perform public.world_gw_credit(p_fight, v_brk, raw * 0.9 * 0.5 * 0.7 * (select count(*) from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not rest), 'guard'); end if;
      for m in select * from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest loop
        perform public.world_gw_hit(p_fight, m.owner_id, raw * 0.9 * case when broke then 0.5 else 1 end, r, '쏟아지는 물살에', true);
      end loop;
    elsif coalesce((vbfx ->> 'block')::int, 0) > 0 then
      vbfx := case when (vbfx ->> 'block')::int > 1 then jsonb_set(vbfx, '{block}', to_jsonb((vbfx ->> 'block')::int - 1)) else vbfx - 'block' end;
      perform public.world_gw_credit(p_fight, nullif(vbfx ->> 'block_by', '')::uuid, raw * 0.7 * (select case when count(*) >= 4 then 2 when count(*) = 3 then 1.5 else 1 end from public.world_gw_members x where x.fight_id = p_fight), 'guard');
      perform public.world_gw_say(p_fight, r, 'good', '주인의 손길이 묶여 허공을 가릅니다.');
    else
      -- 손아귀 수는 인원에 맞춘다(7.7.4): 1·2명 하나, 3명 하나·둘 번갈아, 4명 둘 — 같은 사람을 두 번 노리지 않음
      select count(*) into v_n from public.world_gw_members where fight_id = p_fight;
      v_hands := case when v_n >= 4 then 2 when v_n = 3 then 1 + (r % 2) else 1 end;
      n := coalesce((vbfx -> 'smoke' ->> 'n')::int, 0);
      v_miss := coalesce((vbfx -> 'smoke' ->> 'miss')::numeric, 45);
      for v_h in 1 .. v_hands loop
        select * into m from public.world_gw_members x where x.fight_id = p_fight and x.out_rounds = 0 and not rest and not (x.owner_id = any (v_hit))
         order by public.world_cb_pick_key(coalesce((x.stats ->> 'pres')::numeric, 30) + coalesce((x.fx -> 'taunt' ->> 'pres')::numeric, 0)) limit 1;
        exit when m.owner_id is null;
        v_hit := v_hit || m.owner_id;
        hit_who := m.owner_id; cover_by := null;
        select owner_id into cover_by from public.world_gw_members where fight_id = p_fight and out_rounds = 0 and not rest and fx ->> 'cover' = m.owner_id::text and owner_id <> m.owner_id limit 1;
        select coalesce(x.fx, '{}'::jsonb) into vfx from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = m.owner_id;
        if n > 0 and random() * 100 < v_miss then
          perform public.world_gw_credit(p_fight, nullif(vbfx -> 'smoke' ->> 'by', '')::uuid, raw * 0.7, 'guard');
          perform public.world_gw_say(p_fight, r, 'miss', '연막 속에서 주인의 손길이 ' || m.name || '을(를) 비껴갑니다.');
        elsif random() * 100 < coalesce((m.stats ->> 'eva')::numeric, 0) + coalesce((vfx -> 'evade' ->> 'pct')::numeric, 0) + (case when m.stats ->> 'style' = 'magic' then 15 else 0 end) then
          if vfx -> 'evade' ->> 'by' is not null and vfx -> 'evade' ->> 'by' <> m.owner_id::text then
            perform public.world_gw_credit(p_fight, (vfx -> 'evade' ->> 'by')::uuid, raw * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0)
              * (vfx -> 'evade' ->> 'pct')::numeric / greatest(1, coalesce((m.stats ->> 'eva')::numeric, 0) + (vfx -> 'evade' ->> 'pct')::numeric), 'guard'); end if;
          if vfx ? 'evade' then update public.world_gw_members x set fx = case when (x.fx -> 'evade' ->> 'n')::int > 1 then jsonb_set(x.fx, '{evade,n}', to_jsonb((x.fx -> 'evade' ->> 'n')::int - 1)) else x.fx - 'evade' end where x.fight_id = p_fight and x.owner_id = m.owner_id; end if;
          perform public.world_gw_say(p_fight, r, 'miss', m.name || ' — 주인의 손길을 피했습니다.');
        elsif cover_by is not null then
          perform public.world_gw_credit(p_fight, cover_by, raw * 0.5 * (1 - least(80, coalesce((m.stats ->> 'red')::numeric, 0)) / 100.0), 'guard');
          perform public.world_gw_hit(p_fight, cover_by, raw * 0.5, r, (select name from public.world_gw_members where fight_id = p_fight and owner_id = cover_by) || '이(가) ' || m.name || ' 앞을 막아서 주인의 ' || case when v_h > 1 then '다른 ' else '' end || '손아귀를', false);
        else
          perform public.world_gw_hit(p_fight, hit_who, raw, r, case when v_h > 1 then '주인의 다른 손아귀에' else '주인의 손아귀에' end, false);
        end if;
      end loop;
      if n > 0 and coalesce(array_length(v_hit, 1), 0) > 0 then vbfx := case when n > 1 then jsonb_set(vbfx, '{smoke,n}', to_jsonb(n - 1)) else vbfx - 'smoke' end; end if;
    end if;
  end if;
  update public.world_gw_members set out_rounds = out_rounds - 1, rest = rest or out_rounds = 1, hp = case when out_rounds = 1 then 30 else hp end where fight_id = p_fight and out_rounds > 0;
  update public.world_gw_members set fx = fx - 'cover' where fight_id = p_fight and fx ? 'cover';
  update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;
  select count(*) into alive from public.world_gw_members where fight_id = p_fight and out_rounds = 0;
  -- 혼자면 쓰러져도 한 라운드 쉬고 돌아오므로 「모두 물러남」으로 끝내지 않는다(7.7.4). 대신 열한 번째로 쓰러지면 끝(쓰러짐 10번까지)
  if (select count(*) from public.world_gw_members where fight_id = p_fight) = 1 and (select max(falls) - coalesce(max((stats ->> 'solo_falls')::int), 0) from public.world_gw_members where fight_id = p_fight) > 10 then
    perform public.world_gw_say(p_fight, r, 'bad', '쓰러질 수 있는 횟수를 넘겼습니다. 홀로 선 이의 넋이 더는 버티지 못합니다.');
    perform public.world_gw_settle(p_fight, false); return;
  end if;
  if alive = 0 and (select count(*) from public.world_gw_members where fight_id = p_fight) > 1 then
    perform public.world_gw_say(p_fight, r, 'bad', '모두가 물러났습니다. 소용돌이가 왕좌를 덮습니다.');
    perform public.world_gw_settle(p_fight, false); return;
  end if;
  if now() >= f.ends_at then
    perform public.world_gw_say(p_fight, r, 'bad', '시간이 다 되었습니다. 귀허의 주인이 바다 밑으로 가라앉습니다.');
    perform public.world_gw_settle(p_fight, false); return;
  end if;
  perform public.world_gw_next_round(p_fight);
end $function$;

CREATE OR REPLACE FUNCTION public.world_gw_k(p_fight uuid)
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare aa numeric; n int; ph int;
begin
  select avg((stats ->> 'attack')::numeric), count(*) into aa, n from public.world_gw_members where fight_id = p_fight;
  select phase into ph from public.world_gw_fights where fight_id = p_fight;
  if aa is null then return 1; end if;
  return 1.5 * aa / ((35 + 4 * coalesce(ph, 1)) * case n when 1 then 1 when 2 then 1.4 when 3 then 0.8 else 0.85 end);
end $function$;
