-- 7.7.7p — 직업별 전투 기술 계열(사용자 결정 2026-11-02, 1.0.0 오픈 전에 넣음)
--  · 전투 기술 경험은 든 무기가 아니라 「직업」 기준으로 그 직업의 계열에 쌓인다(world_job_line).
--      호위 무사 근접(melee) · 현장 조사원 사격(ranged, 옛 이름 원거리) · 봉인술사 봉인술(sealing)
--      퇴마관 퇴마술(exorcism, 새로) · 백공 기술관 단도(dagger, 새로) · 의무관 의술(medicine, 새로)
--      분석·막기·응급 처치는 지금처럼 모두가 함께 쓴다.
--  · 갈래를 뒤엎지 않고 더하는 방식: 새 계열의 기본 기술 수치는 그 직업이 전에 쓰던 계열(백공 → 근접, 퇴마관·의무관 → 봉인술)과 같다
--    (토벌 시뮬 결과가 달라지지 않게). 택일 한쪽은 옛 기술의 동작을 그대로 빌려 쓰고(world_skill_catalog.proc_as),
--    다른 한쪽은 직업 고유의 새 동작(백공 재주·퇴마관 정화·의무관 처방). 방패(이목·도발)는 호위 무사에게만 남는다.
--  · 무기마다 쓸 수 있는 직업 태그 equipment_traits.jobs(근접 → 호위 무사·백공, 원거리 → 조사원, 술법 → 퇴마관·봉인술사·의무관).
--    새 무기는 태그가 없으면 공격 방식에 따라 저절로 붙는다(trg_world_weapon_jobs). 장착·환골탈태가 검사한다.
--  · 칭호: 「검의 길·활의 길·술의 길」을 계열 기준으로 바꾸고 「비수의 길·퇴마의 길·의술의 길」과 숨김 칭호 셋을 더한다.
--  롤백(캐릭터 모두 지움) 바로 앞에 올리므로 옛 진행을 옮기지 않는다.
lock table public.world_characters in access exclusive mode;

create or replace function pg_temp.rep(d text, a text, b text, n int default 1) returns text language plpgsql as $r$
declare k int := (length(d) - length(replace(d, a, ''))) / length(a);
begin
  if k <> n then raise exception '7.7.7p anchor (% / %): %', k, n, left(a, 90); end if;
  return replace(d, a, b);
end $r$;
create or replace function pg_temp.fdef(p_name text) returns text language plpgsql as $r$
declare d text; k int;
begin
  select count(*), max(replace(pg_get_functiondef(oid), E'\r\n', E'\n')) into k, d from pg_proc where proname = p_name and pronamespace = 'public'::regnamespace;
  if k <> 1 then raise exception '7.7.7p function % (%)', p_name, k; end if;
  return d;
end $r$;

-- ── 1. 직업 → 계열, 무기 → 직업 ────────────────────────────────────────
create or replace function public.world_job_line(p_job text)
returns text language sql immutable as $f$
  -- 직업마다 전투 기술 경험이 쌓이는 계열(7.7.7p). 분석·막기·응급 처치는 공통.
  select case p_job when 'artificer' then 'melee' when 'scout' then 'ranged' when 'sealmaster' then 'sealing'
    when 'exorcist' then 'exorcism' when 'analyst' then 'dagger' when 'medic' then 'medicine' end
$f$;
create or replace function public.world_weapon_jobs_of(p_type text)
returns jsonb language sql immutable as $f$
  select case coalesce(p_type, 'melee') when 'ranged' then '["scout"]'::jsonb when 'magic' then '["exorcist","sealmaster","medic"]'::jsonb
    else '["artificer","analyst"]'::jsonb end
$f$;
create or replace function public.world_weapon_job_ok(p_cat text, p_traits jsonb, p_job text)
returns boolean language sql immutable as $f$
  -- 무기는 equipment_traits.jobs에 든 직업만(태그가 없으면 공격 방식 기본값)
  select p_cat is distinct from 'weapon' or p_job is null
      or coalesce(p_traits -> 'jobs', public.world_weapon_jobs_of(p_traits ->> 'weapon_type')) ? p_job
$f$;
create or replace function public.world_skill_line_ok(p_cat text, p_req jsonb, p_job text)
returns boolean language sql immutable as $f$
  -- 지금 직업의 계열이 아닌 전투 계열 기술(환골탈태 서첩으로 직업을 바꾼 뒤 남은 것)과 그 계열이 드는 조합 기술은 효과가 없다
  select case when p_job is null then true
    when p_cat in ('melee', 'ranged', 'sealing', 'dagger', 'exorcism', 'medicine') then p_cat = coalesce(public.world_job_line(p_job), p_cat)
    when p_cat = 'combo' then not exists (select 1 from jsonb_object_keys(coalesce(p_req, '{}'::jsonb)) k
      where k in ('melee', 'ranged', 'sealing', 'dagger', 'exorcism', 'medicine') and k is distinct from public.world_job_line(p_job))
    else true end
$f$;
do $g$
declare r text;
begin
  revoke all on function public.world_job_line(text) from public, anon, authenticated;
  revoke all on function public.world_skill_line_ok(text, jsonb, text) from public, anon, authenticated;
  revoke all on function public.world_weapon_jobs_of(text) from public, anon, authenticated;
  revoke all on function public.world_weapon_job_ok(text, jsonb, text) from public, anon, authenticated;
  for r in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname in ('postgres', 'service_role') loop
    execute format('grant execute on function public.world_job_line(text) to %I', r);
    execute format('grant execute on function public.world_weapon_jobs_of(text) to %I', r);
    execute format('grant execute on function public.world_weapon_job_ok(text, jsonb, text) to %I', r);
    execute format('grant execute on function public.world_skill_line_ok(text, jsonb, text) to %I', r);
  end loop;
end $g$;

-- 무기 태그: 지금 있는 무기 모두(우수품 포함)
update public.world_item_catalog set equipment_traits = coalesce(equipment_traits, '{}'::jsonb)
    || jsonb_build_object('jobs', public.world_weapon_jobs_of(equipment_traits ->> 'weapon_type'))
 where category = 'weapon' and not (coalesce(equipment_traits, '{}'::jsonb) ? 'jobs');
create or replace function public.world_weapon_jobs_fill()
returns trigger language plpgsql set search_path to 'pg_catalog', 'public' as $f$
begin
  if new.category = 'weapon' and not (coalesce(new.equipment_traits, '{}'::jsonb) ? 'jobs') then
    new.equipment_traits := coalesce(new.equipment_traits, '{}'::jsonb) || jsonb_build_object('jobs', public.world_weapon_jobs_of(new.equipment_traits ->> 'weapon_type'));
  end if;
  return new;
