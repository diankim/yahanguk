create or replace function public.world_avatar_px_drop(p_grp bigint) returns int
language plpgsql security definer set search_path = '' as $f$
declare n int;
begin
  update public.world_characters c set profile = c.profile - 'avatar' - 'avatar_px', updated_at = now()
    from public.world_avatars a
   where a.owner_id = c.owner_id and coalesce((c.profile ->> 'avatar_px')::boolean, false)
     and exists (select 1 from public.world_outfit_designs d, jsonb_each_text(a.look) k
                  where k.key in ('top_d', 'bottom_d', 'face_d', 'hair_d') and k.value ~ '^[0-9]+$'
                    and d.id = k.value::bigint and coalesce(d.origin, d.id) = p_grp);
  get diagnostics n = row_count;
  return n;
end $f$;
revoke all on function public.world_avatar_px_drop(bigint) from public, anon, authenticated;
grant execute on function public.world_avatar_px_drop(bigint) to fn_owner_field;

select pg_temp.yh_fix('world_outfit_design_remove', array[
  E'  get diagnostics n = row_count;\n  if n > 0 then',
  E'  get diagnostics n = row_count;\n  if n > 0 then\n    perform public.world_avatar_px_drop(p_grp);'
]);
