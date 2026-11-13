create or replace function public.world_gwiryeong_mine()
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  return jsonb_build_object('plants', coalesce((select jsonb_agg(jsonb_build_object('until', p.expires_at) order by p.expires_at)
      from public.world_gwiryeong_plants p where p.holder = uid and p.ended is null and p.expires_at > now()), '[]'::jsonb),
    'warn_h', (public.world_gwiryeong_rules() ->> 'warn_h')::int);
end $function$;
revoke all on function public.world_gwiryeong_mine() from public, anon;
grant execute on function public.world_gwiryeong_mine() to authenticated, service_role;

update public.world_patch_notes set body = body || E'\n- 귀령초 물품 정보와 가방 줄에 지닌 포기가 시드는 날짜·시각과 남은 시간이 나옵니다. 넘겨받은 귀령초도 처음 찾은 때부터 세므로 언제 시드는지 바로 볼 수 있습니다.\n- 휴대폰 현장 화면을 탐색 단추 모음 아래에 이어진 길과 채집터를 두 칸으로 나란히, 그 아래 낚시터가 오도록 바꿨습니다. 탐색력을 보면서 채집·낚시를 할 수 있습니다. 탐사 기록은 여기 있는 이들 바로 위로 옮겼습니다.\n- 채집 규칙 안내는 채집터 제목 옆 「?」에서 봅니다.\n- 휴대폰에서 탐색하다 요괴와 마주치면 전투 화면이 맨 위부터 보입니다(아래로 밀려 있던 것).'
where note_id = '1.1.0' and position('시드는 날짜·시각' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261113050000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
