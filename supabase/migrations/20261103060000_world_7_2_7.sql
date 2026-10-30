-- 7.2.7
-- 제보 22: 안전지대 사이를 잠깐 옮겨 다녀도 도착할 때마다 상태 굴림(나쁜 상태 약 24%)이 돌아 디버프가 붙던 것.
-- 안전지대에 도착한 이동은 상태를 굴리지 않고, 바깥 지역 도착도 굴림 값을 3배로 해 확률을 3분의 1로(나쁜 상태 약 24% → 약 8%, 사용자 결정).

create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $f$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
  execute replace(d, p_old, p_new);
end $f$;

select pg_temp.yh_patch('public.world_status_roll(text,jsonb)',
  $o$ roll:=random();$o$,
  $o$ roll:=random();
 if p_activity='travel' then roll := roll * 3; end if;$o$);
select pg_temp.yh_patch('public.world_status_roll(text,jsonb)',
  $o$ if p_activity='explore' and coalesce(p_context->>'kind','')='field_search' then return$o$,
  $o$ if p_activity='travel' and exists (select 1 from public.world_map_regions m where m.region_id = p_context->>'region_id' and m.is_safe_zone) then return jsonb_build_object('ok',true,'activity',p_activity,'applied',applied,'max_active',status_cap); end if;
 if p_activity='explore' and coalesce(p_context->>'kind','')='field_search' then return$o$);

-- ── 건의 반영(탐색력이 빡빡하다는 의견) ─────────────────────────────
-- ① 기척 숨기기: 요괴와 마주친 직후(첫 행동 전) 한 번, 민첩·감각으로 몰래 물러날 수 있다.
--    확률 = 25 + 민첩×0.8 + 감각×0.5 (+조사원 10) − 요괴가 높은 레벨마다 3 − 우두머리 15, 10~75%.
--    성공하면 싸움 없이 끝나고(보상 없음), 실패하면 요괴가 먼저 덤벼든다. 어느 쪽이든 탐색력은 돌려주지 않는다.
create or replace function public.world_sneak_pct(p_owner uuid, p_mlevel int, p_rank text)
returns int language plpgsql stable security definer set search_path = pg_catalog, public as $f$
begin
  return (select greatest(10, least(75, round(25 + c.agility * 0.8 + c.perception * 0.5 + case when c.job_key = 'scout' then 10 else 0 end
           - greatest(0, coalesce(p_mlevel, c.level) - c.level) * 3 - case when p_rank = 'guardian' then 15 else 0 end)))::int
          from public.world_characters c where c.owner_id = p_owner);
end $f$;
alter function public.world_sneak_pct(uuid, int, text) owner to fn_owner_field;
set role fn_owner_field;
revoke all on function public.world_sneak_pct(uuid, int, text) from public, anon, authenticated;
reset role;

select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$pf_skip boolean := coalesce(current_setting('yh.pf_skip', true), '') = '1'; pf_on$o$,
  $o$sneak_ok boolean := false; pf_skip boolean := coalesce(current_setting('yh.pf_skip', true), '') = '1'; pf_on$o$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$IF act NOT IN ('attack', 'skill', 'guard', 'item', 'flee') THEN$o$,
  $o$IF act NOT IN ('attack', 'skill', 'guard', 'item', 'flee', 'sneak') THEN$o$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$  IF act = 'flee' THEN
    IF coalesce((v_pfx ->> 'bound')::int, 0) > 0 THEN$o$,
  $o$  IF act = 'sneak' THEN
    IF pf_on OR a.turn_count > 0 OR v_pfx ? 'sneak_tried' THEN RAISE EXCEPTION '기척 숨기기는 요괴와 마주친 직후에만 할 수 있습니다.'; END IF;
    v_pfx := v_pfx || jsonb_build_object('sneak_tried', true);
    IF random() * 100 < public.world_sneak_pct(uid, a.mlevel, a.rank) THEN
      fled := true; sneak_ok := true;
      lines := lines || jsonb_build_array('「기척 숨기기」 숨을 죽이고 물러나 ' || m.monster_name || '의 눈을 피했다.');
    ELSE
      lines := lines || jsonb_build_array('기척을 숨기려다 들켰다! ' || m.monster_name || '이(가) 먼저 덤벼든다.');
    END IF;
  ELSIF act = 'flee' THEN
    IF coalesce((v_pfx ->> 'bound')::int, 0) > 0 THEN$o$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$    VALUES (uid, c.character_name, 'battle_fled', m.monster_name || '에게서 달아났습니다.', jsonb_build_object('region_id', a.region_id, 'monster_id', m.monster_id));$o$,
  $o$    VALUES (uid, c.character_name, 'battle_fled', m.monster_name || CASE WHEN sneak_ok THEN '을(를) 기척을 숨겨 피했습니다.' ELSE '에게서 달아났습니다.' END, jsonb_build_object('region_id', a.region_id, 'monster_id', m.monster_id, 'sneak', sneak_ok));$o$);
