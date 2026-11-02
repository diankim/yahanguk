-- 1.0.0d — 오픈 전 다시 검토·직업 균형
--  ① 동승 요청: 알림 문구 하위 질의의 표 별칭 r이 함수 변수 r과 겹쳐 늘 실패하던 것(1.0.0c)
--  ② 동승 운임 거절 문구를 노정패로
--  ③ 칭호 판정 한 번에 답사 완료 수를 한 번만 셈
--  ④ 직업 균형(Lv5·15·25·35 여섯 직업 실측): 껍질 가시 되돌림 최대 15·체력 1 아래로 안 깎음(거울막과 같게, 암영 검객 쓰러짐 15/15가 이것),
--     퇴마진 ×2.0→×1.7(부적 퇴마진 ×2.4→×2.1, 현장에서 퇴마관이 다른 직업의 두 배 빠르던 것),
--     원정 전투력에 술법 능력치(영기×0.75+의지×0.4가 힘보다 크면 그것) — 술법 직업이 힘만 보던 계산에서 약 30% 낮던 것,
--     원정 위험 사건이 위험도 6↑(균형·강행)에서 한 번도 안 나던 것: 위험 몫 (3%+위험도×1%)×태세(강행 1.3·신중 0.7)를 먼저 떼어 둠
lock table public.world_characters in access exclusive mode;

