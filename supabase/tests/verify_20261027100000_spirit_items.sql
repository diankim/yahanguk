-- 영력 회복약 시험(GM 캐릭터). 마지막에 일부러 오류를 내 모든 변경을 되돌린다.
-- "시험결과(되돌림): ..." 오류가 뜨면 정상이다. 내용 안의 줄이 모두 ok인지 확인한다.
do $$
declare gm uuid := 'd3ce7dbb-9d58-4fa5-ade7-33d4e75bb1fe'; r jsonb; sp0 int; sp1 int; sp2 int; out text := ''; err text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', gm, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', gm::text, true);
  update public.world_characters
     set spiritual_power = 30, inventory = coalesce(inventory, '{}'::jsonb) || '{"spirit_tea": 2, "heavenly_dew": 1}'::jsonb
   where owner_id = gm;
  select spiritual_power into sp0 from public.world_characters where owner_id = gm;

  set local role authenticated;
  r := public.world_use_item('spirit_tea');
  reset role;
  select spiritual_power into sp1 from public.world_characters where owner_id = gm;
  out := out || format('[%s] 영초 차: 영력 %s → %s (%s)', case when sp1 > sp0 then 'ok' else 'FAIL' end, sp0, sp1, r ->> 'content') || E'\n';

  set local role authenticated;
  r := public.world_use_item('heavenly_dew');
  reset role;
  select spiritual_power into sp2 from public.world_characters where owner_id = gm;
  out := out || format('[%s] 천령 감로: 영력 %s → %s (100 넘지 않음)', case when sp2 = 100 then 'ok' else 'FAIL' end, sp1, sp2) || E'\n';

  begin
    set local role authenticated;
    perform public.world_use_item('spirit_tea');
    reset role;
    out := out || '[FAIL] 영력이 가득한데 사용됨' || E'\n';
  exception when others then
    get stacked diagnostics err = message_text;
    out := out || format('[ok] 가득할 때 거절: %s', err) || E'\n';
  end;

  out := out || format('[%s] 전투 함수에 영력약 반영',
    case when position('spirit_tea' in pg_get_functiondef('public.world_battle_action(text, text)'::regprocedure)) > 0 then 'ok' else 'FAIL' end) || E'\n';
  out := out || format('[%s] 제작법 5개', case when (select count(*) from public.world_crafting_recipes where output_item in ('spirit_tea','clear_spirit_pill','spirit_qi_pill','moonlight_essence','heavenly_dew')) = 5 then 'ok' else 'FAIL' end);
  raise exception E'시험결과(되돌림):\n%', out;
end $$;
