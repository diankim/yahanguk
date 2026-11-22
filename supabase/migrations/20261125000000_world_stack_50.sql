lock table public.world_item_catalog in share row exclusive mode;

create or replace function public.world_normalize_item_rarity()
 returns trigger
 language plpgsql
 set search_path to 'public'
as $function$
begin
 new.tier:=least(8,greatest(1,coalesce(new.tier,1)));
 new.rarity:=case new.tier when 1 then 'common' when 2 then 'uncommon' when 3 then 'rare' when 4 then 'epic' else 'legendary' end;
 new.acquisition_difficulty:=least(5,new.tier);
 new.drop_rate_modifier:=case new.tier when 1 then 1.0 when 2 then 0.72 when 3 then 0.42 when 4 then 0.20 when 5 then 0.08 when 6 then 0.05 when 7 then 0.03 else 0.02 end;
 new.stack_size:=case when new.stack_size in (20, 25, 40) then 50 else new.stack_size end;
 return new;
end $function$;

update public.world_item_catalog
   set stack_size = 50
 where stack_size in (20, 25, 40);

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261125000000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
