alter table public.world_item_catalog drop constraint world_item_catalog_tier_check;
alter table public.world_item_catalog add constraint world_item_catalog_tier_check check (tier >= 1 and tier <= 9);
create or replace function public.world_normalize_item_rarity()
 returns trigger language plpgsql set search_path to 'public'
as $function$
begin
 new.tier:=least(9,greatest(1,coalesce(new.tier,1)));
 new.rarity:=case new.tier when 1 then 'common' when 2 then 'uncommon' when 3 then 'rare' when 4 then 'epic' else 'legendary' end;
 new.acquisition_difficulty:=least(5,new.tier);
 new.drop_rate_modifier:=case new.tier when 1 then 1.0 when 2 then 0.72 when 3 then 0.42 when 4 then 0.20 when 5 then 0.08 when 6 then 0.05 when 7 then 0.03 when 8 then 0.02 else 0.015 end;
 new.stack_size:=case when new.stack_size in (20, 25, 40) then 50 else new.stack_size end;
 return new;
end $function$;
create or replace function public.world_weapon_rank_rules()
 returns jsonb language sql immutable set search_path to 'pg_catalog', 'public'
as $function$ select '{"steps":[[1,1],[10,5],[14,10],[20,15],[32,25],[42,33],[47,38],[53,44]]}'::jsonb $function$;
