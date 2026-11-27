revoke all on function public.world_gw_pushed_at(uuid, uuid), public.world_gw_pushed(uuid, uuid, integer), public.world_dh_nb(integer), public.world_dh_dist(integer, integer), public.world_dh_step(integer, text), public.world_dh_opp(text), public.world_dh_dirname(text),
  public.world_dh_rift(uuid, integer), public.world_dh_hurt_mul(uuid, uuid), public.world_dh_dmg(uuid, uuid, numeric, integer, text, boolean), public.world_dh_fall(uuid, uuid, integer, text),
  public.world_dh_push(uuid, uuid, text, integer, integer, text, boolean, boolean), public.world_dh_seq(uuid, integer, integer), public.world_dh_hz_cells(uuid, jsonb), public.world_dh_hp(uuid, integer),
  public.world_dh_begin(uuid, integer), public.world_dh_round(uuid), public.world_dh_steps(uuid, integer), public.world_dh_on_attack(uuid, uuid, integer, numeric),
  public.world_dh_mech(uuid, integer, boolean, boolean, uuid[]), public.world_dh_after(uuid, integer), public.world_dh_view(uuid, uuid), public.world_dh_settle(uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.world_gw_pushed_at(uuid, uuid), public.world_gw_pushed(uuid, uuid, integer), public.world_dh_nb(integer), public.world_dh_dist(integer, integer), public.world_dh_step(integer, text), public.world_dh_opp(text), public.world_dh_dirname(text),
  public.world_dh_rift(uuid, integer), public.world_dh_hurt_mul(uuid, uuid), public.world_dh_dmg(uuid, uuid, numeric, integer, text, boolean), public.world_dh_fall(uuid, uuid, integer, text),
  public.world_dh_push(uuid, uuid, text, integer, integer, text, boolean, boolean), public.world_dh_seq(uuid, integer, integer), public.world_dh_hz_cells(uuid, jsonb), public.world_dh_hp(uuid, integer),
  public.world_dh_begin(uuid, integer), public.world_dh_round(uuid), public.world_dh_steps(uuid, integer), public.world_dh_on_attack(uuid, uuid, integer, numeric),
  public.world_dh_mech(uuid, integer, boolean, boolean, uuid[]), public.world_dh_after(uuid, integer), public.world_dh_view(uuid, uuid), public.world_dh_settle(uuid, boolean)
  to service_role, fn_owner_field;

select pg_temp.yh_patch('public.world_gw_next_round(uuid)',
  $o$  if f.boss_id = 'baekya' then perform public.world_by_round(p_fight); return; end if;$o$,
  $n$  if f.boss_id = 'dohaesu' then perform public.world_dh_round(p_fight); return; end if;
  if f.boss_id = 'baekya' then perform public.world_by_round(p_fight); return; end if;$n$);

select pg_temp.yh_patch('public.world_gw_start(uuid)',
  $o$  if f.boss_id = 'baekya' then v_item := public.world_boss_rules() -> 'baekya' ->> 'item'; end if;$o$,
  $n$  if f.boss_id = 'baekya' then v_item := public.world_boss_rules() -> 'baekya' ->> 'item'; end if;
  if f.boss_id = 'dohaesu' then v_item := public.world_boss_rules() -> 'dohaesu' ->> 'item'; end if;$n$);
select pg_temp.yh_patch('public.world_gw_start(uuid)',
  $o$  if f.boss_id = 'baekya' then
    br := public.world_boss_fight_rules(p_fight);$o$,
  $n$  if f.boss_id = 'dohaesu' then
    br := public.world_boss_fight_rules(p_fight);
    update public.world_gw_fights set status = 'fight', max_hp = public.world_dh_hp(p_fight, n), hp = public.world_dh_hp(p_fight, n), phase = 1, round = 0, cycle = 0,
           ends_at = now() + make_interval(mins => (br ->> 'min')::int), updated_at = now() where fight_id = p_fight;
    perform public.world_dh_begin(p_fight, n);
    perform public.world_gw_next_round(p_fight);
    return;
  end if;
  if f.boss_id = 'baekya' then
    br := public.world_boss_fight_rules(p_fight);$n$);

select pg_temp.yh_patch('public.world_gw_settle(uuid,boolean)',
  $o$  if f.boss_id = 'baekya' then perform public.world_by_settle(p_fight, p_won); return; end if;$o$,
  $n$  if f.boss_id = 'dohaesu' then perform public.world_dh_settle(p_fight, p_won); return; end if;
  if f.boss_id = 'baekya' then perform public.world_by_settle(p_fight, p_won); return; end if;$n$);

select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.boss_id = 'baekya' then v_who := '백야'; end if;$o$,
  $n$  if f.boss_id = 'baekya' then v_who := '백야'; end if;
  if f.boss_id = 'dohaesu' then v_who := '도해수'; end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.boss_id = 'baekya' then perform public.world_by_steps(p_fight, r); end if;$o$,
  $n$  if f.boss_id = 'baekya' then perform public.world_by_steps(p_fight, r); end if;
  if f.boss_id = 'dohaesu' then perform public.world_dh_steps(p_fight, r); end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$      if f.boss_id = 'baekya' then d := d * public.world_by_on_attack(p_fight, m.owner_id, r); end if;$o$,
  $n$      if f.boss_id = 'baekya' then d := d * public.world_by_on_attack(p_fight, m.owner_id, r); end if;
      if f.boss_id = 'dohaesu' then d := public.world_dh_on_attack(p_fight, m.owner_id, r, d); end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$    elsif av in ('call', 'move', 'light', 'sweep') and f.boss_id = 'baekya' then$o$,
  $n$    elsif av in ('move', 'guide') and f.boss_id = 'dohaesu' then
      null;
    elsif av in ('call', 'move', 'light', 'sweep') and f.boss_id = 'baekya' then$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.boss_id = 'baekya' then boss_dmg := boss_dmg + public.world_by_mech(p_fight, r, broke, delayed, freed); end if;
  if f.boss_id = 'baekya' then null;$o$,
  $n$  if f.boss_id = 'baekya' then boss_dmg := boss_dmg + public.world_by_mech(p_fight, r, broke, delayed, freed); end if;
  if f.boss_id = 'dohaesu' then boss_dmg := boss_dmg + public.world_dh_mech(p_fight, r, broke, delayed, freed); end if;
  if f.boss_id in ('baekya', 'dohaesu') then null;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.boss_id = 'baekya' then
    update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;
    if public.world_by_after(p_fight, r) then return; end if;$o$,
  $n$  if f.boss_id = 'dohaesu' then
    update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;
    if public.world_dh_after(p_fight, r) then return; end if;
    select * into f from public.world_gw_fights where fight_id = p_fight;
  end if;
  if f.boss_id = 'baekya' then
    update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;
    if public.world_by_after(p_fight, r) then return; end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$    if f.boss_id = 'baekya' then raw := public.world_mk_raw(p_fight); end if;$o$,
  $n$    if f.boss_id in ('baekya', 'dohaesu') then raw := public.world_mk_raw(p_fight); end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$        when f.boss_id = 'baekya' then '흰 소매가 마당을 한꺼번에 휩씁니다!$o$,
  $n$        when f.boss_id = 'dohaesu' then '도해수가 온몸으로 몸부림칩니다! 판 위로 바닷물이 한꺼번에 넘칩니다.' || case when broke then ' (퇴마 결계가 물살을 절반으로 꺾었습니다)' else '' end
        when f.boss_id = 'baekya' then '흰 소매가 마당을 한꺼번에 휩씁니다!$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$when f.boss_id = 'baekya' then '휩쓰는 흰 소매에'$o$,
  $n$when f.boss_id = 'dohaesu' then '넘치는 바닷물에' when f.boss_id = 'baekya' then '휩쓰는 흰 소매에'$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$when f.boss_id = 'baekya' then '모두가 물러났습니다.$o$,
  $n$when f.boss_id = 'dohaesu' then '모두가 물러났습니다. 물목이 다시 거꾸로 돕니다.' when f.boss_id = 'baekya' then '모두가 물러났습니다.$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$when f.boss_id = 'baekya' then '시간이 다 되었습니다.$o$,
  $n$when f.boss_id = 'dohaesu' then '시간이 다 되었습니다. 도해수가 틈 속으로 더 깊이 끼어듭니다.' when f.boss_id = 'baekya' then '시간이 다 되었습니다.$n$);

select pg_temp.yh_patch('public.world_gw_hit(uuid,uuid,numeric,integer,text,boolean)',
  $o$  if exists (select 1 from public.world_gw_fights x where x.fight_id = p_fight and x.boss_id = 'baekya') then$o$,
  $n$  if exists (select 1 from public.world_gw_fights x where x.fight_id = p_fight and x.boss_id = 'dohaesu') then p_raw := p_raw * public.world_dh_hurt_mul(p_fight, p_uid); end if;
  if exists (select 1 from public.world_gw_fights x where x.fight_id = p_fight and x.boss_id = 'baekya') then$n$);

select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$'recall', 'deal', 'move', 'light', 'sweep') then raise exception '알 수 없는 행동입니다.'; end if;$o$,
  $n$'recall', 'deal', 'move', 'light', 'sweep', 'guide') then raise exception '알 수 없는 행동입니다.'; end if;$n$);
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$  if (f.boss_id <> 'baekya' and p_action in ('light', 'sweep')) or (f.boss_id not in ('baekya', 'gapgwi') and not public.world_ux_on(p_fight) and p_action = 'move') then raise exception '알 수 없는 행동입니다.'; end if;$o$,
  $n$  if (f.boss_id <> 'baekya' and p_action in ('light', 'sweep')) or (f.boss_id not in ('baekya', 'gapgwi', 'dohaesu') and not public.world_ux_on(p_fight) and p_action = 'move') or (f.boss_id <> 'dohaesu' and p_action = 'guide') then raise exception '알 수 없는 행동입니다.'; end if;
  if f.boss_id = 'dohaesu' then
    if p_action in ('chain', 'recall', 'deal', 'call') then raise exception '알 수 없는 행동입니다.'; end if;
    if p_move is not null and p_move = me.pos then p_move := null; end if;
    if p_move is not null and not (p_move::int = any (public.world_dh_nb(me.pos))) then raise exception '바로 옆(가로·세로) 칸으로만 옮겨 설 수 있습니다.'; end if;
    if p_action = 'move' and p_move is null then raise exception '옮겨 설 칸을 고르세요.'; end if;
  end if;$n$);
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$  if not mk and f.boss_id not in ('baekya', 'gapgwi') and not public.world_ux_on(p_fight) and (p_action = 'recall' or p_move is not null) then$o$,
  $n$  if not mk and f.boss_id not in ('baekya', 'gapgwi', 'dohaesu') and not public.world_ux_on(p_fight) and (p_action = 'recall' or p_move is not null) then$n$);

