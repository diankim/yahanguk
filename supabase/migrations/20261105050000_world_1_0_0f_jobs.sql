-- 1.0.0f — 퇴마관·월궁 사수 역할 맞바꿈(사용자 결정 2026-11-02): 술법은 한 방, 활은 꾸준히
--  · 퇴마진: ×1.7 → ×1.4 + 반드시 치명타(×1.5, 숙달 「멸마」면 ×2.0) — 한 방 2.1배(멸마 2.8배). 부적 퇴마진 ×2.1 → ×1.7(2.55배).
--  · 급소 사격: ×1.8 → ×1.4, 반드시 치명타 표시 없앰(원래 배율도 안 붙었음), 표식 2 → 3번(맞을 때마다 +25%) — 표식이 늘 걸려 꾸준히.
--  · 치명타: 퇴마관 술법 +6 없앰, 월궁 사수 원거리 +4.
--  · 퇴마관 기본 회피 4+레벨×0.3(영기·의지에는 회피가 안 붙어, 봉인술사 기본 방어처럼 — Lv5 약 10·Lv15 13·Lv35 19, 민첩을 찍는 월궁 사수 14·19·29의 2/3쯤)·달아나기 +8.
--  세 턴 한 바퀴(기술+평타 둘) 기대 피해: 퇴마관 약 +3%, 월궁 사수 약 ±0(표식이 다음 기술까지 이어짐).
lock table public.world_characters in access exclusive mode;

do $p$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_battle_action(text,text)'::regprocedure), E'\r\n', E'\n');
  a := $a$CASE WHEN 'combo_exorcism_wardcraft' = ANY (sk) THEN 2.1 ELSE 1.7 END$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor exo'; end if;
  d := replace(d, a, $b$CASE WHEN 'combo_exorcism_wardcraft' = ANY (sk) THEN 1.7 ELSE 1.4 END$b$);
  a := $a$ELSIF skill_name = '급소 사격' THEN mul := mul * 1.8; v_fx := v_fx || jsonb_build_object('marked', 2);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor aim'; end if;
  d := replace(d, a, $b$ELSIF skill_name = '급소 사격' THEN mul := mul * 1.4; v_fx := v_fx || jsonb_build_object('marked', 3);$b$);
  a := $a$crit := skill_name = '급소 사격' OR force_crit OR random() < cc;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor crit'; end if;
  d := replace(d, a, $b$crit := skill_name = '퇴마진' OR force_crit OR random() < cc;$b$);
  a := $a$IF crit AND skill_name IS DISTINCT FROM '급소 사격' THEN mul := mul * crit_x; END IF;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor critx'; end if;
  d := replace(d, a, $b$IF crit THEN mul := mul * crit_x; END IF;$b$);
  execute d;

  d := replace(pg_get_functiondef('public.world_combat_stats(uuid,jsonb)'::regprocedure), E'\r\n', E'\n');
  a := $a$WHEN c.job_key = 'exorcist' AND style = 'magic' THEN 6 ELSE 0 END$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor cs crit'; end if;
  d := replace(d, a, $b$WHEN c.job_key = 'scout' AND style = 'ranged' THEN 4 ELSE 0 END$b$);
  a := $a$CASE WHEN c.job_key = 'scout' THEN 6 WHEN c.job_key = 'sealmaster' THEN 12 ELSE 0 END$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor cs eva'; end if;
  d := replace(d, a, $b$CASE WHEN c.job_key = 'scout' THEN 6 WHEN c.job_key = 'sealmaster' THEN 12 WHEN c.job_key = 'exorcist' THEN 4 + c.level * 0.3 ELSE 0 END$b$);
  a := $a$CASE WHEN c.job_key = 'scout' THEN 15 ELSE 0 END$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.0f anchor cs flee'; end if;
  d := replace(d, a, $b$CASE WHEN c.job_key = 'scout' THEN 15 WHEN c.job_key = 'exorcist' THEN 8 ELSE 0 END$b$);
  execute d;
end $p$;

update public.world_skill_catalog set description = replace(description, '퇴마진의 피해가 ×1.7에서 ×2.1로', '퇴마진의 피해가 ×1.4에서 ×1.7로(반드시 치명타)')
 where skill_id = 'combo_exorcism_wardcraft';

update public.world_app_meta set value = '20261105050000' where key = 'db_version';