end $f$;
revoke all on function public.world_weapon_jobs_fill() from public, anon, authenticated;
drop trigger if exists trg_world_weapon_jobs on public.world_item_catalog;
create trigger trg_world_weapon_jobs before insert or update of equipment_traits, category on public.world_item_catalog
  for each row execute function public.world_weapon_jobs_fill();

-- 장착 검사·환골탈태(직업이 바뀌면 못 드는 무기를 내려놓음)
do $p$
declare d text;
begin
  d := pg_temp.fdef('world_equip_item');
  if position('world_weapon_job_ok' in d) = 0 then
    d := pg_temp.rep(d, $a$ if it.required_job is not null and c.job_key<>it.required_job then raise exception '직업 제한: % 전용 장비입니다.',public.world_job_name(it.required_job); end if;$a$,
      $a$ if it.required_job is not null and c.job_key<>it.required_job then raise exception '직업 제한: % 전용 장비입니다.',public.world_job_name(it.required_job); end if;
 if not public.world_weapon_job_ok(it.category, it.equipment_traits, c.job_key) then
   raise exception '직업 제한: 이 무기는 % 직업만 쓸 수 있습니다.', (select string_agg(public.world_job_name(j), '·') from jsonb_array_elements_text(coalesce(it.equipment_traits -> 'jobs', public.world_weapon_jobs_of(it.equipment_traits ->> 'weapon_type'))) j);
 end if;$a$);
    execute d;
  end if;
  d := pg_temp.fdef('world_reset_identity');
  if position('world_weapon_job_ok' in d) = 0 then
    d := pg_temp.rep(d, '(i.required_job is not null and i.required_job <> p_job)',
      '(i.required_job is not null and i.required_job <> p_job) or not public.world_weapon_job_ok(i.category, i.equipment_traits, p_job)', 2);
    execute d;
  end if;
end $p$;

-- ── 2. 기술표: 새 계열 셋 + 조합 기술 셋 ───────────────────────────────
alter table public.world_skill_catalog add column if not exists proc_as text;
comment on column public.world_skill_catalog.proc_as is '이 기술이 빌려 쓰는 옛 기술의 동작(skill_id). world_skill_procs가 함께 돌려준다(7.7.7p).';

insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot, proc_as, requires) values
-- 단도(백공 기술관): 기본 수치는 근접과 같음. 택일 ① 공격(근접 공격 갈래와 같은 동작) / ② 재주(새 동작) — 방패 갈래 없음
 ('dagger_t3',  '손목 놀림',     'dagger', '근접 피해 +5%.', '{"damage_pct": 5}', 3, 'base', null, null),
 ('dagger_t8',  '틈새 찌르기',   'dagger', '근접 피해 +10%, 은형·경요 요괴에게 +8% 더.', '{"damage_pct": 10}', 8, 'base', null, null),
 ('dagger_c13a','선수 찌르기',   'dagger', '택일 기술(공격) · 전투의 첫 근접 공격은 반드시 치명타', '{}', 13, 'a', 'melee_x13', null),
 ('dagger_c13b','급소 해부',     'dagger', '택일 기술(재주) · 같은 적을 근접으로 칠 때마다 피해 +4%씩 쌓인다(최대 +20%)', '{}', 13, 'b', null, null),
 ('dagger_t13', '잔칼질',        'dagger', '근접 피해 +3%.', '{"damage_pct": 3}', 13, 'base', null, null),
 ('dagger_t18', '손끝 감각',     'dagger', '근접 피해 +2% · 치명타 +2%.', '{"crit_pct": 2, "damage_pct": 2}', 18, 'base', null, null),
 ('dagger_c24a','마무리 찌르기', 'dagger', '택일 기술(공격) · 적 체력이 30% 아래면 근접 피해 +40%(마무리)', '{}', 24, 'a', 'melee_c24a', null),
 ('dagger_c24b','독 바른 날',    'dagger', '택일 기술(재주) · 근접 공격이 맞으면 20% 확률로 독이 스민다(2턴 동안 매턴 적 최대 체력 4% 피해)', '{}', 24, 'b', null, null),
 ('dagger_t24', '날 세우기',     'dagger', '근접 피해 +4%.', '{"damage_pct": 4}', 24, 'base', null, null),
 ('dagger_c30a','흘려 찌르기',   'dagger', '택일 기술(공격) · 막기·회피에 성공하면 다음 공격이 반드시 치명타', '{}', 30, 'a', 'melee_c30a', null),
 ('dagger_c30b','손재주 덫',     'dagger', '택일 기술(재주) · 근접 공격이 맞으면 30% 확률로 적의 다음 공격이 약해진다(−20%)', '{}', 30, 'b', null, null),
 ('dagger_t30', '일점',          'dagger', '치명타 +3%.', '{"crit_pct": 3}', 30, 'base', null, null),
 ('dagger_t36', '연속 찌르기',   'dagger', '근접 피해 +4%.', '{"damage_pct": 4}', 36, 'base', null, null),
 ('dagger_c43a','해체의 일격',   'dagger', '택일 기술(공격) · 근접 치명타가 적의 방어를 2턴 무너뜨린다(받는 피해 +20%)', '{}', 43, 'a', 'melee_c43a', null),
 ('dagger_c43b','장인의 눈',     'dagger', '택일 기술(재주) · 근접 치명타는 굳은 껍질과 결계를 무시하고 꿰뚫는다', '{}', 43, 'b', null, null),
 ('dagger_t43', '무음 찌르기',   'dagger', '근접 피해 +3% · 치명타 +2%.', '{"crit_pct": 2, "damage_pct": 3}', 43, 'base', null, null),
 ('dagger_t50', '백공지경',      'dagger', '근접 피해 +5% · 치명타 +3%.', '{"crit_pct": 3, "damage_pct": 5}', 50, 'base', null, null),
 ('dagger_m50', '천수비도',      'dagger', '숙달 기술 · 근접 공격 때 20% 확률로 세 번 연속 찌르기(2·3타 피해 50%)', '{}', 50, 'master', 'melee_m50', null),
