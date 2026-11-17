do $d$
declare j jsonb := public.world_project_rules();
begin
  j := jsonb_set(j, '{projects,f:night_office,hubs}', '["lantern_market"]'::jsonb);
  j := jsonb_set(j, '{projects,f:night_office,shops}', to_jsonb(array(select r.shop_id from public.world_map_regions r where r.region_id = 'lantern_market' and r.shop_id is not null)));
  j := jsonb_set(j, '{projects,f:mandate_court,hubs}', '["star_observatory"]'::jsonb);
  execute format('create or replace function public.world_project_rules() returns jsonb language sql immutable set search_path = '''' as %L', format('select %L::jsonb', j::text));
end $d$;

update public.world_patch_notes set body = body || $N$
- 정통파 거점 사업 「청사 다시 세우기」는 백등 야시장에서, 천명원 거점 사업 「관성대 별 기록 잇기」는 무극 관성대에서만 넘깁니다. 본부 정청·본부 객사는 모두가 함께 쓰는 곳이라 거점 사업을 두지 않습니다.$N$
 where note_id = '3.0.0' and position('청사 다시 세우기」는 백등 야시장' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261119060000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
