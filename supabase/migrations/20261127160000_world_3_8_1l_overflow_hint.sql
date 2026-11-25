do $$
declare x record; d text; n int;
begin
  for x in select * from (values
      ('public.world_field_move(uuid)'::regprocedure,
       $a$RAISE EXCEPTION '원정 짐 보따리를 먼저 정리하세요. 챙기거나 버린 뒤 움직일 수 있습니다.';$a$,
       $b$RAISE EXCEPTION '원정 짐 보따리를 먼저 정리하세요. 챙기거나 버린 뒤 움직일 수 있습니다.' USING HINT = 'overflow';$b$),
      ('public.world_guard_action_context()'::regprocedure,
       $a$RAISE EXCEPTION '원정 짐 보따리를 먼저 정리하세요. 챙기거나 버린 뒤 다시 할 수 있습니다.';$a$,
       $b$RAISE EXCEPTION '원정 짐 보따리를 먼저 정리하세요. 챙기거나 버린 뒤 다시 할 수 있습니다.' USING HINT = 'overflow';$b$),
      ('public.world_battle_action(text,text)'::regprocedure,
       $a$      hp := least(100, hp + heal);
      lines := lines || jsonb_build_array((SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || '을(를) 써 체력 ' || heal || ' 회복');$a$,
       $b$      heal := least(100, hp + heal) - hp; hp := hp + heal;
      lines := lines || jsonb_build_array((SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || '을(를) 써 체력 ' || heal || ' 회복');$b$),
      ('public.world_battle_action(text,text)'::regprocedure,
       $a$      sp := least(100, sp + heal);
      lines := lines || jsonb_build_array((SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || '을(를) 써 ' || CASE WHEN style = 'melee' THEN '기력 ' ELSE '영력 ' END || heal || ' 회복');$a$,
       $b$      heal := least(100, sp + heal) - sp; sp := sp + heal;
      lines := lines || jsonb_build_array((SELECT item_name FROM public.world_item_catalog WHERE item_id = it) || '을(를) 써 ' || CASE WHEN style = 'melee' THEN '기력 ' ELSE '영력 ' END || heal || ' 회복');$b$)
  ) v(f, o, nw) loop
    d := pg_get_functiondef(x.f);
    n := (length(d) - length(replace(d, x.o, ''))) / length(x.o);
    if n <> 1 then raise exception '% 조각 % 개', x.f, n; end if;
    execute replace(d, x.o, x.nw);
  end loop;
end $$;

update public.world_quest_steps
   set lines = replace(lines::text, '사월 언니,', '사월 누나,')::jsonb
 where quest_id = 'ep_x_sawol' and lines::text like '%사월 언니,%';

update public.world_patch_notes set body = body || E'\n- [원정] 원정 짐 보따리가 남아 길 떠나기·탐색 등이 막히면 그 자리에서 보따리 창이 바로 열립니다.'
where note_id = '3.8.0' and position('그 자리에서 보따리 창이 바로 열립니다' in body) = 0;

update public.world_patch_notes set body = body || E'\n- [싸움] 싸움 중 회복약·영력약을 쓰면 기록에 실제로 오른 만큼을 적습니다(이미 가득 차 있으면 0). 써서 오른 것이 없어도 회복 효과는 뜹니다.'
where note_id = '3.8.0' and position('실제로 오른 만큼을 적습니다' in body) = 0;

update public.world_patch_notes set body = body || E'\n- [대사] 뒷이야기 일부 장면의 대사를 다듬었습니다.'
where note_id = '3.8.0' and position('[대사] 뒷이야기 일부 장면의 대사를 다듬었습니다.' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127160000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