select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$when f.boss_id = 'baekya' then public.world_by_view(fid, uid)$o$,
  $n$when f.boss_id = 'dohaesu' then public.world_dh_view(fid, uid) when f.boss_id = 'baekya' then public.world_by_view(fid, uid)$n$);

select pg_temp.yh_patch('public.world_gw_open(text,text)',
  $o$    elsif boss = 'baekya' then$o$,
  $n$    elsif boss = 'dohaesu' then
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (x.owner_id, 'gw_invite', '도해수 · 함께 싸우기', c.character_name || '이(가) 뒤집힌 물목에서 도해수 앞에 섰습니다. 60초 안에 합류하세요.',
        jsonb_build_object('fight_id', fid, 'boss', boss, 'mode', md));
    elsif boss = 'baekya' then$n$);

select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $o$  if p_boss in ('mukjeok', 'gapgwi', 'baekya') then$o$,
  $n$  if p_boss in ('mukjeok', 'gapgwi', 'baekya', 'dohaesu') then$n$);
select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $o$raise exception '%', case when p_boss in ('gapgwi', 'baekya') then$o$,
  $n$raise exception '%', case when p_boss in ('gapgwi', 'baekya', 'dohaesu') then$n$);

select pg_temp.yh_patch('public.world_gw_tips(text)',
  $o$select case when p_boss = 'baekya' then jsonb_build_array($o$,
  $n$select case when p_boss = 'dohaesu' then jsonb_build_array(
    '판: 쪽빛 바다 4×4칸, 가운데 네 칸은 틈이다. 한 라운드에 가로·세로 바로 옆 칸으로 한 칸 옮겨 선다. 틈 칸에 서 있으면 받는 피해가 늘고, 물살에 밀려 틈으로 들어가면 빨려 들어 그 싸움에서 빠진다.',
    '해류: 화살표 방향과 숫자가 보이고, 0이 되는 라운드에 모두를 그쪽으로 한 칸 민다. 가장자리에 등을 대면 벽에 막혀 제자리, 「버티기」면 한 칸 덜 밀린다. 해류 뒤집힘은 반대쪽으로 두 칸.',
    '머리 칸: 빛나는 모서리 칸. 도해수가 머리를 드는 ! 라운드에 그 칸에서 「길 알려 주기」를 하면 크게 휘청여 한동안 더 아프게 맞는다. 머리 칸은 구간마다 옮겨 간다.',
    '물보라는 칸 위 숫자를 보고 비킨다. 촉수에 묶인 두 사람은 네 칸 이상 떨어져야 끊긴다. 소용돌이 기둥은 해류를 따라 흐르니 닿지 않게 한다.',
    '젖은 몸: 물살·물보라마다 한 겹, 세 겹이면 한 칸 더 밀린다. 머리 칸에서 길을 알려 주면 마른다.',
    '틈의 숨(마지막 구간): ! 라운드에 절반 넘게 머리 칸에 모여 「길 알려 주기」를 해야 막힌다. 막지 못하면 버티지 않은 사람은 가운데로 한 칸 끌려간다.',
    '제때 달래기: 정해진 라운드까지 체력을 75·50·25% 아래로 깎지 못하면 도해수가 거세져 받는 피해가 늘어난다.')
  when p_boss = 'baekya' then jsonb_build_array($n$);

select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)',
  $o$tt not in ('gw', 'mj', 'gg', 'by', 'raid',$o$, $n$tt not in ('gw', 'mj', 'gg', 'by', 'dh', 'raid',$n$);
select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)',
  $o$  if tt in ('gw', 'mj', 'gg', 'by') then$o$, $n$  if tt in ('gw', 'mj', 'gg', 'by', 'dh') then$n$);
select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)',
  $o$when tt = 'by' then 'baekya' else$o$, $n$when tt = 'by' then 'baekya' when tt = 'dh' then 'dohaesu' else$n$);

select pg_temp.yh_patch('public.world_quest_task_label(jsonb)',
  $o$    when p_task ->> 't' = 'by' then$o$,
  $n$    when p_task ->> 't' = 'dh' then case when p_task ->> 'mode' = 'story' then '뒤집힌 물목에서 도해수를 바다로 돌려보내기' else '깊은 물목에서 도해수를 바다로 돌려보내기' end
    when p_task ->> 't' = 'by' then$n$);