-- 퇴마술(퇴마관): 기본 수치는 봉인술과 같음. ① 몰아치기(봉인술 몰아치기와 같은 동작) / ② 정화(새 동작, 43은 청정결계 동작)
 ('exorcism_t3',  '파사 부적',   'exorcism', '술법 피해 +8%.', '{"damage_pct": 8}', 3, 'base', null, null),
 ('exorcism_t8',  '파사의 기운', 'exorcism', '술법 피해 +15%, 영귀·파봉 요괴에게 +12% 더.', '{"damage_pct": 15}', 8, 'base', null, null),
 ('exorcism_c13a','연격 진언',   'exorcism', '택일 기술(몰아치기) · 술법이 적중하면 25% 확률로 진언이 이어져 피해 40% 추가', '{}', 13, 'a', 'sealing_c13a', null),
 ('exorcism_c13b','파사안',      'exorcism', '택일 기술(정화) · 영귀·은형·파봉 요괴에게 술법 피해 +20%', '{}', 13, 'b', null, null),
 ('exorcism_t13', '삼매 진언',   'exorcism', '술법 피해 +3%.', '{"damage_pct": 3}', 13, 'base', null, null),
 ('exorcism_t18', '정심 수행',   'exorcism', '침식 -5%.', '{"erosion_pct": -5}', 18, 'base', null, null),
 ('exorcism_c24a','진언 폭발',   'exorcism', '택일 기술(몰아치기) · 술법이 적중하면 20% 확률로 터져 피해 25% 추가', '{}', 24, 'a', 'sealing_c24a', null),
 ('exorcism_c24b','퇴마 진언',   'exorcism', '택일 기술(정화) · 술법이 적중하면 30% 확률로 요괴의 결계와 허상을 걷어 낸다', '{}', 24, 'b', null, null),
 ('exorcism_t24', '화염 진언',   'exorcism', '술법 피해 +4%.', '{"damage_pct": 4}', 24, 'base', null, null),
 ('exorcism_c30a','겹진언',      'exorcism', '택일 기술(몰아치기) · 술법 공격 때 25% 확률로 한 번 더 시전(피해 70%)', '{}', 30, 'a', 'sealing_c30a', null),
 ('exorcism_c30b','정화의 불',   'exorcism', '택일 기술(정화) · 술법 공격 때 40% 확률로 침식 −1', '{}', 30, 'b', null, null),
 ('exorcism_t30', '혼백 꿰뚫기', 'exorcism', '치명타 +3%.', '{"crit_pct": 3}', 30, 'base', null, null),
 ('exorcism_t36', '팔부 신장',   'exorcism', '술법 피해 +4% · 침식 -5%.', '{"damage_pct": 4, "erosion_pct": -5}', 36, 'base', null, null),
 ('exorcism_c43a','천벌 뇌화',   'exorcism', '택일 기술(몰아치기) · 술법 공격 때 15% 확률로 벼락(적 최대 체력 8% 피해)', '{}', 43, 'a', 'sealing_c43a', null),
 ('exorcism_c43b','금강 결계',   'exorcism', '택일 기술(정화) · 술법을 쓰면 3턴 동안 받는 피해 −20%, 술법 공격마다 30% 확률로 침식 −1', '{}', 43, 'b', 'sealing_c43b', null),
 ('exorcism_t43', '사천왕 진언', 'exorcism', '술법 피해 +3% · 정신 손실 -5%.', '{"damage_pct": 3, "mental_loss_pct": -5}', 43, 'base', null, null),
 ('exorcism_t50', '항마지경',    'exorcism', '술법 피해 +5% · 치명타 +3%.', '{"crit_pct": 3, "damage_pct": 5}', 50, 'base', null, null),
 ('exorcism_m50', '멸마',        'exorcism', '숙달 기술 · 술법 치명타의 피해가 150%에서 200%로 오른다', '{}', 50, 'master', null, null),
-- 의술(의무관): 기본 수치는 봉인술과 같음. ① 침술(봉인술 몰아치기와 같은 동작) / ② 처방(새 동작)
 ('medicine_t3',  '침 놓기',       'medicine', '술법 피해 +8%, 정신 손실 -3%.', '{"damage_pct": 8, "mental_loss_pct": -3}', 3, 'base', null, null),
 ('medicine_t8',  '혈자리 찌르기', 'medicine', '술법 피해 +15%, 독충·수귀 요괴에게 +12% 더.', '{"damage_pct": 15}', 8, 'base', null, null),
 ('medicine_c13a','연침',          'medicine', '택일 기술(침술) · 술법이 적중하면 25% 확률로 침이 이어져 피해 40% 추가', '{}', 13, 'a', 'sealing_c13a', null),
 ('medicine_c13b','맥 짚기',       'medicine', '택일 기술(처방) · 현장 토벌에서 회복품의 회복량 +20%', '{}', 13, 'b', null, null),
 ('medicine_t13', '오행 침법',     'medicine', '술법 피해 +3%.', '{"damage_pct": 3}', 13, 'base', null, null),
 ('medicine_t18', '정기 다스리기', 'medicine', '침식 -5%.', '{"erosion_pct": -5}', 18, 'base', null, null),
 ('medicine_c24a','파혈침',        'medicine', '택일 기술(침술) · 술법이 적중하면 20% 확률로 혈이 터져 피해 25% 추가', '{}', 24, 'a', 'sealing_c24a', null),
 ('medicine_c24b','보신 처방',     'medicine', '택일 기술(처방) · 술법 공격마다 체력 +3(한 전투에 6번까지)', '{}', 24, 'b', null, null),
 ('medicine_t24', '뜸 기운',       'medicine', '술법 피해 +4%.', '{"damage_pct": 4}', 24, 'base', null, null),
 ('medicine_c30a','연환침',        'medicine', '택일 기술(침술) · 술법 공격 때 25% 확률로 한 번 더 시전(피해 70%)', '{}', 30, 'a', 'sealing_c30a', null),
 ('medicine_c30b','해독 처방',     'medicine', '택일 기술(처방) · 술법 공격 때 35% 확률로 나쁜 상태 하나를 푼다', '{}', 30, 'b', null, null),
 ('medicine_t30', '급소 침',       'medicine', '치명타 +3%.', '{"crit_pct": 3}', 30, 'base', null, null),
 ('medicine_t36', '백맥 순환',     'medicine', '술법 피해 +4% · 침식 -5%.', '{"damage_pct": 4, "erosion_pct": -5}', 36, 'base', null, null),
 ('medicine_c43a','뇌침',          'medicine', '택일 기술(침술) · 술법 공격 때 15% 확률로 벼락침(적 최대 체력 8% 피해)', '{}', 43, 'a', 'sealing_c43a', null),
 ('medicine_c43b','회춘',          'medicine', '택일 기술(처방) · 쓰러질 피해를 받으면 한 전투에 한 번 체력 20으로 버틴다', '{}', 43, 'b', null, null),
 ('medicine_t43', '약선 지혜',     'medicine', '술법 피해 +3% · 회복량 +5%.', '{"damage_pct": 3, "healing_pct": 5}', 43, 'base', null, null),
 ('medicine_t50', '의성지경',      'medicine', '술법 피해 +5% · 치명타 +3%.', '{"crit_pct": 3, "damage_pct": 5}', 50, 'base', null, null),
 ('medicine_m50', '화타의 손',     'medicine', '숙달 기술 · 응급 처방의 회복량 ×1.5', '{}', 50, 'master', null, null),
