-- 1.0.0d — 오픈 전 다시 검토·직업 균형
--  ① 동승 요청: 알림 문구 하위 질의의 표 별칭 r이 함수 변수 r과 겹쳐 늘 실패하던 것(1.0.0c)
--  ② 동승 운임 거절 문구를 노정패로
--  ③ 칭호 판정 한 번에 답사 완료 수를 한 번만 셈
lock table public.world_characters in access exclusive mode;

do $p$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_travel_party_invite_v2(uuid,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$(SELECT r.region_name FROM public.world_map_regions r WHERE r.region_id = p_region_id)$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor ride'; end if;
  execute replace(d, a, $b$(SELECT mr.region_name FROM public.world_map_regions mr WHERE mr.region_id = p_region_id)$b$);

  d := replace(pg_get_functiondef('public.world_travel_party_respond_v2(uuid,boolean)'::regprocedure), E'\r\n', E'\n');
  a := $a$'운행 재화가 부족합니다. 탈것 운임을 확인한 뒤 다시 시도하세요.'$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor fare'; end if;
  execute replace(d, a, $b$'노정패가 모자라 함께 떠날 수 없습니다(운임 %개).', fare$b$);
end $p$;

create or replace function public.world_survey_full_count(p_owner uuid)
returns integer language plpgsql stable set search_path to 'pg_catalog', 'public' as $f$
declare k text := p_owner::text || ':' || coalesce(pg_current_xact_id_if_assigned()::text, ''); c text; v int;
begin
  c := current_setting('yh.svf', true);
  if c is not null and c <> '' and split_part(c, '=', 1) = k and k not like '%:' then return split_part(c, '=', 2)::int; end if;
  v := jsonb_array_length(public.world_survey_full_list(p_owner));
  if k not like '%:' then perform set_config('yh.svf', k || '=' || v, true); end if;
  return v;
end $f$;