select pg_temp.yh_patch('public.world_field_battle_view(uuid)',
  $o$    'known', coalesce(x.defeated, 0) > 0,$o$,
  $o$    'known', coalesce(x.defeated, 0) > 0,
    'sneak', CASE WHEN a.turn_count = 0 AND NOT (coalesce(a.pfx, '{}'::jsonb) ? 'sneak_tried') THEN public.world_sneak_pct(q.o, a.mlevel, a.rank) END,$o$);

-- ② 조용히 살피기: 켜고 탐색하면 요괴 조우가 (민첩+감각)×0.8%만큼 줄고(최대 50%), 꾸러미도 그 절반만큼 준다.
create or replace function public.world_field_search_quiet()
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $f$
declare r jsonb;
begin
  perform set_config('yh.quiet', '1', true);
  r := public.world_field_search();
  perform set_config('yh.quiet', '', true);
  return r;
end $f$;
alter function public.world_field_search_quiet() owner to fn_owner_field;
set role fn_owner_field;
revoke all on function public.world_field_search_quiet() from public, anon;
grant execute on function public.world_field_search_quiet() to authenticated;
reset role;

select pg_temp.yh_patch('public.world_field_search()',
  $o$w_quiet float8 := 6;$o$,
  $o$w_quiet float8 := 6; q_mode float8 := 0; refund boolean := false;$o$);
select pg_temp.yh_patch('public.world_field_search()',
  $o$  w_haz := greatest(3, 8 + depth * 2 - c.agility / 10.0);$o$,
  $o$  w_haz := greatest(3, 8 + depth * 2 - c.agility / 10.0);
  IF coalesce(current_setting('yh.quiet', true), '') = '1' THEN
    q_mode := least(0.5, (coalesce(c.agility, 0) + coalesce(c.perception, 0)) * 0.008);
    w_enc := w_enc * (1 - q_mode); w_cache := w_cache * (1 - q_mode / 2);
  END IF;$o$);
select pg_temp.yh_patch('public.world_field_search()',
  $o$'location', c.location));$o$,
  $o$'location', c.location) || CASE WHEN q_mode > 0 THEN jsonb_build_object('quiet_mode', round((q_mode * 100)::numeric)) ELSE '{}'::jsonb END);$o$);

-- ③ 빈손(바람만 불었다 등)이면 탐색력 1을 돌려준다
select pg_temp.yh_patch('public.world_field_search()',
  $o$    IF battle IS NULL THEN outcome := 'quiet';$o$,
  $o$    IF battle IS NULL THEN outcome := 'quiet'; refund := true;$o$);
select pg_temp.yh_patch('public.world_field_search()',
  $o$    txt := (ARRAY['바람 소리만 들린다. 아무것도 없었다.', '한참을 살폈지만 눈에 띄는 것이 없다.', '멀리서 무언가 울었지만 다가오지 않았다.'])[1 + floor(random() * 3)::int];
    xp := 3;$o$,
  $o$    txt := (ARRAY['바람 소리만 들린다. 아무것도 없었다.', '한참을 살폈지만 눈에 띄는 것이 없다.', '멀리서 무언가 울었지만 다가오지 않았다.',
                  '이미 누가 훑고 지나간 자리다. 발자국만 어지럽다.', '젖은 낙엽을 뒤적였지만 쓸 만한 것은 없었다.', '길이 막혀 되돌아 나왔다.'])[1 + floor(random() * 6)::int];
    xp := 3; refund := true;$o$);
select pg_temp.yh_patch('public.world_field_search()',
  $o$  IF free_st THEN txt := txt || ' (「만리추적」 탐색력을 쓰지 않았다)'; END IF;$o$,
  $o$  IF free_st THEN txt := txt || ' (「만리추적」 탐색력을 쓰지 않았다)'; END IF;
  IF refund AND NOT free_st THEN left_st := public.world_stamina_change(uid, 1); txt := txt || ' 헛걸음이라 탐색력을 돌려받았다.'; payload := payload || jsonb_build_object('refund', 1); END IF;$o$);