-- 조합 기술: 계열마다 하나씩(근접·사격·봉인술처럼)
 ('combo_dagger_leatherwork', '칼집 손질', 'combo', '조합 기술(단도·가죽 공예 둘 다 18단계) · 공격할 때 무기가 닳지 않을 확률 50%', '{}', 18, 'combo', 'combo_melee_smithing', '{"dagger": 18, "leatherwork": 18}'),
 ('combo_exorcism_wardcraft', '부적 퇴마진', 'combo', '조합 기술(퇴마술·봉인 공예 둘 다 18단계) · 퇴마진의 피해가 ×2.0에서 ×2.4로', '{}', 18, 'combo', null, '{"exorcism": 18, "wardcraft": 18}'),
 ('combo_medicine_alchemy',   '약선 처방', 'combo', '조합 기술(의술·연금 둘 다 18단계) · 응급 처방의 회복량 +10', '{}', 18, 'combo', null, '{"medicine": 18, "alchemy": 18}')
on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description,
  passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot, proc_as = excluded.proc_as, requires = excluded.requires;
update public.world_skill_catalog set description = replace(description, '원거리·탐사', '사격·탐사') where skill_id = 'combo_ranged_tracking';

-- 원정에서의 기술 효과·일지 줄(옛 기술과 같은 크기)
insert into public.world_exp_skill_def(skill_id, atk, guard, win, loot, find, heal, ward, kind, txt) values
 ('dagger_c13a', 3, 0, 0, 0, 0, 0, 0, 'fight', '칼을 뽑는 순간 먼저 찔러 들어갑니다.'),
 ('dagger_c13b', 3, 0, 0, 0, 0, 0, 0, 'fight', '급소를 하나씩 해부해 들어갑니다.'),
 ('dagger_c24a', 4, 0, 0, 0, 0, 0, 0, 'fight', '흔들리는 요괴의 숨통을 노립니다.'),
 ('dagger_c24b', 3, 0, 0.01, 0, 0, 0, 0, 'fight', '날에 바른 독이 요괴를 갉아먹습니다.'),
 ('dagger_c30a', 4, 0, 0.01, 0, 0, 0, 0, 'fight', '흘려 넘긴 틈으로 날을 밀어 넣습니다.'),
 ('dagger_c30b', 0, 4, 0, 0, 0, 0, 0, 'fight', '손재주로 놓은 덫이 요괴의 발을 묶습니다.'),
 ('dagger_c43a', 6, 0, 0, 0, 0, 0, 0, 'fight', '이음새를 끊어 요괴의 방어를 해체합니다.'),
 ('dagger_c43b', 6, 0, 0, 0, 0, 0, 0, 'fight', '장인의 눈으로 껍질의 틈을 찌릅니다.'),
 ('dagger_m50', 8, 0, 0.02, 0, 0, 0, 0, 'fight', '천 개의 날처럼 손이 보이지 않습니다.'),
 ('exorcism_c13a', 3, 0, 0, 0, 0, 0, 0, 'fight', '진언을 이어 외워 요괴를 몰아칩니다.'),
 ('exorcism_c13b', 4, 0, 0, 0, 0, 0, 0, 'fight', '파사안으로 요괴의 본모습을 꿰뚫어 봅니다.'),
 ('exorcism_c24a', 4, 0, 0, 0, 0, 0, 0, 'fight', '진언이 요괴 앞에서 터집니다.'),
 ('exorcism_c24b', 3, 0, 0, 0, 0, 0, 3, 'fight', '진언으로 요괴의 결계를 걷어 냅니다.'),
 ('exorcism_c30a', 4, 0, 0, 0, 0, 0, 0, 'fight', '진언을 겹으로 엮어 몰아칩니다.'),
 ('exorcism_c30b', 0, 0, 0, 0, 0, 0, 6, 'camp', '정화의 불로 스며든 요기를 사릅니다.'),
 ('exorcism_c43a', 6, 0, 0, 0, 0, 0, 0, 'fight', '하늘의 벌을 진언에 실어 내립니다.'),
 ('exorcism_c43b', 0, 3, 0, 0, 0, 0, 8, 'camp', '금강 결계를 쳐 쉬어 갑니다.'),
 ('exorcism_m50', 8, 0, 0.02, 0, 0, 0, 0, 'fight', '멸마의 일격이 요괴를 사릅니다.'),
 ('medicine_c13a', 3, 0, 0, 0, 0, 0, 0, 'fight', '침을 이어 놓아 요괴의 혈을 막습니다.'),
 ('medicine_c13b', 0, 0, 0, 0, 0, 1, 0, 'camp', '맥을 짚어 약효를 끌어올립니다.'),
 ('medicine_c24a', 4, 0, 0, 0, 0, 0, 0, 'fight', '혈자리를 터뜨려 요괴를 흔듭니다.'),
 ('medicine_c24b', 0, 2, 0, 0, 0, 2, 0, 'fight', '몸을 보하는 처방으로 버팁니다.'),
 ('medicine_c30a', 4, 0, 0, 0, 0, 0, 0, 'fight', '침을 고리처럼 이어 놓습니다.'),
 ('medicine_c30b', 0, 0, 0, 0, 0, 1, 4, 'camp', '해독 처방으로 요독을 다스립니다.'),
 ('medicine_c43a', 6, 0, 0, 0, 0, 0, 0, 'fight', '벼락침이 요괴를 꿰뚫습니다.'),
 ('medicine_c43b', 0, 4, 0.01, 0, 0, 0, 0, 'fight', '쓰러질 뻔한 숨을 되살립니다.'),
 ('medicine_m50', 0, 0, 0.02, 0, 0, 3, 0, 'camp', '화타의 손으로 상처를 다스립니다.'),
 ('combo_dagger_leatherwork', 4, 0, 0, 0, 0, 0, 0, 'fight', '손질해 둔 날로 거침없이 찌릅니다.'),
 ('combo_exorcism_wardcraft', 4, 0, 0, 0, 0, 0, 3, 'fight', '부적을 둘러 퇴마진을 펼칩니다.'),
 ('combo_medicine_alchemy', 0, 0, 0, 0, 0, 2, 0, 'camp', '손수 지은 약으로 몸을 추스릅니다.')
on conflict (skill_id) do update set atk = excluded.atk, guard = excluded.guard, win = excluded.win, loot = excluded.loot, find = excluded.find,
  heal = excluded.heal, ward = excluded.ward, kind = excluded.kind, txt = excluded.txt;

-- ── 3. 기술 판정 도우미 ─────────────────────────────────────────────
-- 고유 효과 목록: 익힌 기술 + 그 기술이 빌려 쓰는 옛 기술의 동작
create or replace function public.world_skill_procs(p_uid uuid)
returns text[] language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
#variable_conflict use_column
begin
  return (select * from (select coalesce((select array_agg(distinct v) from (
      select sk.skill_id, sk.proc_as
        from public.world_characters c
        left join public.world_skill_picks pk on pk.owner_id = c.owner_id
        join public.world_skill_catalog sk on sk.slot in ('extra', 'a', 'b', 'master', 'combo')
       where c.owner_id = p_uid
         and public.world_skill_line_ok(sk.category, sk.requires, c.job_key)
         and public.world_skill_has(c.skill_progress, coalesce(pk.picks, '{}'::jsonb), sk.category, sk.unlock_rank, sk.slot, sk.requires)) q
      cross join lateral unnest(array[q.skill_id, q.proc_as]) v where v is not null), '{}')
  ) yhq limit 1);
