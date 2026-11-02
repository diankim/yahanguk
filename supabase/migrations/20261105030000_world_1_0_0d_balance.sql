-- 1.0.0d — 오픈 전 다시 검토·직업 균형
--  ① 동승 요청: 알림 문구 하위 질의의 표 별칭 r이 함수 변수 r과 겹쳐 늘 실패하던 것(1.0.0c)
--  ② 동승 운임 거절 문구를 노정패로
--  ③ 칭호 판정 한 번에 답사 완료 수를 한 번만 셈
--  ④ 직업 균형(Lv5·15·25·35 여섯 직업 실측): 껍질 가시 되돌림 최대 15·체력 1 아래로 안 깎음(거울막과 같게, 암영 검객 쓰러짐 15/15가 이것),
--     퇴마진 ×2.0→×1.7(부적 퇴마진 ×2.4→×2.1, 현장에서 퇴마관이 다른 직업의 두 배 빠르던 것),
--     원정 전투력에 술법 능력치(영기×0.75+의지×0.4가 힘보다 크면 그것) — 술법 직업이 힘만 보던 계산에서 약 30% 낮던 것,
--     원정 위험 사건이 위험도 6↑(균형·강행)에서 한 번도 안 나던 것: 발견 칸 위쪽을 0.97−위험도×1% 로 막아 위험 몫을 남김
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

do $p$
declare d text; a text; b text;
begin
  d := replace(pg_get_functiondef('public.world_battle_action(text,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$thorn := greatest(1, round(dmg * 0.3)); hp := greatest(0, hp - thorn);$a$;
  b := $b$thorn := least(15, greatest(1, round(dmg * 0.3))); hp := greatest(least(hp, 1), hp - thorn);$b$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor thorn'; end if;
  d := replace(d, a, b);
  a := $a$CASE WHEN 'combo_exorcism_wardcraft' = ANY (sk) THEN 2.4 ELSE 2.0 END$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor exo'; end if;
  d := replace(d, a, $b$CASE WHEN 'combo_exorcism_wardcraft' = ANY (sk) THEN 2.1 ELSE 1.7 END$b$);
  execute d;

  d := replace(pg_get_functiondef('public.world_expedition_settle(uuid,integer)'::regprocedure), E'\r\n', E'\n');
  a := $a$power := 12 + c.level * 5 + c.strength * 2.5 + c.agility * 1.5$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor power'; end if;
  d := replace(d, a, $b$power := 12 + c.level * 5 + greatest(c.strength, c.spirit_affinity * 0.75 + c.willpower * 0.4) * 2.5 + c.agility * 1.5$b$);
  a := $a$elsif roll < p_fight + 0.35 + 0.22 + c.perception * 0.002 then$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0d anchor hazard'; end if;
  d := replace(d, a, $b$elsif roll < least(p_fight + 0.35 + 0.22 + c.perception * 0.002, 0.97 - danger * 0.01) then$b$);
  execute d;
end $p$;

update public.world_skill_catalog set description = replace(description, '퇴마진의 피해가 ×2.0에서 ×2.4로', '퇴마진의 피해가 ×1.7에서 ×2.1로')
 where skill_id = 'combo_exorcism_wardcraft';