-- ④ 꾸러미: 2~3개, 지역 특산물 확률 50%+깊이×8%, 전 3~(8+위험도×3). 대세력 조사원은 네 번에 한 번꼴로 길에서 만난 이와 나누고
--    그 세력의 영향력을 1.5 더 쌓는다(world_influence_tick이 payload.infl을 더한다, 한 번 정산 40 상한은 그대로)
select pg_temp.yh_patch('public.world_field_search()',
  $o$    IF random() < 0.35 + depth * 0.08 + (public.world_status_effect_total('rare_loot_pct')$o$,
  $o$    IF random() < 0.5 + depth * 0.08 + (public.world_status_effect_total('rare_loot_pct')$o$);
select pg_temp.yh_patch('public.world_field_search()',
  $o$    qty := 1 + CASE WHEN random() < 0.3 + depth * 0.05 THEN 1 ELSE 0 END;
    gil_gain := floor(random() * (4 + r.danger_level * 2))::int;
    inv := public.world_inv_add(inv, it, qty);
    txt := (ARRAY['누군가 숨겨 둔 꾸러미에서 ', '쓰러진 짐수레 밑에서 ', '바위 틈 보따리에서 ', '버려진 야영지에서 '])[1 + floor(random() * 4)::int]
           || (SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || ' ×' || qty || CASE WHEN gil_gain > 0 THEN '와(과) ' || gil_gain || '전' ELSE '' END || '을(를) 챙겼다.';
    xp := 5; payload := jsonb_build_object('item_id', it, 'qty', qty, 'gil', gil_gain);$o$,
  $o$    qty := 2 + CASE WHEN random() < 0.35 + depth * 0.05 THEN 1 ELSE 0 END;
    gil_gain := 3 + floor(random() * (6 + r.danger_level * 3))::int;
    IF c.major_faction_id IS NOT NULL AND NOT coalesce(r.is_safe_zone, false) AND r.home_faction_id IS NOT NULL AND random() < 0.25 THEN
      qty := qty - 1; gil_gain := gil_gain / 2;
      inv := public.world_inv_add(inv, it, qty);
      txt := (ARRAY['꾸러미를 풀다 길가의 부랑자와 눈이 마주쳤다. 절반을 나눠 주자 고개를 숙이며 고마워했다. ',
                    '굶주린 피난민 가족에게 꾸러미 몫을 나눠 주었다. 소문은 빨리 돈다. ',
                    '약초꾼 노파가 같은 꾸러미를 찾고 있었다. 반을 건네자 이 일대의 길을 일러 주었다. ',
                    '떠돌이 아이들에게 먹을 것을 나눠 주었다. 아이들이 깃발을 알아보고 손을 흔든다. ',
                    '짐을 잃은 행상에게 몫을 나눠 주었다. 그는 다음 장터에서 이 일을 말하겠다고 했다. '])[1 + floor(random() * 5)::int]
             || coalesce((SELECT f.faction_name FROM public.world_major_factions f WHERE f.faction_id = c.major_faction_id), '소속 세력') || '의 이름이 이 지역에 퍼졌다(세력 영향력 +1.5). 남은 몫 '
             || (SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || ' ×' || qty || CASE WHEN gil_gain > 0 THEN '와(과) ' || gil_gain || '전' ELSE '' END || '을(를) 챙겼다.';
      xp := 8; payload := jsonb_build_object('item_id', it, 'qty', qty, 'gil', gil_gain, 'infl', 1.5, 'shared', true);
    ELSE
      inv := public.world_inv_add(inv, it, qty);
      txt := (ARRAY['누군가 숨겨 둔 꾸러미에서 ', '쓰러진 짐수레 밑에서 ', '바위 틈 보따리에서 ', '버려진 야영지에서 ', '나무 구멍 속 보자기에서 ',
                    '무너진 제단 아래에서 ', '떠난 행상이 두고 간 짐에서 ', '물가에 걸린 바구니에서 '])[1 + floor(random() * 8)::int]
             || (SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || ' ×' || qty || CASE WHEN gil_gain > 0 THEN '와(과) ' || gil_gain || '전' ELSE '' END || '을(를) 챙겼다.';
      xp := 5; payload := jsonb_build_object('item_id', it, 'qty', qty, 'gil', gil_gain);
    END IF;$o$);
select pg_temp.yh_patch('public.world_influence_tick()',
  $o$else 0.3 end pts$o$,
  $o$else 0.3 + least(3, coalesce((e.payload ->> 'infl')::numeric, 0)) end pts$o$);

-- ⑤ 채집: 한국 시각 하루 처음 10번은 채집터와 상관없이 탐색력을 쓰지 않는다(그 뒤로는 1씩).
--    채집터마다 하루 제한으로 바꾸지 않은 까닭: 찾아 둔 채집터가 수십~수백 곳이라 탐색력 없이 돌면 재료가 넘쳐 시세·제작이 무너진다.
select pg_temp.yh_patch('public.world_field_gather(uuid)',
  $o$x text; k text; v int; tool_id text;$o$,
  $o$x text; k text; v int; tool_id text; free_day int := 0; gcnt int := 0;$o$);
select pg_temp.yh_patch('public.world_field_gather(uuid)',
  $o$  IF 'foraging_m50' = ANY (sk) AND random() < 0.25 THEN free_st := true;$o$,
  $o$  SELECT count(*)::int INTO gcnt FROM public.world_events e WHERE e.actor_id = uid AND e.event_type = 'gather'
     AND e.created_at >= (date_trunc('day', now() AT TIME ZONE 'Asia/Seoul') AT TIME ZONE 'Asia/Seoul') AND (e.payload ->> 'free_day') = 'true';
  IF gcnt < 10 THEN free_st := true; free_day := gcnt + 1; notes := notes || format('오늘의 무료 채집 %s/10 · 탐색력을 쓰지 않았다', gcnt + 1); END IF;
  IF NOT free_st AND 'foraging_m50' = ANY (sk) AND random() < 0.25 THEN free_st := true;$o$);
select pg_temp.yh_patch('public.world_field_gather(uuid)',
  $o$'profession_match', prof_match, 'extra', extra));$o$,
  $o$'profession_match', prof_match, 'extra', extra, 'free_day', free_day > 0));$o$);
select pg_temp.yh_patch('public.world_field_gather(uuid)',
  $o$'stamina', left_st, 'ready_at'$o$,
  $o$'stamina', left_st, 'free_left', greatest(0, 10 - gcnt - CASE WHEN free_day > 0 THEN 1 ELSE 0 END), 'ready_at'$o$);

-- ⑥ 꼬마 동무 알: 탐색에 더해 채집·낚시(잡았을 때)에서도 같은 확률(빛나는 알 0.06%·얼룩무늬 알 0.5%)
select pg_temp.yh_patch('public.world_event_char_apply()',
  $o$if k = 'explore' and p ->> 'kind' = 'field_search' and rare is null then$o$,
  $o$if ((k = 'explore' and p ->> 'kind' = 'field_search') or k = 'gather' or (k = 'fish' and coalesce((p ->> 'caught')::boolean, false))) and rare is null then$o$);

update public.world_patch_notes set body = body || $n$

## 7.2.7
**탐색·채집 (제보·건의 반영)**
- **기척 숨기기**: 탐색에서 요괴와 마주치면 첫 행동 전에 한 번 「기척 숨기기」를 고를 수 있습니다. 성공하면 싸우지 않고 지나가고, 실패하면 요괴가 먼저 덤벼듭니다. 성공 확률은 민첩·감각이 높을수록 오르고(10~75%, 현장 조사원은 조금 더 높음) 요괴 레벨이 높거나 우두머리면 내려갑니다. 어느 쪽이든 탐색력은 돌려받지 않습니다.
- **조용히 살피기**: 현장의 탐색 칸에서 켜고 끄며, 켜고 탐색하면 요괴와 마주칠 확률이 (민첩+감각)×0.8%만큼 줄어듭니다(최대 50%). 대신 꾸러미도 그 절반만큼 덜 나옵니다.
- **빈손이면 탐색력을 돌려받습니다**: 「바람 소리만 들린다」처럼 아무것도 없던 탐색은 탐색력 1을 돌려줍니다.
- **꾸러미가 좋아졌습니다**: 2~3개, 지역 특산물이 나올 확률과 함께 들어 있는 전이 늘었습니다. 대세력 조사원은 가끔 길에서 만난 사람과 꾸러미를 나누는데, 그러면 소속 세력의 영향력이 그 지역에 더 쌓입니다(세력 판도에 반영).
- **하루 처음 10번 채집은 탐색력을 쓰지 않습니다**(한국 시각 0시에 다시 10번, 채집터와 상관없이). 그 뒤로는 지금처럼 1씩 씁니다.
  - 「채집터마다 하루 몇 번」으로 바꾸지 않은 까닭: 오래 돌아다닌 조사원은 채집터를 수십~수백 곳 찾아 두었습니다. 탐색력 없이 그곳들을 매일 돌 수 있으면 재료가 쏟아져 재료·제작품 시세가 무너지고, 많이 돌아다닌 사람만 크게 앞서 갑니다. 그래서 누구나 같은 하루 10번으로 정했습니다.
- **꼬마 동무 알**이 탐색뿐 아니라 채집·낚시(잡았을 때)에서도 같은 확률로 나옵니다.

**그 밖**
- 안전지대에 도착하는 이동에서는 상태이상이 붙지 않습니다(안전지대 사이를 오가기만 해도 디버프가 생기던 것, 제보 22). 바깥 지역에 도착할 때 상태이상이 붙을 확률도 3분의 1로 줄였습니다(약 24% → 약 8%).
- 채팅 얼굴의 테두리를 프로필 카드의 테두리 그대로 작게 줄여 보여 줍니다(모서리 문양까지).
- 현장의 채집터 갈래 이름을 일지 › 도감과 같게 맞췄습니다(영물 → 영기, 광석 → 광맥, 수변 → 물가).
$n$ where note_id = '7.2.0' and position('## 7.2.7' in body) = 0;

update public.world_app_meta set value = '20261103060000' where key = 'db_version';
