revoke all on function public.world_du_qr(integer), public.world_du_cell(integer, integer), public.world_du_ring(integer), public.world_du_dir(integer), public.world_du_step(integer, integer), public.world_du_out(integer),
  public.world_du_open(uuid, integer), public.world_du_nb(integer), public.world_du_dmg(uuid, uuid, numeric, integer, text, numeric), public.world_du_fall(uuid, uuid, integer, text),
  public.world_du_push(uuid, uuid, integer, integer, integer, text), public.world_du_seq(uuid, integer, integer), public.world_du_slide_cells(integer), public.world_du_line(integer, integer),
  public.world_du_hz_cells(uuid, jsonb), public.world_du_hp(uuid, integer), public.world_du_begin(uuid, integer), public.world_du_round(uuid), public.world_du_steps(uuid, integer),
  public.world_du_mech(uuid, integer, boolean, boolean, uuid[]), public.world_du_after(uuid, integer), public.world_du_view(uuid, uuid), public.world_du_settle(uuid, boolean)
  from public, anon, authenticated;
grant execute on function public.world_du_qr(integer), public.world_du_cell(integer, integer), public.world_du_ring(integer), public.world_du_dir(integer), public.world_du_step(integer, integer), public.world_du_out(integer),
  public.world_du_open(uuid, integer), public.world_du_nb(integer), public.world_du_dmg(uuid, uuid, numeric, integer, text, numeric), public.world_du_fall(uuid, uuid, integer, text),
  public.world_du_push(uuid, uuid, integer, integer, integer, text), public.world_du_seq(uuid, integer, integer), public.world_du_slide_cells(integer), public.world_du_line(integer, integer),
  public.world_du_hz_cells(uuid, jsonb), public.world_du_hp(uuid, integer), public.world_du_begin(uuid, integer), public.world_du_round(uuid), public.world_du_steps(uuid, integer),
  public.world_du_mech(uuid, integer, boolean, boolean, uuid[]), public.world_du_after(uuid, integer), public.world_du_view(uuid, uuid), public.world_du_settle(uuid, boolean)
  to service_role, fn_owner_field;

select pg_temp.yh_patch('public.world_gw_next_round(uuid)',
  $o$  if f.boss_id = 'dohaesu' then perform public.world_dh_round(p_fight); return; end if;$o$,
  $n$  if f.boss_id = 'ttangul' then perform public.world_du_round(p_fight); return; end if;
  if f.boss_id = 'dohaesu' then perform public.world_dh_round(p_fight); return; end if;$n$);

select pg_temp.yh_patch('public.world_gw_start(uuid)',
  $o$  if f.boss_id = 'dohaesu' then v_item := public.world_boss_rules() -> 'dohaesu' ->> 'item'; end if;$o$,
  $n$  if f.boss_id = 'dohaesu' then v_item := public.world_boss_rules() -> 'dohaesu' ->> 'item'; end if;
  if f.boss_id = 'ttangul' then v_item := public.world_boss_rules() -> 'ttangul' ->> 'item'; end if;$n$);
select pg_temp.yh_patch('public.world_gw_start(uuid)',
  $o$  if f.boss_id = 'dohaesu' then
    br := public.world_boss_fight_rules(p_fight);$o$,
  $n$  if f.boss_id = 'ttangul' then
    br := public.world_boss_fight_rules(p_fight);
    update public.world_gw_fights set status = 'fight', max_hp = public.world_du_hp(p_fight, n), hp = public.world_du_hp(p_fight, n), phase = 1, round = 0, cycle = 0,
           ends_at = now() + make_interval(mins => (br ->> 'min')::int), updated_at = now() where fight_id = p_fight;
    perform public.world_du_begin(p_fight, n);
    perform public.world_gw_next_round(p_fight);
    return;
  end if;
  if f.boss_id = 'dohaesu' then
    br := public.world_boss_fight_rules(p_fight);$n$);

