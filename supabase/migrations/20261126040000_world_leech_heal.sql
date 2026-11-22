do $m$
declare src text; def text; fn regprocedure; o text; n text;
begin
  fn := 'public.world_raid_action'::regproc::regprocedure;
  select prosrc into src from pg_proc where oid = fn;
  o := 'h0 int; h1 int; amt int;';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_action 선언 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, 'h0 int; h1 int; amt int; v_lh int := 0;');
  o := '  update public.world_characters set spiritual_power = sp, inventory = inv,' || chr(10) || '    health = case when health > 0 then least(100, health + coalesce(nullif(current_setting(''yh.leech'', true), '''')::int, 0)) else health end, updated_at = now() where owner_id = uid;';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_action 피흡 자리 모양이 예상과 다릅니다'; end if;
  n := '  v_lh := coalesce(nullif(current_setting(''yh.leech'', true), '''')::int, 0);' || chr(10) ||
       '  if v_lh > 0 then select greatest(0, least(100 - x.health, v_lh)) into v_lh from public.world_characters x where x.owner_id = uid and x.health > 0; v_lh := coalesce(v_lh, 0); end if;' || chr(10) ||
       o || chr(10) ||
       '  if v_lh > 0 then mb.heal := mb.heal + v_lh; perform public.world_raid_credit(p_raid, uid, v_lh, ''heal_self''); end if;';
  src := replace(src, o, n);
  def := regexp_replace(pg_get_functiondef(fn), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';

  fn := 'public.world_gw_resolve'::regproc::regprocedure;
  select prosrc into src from pg_proc where oid = fn;
  o := 'declare cbr jsonb;';
  if position(o in src) = 0 then raise exception 'world_gw_resolve 선언 모양이 예상과 다릅니다'; end if;
  src := regexp_replace(src, '^(\s*)declare cbr jsonb;', E'\\1declare v_lh int; cbr jsonb;');
  o := 'update public.world_gw_members set hp = least(100, hp + public.world_leech_of(m.owner_id, d)) where fight_id = p_fight and owner_id = m.owner_id and out_rounds = 0 and hp > 0;';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_gw_resolve 피흡 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o,
    'v_lh := null; select greatest(0, least(100 - x.hp, public.world_leech_of(m.owner_id, d))) into v_lh from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = m.owner_id and x.out_rounds = 0 and x.hp > 0;' || chr(10) ||
    '          if coalesce(v_lh, 0) > 0 then update public.world_gw_members set hp = hp + v_lh, heal = heal + v_lh where fight_id = p_fight and owner_id = m.owner_id; perform public.world_gw_credit(p_fight, m.owner_id, v_lh, ''heal_self''); end if;');
  def := regexp_replace(pg_get_functiondef(fn), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';
end $m$;

update public.world_patch_notes set body = body || E'\n- 피해 기록 「회복」 칸에 혈기사가 피를 흡수해 되찾은 체력도 함께 셈해집니다.'
 where note_id = '3.7.0' and body not like '%피를 흡수해 되찾은 체력도%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126040000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
