select pg_temp.yh_patch('public.world_gwiryeong_chance(text,jsonb)',
  $q$p_type in ('gw_win', 'raid_win', 'mk_win')$q$,
  $q$p_type in ('gw_win', 'raid_win', 'mk_win', 'gg_win', 'by_win')$q$);
drop trigger if exists trg_world_gwiryeong_roll on public.world_events;
create trigger trg_world_gwiryeong_roll after insert on public.world_events for each row
  when (new.event_type = any (array['gather', 'combat', 'expedition_end', 'gw_win', 'mk_win', 'gg_win', 'by_win'])) execute function public.world_gwiryeong_roll();