select pg_temp.yh_patch('public.world_gw_settle(uuid,boolean)',
  $o$  if f.boss_id = 'dohaesu' then perform public.world_dh_settle(p_fight, p_won); return; end if;$o$,
  $n$  if f.boss_id = 'ttangul' then perform public.world_du_settle(p_fight, p_won); return; end if;
  if f.boss_id = 'dohaesu' then perform public.world_dh_settle(p_fight, p_won); return; end if;$n$);

select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.boss_id = 'dohaesu' then v_who := '도해수'; end if;$o$,
  $n$  if f.boss_id = 'dohaesu' then v_who := '도해수'; end if;
  if f.boss_id = 'ttangul' then v_who := '땅울이'; end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.boss_id = 'dohaesu' then perform public.world_dh_steps(p_fight, r); end if;$o$,
  $n$  if f.boss_id = 'dohaesu' then perform public.world_dh_steps(p_fight, r); end if;
  if f.boss_id = 'ttangul' then perform public.world_du_steps(p_fight, r); end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$    elsif av in ('move', 'guide') and f.boss_id = 'dohaesu' then$o$,
  $n$    elsif av in ('move', 'stop') and f.boss_id = 'ttangul' then
      null;
    elsif av in ('move', 'guide') and f.boss_id = 'dohaesu' then$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.boss_id = 'dohaesu' then boss_dmg := boss_dmg + public.world_dh_mech(p_fight, r, broke, delayed, freed); end if;
  if f.boss_id in ('baekya', 'dohaesu') then null;$o$,
  $n$  if f.boss_id = 'dohaesu' then boss_dmg := boss_dmg + public.world_dh_mech(p_fight, r, broke, delayed, freed); end if;
  if f.boss_id = 'ttangul' then boss_dmg := boss_dmg + public.world_du_mech(p_fight, r, broke, delayed, freed); end if;
  if f.boss_id in ('baekya', 'dohaesu', 'ttangul') then null;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$  if f.boss_id = 'dohaesu' then
    update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;
    if public.world_dh_after(p_fight, r) then return; end if;$o$,
  $n$  if f.boss_id = 'ttangul' then
    update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;
    if public.world_du_after(p_fight, r) then return; end if;
    select * into f from public.world_gw_fights where fight_id = p_fight;
  end if;
  if f.boss_id = 'dohaesu' then
    update public.world_gw_fights set bfx = vbfx where fight_id = p_fight;
    if public.world_dh_after(p_fight, r) then return; end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$    if f.boss_id in ('baekya', 'dohaesu') then raw := public.world_mk_raw(p_fight); end if;$o$,
  $n$    if f.boss_id in ('baekya', 'dohaesu', 'ttangul') then raw := public.world_mk_raw(p_fight); end if;$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$        when f.boss_id = 'dohaesu' then '도해수가 온몸으로 몸부림칩니다!$o$,
  $n$        when f.boss_id = 'ttangul' then '땅울이가 땅을 울립니다! 돌판 전체가 들썩입니다.' || case when broke then ' (퇴마 결계가 울림을 절반으로 꺾었습니다)' else '' end
        when f.boss_id = 'dohaesu' then '도해수가 온몸으로 몸부림칩니다!$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$when f.boss_id = 'dohaesu' then '넘치는 바닷물에'$o$,
  $n$when f.boss_id = 'ttangul' then '땅울음에' when f.boss_id = 'dohaesu' then '넘치는 바닷물에'$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$when f.boss_id = 'dohaesu' then '모두가 물러났습니다. 물목이 다시 거꾸로 돕니다.'$o$,
  $n$when f.boss_id = 'ttangul' then '모두가 물러났습니다. 고임터에 울음이 가득 찹니다.' when f.boss_id = 'dohaesu' then '모두가 물러났습니다. 물목이 다시 거꾸로 돕니다.'$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$when f.boss_id = 'dohaesu' then '시간이 다 되었습니다. 도해수가$o$,
  $n$when f.boss_id = 'ttangul' then '시간이 다 되었습니다. 땅울이가 고임 구덩이 밑으로 몸을 묻습니다.' when f.boss_id = 'dohaesu' then '시간이 다 되었습니다. 도해수가$n$);