do $p$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_travel_party_invite_v2(uuid,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$(SELECT r.region_name FROM public.world_map_regions r WHERE r.region_id = p_region_id)$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor ride'; end if;
  execute replace(d, a, $b$(SELECT mr.region_name FROM public.world_map_regions mr WHERE mr.region_id = p_region_id)$b$);

  d := replace(pg_get_functiondef('public.world_travel_party_respond_v2(uuid,boolean)'::regprocedure), E'\r\n', E'\n');
  a := $a$'운행 재화가 부족합니다. 탈것 운임을 확인한 뒤 다시 시도하세요.'$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor fare'; end if;
  execute replace(d, a, $b$'노정패가 모자라 함께 떠날 수 없습니다(운임 %개).', fare$b$);
end $p$;

create or replace function public.world_survey_full_count(p_owner uuid)
returns integer language plpgsql stable set search_path to 'pg_catalog', 'public' as $f$
declare k text := p_owner::text || ':' || coalesce(pg_current_xact_id_if_assigned()::text, ''); c text; v int;
begin
  c := current_setting('yh.svf', true);
  if c is not null and c <> '' and split_part(c, '=', 1) = k and k not like '%:' then return split_part(c, '=', 2)::int; end if;
  v := jsonb_array_length(public.world_survey_full_list(p_owner));
  if k not like '%:' then perform set_config('yh.svf', k || '=' || v, true); end if;
  return v;
end $f$;

do $p$
declare d text; a text; b text;
begin
  d := replace(pg_get_functiondef('public.world_battle_action(text,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$thorn := greatest(1, round(dmg * 0.3)); hp := greatest(0, hp - thorn);$a$;
  b := $b$thorn := least(15, greatest(1, round(dmg * 0.3))); hp := greatest(least(hp, 1), hp - thorn);$b$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor thorn'; end if;
  d := replace(d, a, b);
  a := $a$CASE WHEN 'combo_exorcism_wardcraft' = ANY (sk) THEN 2.4 ELSE 2.0 END$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor exo'; end if;
  d := replace(d, a, $b$CASE WHEN 'combo_exorcism_wardcraft' = ANY (sk) THEN 2.1 ELSE 1.7 END$b$);
  execute d;

  d := replace(pg_get_functiondef('public.world_expedition_settle(uuid,integer)'::regprocedure), E'\r\n', E'\n');
  a := $a$power := 12 + c.level * 5 + c.strength * 2.5 + c.agility * 1.5$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor power'; end if;
  d := replace(d, a, $b$power := 12 + c.level * 5 + greatest(c.strength, c.spirit_affinity * 0.75 + c.willpower * 0.4) * 2.5 + c.agility * 1.5$b$);
  -- 위험 몫을 먼저 떼어 둠: (3% + 위험도×1%) × 태세(강행 1.3·신중 0.7), 나머지 싸움·채집·발견은 그 아래에서
  foreach a in array array[$a$if roll < p_fight then$a$, $a$elsif roll < p_fight + 0.35 then$a$, $a$elsif roll < p_fight + 0.35 + 0.22 + c.perception * 0.002 then$a$] loop
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor hazard %', a; end if;
    d := replace(d, a, regexp_replace(a, 'roll < (.*) then$', $r$roll < least(\1, (1 - (0.03 + danger * 0.01) * case e.stance when 'bold' then 1.3 when 'cautious' then 0.7 else 1 end)) then$r$));
  end loop;
  execute d;
end $p$;

update public.world_skill_catalog set description = replace(description, '퇴마진의 피해가 ×2.0에서 ×2.4로', '퇴마진의 피해가 ×1.7에서 ×2.1로')
 where skill_id = 'combo_exorcism_wardcraft';
-- 의무관 현장 처치 속도(Lv15 5.1턴, 다른 직업 2.9~4.3): 의술 8단계 술법 피해 +8% → +16%(의술 50단계 합 +17% → +25%).
-- 보스 체력은 참가자 공격력에 맞춰지므로 보스 난이도는 거의 그대로, 현장·원정만 빨라진다.
update public.world_skill_catalog set passive_effect = jsonb_set(passive_effect, '{damage_pct}', '16'),
  description = replace(description, '술법 피해 +8%,', '술법 피해 +16%,')
 where skill_id = 'medicine_t8' and (passive_effect ->> 'damage_pct')::int = 8;

-- 꾸미기 알림 조사: 「귀허 소용돌이 테」을 → 「…」를(world_josa)
do $p$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_cosmetic_award_check(uuid,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$'「' || t.cosmetic_name || '」을 얻었습니다$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor cosm'; end if;
  execute replace(d, a, $b$'「' || t.cosmetic_name || '」' || right(public.world_josa(t.cosmetic_name, '을', '를'), 1) || ' 얻었습니다$b$);
end $p$;

-- ⑤ 봉연의 그림자 퇴장(world_raid_leave)
--  · 모집 중에 나가면 신청을 거둔다(기록 없음).
--  · 싸우는 중에 나가면 그때까지 쌓은 기여도는 그대로 두고, 토벌이 끝날 때 그 몫만큼 보상(기여 1% 이상 조건 그대로).
--    나간 동안은 요괴가 노리지 않고, 광역·「모두 물러남」·기운 끊기 인원에서 빠지며, 가방 물품도 그대로 쓴다(out_until을 먼 뒤로).
--  · 다시 참가하면(world_raid_join) 보스 체력을 더 늘리지 않고 「쉬는 중」으로 돌아온다(나갔다 들어오기로 체력을 부풀리거나 줄이지 못하게).
--  · 결전(final)은 포기 투표로만 끝낸다.
alter table public.world_raid_members add column if not exists left_at timestamptz;

create or replace function public.world_raid_leave(p_raid uuid)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); rd public.world_raids%rowtype; mb public.world_raid_members%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into rd from public.world_raids where raid_id = p_raid for update;
  if not found then raise exception '알 수 없는 토벌입니다.'; end if;
  if rd.kind <> 'world' then raise exception '결전은 「포기하고 나오기」로만 끝낼 수 있습니다.'; end if;
  select * into mb from public.world_raid_members where raid_id = p_raid and owner_id = uid for update;
  if not found then raise exception '이 토벌에 참가하지 않았습니다.'; end if;
  if rd.status = 'signup' then
    delete from public.world_raid_members where raid_id = p_raid and owner_id = uid;
    perform public.world_raid_say(p_raid, 'join', mb.name || ' — 신청을 거두었습니다.');
    update public.world_raids set updated_at = now() where raid_id = p_raid;
    return jsonb_build_object('ok', true, 'content', '참가 신청을 거두었습니다.');
  end if;
  if rd.status <> 'fight' then raise exception '이미 끝난 토벌입니다.'; end if;
  if mb.left_at is not null then raise exception '이미 토벌에서 나왔습니다.'; end if;
  update public.world_raid_members set left_at = now(), out_until = now() + interval '30 days', fx = '{}'::jsonb
   where raid_id = p_raid and owner_id = uid;
  perform public.world_raid_say(p_raid, 'join', mb.name || ' — 토벌에서 물러나 떠났습니다(쌓은 기여는 남음).');
  update public.world_raids set updated_at = now() where raid_id = p_raid;
  return jsonb_build_object('ok', true, 'content', '토벌에서 나왔습니다. 지금까지의 기여도는 남아, 토벌이 끝나면 그 몫만큼 보상을 받습니다. 다시 참가하면 이어서 싸울 수 있습니다.');
end $f$;
revoke all on function public.world_raid_leave(uuid) from public, anon;
grant execute on function public.world_raid_leave(uuid) to authenticated;

do $p$
declare d text; a text;
begin
  -- 다시 참가: 나간 사람은 체력을 늘리지 않고 「쉬는 중」으로 돌아옴
  d := replace(pg_get_functiondef('public.world_raid_join(uuid)'::regprocedure), E'\r\n', E'\n');
  a := $a$  if exists (select 1 from public.world_raid_members where raid_id = p_raid and owner_id = uid) then raise exception '이미 신청했습니다.'; end if;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor rejoin'; end if;
  execute replace(d, a, $b$  if exists (select 1 from public.world_raid_members where raid_id = p_raid and owner_id = uid and left_at is not null) then
    update public.world_raid_members set left_at = null, out_until = now() where raid_id = p_raid and owner_id = uid;
    perform public.world_raid_say(p_raid, 'join', c.character_name || ' — 토벌에 돌아왔습니다.');
    update public.world_raids set updated_at = now() where raid_id = p_raid;
    return jsonb_build_object('ok', true, 'content', '토벌에 돌아왔습니다. 쉬는 중이니 준비되면 행동하세요.');
  end if;
$b$ || a);

  -- 행동: 나간 사람은 다시 참가해야 싸움, 나간 동료는 살릴 수 없음
  d := replace(pg_get_functiondef('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$  if mb.out_until is not null and mb.out_until > now() then$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor act'; end if;
  d := replace(d, a, $b$  if mb.left_at is not null then raise exception '토벌에서 나왔습니다. 「다시 참가」하면 이어서 싸울 수 있습니다.'; end if;
$b$ || a);
  a := $a$        if tm.out_until is null then raise exception '물러난 동료에게만 쓸 수 있습니다.'; end if;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor revive'; end if;
  d := replace(d, a, a || $b$
        if tm.left_at is not null then raise exception '토벌에서 나간 동료입니다.'; end if;$b$);
  execute d;

  -- 스냅샷: 나간 사람은 left, 쉼·물러남 초를 세지 않음
  d := replace(pg_get_functiondef('public.world_raid_snapshot_core(uuid)'::regprocedure), E'\r\n', E'\n');
  a := $a$'out', case when x.out_until > now() then ceil(extract(epoch from x.out_until - now())) end, 'resting', x.out_until is not null and x.out_until <= now(),$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor snap m'; end if;
  d := replace(d, a, $b$'out', case when x.left_at is null and x.out_until > now() then ceil(extract(epoch from x.out_until - now())) end, 'resting', x.left_at is null and x.out_until is not null and x.out_until <= now(), 'left', x.left_at is not null,$b$);
  a := $a$'out', case when me.out_until > now() then ceil(extract(epoch from me.out_until - now())) end, 'resting', me.out_until is not null and me.out_until <= now(),$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor snap me'; end if;
  d := replace(d, a, $b$'out', case when me.left_at is null and me.out_until > now() then ceil(extract(epoch from me.out_until - now())) end, 'resting', me.left_at is null and me.out_until is not null and me.out_until <= now(), 'left', me.left_at is not null,$b$);
  execute d;
end $p$;

-- 퇴장 뒷마무리: 퇴장한 봉연은 결전 시작을 막지 않음(귀허와 같게), 현장 띠의 「참가 중」에서 빠짐, 지역 문구는 「참가」
do $p$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_raid_final_start()'::regprocedure), E'\r\n', E'\n');
  a := $a$where m.owner_id = uid and x.status in ('signup', 'fight')) then$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor final busy'; end if;
  execute replace(d, a, $b$where m.owner_id = uid and x.status in ('signup', 'fight') and m.left_at is null) then$b$);

  d := replace(pg_get_functiondef('public.world_raid_brief()'::regprocedure), E'\r\n', E'\n');
  a := $a$'joined', exists (select 1 from public.world_raid_members m where m.raid_id = rd.raid_id and m.owner_id = uid)$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor brief'; end if;
  execute replace(d, a, $b$'joined', exists (select 1 from public.world_raid_members m where m.raid_id = rd.raid_id and m.owner_id = uid and m.left_at is null)$b$);

  d := replace(pg_get_functiondef('public.world_raid_join(uuid)'::regprocedure), E'\r\n', E'\n');
  a := $a$'%에 있어야 신청할 수 있습니다.'$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor join msg'; end if;
  execute replace(d, a, $b$'%에 있어야 참가할 수 있습니다.'$b$);
end $p$;

-- ⑥ 내 레벨보다 높은 지역: 일반 요괴가 내 레벨 +3에서 멈춰 +5·+8 지역도 +3처럼 싸워지던 것(침식은 +5부터 두 배인데 싸움·경험치는 그대로).
--    일반 요괴 상한 +3 → +5(정예·우두머리 +6 그대로). 레벨 차 경험치 1.5배도 +5에서 실제로 받는다.
do $p$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_battle_open(uuid,text,uuid,integer,integer)'::regprocedure), E'\r\n', E'\n');
  a := $a$lv := least(lv, p_level + CASE rk WHEN 'normal' THEN 3 ELSE 6 END);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor lvcap'; end if;
  execute replace(d, a, $b$lv := least(lv, p_level + CASE rk WHEN 'normal' THEN 5 ELSE 6 END);$b$);
end $p$;
