do $m$
declare src text; def text; r record; n int;
begin
  for r in select p.oid::regprocedure fn, p.proname from pg_proc p where p.pronamespace = 'public'::regnamespace
             and p.proname in ('world_raid_tick', 'world_raid_chat', 'world_raid_begin_fight', 'world_sys_chat_names') loop
    select prosrc into src from pg_proc where oid = r.fn;
    if r.proname = 'world_sys_chat_names' then
      n := (length(src) - length(replace(src, '''봉연 소식''', ''))) / length('''봉연 소식''');
      if n <> 1 then raise exception 'world_sys_chat_names 모양이 예상과 다릅니다'; end if;
      src := replace(src, '''봉연 소식''', '''봉연 소식'', ''그림자 소식''');
    else
      src := replace(replace(replace(src, '봉연 소식', '그림자 소식'), '봉연 · ', '그림자 · '), '현장의 봉연 띠', '현장의 그림자 띠');
    end if;
    def := regexp_replace(pg_get_functiondef(r.fn), 'AS \$function\$.*\$function\$', '', 's');
    execute def || ' AS $fn$' || src || '$fn$';
  end loop;
  if exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('world_raid_tick', 'world_raid_chat', 'world_raid_begin_fight')
             and (p.prosrc like '%봉연 소식%' or p.prosrc like '%봉연 · %')) then raise exception '봉연 이름이 남았습니다'; end if;
end $m$;

update public.world_patch_notes set body = body || E'\n- 그림자 알림과 전체 채팅 소식 이름을 「그림자 소식」·「그림자 · …」로 바꿨습니다.\n- 싸움 화면에서 검은 낙인이 찍힌 사람과 그림자 손아귀에 잡힌 사람의 칸에 색과 「낙인」·「손아귀」 표시가 붙습니다.\n- 전투 기록에 낙인·손아귀·묵흔으로 맞은 줄이 무엇에 맞았는지 함께 나옵니다.'
 where note_id = '3.7.0' and body not like '%「그림자 소식」%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126100000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
