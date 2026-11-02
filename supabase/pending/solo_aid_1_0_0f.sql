-- solo_aid_1_0_0f.sql — 혼자 도전 보정(world_solo_aid) 다시 맞춤 + 결전 받는 피해를 귀허와 떼어 냄 (제안, 배포 안 함)
-- 기준 DB: 복제본 yh_fx6(운영 + 1.0.0e + 1.0.0f 후보). world_raid_action 본문은 그 1.0.0f 후보 본문에 한 줄만 바꾼 것 —
-- 운영에 1.0.0f 후보가 먼저 들어가지 않으면 이 본문을 그대로 쓰지 말고 같은 한 줄만 옮길 것.
-- 배포는 §17 11-1(버퍼 + owner_inherit_begin/end; world_raid_action 주인 fn_owner_field).
--
-- 시뮬 조건(로컬 복제 PostgreSQL 16, 정석 플레이):
--   빌드: 귀허 Lv38 · 결전 Lv36(협동 기술 넷이 모두 열리는 첫 레벨 — Lv35면 36단계 기술이 잠김), 소속 본부 직속,
--         능력치 3×(L−1)을 주 능력치 상한(직업 기본+1.5L) → 체질 → 나머지, 직업 계열·전투 숙련 = 레벨, 분석·막기·응급 처치 L/3,
--         6단계 장비 한 벌(무기 *_keen · 갑옷 갈래 · 관모·신·노리개·호신부·탈), 회복품 반요 고약(체력 70).
--   행동: 수법 정석(제 사슬·이름 부르기(혼자 30%)·의무관 해독 침·얼굴에 맞는 공격·물살 예고에 버티기·결전 휘두르기 예고에 방어·
--         끊지 못할 기운 모으기는 마지막 차례에 방어·사슬에 묶이면 공격 대신 기술), 협동 기술은 다시 쓰기·영력이 되면 우선순위대로,
--         체력 50↓ 회복 기술·40↓ 회복품(귀허 2·결전 5). 일부러 하는 실수 0%, 엔진 난수는 그대로.
--   시간: 귀허 고른 라운드 3초(수법 5초)·물러난 라운드 마감까지, 결전 행동 2초·쓰러지면 30초 — 시각 칸을 그만큼 당겨 엔진이 직접 15·20분 판정.
--
-- 결과(승/판, 진 판의 보스 남은 체력 평균)
--   직업      | 지금 값(7.7.7r) 귀허 · 결전             | 제안 값 귀허 · 결전 (조정 마지막 20판 + 확인 20판 = 40판)
--   호위 무사 | 10/10(쓰러짐 6.6)·0/10(남은 29%)        | 9/40(2.3/10, 남은 4~6%) · 10/40(2.5/10, 남은 4~6%)
--   월궁 사수 | 10/10(4.5)·10/10(10분)                 | 5/20(2.5/10, solo −25/−46 확인판) · 8/40(2.0/10, 남은 7%)
--   퇴마관    | 10/10(4.0)·10/10(12.5분)               | 9/40(2.3/10, 남은 8~10%) · 14/40(3.5/10, 남은 6%)
--   의무관    | 10/10(2.6)·0/10(남은 39%)              | 10/40(2.5/10, 남은 11%) · 8/40(2.0/10, 남은 9~10%)
--   봉인술사  | 10/10(7.1)·8/10                        | 13/40(3.3/10, 남은 9~11%) · 12/40(3.0/10, 남은 5%)
--   암영 검객 | 10/10(5.2)·0/10(남은 31%)              | 13/40(3.3/10, 남은 6~11%) · 8/20(4.0/10, final 34 확인판; 36에서 16/40)
--   (n=20이면 95% 구간 대략 ±20%p, n=40이면 ±15%p)
-- 2·4인 귀허(같은 값, 보정은 혼자만 붙음 — world_gw_start n=1 · world_raid_action count=1): 호위+퇴마 10/10·암영+의무 10/10·넷 10/10, 쓰러짐 0
--   → 넷 10/10은 맞지만 둘 5/10 목표보다 훨씬 쉬움(혼자 보정과 무관한 별도 과제).

