create or replace function pg_temp.yh_sub(p_name text, p_old text, p_new text, p_n int) returns void language plpgsql as $f$
declare d text; n int;
begin
  select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name;
  n := (length(d) - length(replace(d, p_old, ''))) / length(p_old);
  if n <> p_n then raise exception '함수 % 모양이 예상과 다릅니다(「%」 % 곳, 예상 %)', p_name, p_old, n, p_n; end if;
  execute replace(d, p_old, p_new);
end $f$;

select pg_temp.yh_sub('world_battle_action', '나쁜 상태 하나를', '흉한 상태 하나를', 3);
select pg_temp.yh_sub('world_feast_tick', '(이로운 상태는 상태 창에서 끌 수 있습니다)', '(길한 상태는 상태 창에서 끌 수 있습니다)', 1);
select pg_temp.yh_sub('world_field_rest', '나쁜 상태 ', '흉한 상태 ', 1);
select pg_temp.yh_sub('world_gimmick_tip', '''상태이상을 노리는 공격입니다.''', '''흉한 상태를 거는 공격입니다.''', 1);
select pg_temp.yh_sub('world_job_skill_rules', '나쁜 상태 하나를', '흉한 상태 하나를', 1);
select pg_temp.yh_sub('world_status_dismiss', '''이로운 상태만 끌 수 있습니다.''', '''길한 상태만 끌 수 있습니다.''', 1);
select pg_temp.yh_sub('world_survival_action', '부적으로 풀 상태이상이 없습니다', '부적으로 풀 흉한 상태가 없습니다', 1);
select pg_temp.yh_sub('world_survival_action', ''' 상태이상 ''||cl||''개가 풀렸다.''', ''' 흉한 상태 ''||cl||''개가 풀렸다.''', 1);

update public.world_status_catalog set cure = replace(cure, '이로운 효과입니다.', '길한 상태입니다.') where cure like '%이로운 효과입니다.%';
update public.world_item_catalog set description = replace(description, '이로운 상태', '길한 상태') where description like '%이로운 상태%';
update public.world_skill_catalog set description = replace(replace(replace(description, '이로운 상태', '길한 상태'), '나쁜 상태', '흉한 상태'), '어떤 상태이상도', '어떤 흉한 상태도')
 where description ~ '(이로운 상태|나쁜 상태|상태이상)';

update public.world_patch_notes set body = replace(body, E'하나하나 읽고 답합니다.\n', E'하나하나 읽고 답합니다.\n· **정기 점검과 제보 확인** — 매일 **오전 9시 30분**과 **오후 9시 30분**(한국 시각)에 정기 점검을 하고, 그사이 들어온 제보·소감도 그때 함께 모아 확인합니다. 정기 점검 사이에도 틈틈이 점검하고 고친 것을 반영하고 있습니다. 답이 조금 늦더라도 놓친 것은 아니니, 이 일정을 참고해 주세요.\n')
where note_id = '0.0.0' and position('정기 점검과 제보 확인' in body) = 0 and position(E'하나하나 읽고 답합니다.\n' in body) > 0;

update public.world_patch_notes set body = body || E'\n- [상태] 「이로운 상태 / 나쁜 상태(상태이상)」를 「길한 상태 / 흉한 상태」로 이름을 맞췄습니다.'
where note_id = '3.8.0' and position('[상태] 「이로운 상태' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261128040000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
