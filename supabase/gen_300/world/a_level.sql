create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute replace(d, p_old, p_new);
end $$;

create or replace function public.world_level_rules() returns jsonb
language sql immutable as $$ select '{"cap": 50, "per_level": 3, "stat_points_cap": 147}'::jsonb $$;

select pg_temp.yh_patch('public.world_bijang_encounter(uuid,text,integer,text)', 'least(46, greatest(', 'least(public.world_level_cap() + 1, greatest(');

select pg_temp.yh_patch('public.world_normalize_item_rarity()', 'least(7,greatest(1,coalesce(new.tier,1)))', 'least(8,greatest(1,coalesce(new.tier,1)))');
select pg_temp.yh_patch('public.world_normalize_item_rarity()', 'when 6 then 0.05 else 0.03 end', 'when 6 then 0.05 when 7 then 0.03 else 0.02 end');
alter table public.world_item_catalog drop constraint world_item_catalog_tier_check;
alter table public.world_item_catalog add constraint world_item_catalog_tier_check check (tier between 1 and 8);