-- ① 결전은 solo_guard 대신 final_guard(없으면 0)를 쓴다: 귀허에서 맞춘 받는 피해 보정이 결전으로 새지 않게
CREATE OR REPLACE FUNCTION public.world_raid_action(p_raid uuid, p_action text, p_skill text DEFAULT NULL::text, p_target uuid DEFAULT NULL::uuid, p_item text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; rd public.world_raids%rowtype; mb public.world_raid_members%rowtype;
  tm public.world_raid_members%rowtype; sk public.world_coop_skills%rowtype; st jsonb; f jsonb; rfx jsonb; act text := lower(coalesce(p_action, ''));
  here text; sp int; inv jsonb; ammo text; mul numeric := 1; dmg int := 0; crit boolean := false; credit numeric := 0; h0 int; h1 int; amt int;
  n_act int; pick uuid; lv int; raw numeric; ph_mul numeric; k text; v jsonb; tgt uuid; nm text; newp int; tot numeric; acc numeric; rnd numeric; m record;
  bm text; bp numeric := 0; be text; bep numeric := 0; bc text; bcp numeric := 0; bcn text; ex numeric;
  bt int; tick boolean := true; bnow numeric; cbr jsonb; cbc jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if act not in ('attack', 'guard', 'item', 'coop') then raise exception '알 수 없는 행동입니다.'; end if;
  -- 7.7.7m: 내 1초 간격을 토벌 행(모두가 함께 씀)을 잠그기 전에 — 연타가 다른 참가자의 행동을 줄 세우지 않게
  perform public.world_rate_check('raid', uid, p_raid);
  select * into rd from public.world_raids where raid_id = p_raid for update;
  if not found then raise exception '알 수 없는 토벌입니다.'; end if;
  if rd.status <> 'fight' then raise exception '지금은 싸울 수 없습니다.'; end if;
  if rd.ends_at <= now() then perform public.world_raid_settle(p_raid, false); return public.world_raid_snapshot(p_raid); end if;
  select * into mb from public.world_raid_members where raid_id = p_raid and owner_id = uid for update;
  if not found then raise exception '참가 신청한 조사원만 싸울 수 있습니다. 진행은 관전으로 볼 수 있습니다.'; end if;
  if mb.last_action_at is not null and mb.last_action_at > now() - interval '1 second' then raise exception '숨을 고르는 중입니다. 잠시 후 다시 행동하세요.'; end if;
  if mb.left_at is not null then raise exception '토벌에서 나왔습니다. 「다시 참가」하면 이어서 싸울 수 있습니다.'; end if;
  if mb.out_until is not null and mb.out_until > now() then
    raise exception '물러나 숨을 고르는 중입니다(%초 뒤 돌아옴).', ceil(extract(epoch from mb.out_until - now())); end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태입니다.'; end if;
  select region_id into here from public.world_map_regions where region_name = c.location;
  if here is distinct from rd.region_id then raise exception '토벌이 벌어진 곳에 있어야 합니다.'; end if;
  if exists (select 1 from public.world_expeditions where owner_id = uid and status = 'active') then raise exception '원정 중에는 싸울 수 없습니다.'; end if;
  -- 토벌 보강 6.1.1
  if c.travel_destination is not null then raise exception '이동 중에는 싸울 수 없습니다.'; end if;
  if exists (select 1 from public.world_idle_activities where owner_id = uid and status = 'active') then raise exception '자율 활동 중에는 싸울 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false) and a.mlevel is not null) then
    raise exception '진행 중인 요괴 전투를 먼저 끝내세요.'; end if;

  st := public.world_raid_stats(uid);
  f := mb.fx; rfx := rd.fx; sp := c.spiritual_power; inv := coalesce(c.inventory, '{}'::jsonb);
  if mb.out_until is not null then mb.out_until := null;
    -- 결전: 쉬다가 돌아오면 체력 30(귀허와 같게 — 회복품이 셋뿐이라 체력 1로 돌아오면 곧바로 다시 쓰러진다)
    if rd.kind = 'final' and c.health < 30 then c.health := 30; update public.world_characters set health = 30, updated_at = now() where owner_id = uid; end if;
  end if;

  if act = 'attack' then
    -- 무기 소모: 근접 기력 2·술법 영력 3·원거리 한 발, 없으면 피해 절반
    if st ->> 'style' = 'magic' then if sp >= 2 then sp := sp - 2; else mul := mul * 0.5; end if;
    elsif st ->> 'style' = 'ranged' then
      ammo := public.world_ammo_of(uid);
      if ammo is not null and coalesce((inv ->> ammo)::int, 0) >= 1 then inv := public.world_inv_add(inv, ammo, -1); if (inv ->> ammo)::int <= 0 then inv := inv - ammo; end if;
      else mul := mul * 0.5; end if;
    else if sp >= 2 then sp := sp - 2; else mul := mul * 0.5; end if; end if;
    cbr := public.world_cb_attack(st, f, rfx, 0.85, 0.3);
    f := cbr -> 'fx'; rfx := cbr -> 'bfx'; crit := (cbr ->> 'crit')::boolean;
    if rd.kind = 'final' and (select count(*) from public.world_raid_members where raid_id = p_raid) = 1 then
      mul := mul * (1 + coalesce((public.world_solo_aid(c.job_key) ->> 'final_dmg')::numeric, (public.world_solo_aid(c.job_key) ->> 'solo_dmg')::numeric, 0) / 100.0);
    elsif rd.kind = 'final' then mul := mul * (1 + coalesce((public.world_solo_aid(c.job_key) ->> 'final_all')::numeric, 0) / 100.0); end if;
    dmg := greatest(1, round((cbr ->> 'd')::numeric * mul))::int;
    rd.hp := greatest(case when rd.fx ? 'last_night' then ceil(rd.max_hp * 0.03)::int else 0 end, rd.hp - dmg); mb.dmg := mb.dmg + dmg; credit := 0;
    -- 늘려 준 몫은 건 사람에게(공용 world_cb_boost_credits), 남은 몫이 내 기여
    for cbc in select * from jsonb_array_elements(public.world_cb_boost_credits(dmg, crit, cbr -> 'src', uid, (st ->> 'crit')::numeric)) loop
      if cbc ->> 2 = 'dmg' then credit := (cbc ->> 1)::numeric; else perform public.world_raid_credit(p_raid, (cbc ->> 0)::uuid, (cbc ->> 1)::numeric, 'boost'); end if;
    end loop;
    if rfx ? 'charge' then rfx := jsonb_set(rfx, '{charge,got}', to_jsonb((rfx -> 'charge' ->> 'got')::int + dmg)); end if;
    perform public.world_raid_say(p_raid, case when crit then 'crit' else 'atk' end, mb.name || ' — ' || dmg || '의 피해' || case when crit then '(치명타)' else '' end || '.');
  elsif act = 'guard' then
    f := f || jsonb_build_object('guard', 1); mb.guarded := mb.guarded + 1;
    perform public.world_raid_say(p_raid, 'guard', mb.name || ' — 방어 태세를 갖췄습니다.');
  elsif act = 'item' then
    -- 물품은 평소 쓰는 길(world_use_item)을 그대로 거친다
    update public.world_characters set spiritual_power = sp where owner_id = uid;
    h0 := c.health;
    perform set_config('yh.raid_item', '1', true);
    perform public.world_use_item(p_item);
    perform set_config('yh.raid_item', '', true);
    select * into c from public.world_characters where owner_id = uid;
    sp := c.spiritual_power; inv := coalesce(c.inventory, '{}'::jsonb); h1 := c.health;
    if rd.kind = 'final' and h1 > h0 then
      if mb.items_used >= 5 then raise exception '결전에서는 체력 회복품을 한 싸움에 다섯 개까지만 쓸 수 있습니다.'; end if;
      mb.items_used := mb.items_used + 1;
    end if;
    mb.heal := mb.heal + greatest(0, h1 - h0); credit := greatest(0, h1 - h0);
    perform public.world_raid_say(p_raid, 'item', mb.name || ' — ' || coalesce((select item_name from public.world_item_catalog where item_id = p_item), '물품') || '을(를) 썼습니다' || case when h1 > h0 then '(체력 +' || (h1 - h0) || ')' else '' end || '.');
  else
    select * into sk from public.world_coop_skills where skill_id = p_skill;
    if not found or sk.job_key <> c.job_key then raise exception '쓸 수 없는 협동 기술입니다.'; end if;
    if coalesce(c.combat_rank, 1) < sk.unlock_rank then raise exception '전투 숙련 %단계에 열리는 기술입니다.', sk.unlock_rank; end if;
    if mb.cd ? sk.skill_id and (mb.cd ->> sk.skill_id)::timestamptz > now() then
      raise exception '%은(는) %초 뒤에 다시 쓸 수 있습니다.', sk.skill_name, ceil(extract(epoch from (mb.cd ->> sk.skill_id)::timestamptz - now())); end if;
    if sp < sk.cost then raise exception '영력이 모자랍니다(필요 %).', sk.cost; end if;
    tgt := case when sk.target = 'self' then uid else coalesce(p_target, uid) end;
    if sk.target = 'ally' then
      select * into tm from public.world_raid_members where raid_id = p_raid and owner_id = tgt for update;
      if not found then raise exception '이 토벌에 참가한 동료에게만 쓸 수 있습니다.'; end if;
      if sk.effect ->> 'type' = 'revive' then
        if tm.out_until is null then raise exception '물러난 동료에게만 쓸 수 있습니다.'; end if;
        if tm.left_at is not null then raise exception '토벌에서 나간 동료입니다.'; end if;
      elsif tm.out_until is not null and tm.out_until > now() then raise exception '물러난 동료에게는 쓸 수 없습니다.'; end if;
    end if;
    sp := sp - sk.cost;
    mb.cd := mb.cd || jsonb_build_object(sk.skill_id, now() + make_interval(secs => sk.cooldown_s));
    mb.coop := mb.coop + 1; credit := 0;
    k := sk.effect ->> 'type'; v := sk.effect;
    -- 자신에게 거는 효과는 아래에서 mb.fx(f)에 바로 쓴다
    if sk.target in ('ally', 'self') and tgt = uid then
      if k in ('ward', 'might', 'evade', 'gward', 'crit_next') then f := f || public.world_cb_buff(k, v, uid);
      elsif k = 'shield' then f := f || jsonb_build_object('shield', coalesce((f ->> 'shield')::int, 0) + (v ->> 'amt')::int, 'shield_by', uid);
      elsif k = 'cleanse_heal' then f := f - 'bound';
      elsif k = 'cover' then raise exception '자기 자신은 대신 막을 수 없습니다.';
      end if;
    elsif sk.target = 'ally' then
      update public.world_raid_members set fx = case
          when k in ('ward', 'might', 'evade', 'gward', 'crit_next') then fx || public.world_cb_buff(k, v, uid)
          when k = 'shield' then fx || jsonb_build_object('shield', coalesce((fx ->> 'shield')::int, 0) + (v ->> 'amt')::int, 'shield_by', uid)
          when k = 'cleanse_heal' then fx - 'bound'
          when k = 'cover' then fx || jsonb_build_object('cover', jsonb_build_object('by', uid, 'until', now() + make_interval(secs => (v ->> 'secs')::int)))
          else fx end,
        out_until = case when k = 'revive' then least(out_until, now()) else out_until end
       where raid_id = p_raid and owner_id = tgt;
    end if;
    if k in ('heal', 'cleanse_heal', 'revive', 'sp', 'gward') then
      amt := case k when 'revive' then (v ->> 'hp')::int when 'sp' then 0 when 'gward' then 0
             else round((v ->> 'amt')::int * (1 + coalesce((c.skill_progress -> 'first_aid' ->> 'rank')::int, 0) / 100.0)) end;
      -- 결전: 회복 기술은 절반(회복품을 다섯으로 묶어 회복 기술이 승패를 혼자 정하던 것 — 회복 직업 없는 조가 해볼 만하게)
      if rd.kind = 'final' and k in ('heal', 'cleanse_heal') then amt := ceil(amt * 0.5); end if;
      if k = 'revive' then
        select health into h1 from public.world_characters where owner_id = tgt;
        update public.world_characters set health = greatest(health, amt), updated_at = now() where owner_id = tgt;
        amt := greatest(0, amt - coalesce(h1, 0));
      elsif k = 'sp' then
        if tgt <> uid then perform public.world_raid_credit(p_raid, uid, (select greatest(0, least((v ->> 'amt')::int, 100 - x.spiritual_power)) from public.world_characters x where x.owner_id = tgt) * coalesce((st ->> 'attack')::numeric, 0) * 0.05, 'boost'); end if;
        update public.world_characters set spiritual_power = least(100, spiritual_power + (v ->> 'amt')::int), updated_at = now() where owner_id = tgt and owner_id <> uid;
        if tgt = uid then sp := least(100, sp + (v ->> 'amt')::int); end if;
      elsif k = 'gward' then
        update public.world_characters set mental = least(100, mental + coalesce((v ->> 'mind')::int, 0)), updated_at = now() where owner_id = tgt;
      else
        if tgt = uid then
          select health into h0 from public.world_characters where owner_id = uid;
        end if;
        select health into h1 from public.world_characters where owner_id = tgt;
        update public.world_characters set health = least(100, health + amt), updated_at = now() where owner_id = tgt and health > 0;
        amt := case when coalesce(h1, 0) > 0 then greatest(0, least(100, h1 + amt) - h1) else 0 end;
      end if;
      if amt > 0 then mb.heal := mb.heal + amt; perform public.world_raid_credit(p_raid, uid, amt, case when tgt = uid then 'heal_self' else 'heal' end); end if;
    end if;
    if k = 'heal_all' then
      amt := round((v ->> 'amt')::int * (1 + coalesce((c.skill_progress -> 'first_aid' ->> 'rank')::int, 0) / 100.0));
      if rd.kind = 'final' then amt := ceil(amt * 0.5); end if; -- heal_all final half
      select sum(greatest(0, least(100, ch.health + amt) - ch.health)) into acc from public.world_characters ch join public.world_raid_members x on x.owner_id = ch.owner_id
       where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and ch.health > 0;
      update public.world_characters ch set health = least(100, ch.health + amt), updated_at = now()
        from public.world_raid_members x where x.raid_id = p_raid and x.owner_id = ch.owner_id and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and ch.health > 0;
      get diagnostics n_act = row_count;
      mb.heal := mb.heal + coalesce(acc, 0)::int; perform public.world_raid_credit(p_raid, uid, coalesce(acc, 0), 'heal');
    elsif k in ('ward_all', 'might_all', 'crit_all', 'rally', 'resonance') then
      update public.world_raid_members x set fx = x.fx || public.world_cb_buff(k, v, uid)
       where x.raid_id = p_raid and x.owner_id <> uid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id);
      f := f || public.world_cb_buff(k, v, uid);
    elsif k = 'taunt' then
      f := f || public.world_cb_buff('taunt', v, uid);
    elsif k = 'expose' then
      rfx := rfx || jsonb_build_object('expose', jsonb_build_object('pct', v -> 'pct', 'n', v -> 'n', 'by', uid), 'stagger', coalesce((rfx ->> 'stagger')::int, 0) + coalesce((v ->> 'stagger')::int, 0), 'stagger_by', uid);
    elsif k = 'delay' then
      rfx := rfx || jsonb_build_object('stagger', coalesce((rfx ->> 'stagger')::int, 0) + (v ->> 'n')::int, 'stagger_by', uid);
      if rfx ? 'charge' then rfx := jsonb_set(rfx, '{charge,left}', to_jsonb((rfx -> 'charge' ->> 'left')::int + 3));
        if (rfx -> 'charge' ->> 'until') is not null then rfx := jsonb_set(rfx, '{charge,until}', to_jsonb((rfx -> 'charge' ->> 'until')::numeric + 6)); end if; end if;
    elsif k = 'smoke' then
      rfx := rfx || jsonb_build_object('smoke', jsonb_build_object('miss', v -> 'miss', 'n', v -> 'n', 'by', uid));
    elsif k = 'break' then
      rfx := rfx || jsonb_build_object('break', v -> 'pct', 'break_by', uid);
    end if;
    select name into nm from public.world_raid_members where raid_id = p_raid and owner_id = tgt;
    perform public.world_raid_say(p_raid, 'coop', mb.name || ' — [' || sk.skill_name || '] ' ||
      case when sk.target = 'ally' and tgt <> uid then nm || '에게 · ' else '' end || sk.exp_text || '.');
  end if;

  -- 내 행동을 먼저 적고(체력·영력·가방), 보스의 반격은 그 뒤에 실제 캐릭터에 쓴다
  update public.world_characters set spiritual_power = sp, inventory = inv, updated_at = now() where owner_id = uid;
  mb.acts := mb.acts + 1; mb.last_action_at := now();
  mb.contrib := mb.contrib + credit * case when rd.kind = 'world' then least(1, mb.level / 30.0) else 1 end;
  update public.world_raid_members set fx = f, cd = mb.cd, dmg = mb.dmg, heal = mb.heal, coop = mb.coop, guarded = mb.guarded, acts = mb.acts,
    contrib = mb.contrib, last_action_at = mb.last_action_at, out_until = mb.out_until, stats = case when rd.kind = 'final' and (select count(*) from public.world_raid_members where raid_id = p_raid) = 1 then st || (public.world_solo_aid(c.job_key) - 'solo_guard' - 'final_guard') || jsonb_build_object('solo_guard', coalesce(public.world_solo_aid(c.job_key) -> 'final_guard', '0'::jsonb)) else st end, items_used = mb.items_used where raid_id = p_raid and owner_id = uid;
  perform public.world_raid_credit(p_raid, uid, credit, case act when 'attack' then 'dmg' when 'item' then 'heal_self' end);
  if act = 'coop' then perform public.world_raid_credit(p_raid, uid, 1, 'skill'); end if;

  rd.turn := rd.turn + 1;
  if rd.hp <= 0 then
    update public.world_raids set hp = 0, turn = rd.turn, fx = rfx, updated_at = now() where raid_id = p_raid;
    perform public.world_raid_say(p_raid, 'win', mb.name || '의 일격에 ' || rd.boss_name || '이(가) 무너졌습니다.');
    perform public.world_raid_settle(p_raid, true);
    return public.world_raid_snapshot(p_raid);
  end if;
  newp := case when rd.hp * 100 <= rd.max_hp * 40 then 3 when rd.hp * 100 <= rd.max_hp * 70 then 2 else 1 end;
  if newp > rd.phase then
    rd.phase := newp;
    perform public.world_raid_say(p_raid, 'phase', case newp when 2 then rd.boss_name || '의 사슬이 풀리며 움직임이 사나워집니다(2단계).'
                                                    else rd.boss_name || '이(가) 봉연의 기운을 끌어모으기 시작합니다(3단계).' end);
  end if;
  ph_mul := case rd.phase when 1 then 1 when 2 then 1.15 else 1.3 end * case when rd.kind = 'final' then 1.1 else 1 end;
  select count(*) into n_act from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id
   where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds' and ch.health > 1;

  -- 7.7.6: 서버 보스는 큰 수법을 2초 박자로 센다(결전은 차례 그대로)
  if rd.kind = 'world' then
    bnow := extract(epoch from now()); tick := false;
    if not (rfx ? 'beat_at') then rfx := rfx || jsonb_build_object('beat', 0, 'beat_at', bnow);
    elsif bnow >= (rfx ->> 'beat_at')::numeric + 2 then
      rfx := rfx || jsonb_build_object('beat', (rfx ->> 'beat')::int + 1, 'beat_at', bnow); tick := true;
    end if;
    bt := (rfx ->> 'beat')::int;
  else bt := rd.turn; end if;

  if coalesce((rfx ->> 'stagger')::int, 0) > 0 then
    rfx := case when (rfx ->> 'stagger')::int <= 1 then rfx - 'stagger' else jsonb_set(rfx, '{stagger}', to_jsonb((rfx ->> 'stagger')::int - 1)) end;
    if rfx ? 'stagger_by' then perform public.world_raid_credit(p_raid, (rfx ->> 'stagger_by')::uuid, public.world_raid_boss_base(p_raid, rd.kind, c.level) * ph_mul * 0.7 * (least(0.4, 0.8 / greatest(1, n_act)) + 0.8 * greatest(1, n_act) / 7.0), 'guard'); end if;
    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 휘청여 반격하지 못합니다.');
  elsif rfx ? 'charge' then
    rfx := jsonb_set(rfx, '{charge,left}', to_jsonb((rfx -> 'charge' ->> 'left')::int - case when tick then 1 else 0 end));
    if (rfx -> 'charge' ->> 'got')::int >= (rfx -> 'charge' ->> 'need')::int then
      rfx := rfx - 'charge';
      perform public.world_raid_say(p_raid, 'boss', '몰아친 공격에 ' || rd.boss_name || '의 기운 모으기가 끊겼습니다.');
    elsif (case when (rfx -> 'charge' ->> 'until') is not null then extract(epoch from now()) >= (rfx -> 'charge' ->> 'until')::numeric else (rfx -> 'charge' ->> 'left')::int <= 0 end) then
      rfx := rfx - 'charge';
      perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 모은 봉연의 기운을 터뜨립니다!');
      for m in select x.owner_id, x.level from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds' loop
        raw := public.world_raid_boss_base(p_raid, rd.kind, m.level) * ph_mul * 2.2 * case when rfx ? 'break' then (1 - (rfx ->> 'break')::numeric / 100.0) else 1 end;
        perform public.world_raid_hit(p_raid, m.owner_id, raw, 'burst');
      end loop;
      if rfx ? 'break_by' then perform public.world_raid_credit(p_raid, (rfx ->> 'break_by')::uuid, public.world_raid_boss_base(p_raid, rd.kind, c.level) * ph_mul * 2.2 * (rfx ->> 'break')::numeric / 100.0 * 0.7 * greatest(1, n_act), 'guard'); end if;
      rfx := rfx - 'break' - 'break_by';
    end if;
  elsif tick and rd.phase = 3 and bt % 11 = 0 then
    rfx := rfx || jsonb_build_object('charge', jsonb_build_object('left', case when rd.kind = 'world' then 4 else 5 + greatest(1, n_act) end, 'until', case when rd.kind = 'world' then round(extract(epoch from now())::numeric + 8, 2) end, 'need', public.world_raid_charge_need(p_raid, rd.kind, rd.max_hp), 'got', 0));
    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 기운을 모읍니다. ' || public.world_raid_charge_need(p_raid, rd.kind, rd.max_hp) || ' 넘게 몰아쳐 끊거나, 방어하세요!');
  elsif tick and bt % 7 = 0 then
    perform public.world_raid_say(p_raid, 'boss', rd.boss_name || '이(가) 크게 휘둘러 모두를 덮칩니다.');
    for m in select x.owner_id, x.level from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds' loop
      raw := public.world_raid_boss_base(p_raid, rd.kind, m.level) * ph_mul * 0.8 * case when rfx ? 'break' then (1 - (rfx ->> 'break')::numeric / 100.0) else 1 end;
      perform public.world_raid_hit(p_raid, m.owner_id, raw, 'slam');
    end loop;
    if rfx ? 'break_by' then perform public.world_raid_credit(p_raid, (rfx ->> 'break_by')::uuid, public.world_raid_boss_base(p_raid, rd.kind, c.level) * ph_mul * 0.8 * (rfx ->> 'break')::numeric / 100.0 * 0.7 * greatest(1, n_act), 'guard'); end if;
    rfx := rfx - 'break' - 'break_by';
  elsif tick and rd.phase >= 2 and bt % 5 = 0 then
    select x.owner_id, x.name into pick, nm from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) order by random() limit 1;
    if pick is not null then
      update public.world_raid_members set fx = fx || '{"bound":1}'::jsonb where raid_id = p_raid and owner_id = pick;
      perform public.world_raid_say(p_raid, 'boss', '봉연의 사슬이 ' || nm || '을(를) 휘감습니다(다음 공격 절반).');
    end if;
  elsif random() < least(0.4, 0.8 / greatest(1, n_act)) then
    -- 표적: 이목^1.3에 비례(호법 신장은 이목을 더한다)
    select x.owner_id, x.level into pick, lv from public.world_raid_members x
     where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds'
     order by public.world_cb_pick_key((x.stats ->> 'pres')::numeric + coalesce((x.fx -> 'taunt' ->> 'pres')::numeric, 0)) limit 1;
    if pick is not null then
      if rfx ? 'smoke' and random() * 100 < (rfx -> 'smoke' ->> 'miss')::numeric then
        perform public.world_raid_credit(p_raid, nullif(rfx -> 'smoke' ->> 'by', '')::uuid, public.world_raid_boss_base(p_raid, rd.kind, lv) * ph_mul * 0.7, 'guard');
        perform public.world_raid_say(p_raid, 'miss', '연막 속에서 ' || rd.boss_name || '의 공격이 빗나갔습니다.');
      else
        perform public.world_raid_hit(p_raid, pick, public.world_raid_boss_base(p_raid, rd.kind, lv) * ph_mul, 'single');
      end if;
      if rfx ? 'smoke' then rfx := case when (rfx -> 'smoke' ->> 'n')::int <= 1 then rfx - 'smoke' else jsonb_set(rfx, '{smoke,n}', to_jsonb((rfx -> 'smoke' ->> 'n')::int - 1)) end; end if;
    end if;
  end if;

  -- 결전에서 모두 물러나면 보스가 기운을 되찾는다
  if rd.kind = 'final' and not exists (select 1 from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id)) then
    rd.hp := least(rd.max_hp, rd.hp + round(rd.max_hp * 0.015));
    perform public.world_raid_say(p_raid, 'boss', '모두 물러난 사이 ' || rd.boss_name || '이(가) 기운을 되찾습니다(체력 +1.5%).');
  end if;
  rd.intent := case when rfx ? 'charge' then '기운을 모으는 중 — ' || case when rd.kind = 'world' then greatest(0, ceil(coalesce((rfx -> 'charge' ->> 'until')::numeric, extract(epoch from now()) + (rfx -> 'charge' ->> 'left')::int * 2) - extract(epoch from now())))::int || '초' else '남은 ' || (rfx -> 'charge' ->> 'left') || '번' end || ' 안에 ' || greatest(0, (rfx -> 'charge' ->> 'need')::int - (rfx -> 'charge' ->> 'got')::int) || ' 더 몰아치면 끊긴다'
                    when (bt + 1) % 7 = 0 then '크게 휘두를 낌새가 보인다 — 방어하라'
                    when rd.phase >= 2 and (bt + 1) % 5 = 0 then '사슬이 꿈틀거린다'
                    else null end;
  update public.world_raids set hp = rd.hp, turn = rd.turn, phase = rd.phase, fx = rfx, intent = rd.intent, updated_at = now() where raid_id = p_raid;
  return public.world_raid_snapshot(p_raid);
end $function$

;

-- ② 혼자 도전 보정 값
create or replace function public.world_solo_aid(p_job text)
 returns jsonb language sql immutable as $function$
  -- 혼자 도전 보정(1.0.0f): 협동 기술·6단계 장비 한 벌로 정석 플레이 시뮬(직업마다 귀허·결전 20~40판) → 혼자 2~3/10
  -- solo_dmg·solo_guard는 귀허, final_dmg·final_guard는 결전(final_guard 없으면 0 — world_raid_action)
  select case p_job
    when 'artificer'  then '{"solo_dmg": -38, "solo_guard": -22, "final_dmg": -2}'
    when 'scout'      then '{"solo_dmg": -25, "solo_guard": -46, "final_dmg": -47}'
    when 'exorcist'   then '{"solo_dmg": -42, "solo_guard": -17, "final_dmg": 13}'
    when 'medic'      then '{"solo_dmg": -21, "solo_guard": -46, "final_dmg": 18}'
    when 'sealmaster' then '{"solo_dmg": -42, "solo_guard": -32, "final_dmg": 5}'
    when 'analyst'    then '{"solo_dmg": -17, "solo_guard": -28, "final_dmg": 34}'
    else '{}' end::jsonb
$function$;