end $f$;
-- 실제로 익힌 기술만(원정 기술 효과·일지 줄은 빌려 온 동작을 두 번 세지 않게 이것으로)
create or replace function public.world_skill_owned(p_uid uuid)
returns text[] language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
#variable_conflict use_column
begin
  return (select * from (select coalesce(array_agg(sk.skill_id), '{}')
    from public.world_characters c
    left join public.world_skill_picks pk on pk.owner_id = c.owner_id
    join public.world_skill_catalog sk on sk.slot in ('extra', 'a', 'b', 'master', 'combo')
   where c.owner_id = p_uid
     and public.world_skill_line_ok(sk.category, sk.requires, c.job_key)
     and public.world_skill_has(c.skill_progress, coalesce(pk.picks, '{}'::jsonb), sk.category, sk.unlock_rank, sk.slot, sk.requires)
  ) yhq limit 1);
end $f$;
revoke all on function public.world_skill_owned(uuid) from public, anon, authenticated;
grant execute on function public.world_skill_owned(uuid) to fn_owner_field;
-- 빌려 쓴 동작이 남긴 전투 기록 줄의 기술 이름을 내 기술 이름으로
create or replace function public.world_skill_alias_lines(p_uid uuid, p_lines jsonb)
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare t text := p_lines::text; r record;
begin
  for r in select sk.skill_name, o.skill_name as old_name
             from unnest(public.world_skill_owned(p_uid)) x(id)
             join public.world_skill_catalog sk on sk.skill_id = x.id and sk.proc_as is not null
             join public.world_skill_catalog o on o.skill_id = sk.proc_as loop
    t := replace(t, '「' || r.old_name || '」', '「' || r.skill_name || '」');
  end loop;
  return t::jsonb;
