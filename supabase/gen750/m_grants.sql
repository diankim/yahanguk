
-- ── 새 도우미 권한: 조사원이 직접 부를 필요는 없다. 값만 셈하는 순수 함수 셋은 부른 쪽 권한 함수에서도 쓰이게 authenticated에 남긴다 ──
do $g$
declare f text; r text;
begin
  foreach f in array array['public.world_craft_line(text)', 'public.world_line_base(jsonb,text,text)', 'public.world_gear_line(text)',
                           'public.world_item_hq_traits(jsonb)', 'public.world_item_hq_note(text,text)', 'public.world_item_hq_sync()',
                           'public.world_item_base(text)', 'public.world_craft_line_of(text)', 'public.world_line_name(text)', 'public.world_skill_name(text)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to postgres, service_role', f);
    for r in select rolname from pg_roles where rolname like 'fn_owner%' loop
      execute format('grant execute on function %s to %I', f, r);
    end loop;
  end loop;
  foreach f in array array['public.world_item_base(text)', 'public.world_craft_line_of(text)', 'public.world_line_name(text)'] loop
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $g$;
