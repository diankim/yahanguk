do $$
declare r jsonb := public.world_boss_rules();
begin
  r := jsonb_set(r, '{sealed_lord,ultimate,hp_atk}', '24.8'::jsonb);
  r := jsonb_set(r, '{sealed_lord,ultimate,hp_min}', '18000'::jsonb);
  r := jsonb_set(r, '{gwiheo,ultimate,hp_atk}', '16.3'::jsonb);
  r := jsonb_set(r, '{gwiheo,ultimate,hp_min}', '21600'::jsonb);
  r := jsonb_set(r, '{gwiheo,ultimate,hp_n}', '[1, 0.65, 0.8, 0.88]'::jsonb);
  r := jsonb_set(r, '{gwiheo,ultimate,hex,charge,pct}', '17.5'::jsonb);
  r := jsonb_set(r, '{gwiheo,ultimate,acts}', '[{"boss": "sealed_lord", "cuts": [14, 26, 35], "name": "구중 봉주", "rounds": 48}, {"boss": "gwiheo", "cuts": [23, 39, 54], "name": "귀허의 주인", "rounds": 68}]'::jsonb);
  r := jsonb_set(r, '{mukjeok,ultimate,hp_atk}', '25.2'::jsonb);
  r := jsonb_set(r, '{mukjeok,ultimate,hp_min}', '28800'::jsonb);
  r := jsonb_set(r, '{mukjeok,ultimate,acts}', '[{"boss": "mukjeok", "cuts": [15, 30, 45], "name": "먹그림자", "rounds": 63}]'::jsonb);
  r := jsonb_set(r, '{gapgwi,ultimate,hp_atk}', '30'::jsonb);
  r := jsonb_set(r, '{gapgwi,ultimate,hp_min}', '21600'::jsonb);
  r := jsonb_set(r, '{baekya,ultimate,hp_atk}', '14.4'::jsonb);
  r := jsonb_set(r, '{baekya,ultimate,hp_min}', '21600'::jsonb);
  r := jsonb_set(r, '{gapgwi,ultimate,acts}', '[{"boss": "gapgwi", "cuts": [20, 36, 48], "name": "값귀", "rounds": 59}, {"boss": "baekya", "cuts": [18, 35, 50], "name": "백야", "rounds": 71}]'::jsonb);
  execute format('create or replace function public.world_boss_rules() returns jsonb language sql immutable set search_path = '''' as $f$ select %L::jsonb $f$', r);
end $$;

update public.world_patch_notes set body = replace(body, '[무용담] 무용담 세 판(귀허의 주인·먹그림자·값귀)의 우두머리 체력을 늘렸습니다. 실제 공격이 예상보다 빨리 들어가 전멸기가 너무 일찍 찾아오던 것을 맞췄습니다.', '[무용담] 무용담 세 판(귀허의 주인·먹그림자·값귀)의 우두머리 체력을 크게 늘리고, 막마다 라운드 제한과 체력 기한도 그만큼 늘렸습니다. 실제 공격이 예상보다 빨리 들어가 전멸기가 너무 일찍 찾아오던 것을 맞췄습니다.')
where note_id = '3.8.0' and position('라운드 제한과 체력 기한도' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127130000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
