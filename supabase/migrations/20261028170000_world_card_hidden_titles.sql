-- 조사원 카드: 숨김 칭호를 얻은 사람이 대표·장착으로 내걸면, 보는 사람이 그 칭호를 얻지 못했어도 이름은 보여 준다.
-- (예전에는 「숨김 칭호」로 바꿔 보였다.) 설명은 얻는 방법의 단서가 될 수 있어 계속 가린다.
do $$
declare d text;
  a1 text := $q$then '숨김 칭호' else tc.title_name end$q$;
  a2 text := $q$then jsonb_build_object('name', '숨김 칭호', 'hidden', true)$q$;
begin
  d := pg_get_functiondef('public.world_character_card(uuid)'::regprocedure);
  if position(a1 in d) = 0 and position(a2 in d) = 0 then return; end if;
  if position(a1 in d) = 0 or position(a2 in d) = 0 then raise exception '조사원 카드 함수에서 숨김 칭호 줄을 찾지 못했습니다'; end if;
  d := replace(d, a1, $q$then tc.title_name else tc.title_name end$q$);
  d := replace(d, a2, $q$then jsonb_build_object('name', tc.title_name, 'hidden', true, 'description', '숨겨진 칭호 · 얻는 방법은 알려지지 않았습니다.')$q$);
  execute d;
end $$;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028170000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
