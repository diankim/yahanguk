create or replace function pg_temp.yh_line(p_q text, p_s int, p_old text, p_new text) returns void language plpgsql as $f$
declare v jsonb; n int;
begin
  select lines into strict v from public.world_quest_steps where quest_id = p_q and step = p_s;
  n := (length(v::text) - length(replace(v::text, p_old, ''))) / length(p_old);
  if n <> 1 then raise exception '대사 %:% 모양이 예상과 다릅니다(「%」 % 곳)', p_q, p_s, p_old, n; end if;
  update public.world_quest_steps set lines = (
    select jsonb_agg(case when e ? 't' then jsonb_set(e, '{t}', to_jsonb(replace(e->>'t', p_old, p_new))) else e end order by o)
    from jsonb_array_elements(lines) with ordinality x(e, o))
  where quest_id = p_q and step = p_s;
end $f$;

do $$
declare n int;
begin
  select count(*) into n from public.world_quest_steps s, jsonb_array_elements(coalesce(s.need->'tasks', '[]')) t
  where t->>'t' = 'win' and t->>'n' = '8';
  if n <> 45 then raise exception '처치 8 할 일 수가 예상과 다릅니다(% 곳)', n; end if;
  update public.world_quest_steps s set need = jsonb_set(s.need, '{tasks}', (
    select jsonb_agg(case when t->>'t' = 'win' and t->>'n' = '8' then jsonb_set(t, '{n}', '6'::jsonb) else t end order by o)
    from jsonb_array_elements(s.need->'tasks') with ordinality x(t, o)))
  where exists (select 1 from jsonb_array_elements(coalesce(s.need->'tasks', '[]')) t where t->>'t' = 'win' and t->>'n' = '8');
end $$;

select pg_temp.yh_line('ep_dd_4', 1, '여덟만 쓰러뜨려', '여섯만 쓰러뜨려');
select pg_temp.yh_line('mde_hanseol', 2, '여덟 다 돌아왔어요', '여섯 다 돌아왔어요');
select pg_temp.yh_line('mds_arrows', 2, '여덟만 떨어뜨립시다', '여섯만 떨어뜨립시다');
select pg_temp.yh_line('mds_dummy', 2, '여덟만 떨어뜨립시다', '여섯만 떨어뜨립시다');
select pg_temp.yh_line('mds_lantern', 1, '여덟만 풀어 보내면', '여섯만 풀어 보내면');
select pg_temp.yh_line('mds_n_gold', 2, '여덟쯤 풀어 보내면', '여섯쯤 풀어 보내면');
select pg_temp.yh_line('mke_hisu_1', 3, '여덟째 먹귀가', '여섯째 먹귀가');
select pg_temp.yh_line('mks_broken_brush', 1, '먹비 넋 여덟만', '먹비 넋 여섯만');
select pg_temp.yh_line('mks_broken_brush', 2, '여덟째 넋도', '여섯째 넋도');
select pg_temp.yh_line('mks_crow_letters', 1, '여덟만 쫓아 주세요', '여섯만 쫓아 주세요');
select pg_temp.yh_line('mks_last_line', 1, '갈피귀 여덟만', '갈피귀 여섯만');
select pg_temp.yh_line('mks_lightning', 1, '한 놈이 여덟 놈으로', '한 놈이 여섯 놈으로');
select pg_temp.yh_line('mks_lightning', 1, '번갯불 여덟만.', '번갯불 여섯만.');
select pg_temp.yh_line('mks_lightning', 1, '나는 여덟을 쫓고', '나는 여섯을 쫓고');
select pg_temp.yh_line('mks_lightning', 1, '일단 여덟부터!', '일단 여섯부터!');
select pg_temp.yh_line('mks_lightning', 2, '번갯불 여덟이', '번갯불 여섯이');
select pg_temp.yh_line('mks_lightning', 2, '나는 여덟부터', '나는 여섯부터');
select pg_temp.yh_line('mks_stone_turtle', 3, '돌거북 여덟을', '돌거북 여섯을');
select pg_temp.yh_line('mks_tab_ledger', 2, '먹귀 여덟을', '먹귀 여섯을');
select pg_temp.yh_line('mks_totem', 2, '여덟 놈만 물리쳐', '여섯 놈만 물리쳐');
select pg_temp.yh_line('rg_yeoseotjjae_1', 1, '손가락 여덟 개를', '손가락 여섯 개를');
select pg_temp.yh_line('rg_yeoseotjjae_1', 1, '여덟 판.', '여섯 판.');
select pg_temp.yh_line('rg_yeoseotjjae_1', 2, '여덟. 여덟 다 이겼다.', '여섯. 여섯 다 이겼다.');
select pg_temp.yh_line('rg_yeoseotjjae_1', 3, '무관 거리 · 여덟 · 여덟 이김', '무관 거리 · 여섯 · 여섯 이김');
select pg_temp.yh_line('rg_yeoseotjjae_1', 3, '여덟 판 다 이긴 값', '여섯 판 다 이긴 값');
select pg_temp.yh_line('rg_yeoseotjjae_5', 1, '무관 거리 · 여덟 · 여덟 이김', '무관 거리 · 여섯 · 여섯 이김');
select pg_temp.yh_line('rg_yeoseotjjae_5', 1, '여덟 판. 첫날처럼.', '여섯 판. 첫날처럼.');
select pg_temp.yh_line('rg_yeoseotjjae_5', 2, '여덟째 놈까지 쓰러뜨리고', '마지막 놈까지 쓰러뜨리고');
select pg_temp.yh_line('rg_yeoseotjjae_5', 2, '여덟. 여덟 이김.', '여섯. 여섯 이김.');
select pg_temp.yh_line('rg_yeoseotjjae_5', 3, '무관 거리, 여덟.', '무관 거리, 여섯.');

do $$ begin
  update public.world_quest_steps set goal = replace(goal, '먹귀를 8번', '먹귀를 6번') where quest_id = 'mkq_2' and step = 2 and goal like '%먹귀를 8번%';
  if not found then raise exception 'mkq_2 목표 모양이 예상과 다릅니다'; end if;
end $$;

select public.world_quest_label_refresh();

update public.world_patch_notes set body = body || E'\n- [퀘스트] 요괴를 8마리 물리치는 할 일을 모두 6마리로 줄이고, 그에 맞춰 묵적록·명등기·연담 일부 대사를 다듬었습니다.'
where note_id = '3.8.0' and position('[퀘스트] 요괴를 8마리 물리치는 할 일을' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127200000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
