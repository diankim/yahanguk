do $w$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_notify_downed()'::regprocedure), E'\r\n', E'\n');
  if position('''rescued''' in d) > 0 then return; end if;
  a := $a$'. 구조하러 가지 않아도 됩니다.');$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.4h world_notify_downed 기준 문구가 없습니다'; end if;
  execute replace(d, a, a || $b$
  if coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), new.owner_id::text) <> new.owner_id::text then
   insert into public.world_notifications(user_id,kind,title,content,payload) values(new.owner_id,'rescued','다시 일어났습니다',
     coalesce((select character_name||' 조사원이' from public.world_characters where owner_id::text = current_setting('request.jwt.claim.sub', true)), '누군가')||' 일으켜 주었습니다. 체력 '||new.health||'(으)로 돌아왔습니다.',jsonb_build_object('health',new.health,'location',new.location));
  end if;$b$);
end $w$;

create or replace function public.world_fish_gap(p uuid) returns int
language sql stable as $f$
  select case when 'fishing_c24a' = any (public.world_skill_procs(p)) then 15 else 20 end
$f$;
revoke all on function public.world_fish_gap(uuid) from public, anon, authenticated;
grant execute on function public.world_fish_gap(uuid) to fn_owner_field;

do $w$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_fish()'::regprocedure), E'\r\n', E'\n');
  if position('world_fish_gap' in d) = 0 then
    a := $a$  if 'fishing_c24a' = any (sk) then gap := 15; end if; -- 재빠른 챔질$a$;
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.4h world_fish 기준 문구가 없습니다'; end if;
    execute replace(d, a, '  gap := public.world_fish_gap(uid);');
  end if;
  d := replace(pg_get_functiondef('public.world_fish_spot()'::regprocedure), E'\r\n', E'\n');
  if position('world_fish_gap' in d) = 0 then
    a := $a$interval '20 seconds'$a$;
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 2 then raise exception '1.0.4h world_fish_spot 기준 문구가 없습니다'; end if;
    d := replace(d, a, 'make_interval(secs => gp)');
    a := '  last timestamptz; rod int;';
    if position(a in d) = 0 then raise exception '1.0.4h world_fish_spot 선언 문구가 없습니다'; end if;
    d := replace(d, a, a || ' gp int := public.world_fish_gap(public.fn_owner_auth_uid());');
    a := $a$'rod', rod, $a$;
    if position(a in d) = 0 then raise exception '1.0.4h world_fish_spot rod 문구가 없습니다'; end if;
    execute replace(d, a, a || $b$'gap', gp, $b$);
  end if;
end $w$;

create or replace function public.world_title_preset_save(p_slot integer, p_name text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); nm text := left(btrim(coalesce(p_name, '')), 12); t text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_slot < 1 or p_slot > public.world_title_preset_slots(uid) then raise exception '아직 열리지 않은 묶음 칸입니다.'; end if;
  if nm = '' then nm := '묶음 ' || p_slot; end if;
  perform 1 from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select coalesce(array_agg(title_key order by earned_at, title_key), '{}') into t from public.world_character_titles where owner_id = uid and is_equipped;
  if cardinality(t) = 0 then raise exception '장착한 칭호가 있어야 저장할 수 있습니다.'; end if;
  insert into public.world_title_presets(owner_id, slot, name, titles, display) values (uid, p_slot, nm, t, null)
  on conflict (owner_id, slot) do update set name = excluded.name, titles = excluded.titles, display = null, updated_at = now();
  return jsonb_build_object('ok', true, 'content', '「' || nm || '」에 지금 장착한 칭호를 저장했습니다.');
end $function$;

create or replace function public.world_title_preset_apply(p_slot integer)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); pr public.world_title_presets%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform 1 from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select * into pr from public.world_title_presets where owner_id = uid and slot = p_slot;
  if not found then raise exception '저장된 묶음이 없습니다.'; end if;
  update public.world_character_titles set is_equipped = (title_key = any (pr.titles[1:3])) where owner_id = uid and (is_equipped or title_key = any (pr.titles[1:3]));
  return jsonb_build_object('ok', true, 'content', '「' || pr.name || '」 묶음으로 바꿨습니다. 대표 칭호는 그대로입니다.');
end $function$;

create or replace function public.world_gwiryeong_rules() returns jsonb language sql immutable as $f$
  select jsonb_build_object('hold', 1, 'cooldown_h', 72, 'window_days', 3, 'cap_div', 2, 'yohwa_mul', 3, 'party_mul', 2)
$f$;
revoke all on function public.world_gwiryeong_rules() from public, anon, authenticated;
grant execute on function public.world_gwiryeong_rules() to fn_owner_field;

create or replace function public.world_gwiryeong_reserve(p_uid uuid, p_source text)
 returns boolean language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare cap int; ru jsonb := public.world_gwiryeong_rules(); win interval;
begin
  if p_uid is null then return false; end if;
  win := make_interval(days => (ru ->> 'window_days')::int);
  if exists (select 1 from public.world_gwiryeong_log l where l.owner_id = p_uid and l.got_at > now() - make_interval(hours => (ru ->> 'cooldown_h')::int)) then return false; end if;
  if coalesce((select (c.inventory ->> 'gwiryeong_cho')::int from public.world_characters c where c.owner_id = p_uid), 0)
     + coalesce((select (s.items ->> 'gwiryeong_cho')::int from public.world_storage s where s.owner_id = p_uid), 0) >= (ru ->> 'hold')::int then return false; end if;
  perform pg_advisory_xact_lock(hashtext('yh-gwiryeong-week'));
  cap := greatest(1, (select count(*) from public.world_yohwa_log y where y.kind = 'onset' and y.at > now() - win)::int / (ru ->> 'cap_div')::int);
  if (select count(*) from public.world_gwiryeong_log l where l.got_at > now() - win) >= cap then return false; end if;
  insert into public.world_gwiryeong_log(owner_id, source) values (p_uid, p_source);
  return true;
end $function$;

create or replace function public.world_gwiryeong_mul(p_uid uuid) returns numeric
 language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
declare ru jsonb := public.world_gwiryeong_rules();
begin
  if exists (select 1 from public.world_character_statuses s where s.owner_id = p_uid and s.status_key = 'yohwa') then return (ru ->> 'yohwa_mul')::numeric; end if;
  if exists (select 1 from public.world_party_members a join public.world_party_members b on b.party_id = a.party_id and b.owner_id <> a.owner_id
               join public.world_character_statuses s on s.owner_id = b.owner_id and s.status_key = 'yohwa' where a.owner_id = p_uid) then return (ru ->> 'party_mul')::numeric; end if;
  return 1;
end $function$;
revoke all on function public.world_gwiryeong_mul(uuid) from public, anon, authenticated;
grant execute on function public.world_gwiryeong_mul(uuid) to fn_owner_field;

do $w$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_gwiryeong_give(uuid, numeric, text)'::regprocedure), E'\r\n', E'\n');
  if position('world_gwiryeong_mul' in d) > 0 then return; end if;
  a := 'random() >= p_chance then return false; end if;';
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.4h world_gwiryeong_give 기준 문구가 없습니다'; end if;
  execute replace(d, a, 'random() >= least(0.05, p_chance * public.world_gwiryeong_mul(p_uid)) then return false; end if;');
end $w$;

update public.world_app_meta set value = '20261106000000' where key = 'db_version';