end $f$;
revoke all on function public.world_skill_alias_lines(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.world_skill_alias_lines(uuid, jsonb) to fn_owner_field;

do $p$
declare d text;
begin
  -- 원정 기술 효과는 익힌 기술로
  d := pg_temp.fdef('world_exp_skill_fx');
  if position('world_skill_owned' in d) = 0 then execute pg_temp.rep(d, 'unnest(public.world_skill_procs(p_uid))', 'unnest(public.world_skill_owned(p_uid))'); end if;

  -- 계열 이름(원거리 → 사격)
  d := pg_temp.fdef('world_line_name');
  if position('dagger' in d) = 0 then
    execute pg_temp.rep(d, $a$when 'melee' then '근접' when 'ranged' then '원거리' when 'sealing' then '봉인술'$a$,
      $a$when 'melee' then '근접' when 'ranged' then '사격' when 'sealing' then '봉인술' when 'dagger' then '단도' when 'exorcism' then '퇴마술' when 'medicine' then '의술'$a$);
  end if;

  -- 전투 숙련 = 전투 계열 가운데 최고 단계
  d := pg_temp.fdef('world_skill_sync');
  if position('dagger' in d) = 0 then
    d := pg_temp.rep(d, $a$if k in ('melee', 'ranged', 'sealing', 'analysis', 'guarding', 'first_aid') then$a$,
      $a$if k in ('analysis', 'guarding', 'first_aid') or k = (case new.job_key when 'artificer' then 'melee' when 'scout' then 'ranged' when 'sealmaster' then 'sealing'
        when 'exorcist' then 'exorcism' when 'analyst' then 'dagger' when 'medic' then 'medicine' else k end) then$a$);
    -- 직업이 바뀌면(환골탈태 서첩) 전투 숙련을 다시 센다
    d := pg_temp.rep(d, 'and new.combat_rank is not distinct from old.combat_rank', 'and new.job_key is not distinct from old.job_key and new.combat_rank is not distinct from old.combat_rank');
    execute d;
  end if;

  -- 새 캐릭터: 새 계열 칸도 만든다
  d := pg_temp.fdef('world_initialize_skill_tracks');
  if position('dagger' in d) = 0 then
    execute pg_temp.rep(d, $a$ 'sealing',coalesce(new.skill_progress->'sealing','{"xp":0,"rank":1}'::jsonb),$a$,
      $a$ 'sealing',coalesce(new.skill_progress->'sealing','{"xp":0,"rank":1}'::jsonb),
 'dagger',coalesce(new.skill_progress->'dagger','{"xp":0,"rank":1}'::jsonb),
 'exorcism',coalesce(new.skill_progress->'exorcism','{"xp":0,"rank":1}'::jsonb),
 'medicine',coalesce(new.skill_progress->'medicine','{"xp":0,"rank":1}'::jsonb),$a$);
  end if;

  -- 자율 수련·원정 귀환의 전투 경험 절반: 든 무기 → 직업 계열
  d := pg_temp.fdef('world_idle_skill_for');
  if position('world_job_line' in d) = 0 then
    execute pg_temp.rep(d, $a$coalesce((
      select case i.equipment_traits ->> 'weapon_type' when 'ranged' then 'ranged' when 'magic' then 'sealing' else 'melee' end
        from public.world_character_equipment e join public.world_item_catalog i on i.item_id = e.item_id
       where e.owner_id = p_owner and e.slot = 'weapon' limit 1), 'melee')$a$,
      $a$coalesce((select public.world_job_line(c.job_key) from public.world_characters c where c.owner_id = p_owner), 'melee')$a$);
  end if;

  -- 토벌 기록의 기술 경험: 공격은 직업 계열로(분석·응급 처치·막기는 그대로)
  d := pg_temp.fdef('world_event_char_apply');
  if position('world_job_line' in d) = 0 then
    d := pg_temp.rep(d, E'      when k = ''combat'' and coalesce(p ->> ''action'', '''') = ''ranged'' then ''ranged''\n', '');
    d := pg_temp.rep(d, E'      when k = ''combat'' and coalesce(p ->> ''action'', '''') = ''seal'' then ''sealing''\n', '');
    d := pg_temp.rep(d, $a$      when k = 'combat' then 'melee'$a$,
      $a$      when k = 'combat' then coalesce(p ->> 'line', public.world_job_line((select x.job_key from public.world_characters x where x.owner_id = uid)), 'melee')$a$);
    execute d;
  end if;

  -- 원정 수법 저절로 대처: 「봉인술」 대처는 술법 계열(봉인술·퇴마술·의술) 가운데 높은 단계로
  d := pg_temp.fdef('world_exp_fight_story');
  if position('world_job_line' in d) = 0 then
    execute pg_temp.rep(d, $a$coalesce((p_ctx -> 'sp' -> cn[1] ->> 'rank')::int, 1)$a$,
      $a$(CASE WHEN cn[1] = 'sealing' THEN CASE WHEN public.world_job_line(p_job) IN ('sealing', 'exorcism', 'medicine') THEN coalesce((p_ctx -> 'sp' -> public.world_job_line(p_job) ->> 'rank')::int, 1) ELSE 1 END ELSE coalesce((p_ctx -> 'sp' -> cn[1] ->> 'rank')::int, 1) END)$a$);
  end if;
  d := pg_temp.fdef('world_gimmick_tip');
  if position('퇴마술' in d) = 0 then execute pg_temp.rep(d, $a$when 'sealing' then '봉인술'$a$, $a$when 'sealing' then '봉인술·퇴마술·의술'$a$); end if;

  -- 전투 능력치: 기본 기술 피해·치명타는 직업 계열에서
  d := pg_temp.fdef('world_combat_stats');
  if position('world_job_line' in d) = 0 then
    d := pg_temp.rep(d, $a$  skill_cat := CASE style WHEN 'ranged' THEN 'ranged' WHEN 'magic' THEN 'sealing' ELSE 'melee' END;$a$,
      $a$  skill_cat := coalesce(public.world_job_line(c.job_key), CASE style WHEN 'ranged' THEN 'ranged' WHEN 'magic' THEN 'sealing' ELSE 'melee' END);$a$);
    d := pg_temp.rep(d, '-- 익힌 전투 기술: 공격 방식에 맞는 계열(근접·원거리·봉인)과 분석 계열의 상시 효과', '-- 익힌 전투 기술: 직업 계열(7.7.7p)과 분석·조합 기술의 상시 효과');
    d := pg_temp.rep(d, $a$WHERE sk.category IN (skill_cat, 'analysis', 'combo') AND $a$, $a$WHERE sk.category IN (skill_cat, 'analysis', 'combo') AND public.world_skill_line_ok(sk.category, sk.requires, c.job_key) AND $a$);
    execute d;
  end if;
end $p$;

-- ── 4. 현장 토벌: 새 고유 효과 ─────────────────────────────────────────
do $p$
declare d text;
begin
  d := pg_temp.fdef('world_battle_action');
  if position('dagger_c13b' in d) = 0 then
    -- 8단계 기본 기술의 갈래 덤 + 급소 해부·파사안
    d := pg_temp.rep(d, $a$    IF style = 'magic' AND m.mechanic_key = 'warded' AND coalesce((c.skill_progress -> 'sealing' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.12; END IF;$a$,
      $a$    IF style = 'magic' AND c.job_key = 'sealmaster' AND m.mechanic_key = 'warded' AND coalesce((c.skill_progress -> 'sealing' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.12; END IF;
    IF style = 'melee' AND c.job_key = 'analyst' AND m.kind IN ('mirror', 'shadow') AND coalesce((c.skill_progress -> 'dagger' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.08; END IF;
    IF style = 'magic' AND c.job_key = 'exorcist' AND m.kind IN ('ghost', 'breaker') AND coalesce((c.skill_progress -> 'exorcism' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.12; END IF;
    IF style = 'magic' AND c.job_key = 'medic' AND m.kind IN ('venom', 'water') AND coalesce((c.skill_progress -> 'medicine' ->> 'rank')::int, 0) >= 8 THEN mul := mul * 1.12; END IF;
    IF style = 'magic' AND 'exorcism_c13b' = ANY (sk) AND m.kind IN ('ghost', 'shadow', 'breaker') THEN mul := mul * 1.2; END IF;
    IF style = 'melee' AND 'dagger_c13b' = ANY (sk) THEN
      mul := mul * (1 + 0.04 * least(5, coalesce((v_pfx ->> 'dissect')::int, 0)));
      v_pfx := v_pfx || jsonb_build_object('dissect', least(5, coalesce((v_pfx ->> 'dissect')::int, 0) + 1));
    END IF;$a$);
    d := pg_temp.rep(d, $a$IF style = 'melee' AND m.mechanic_key = 'armored' AND coalesce((c.skill_progress -> 'melee'$a$, $a$IF style = 'melee' AND c.job_key = 'artificer' AND m.mechanic_key = 'armored' AND coalesce((c.skill_progress -> 'melee'$a$);
    -- 멸마: 술법 치명타 200%
    d := pg_temp.rep(d, '    cc := least(0.65, crit_p / 100.0',
      E'    IF style = ''magic'' AND ''exorcism_m50'' = ANY (sk) THEN crit_x := greatest(crit_x, 2.0); END IF;\n    cc := least(0.65, crit_p / 100.0');
    -- 장인의 눈: 근접 치명타는 껍질·결계 무시(관통시와 같은 자리)
    d := pg_temp.rep(d, $a$(style = 'ranged' AND 'ranged_c43a' = ANY (sk))$a$,
      $a$((style = 'ranged' AND 'ranged_c43a' = ANY (sk)) OR (crit AND style = 'melee' AND 'dagger_c43b' = ANY (sk)))$a$, 3);
    -- 공격이 맞은 뒤: 독 바른 날·손재주 덫·퇴마 진언·정화의 불·보신 처방·해독 처방
    d := pg_temp.rep(d, $a$    IF style = 'melee' AND 'melee_x30' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('pshield', least(15, coalesce((v_pfx ->> 'pshield')::int, 0) + 3)); END IF;$a$,
      $a$    IF style = 'melee' AND 'melee_x30' = ANY (sk) THEN v_pfx := v_pfx || jsonb_build_object('pshield', least(15, coalesce((v_pfx ->> 'pshield')::int, 0) + 3)); END IF;
    IF style = 'melee' AND dmg > 0 AND a.current_hp > 0 THEN
      IF 'dagger_c24b' = ANY (sk) AND random() < 0.2 THEN
        v_fx := v_fx || jsonb_build_object('pierce', greatest(2, coalesce((v_fx ->> 'pierce')::int, 0))); lines := lines || jsonb_build_array('「독 바른 날」 날의 독이 스며들었다.');
      END IF;
      IF 'dagger_c30b' = ANY (sk) AND random() < 0.3 THEN
        v_fx := v_fx || jsonb_build_object('weak', greatest(2, coalesce((v_fx ->> 'weak')::int, 0))); lines := lines || jsonb_build_array('「손재주 덫」 ' || m.monster_name || '의 다음 공격이 무뎌진다.');
      END IF;
    END IF;
    IF style = 'magic' AND dmg > 0 THEN
      IF 'exorcism_c24b' = ANY (sk) AND (v_fx ? 'barrier' OR v_fx ? 'evade') AND random() < 0.3 THEN
        v_fx := v_fx - 'barrier' - 'evade'; lines := lines || jsonb_build_array('「퇴마 진언」 요괴의 결계와 허상을 걷어 냈다.');
      END IF;
      IF 'exorcism_c30b' = ANY (sk) AND er > 0 AND random() < 0.4 THEN er := er - 1; END IF;
      IF 'medicine_c24b' = ANY (sk) AND coalesce((v_pfx ->> 'mend')::int, 0) < 6 AND hp < 100 THEN
        hp := least(100, hp + 3); v_pfx := v_pfx || jsonb_build_object('mend', coalesce((v_pfx ->> 'mend')::int, 0) + 1); lines := lines || jsonb_build_array('「보신 처방」 체력 +3');
      END IF;
      IF 'medicine_c30b' = ANY (sk) AND random() < 0.35 THEN
        UPDATE public.world_character_statuses SET expires_at = now() WHERE status_id = (SELECT cs.status_id FROM public.world_character_statuses cs JOIN public.world_status_catalog sc USING (status_key)
          WHERE cs.owner_id = uid AND cs.expires_at > now() AND sc.polarity = 'negative' AND cs.status_key NOT IN ('yohwa', 'yohwa_seal') ORDER BY cs.expires_at LIMIT 1);
        IF FOUND THEN lines := lines || jsonb_build_array('「해독 처방」 나쁜 상태 하나를 풀었다.'); END IF;
      END IF;
    END IF;$a$);
    -- 맥 짚기: 회복품 회복량 +20%(체력·영력 회복품 두 곳)
    d := pg_temp.rep(d, $a$IF c.job_key = 'medic' THEN heal := round(heal * 1.15); END IF;$a$,
      $a$IF c.job_key = 'medic' THEN heal := round(heal * 1.15); END IF; IF 'medicine_c13b' = ANY (sk) THEN heal := round(heal * 1.2); END IF;$a$, 2);
    -- 화타의 손·약선 처방: 응급 처방
    d := pg_temp.rep(d, $a$heal := least(40, 15 + c.vitality / 2 + c.willpower / 2);$a$,
      $a$heal := least(40, 15 + c.vitality / 2 + c.willpower / 2); IF 'medicine_m50' = ANY (sk) THEN heal := round(heal * 1.5); END IF; IF 'combo_medicine_alchemy' = ANY (sk) THEN heal := heal + 10; END IF;$a$);
    -- 회춘: 쓰러질 피해를 한 번 체력 20으로
    d := pg_temp.rep(d, '    -- 금강불괴: 한 번 체력 1로 버틴다',
      $a$    -- 회춘(의술 43 택일): 한 번 체력 20으로 버틴다
    IF ended IS NULL AND hp <= 0 AND 'medicine_c43b' = ANY (sk) AND NOT coalesce((v_pfx ->> 'reborn')::boolean, false) THEN
      hp := 20; v_pfx := v_pfx || jsonb_build_object('reborn', true); lines := lines || jsonb_build_array('「회춘」 끊어지던 숨을 되살려 다시 섰다. 체력 20');
    END IF;
    -- 금강불괴: 한 번 체력 1로 버틴다$a$);
    -- 부적 퇴마진
    d := pg_temp.rep(d, $a$IF skill_name = '퇴마진' THEN mul := mul * 2.0;$a$,
      $a$IF skill_name = '퇴마진' THEN mul := mul * CASE WHEN 'combo_exorcism_wardcraft' = ANY (sk) THEN 2.4 ELSE 2.0 END;$a$);
    -- 빌려 쓴 동작의 기록 줄 이름을 내 기술 이름으로
    d := pg_temp.rep(d, '  UPDATE public.world_characters SET health = hp, mental = mn, spiritual_power = sp, erosion = er,',
      E'  IF EXISTS (SELECT 1 FROM unnest(sk) x WHERE x ~ ''^(dagger|exorcism|medicine|combo_dagger)_'') THEN lines := public.world_skill_alias_lines(uid, lines); END IF;\n  UPDATE public.world_characters SET health = hp, mental = mn, spiritual_power = sp, erosion = er,');
    -- 토벌 기록에 계열(기술 경험·칭호가 이것으로 셈)
    d := pg_temp.rep(d, $a$'action', CASE style WHEN 'ranged' THEN 'ranged' WHEN 'magic' THEN 'seal' ELSE 'attack' END,$a$,
      $a$'action', CASE style WHEN 'ranged' THEN 'ranged' WHEN 'magic' THEN 'seal' ELSE 'attack' END, 'line', public.world_job_line(c.job_key),$a$);
    execute d;
  end if;
end $p$;

-- ── 4-2. 지난 직업 계열은 효과 없음 · 환골탈태 서첩을 세력 비고에서 ─────────
do $p$
declare d text;
begin
  d := pg_temp.fdef('world_skill_effect');
  if position('world_skill_line_ok' in d) = 0 then
    execute pg_temp.rep(d, $a$     and public.world_skill_has(c.skill_progress, coalesce(pk.picks, '{}'::jsonb), sk.category, sk.unlock_rank, sk.slot, sk.requires);$a$,
      $a$     and public.world_skill_line_ok(sk.category, sk.requires, c.job_key)
     and public.world_skill_has(c.skill_progress, coalesce(pk.picks, '{}'::jsonb), sk.category, sk.unlock_rank, sk.slot, sk.requires);$a$);
  end if;
  d := pg_temp.fdef('world_skill_pending');
  if position('world_job_line' in d) = 0 then
    execute pg_temp.rep(d, $a$where s.slot = 'a' and s.category <> 'combo'$a$,
      $a$where s.slot = 'a' and s.category <> 'combo'
       and (s.category not in ('melee', 'ranged', 'sealing', 'dagger', 'exorcism', 'medicine') or s.category = public.world_job_line((select x.job_key from public.world_characters x where x.owner_id = uid)))$a$);
  end if;
  -- 지난 직업의 전투 계열 택일은 고를 수 없다(효과가 없으므로 전만 날리지 않게)
  d := pg_temp.fdef('world_skill_choose');
  if position('world_skill_line_ok' in d) = 0 then
    execute pg_temp.rep(d, $a$  if coalesce((c.skill_progress -> p_line ->> 'rank')::int, 1) < p_tier then$a$,
      $a$  if not public.world_skill_line_ok(p_line, null, c.job_key) then raise exception '지금 직업의 전투 계열이 아니라 고를 수 없습니다.'; end if;
  if coalesce((c.skill_progress -> p_line ->> 'rank')::int, 1) < p_tier then$a$);
  end if;
  -- 봉인술 3단계 「부적 정련」의 봉인 공예 품질 +5는 봉인술사에게만
  d := pg_temp.fdef('world_craft_item');
  if position($a$c.job_key = 'sealmaster' and coalesce((c.skill_progress -> 'sealing'$a$ in d) = 0 then
    execute pg_temp.rep(d, $a$when line = 'wardcraft' and coalesce((c.skill_progress -> 'sealing' ->> 'rank')::int, 0) >= 3$a$,
      $a$when line = 'wardcraft' and c.job_key = 'sealmaster' and coalesce((c.skill_progress -> 'sealing' ->> 'rank')::int, 0) >= 3$a$);
  end if;
  -- 환골탈태 서첩: 레벨·기술 단계는 그대로, 직업·소속을 다시 고르고 능력치를 처음으로(대세력·평판은 그대로 — 세력 비고에서 공훈으로 산다)
  d := pg_temp.fdef('world_reset_identity');
  if position('major_faction_id = null' in d) > 0 then
    execute pg_temp.rep(d, 'major_faction_id = null, faction_reputation = 0,', '');
  end if;
end $p$;
update public.world_item_catalog
   set description = '직업과 소속을 다시 고릅니다. 레벨·기술 단계·대세력·물품·전·칭호는 그대로이고, 능력치는 새 직업의 기본값으로 돌아가 쓴 포인트를 모두 돌려받습니다. 지난 직업의 전투 계열 기술은 효과가 없어집니다. 귀속 물품이라 거래·판매할 수 없습니다(창고에는 맡길 수 있습니다).'
 where item_id = 'reset_identity';
-- 세력 비고: 2등급부터 공훈 300(세력 장비와 같은 값)
insert into public.world_faction_vault(faction_id, item_id, rank_need, price, sort, kind)
select distinct faction_id, 'reset_identity', 2, 300, 26, 'item' from public.world_faction_vault
on conflict (faction_id, item_id) do update set rank_need = excluded.rank_need, price = excluded.price, sort = excluded.sort, kind = excluded.kind;

-- ── 5. 칭호: 계열마다 「…의 길」과 숨김 칭호 ──────────────────────────
update public.world_title_catalog set rule = '{"n": 50, "p": {"line": "melee"}, "ev": "combat"}', condition_text = '근접 계열(호위 무사)로 50마리 토벌' where title_key = 'blade_path';
update public.world_title_catalog set rule = '{"n": 50, "p": {"line": "ranged"}, "ev": "combat"}', condition_text = '사격 계열(현장 조사원)로 50마리 토벌' where title_key = 'bow_path';
update public.world_title_catalog set rule = '{"n": 50, "p": {"line": "sealing"}, "ev": "combat"}', condition_text = '봉인술 계열(봉인술사)로 50마리 토벌', description = '부적과 방울로 요기를 묶는다.' where title_key = 'seal_path';
update public.world_title_catalog set rule = '{"n": 10, "p": {"line": "ranged", "env_weather": "wind"}, "ev": "combat"}', condition_text = '삭풍 속에서 사격 계열로 10마리 토벌' where title_key = 'wind_archer';
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, hidden, rule, sort, category, grade) values
 ('dagger_path', '비수의 길', 'sword', '짧은 날 하나로 급소를 찾는다.', '단도 계열(백공 기술관)로 50마리 토벌', '{"melee_pct": 2, "crit_pct": 1}', false, '{"n": 50, "p": {"line": "dagger"}, "ev": "combat"}', 20, '전투', 2),
 ('exorcism_path', '퇴마의 길', 'sword', '진언 한 줄에 요기가 흩어진다.', '퇴마술 계열(퇴마관)로 50마리 토벌', '{"magic_pct": 2, "mental_loss_pct": -3}', false, '{"n": 50, "p": {"line": "exorcism"}, "ev": "combat"}', 20, '전투', 2),
 ('medicine_path', '의술의 길', 'sword', '침과 약으로 싸우고, 침과 약으로 살린다.', '의술 계열(의무관)로 50마리 토벌', '{"magic_pct": 1, "healing_pct": 3}', false, '{"n": 50, "p": {"line": "medicine"}, "ev": "combat"}', 20, '전투', 2),
 ('dark_dagger', '그믐밤 비수', 'moon', '달 없는 밤, 날은 소리 없이 지나간다.', '삼경에 단도 계열로 10마리 토벌', '{"crit_pct": 2, "melee_pct": 3}', true, '{"n": 10, "p": {"line": "dagger"}, "ev": "combat", "phase": "night"}', 61, '비밀', 3),
 ('mist_exorcist', '안개 속 퇴마사', 'moon', '보이지 않는 것을 진언으로 짚는다.', '농무 속에서 퇴마술 계열로 10마리 토벌', '{"magic_pct": 3, "mental_loss_pct": -3}', true, '{"n": 10, "p": {"line": "exorcism", "env_weather": "fog"}, "ev": "combat"}', 61, '비밀', 3),
 ('rain_healer', '빗속의 의원', 'moon', '빗소리 속에서도 맥은 흔들리지 않는다.', '장우 속에서 의술 계열로 10마리 토벌', '{"magic_pct": 2, "healing_pct": 3}', true, '{"n": 10, "p": {"line": "medicine", "env_weather": "rain"}, "ev": "combat"}', 61, '비밀', 3)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text,
  bonus = excluded.bonus, hidden = excluded.hidden, rule = excluded.rule, category = excluded.category, grade = excluded.grade;

-- ── 6. 가방·창고 기본 10칸씩 더(직업을 바꿔 키우면 직업 전용 무기·장비를 여러 벌 챙기므로) ─────
-- 가방 기본 24 → 34(새 캐릭터 기본값, 롤백 뒤 모두 새로 만든다), 창고 기본 60 → 70(최대 98 → 108)
alter table public.world_characters alter column bag_capacity set default 34;
do $p$
declare d text;
begin
  d := pg_temp.fdef('world_storage_capacity');
  if position($a$'base', 70$a$ in d) = 0 then
    d := pg_temp.rep(d, $a$'base', 60$a$, $a$'base', 70$a$);
    d := pg_temp.rep(d, $a$'total', 60 + $a$, $a$'total', 70 + $a$);
    execute d;
  end if;
end $p$;

-- 확인: 모든 무기에 직업 태그, 새 계열 18개씩
do $c$
begin
  if exists (select 1 from public.world_item_catalog where category = 'weapon' and jsonb_typeof(equipment_traits -> 'jobs') is distinct from 'array') then raise exception '7.7.7p: 직업 태그 없는 무기'; end if;
  if (select count(*) from public.world_skill_catalog where category in ('dagger', 'exorcism', 'medicine')) <> 54 then raise exception '7.7.7p: 새 계열 기술 수'; end if;
  if exists (select 1 from public.world_skill_catalog s where s.proc_as is not null and not exists (select 1 from public.world_skill_catalog o where o.skill_id = s.proc_as)) then raise exception '7.7.7p: proc_as 대상 없음'; end if;
end $c$;

update public.world_app_meta set value = '20261104204300' where key = 'db_version';
