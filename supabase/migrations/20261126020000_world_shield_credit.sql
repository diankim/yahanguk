do $m$
declare src text; o text; def text;
begin
  select prosrc into src from pg_proc where oid = 'public.world_cb_mitigate(numeric, jsonb, jsonb, uuid, boolean, boolean, text, boolean)'::regprocedure;
  o := 'if vby is not null and vby <> p_self::text then cr := cr || jsonb_build_array(jsonb_build_array(vby, ab, ''guard'')); end if;';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_cb_mitigate 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, 'if vby is not null and vby <> p_self::text then cr := cr || jsonb_build_array(jsonb_build_array(vby, ab, ''guard''), jsonb_build_array(vby, ab, ''shield'')); end if;');
  def := regexp_replace(pg_get_functiondef('public.world_cb_mitigate(numeric, jsonb, jsonb, uuid, boolean, boolean, text, boolean)'::regprocedure), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';
end $m$;

update public.world_patch_notes set body = body || E'\n- 봉연의 그림자·귀허류 싸움의 피해 기록 「회복」 칸에 동료에게 씌운 보호막이 막아 낸 피해가 함께 셈해지고, 막대와 숫자는 회복과 나눠 다른 색으로 보입니다.\n- 싸움 화면 참가자 칸과 피해 기록에 조련사·혈기사·여명 창객·진법가의 직업 색이 붙습니다.'
 where note_id = '3.7.0' and body not like '%동료에게 씌운 보호막이 막아 낸 피해가 함께%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126020000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