select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$'recall', 'deal', 'move', 'light', 'sweep', 'guide') then raise exception '알 수 없는 행동입니다.'; end if;$o$,
  $n$'recall', 'deal', 'move', 'light', 'sweep', 'guide', 'stop') then raise exception '알 수 없는 행동입니다.'; end if;$n$);
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$or (f.boss_id not in ('baekya', 'gapgwi', 'dohaesu') and not public.world_ux_on(p_fight) and p_action = 'move') or (f.boss_id <> 'dohaesu' and p_action = 'guide') then raise exception '알 수 없는 행동입니다.'; end if;$o$,
  $n$or (f.boss_id not in ('baekya', 'gapgwi', 'dohaesu', 'ttangul') and not public.world_ux_on(p_fight) and p_action = 'move') or (f.boss_id <> 'dohaesu' and p_action = 'guide') or (f.boss_id <> 'ttangul' and p_action = 'stop') then raise exception '알 수 없는 행동입니다.'; end if;
  if f.boss_id = 'ttangul' then
    if p_action in ('chain', 'recall', 'deal', 'call') then raise exception '알 수 없는 행동입니다.'; end if;
    if p_move is not null and p_move = me.pos then p_move := null; end if;
    if p_move is not null and not (p_move::int = any (public.world_du_nb(me.pos))) then raise exception '바로 옆 칸으로만 옮겨 설 수 있습니다.'; end if;
    if p_action = 'move' and p_move is null then raise exception '옮겨 설 칸을 고르세요.'; end if;
    if p_action = 'stop' and coalesce(me.gval, 0) = 0 then raise exception '쐐기돌을 먼저 주워 드세요.'; end if;
  end if;$n$);
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text,smallint)',
  $o$  if not mk and f.boss_id not in ('baekya', 'gapgwi', 'dohaesu') and not public.world_ux_on(p_fight)$o$,
  $n$  if not mk and f.boss_id not in ('baekya', 'gapgwi', 'dohaesu', 'ttangul') and not public.world_ux_on(p_fight)$n$);

select pg_temp.yh_patch('public.world_gw_snapshot(uuid,text)',
  $o$when f.boss_id = 'dohaesu' then public.world_dh_view(fid, uid)$o$,
  $n$when f.boss_id = 'ttangul' then public.world_du_view(fid, uid) when f.boss_id = 'dohaesu' then public.world_dh_view(fid, uid)$n$);

select pg_temp.yh_patch('public.world_gw_open(text,text)',
  $o$    elsif boss = 'dohaesu' then$o$,
  $n$    elsif boss = 'ttangul' then
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (x.owner_id, 'gw_invite', '땅울이 · 함께 싸우기', c.character_name || '이(가) 고임터에서 땅울이 앞에 섰습니다. 60초 안에 합류하세요' || case when md = 'story' then '.' else '(' || (br ->> 'item_name') || ' 1개).' end,
        jsonb_build_object('fight_id', fid, 'boss', boss, 'mode', md));
    elsif boss = 'dohaesu' then$n$);

select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $o$  if p_boss in ('mukjeok', 'gapgwi', 'baekya', 'dohaesu') then$o$,
  $n$  if p_boss in ('mukjeok', 'gapgwi', 'baekya', 'dohaesu', 'ttangul') then$n$);
select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $o$raise exception '%', case when p_boss in ('gapgwi', 'baekya', 'dohaesu') then$o$,
  $n$raise exception '%', case when p_boss in ('gapgwi', 'baekya', 'dohaesu', 'ttangul') then$n$);
