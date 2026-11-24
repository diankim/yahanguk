do $$
declare r jsonb := public.world_boss_rules();
begin
  r := jsonb_set(r, '{sealed_lord,ultimate,hp_atk}', '17.4'::jsonb);
  r := jsonb_set(r, '{sealed_lord,ultimate,hp_min}', '12600'::jsonb);
  r := jsonb_set(r, '{gwiheo,ultimate,hp_atk}', '9.5'::jsonb);
  r := jsonb_set(r, '{gwiheo,ultimate,hp_min}', '12600'::jsonb);
  execute format('create or replace function public.world_boss_rules() returns jsonb language sql immutable set search_path = '''' as $f$ select %L::jsonb $f$', r);
end $$;

update public.world_patch_notes set body = body || E'\n- [무용담] 무용담 · 귀허의 주인의 구중 봉주·귀허의 주인 체력을 늘렸습니다. 실제 공격이 예상보다 빨리 들어가 전멸기가 너무 일찍 찾아오던 것을 맞췄습니다.\n- [싸움 화면] 파티 토벌·그림자 토벌·귀허류 싸움에서도 방어·버티기를 하면 먹 방패가, 체력을 회복하면 그 사람 칸에 「+」가 떠오릅니다.'
where note_id = '3.8.0' and position('[무용담] 무용담 · 귀허의 주인의 구중 봉주' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127110000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
