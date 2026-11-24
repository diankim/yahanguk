do $$
declare r jsonb := public.world_boss_rules();
begin
  r := jsonb_set(r, '{mukjeok,ultimate,hp_atk}', '14.7'::jsonb);
  r := jsonb_set(r, '{mukjeok,ultimate,hp_min}', '16800'::jsonb);
  r := jsonb_set(r, '{gapgwi,ultimate,hp_atk}', '17.5'::jsonb);
  r := jsonb_set(r, '{gapgwi,ultimate,hp_min}', '12600'::jsonb);
  r := jsonb_set(r, '{baekya,ultimate,hp_atk}', '8.4'::jsonb);
  r := jsonb_set(r, '{baekya,ultimate,hp_min}', '12600'::jsonb);
  execute format('create or replace function public.world_boss_rules() returns jsonb language sql immutable set search_path = '''' as $f$ select %L::jsonb $f$', r);
end $$;

update public.world_patch_notes set body = replace(body, '[무용담] 무용담 · 귀허의 주인의 구중 봉주·귀허의 주인 체력을 늘렸습니다.', '[무용담] 무용담 세 판(귀허의 주인·먹그림자·값귀)의 우두머리 체력을 늘렸습니다.')
where note_id = '3.8.0' and position('[무용담] 무용담 · 귀허의 주인의 구중 봉주' in body) > 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127120000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