select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $o$when p_boss = 'dohaesu' then '도해수를 바다로 돌려보냈습니다'$o$,
  $n$when p_boss = 'ttangul' then '땅울이를 잠재웠습니다' when p_boss = 'dohaesu' then '도해수를 바다로 돌려보냈습니다'$n$);
select pg_temp.yh_patch('public.world_gw_ready_check(uuid,text,text)',
  $o$when p_boss = 'dohaesu' then '물목이 아직 거꾸로 돌고 있습니다'$o$,
  $n$when p_boss = 'ttangul' then '고임터가 아직 울고 있습니다' when p_boss = 'dohaesu' then '물목이 아직 거꾸로 돌고 있습니다'$n$);

select pg_temp.yh_patch('public.world_gw_tips(text)',
  $o$select case when p_boss = 'dohaesu' then jsonb_build_array($o$,
  $n$select case when p_boss = 'ttangul' then jsonb_build_array(
    '판: 육각 돌판 열아홉 칸, 가운데 칸에는 땅울이가 있어 설 수 없다. 한 라운드에 바로 옆 칸으로 한 칸 옮겨 선다. 무너진 칸으로 밀리거나 디디면 고임 구덩이로 떨어져 그 싸움에서 빠진다.',
    '산사태: 숫자가 보이는 쪽 칸들이 0이 되는 라운드에 쓸려 바깥으로 밀린다. 바깥 끝에서 밀리면 떨어진다. 「버티기」면 한 칸 덜 밀린다.',
    '땅의 무게: 숫자가 붙은 칸이 0에 무너져 한동안 구멍이 된다. 한 번 금 간 칸이 다시 무너지면 영영 구멍으로 남는다. 무너진 칸 옆에는 쐐기돌이 굴러 나온다.',
    '끌개: 돌판 네 귀퉁이 끌개가 0이 되면 땅울이가 기운을 끌어와 체력을 채운다. 쐐기돌을 들고 그 끌개 칸에서 「쐐기 박기」를 하면 끌개가 한동안 멈추고 땅울이가 크게 휘청인다.',
    '돌주먹은 한 사람을 노려 크게 치고 한 칸 밀어낸다(방어면 4분의 1). 굴러오는 바위는 한 줄을 지나며 그 방향으로 민다 — 줄에서 비킨다.',
    '판 깎기(마지막 구간): 바깥 고리가 통째로 무너져 일곱 칸만 남는다. 숫자가 0이 되기 전에 안쪽 고리로 들어와야 한다. 그 뒤 몸부림 세 라운드는 돌판이 기울어 모두를 한쪽으로 민다.',
    '제때 잠재우기: 정해진 라운드까지 체력을 75·50·25% 아래로 깎지 못하면 땅울이가 거세져 받는 피해가 늘어난다.')
  when p_boss = 'dohaesu' then jsonb_build_array($n$);

select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)',
  $o$tt not in ('gw', 'mj', 'gg', 'by', 'dh', 'raid',$o$, $n$tt not in ('gw', 'mj', 'gg', 'by', 'dh', 'du', 'raid',$n$);
select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)',
  $o$  if tt in ('gw', 'mj', 'gg', 'by', 'dh') then$o$, $n$  if tt in ('gw', 'mj', 'gg', 'by', 'dh', 'du') then$n$);
select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)',
  $o$when tt = 'dh' then 'dohaesu' else$o$, $n$when tt = 'dh' then 'dohaesu' when tt = 'du' then 'ttangul' else$n$);

select pg_temp.yh_patch('public.world_quest_task_label(jsonb)',
  $o$    when p_task ->> 't' = 'dh' then$o$,
  $n$    when p_task ->> 't' = 'du' then case when p_task ->> 'mode' = 'story' then '고임터에서 땅울이를 잠재우기' else '깊은 고임터에서 땅울이를 잠재우기' end
    when p_task ->> 't' = 'dh' then$n$);
