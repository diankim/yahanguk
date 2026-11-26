select pg_temp.yh_patch('public.world_gw_open(text,text)',
  $o$  if md = 'ultimate' and n = 0 then raise exception '무용담은 같은 곳에 함께 설 파티원이 있어야 열 수 있습니다(2~4명).'; end if;$o$,
  $n$  if md = 'ultimate' and n = 0 then raise exception '무용담은 같은 곳에 함께 설 파티원이 있어야 열 수 있습니다(2~4명).'; end if;
  if md = 'hard' and n + 1 < coalesce((public.world_boss_rules() -> boss ->> 'hard_min')::int, 1) then
    raise exception '%은(는) 같은 곳에 함께 설 파티원이 있어야 열 수 있습니다(%~4명).', public.world_boss_rules() -> boss -> 'modes' ->> 'hard', (public.world_boss_rules() -> boss ->> 'hard_min')::int; end if;$n$);
select pg_temp.yh_patch('public.world_gw_begin(uuid)',
  $o$    raise exception '무용담은 둘 이상이 모여야 시작할 수 있습니다.'; end if;$o$,
  $n$    raise exception '무용담은 둘 이상이 모여야 시작할 수 있습니다.'; end if;
  if exists (select 1 from public.world_gw_fights f where f.fight_id = p_fight and f.mode = 'hard'
      and (select count(*) from public.world_gw_members where fight_id = p_fight) < coalesce((public.world_boss_rules() -> f.boss_id ->> 'hard_min')::int, 1)) then
    raise exception '%은(는) 둘 이상이 모여야 시작할 수 있습니다.', (select public.world_boss_rules() -> f.boss_id -> 'modes' ->> 'hard' from public.world_gw_fights f where f.fight_id = p_fight); end if;$n$);
select pg_temp.yh_patch('public.world_gw_start(uuid)',
  $o$  if f.mode = 'ultimate' then
    if n < 2 then$o$,
  $n$  if f.mode = 'hard' and n < coalesce((public.world_boss_rules() -> f.boss_id ->> 'hard_min')::int, 1) then
    update public.world_gw_fights set status = 'failed', ended_at = now(), updated_at = now() where fight_id = p_fight;
    perform public.world_gw_say(p_fight, 0, 'bad', (public.world_boss_rules() -> f.boss_id -> 'modes' ->> 'hard') || '은(는) 둘 이상이 함께여야 합니다. 모이지 않아 흩어졌습니다.');
    return;
  end if;
  if f.mode = 'ultimate' then
    if n < 2 then$n$);
