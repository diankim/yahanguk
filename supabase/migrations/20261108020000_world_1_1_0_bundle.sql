create or replace function public.world_chat_mark(p_uid uuid)
returns text language sql stable security definer set search_path to '' as $f$
  select case when p_uid is not null and public.world_yohwa_public(p_uid) = 'frenzy' then 'frenzy' end
$f$;
revoke all on function public.world_chat_mark(uuid) from public, anon, authenticated;
grant execute on function public.world_chat_mark(uuid) to fn_owner_field, service_role;

alter table public.world_party_messages add column if not exists sender_mark text;

do $w$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_chat_stamp_title()'::regprocedure), E'\r\n', E'\n');
  a := $a$new.sender_mark := case when new.sender_id is not null and public.world_yohwa_public(new.sender_id) = 'frenzy' then 'frenzy' end;$a$;
  if position(a in d) > 0 then execute replace(d, a, 'new.sender_mark := public.world_chat_mark(new.sender_id);');
  elsif position('world_chat_mark' in d) = 0 then raise exception '1.1.0 world_chat_stamp_title 기준 문구가 없습니다'; end if;

  d := replace(pg_get_functiondef('public.world_circle_send(uuid, text)'::regprocedure), E'\r\n', E'\n');
  a := $a$case when public.world_yohwa_public(uid) = 'frenzy' then 'frenzy' end$a$;
  if position(a in d) > 0 then execute replace(d, a, 'public.world_chat_mark(uid)');
  elsif position('world_chat_mark' in d) = 0 then raise exception '1.1.0 world_circle_send 기준 문구가 없습니다'; end if;

  d := replace(pg_get_functiondef('public.world_party_chat_send(text)'::regprocedure), E'\r\n', E'\n');
  a := $a$insert into public.world_party_messages(party_id,sender_id,content) values(pid,uid,msg)$a$;
  if position(a in d) > 0 then execute replace(d, a, 'insert into public.world_party_messages(party_id,sender_id,content,sender_mark) values(pid,uid,msg,public.world_chat_mark(uid))');
  elsif position('world_chat_mark' in d) = 0 then raise exception '1.1.0 world_party_chat_send 기준 문구가 없습니다'; end if;

  d := replace(pg_get_functiondef('public.world_party_chat_snapshot()'::regprocedure), E'\r\n', E'\n');
  a := $a$'content',m.content,'created_at',m.created_at)$a$;
  if position(a in d) > 0 then execute replace(d, a, $x$'content',m.content,'sender_mark',m.sender_mark,'created_at',m.created_at)$x$);
  elsif position('sender_mark' in d) = 0 then raise exception '1.1.0 world_party_chat_snapshot 기준 문구가 없습니다'; end if;
end $w$;

create or replace function public.world_job_skill_rules()
returns jsonb language sql immutable set search_path to '' as $f$
  select jsonb_build_object(
    'artificer', jsonb_build_object('name', '파갑참', 'desc', '근접으로 방어·껍질·결계를 무시하고 1.7배 피해를 줍니다.', 'duel', jsonb_build_object('kind', 'pierce', 'mul', 1.7), 'line', '{me}의 「파갑참」!'),
    'scout', jsonb_build_object('name', '급소 사격', 'desc', '원거리 ×1.4로 쏘고 표식을 남겨 다음 세 번의 공격이 25%씩 강해집니다.', 'duel', jsonb_build_object('kind', 'crit', 'mul', 1), 'line', '{me}의 「급소 사격」!'),
    'exorcist', jsonb_build_object('name', '퇴마진', 'desc', '반드시 치명타로 꽂히는 술법 한 방(×1.4)으로 결계를 깨뜨립니다.', 'duel', jsonb_build_object('kind', 'burst', 'mul', 2.0), 'line', '{me}의 「퇴마진」!'),
    'medic', jsonb_build_object('name', '응급 처방', 'desc', '체력을 회복하고 나쁜 상태 하나를 걷어냅니다. 한 전투에 한 번.', 'duel', jsonb_build_object('kind', 'heal', 'heal', 0.25), 'line', '{me}의 「응급 처방」: 기세 {n} 회복'),
    'sealmaster', jsonb_build_object('name', '봉인술', 'desc', '피해를 주고 요괴의 다음 행동을 묶습니다. 우두머리는 절반 확률.', 'duel', jsonb_build_object('kind', 'bind', 'mul', 1.1), 'line', '{me}의 「봉인술」: {them}을(를) 묶었다.'),
    'analyst', jsonb_build_object('name', '약점 간파', 'desc', '다음 세 번의 공격이 40% 강해지고 치명타가 잘 납니다.', 'duel', jsonb_build_object('kind', 'focus', 'n', 3, 'mul', 1.4), 'line', '{me}의 「약점 간파」: 상대의 빈틈을 읽었다.'))
$f$;
revoke all on function public.world_job_skill_rules() from public, anon, authenticated;
grant execute on function public.world_job_skill_rules() to fn_owner_field, service_role;

do $w$
declare d text; a text; o text; own text;
begin
  select pg_get_userbyid(proowner) into own from pg_proc where oid = 'public.world_tourney_duel'::regproc;
  execute format('grant execute on function public.world_job_skill_rules() to %I', own);
  d := replace(pg_get_functiondef('public.world_tourney_duel'::regproc), E'\r\n', E'\n');
  if position('world_job_skill_rules' in d) = 0 then
    a := substring(d from position('        if job[i] = ''medic'' then' in d) for position('        end if;' in substring(d from position('        if job[i] = ''medic'' then' in d))) + length('        end if;') - 1);
    if a is null or a = '' or position('''analyst''' in a) = 0 or position('''sealmaster''' in a) = 0 then raise exception '1.1.0 world_tourney_duel 기준 문구가 없습니다'; end if;
    d := replace(d, a, $x$        sk := public.world_job_skill_rules() -> job[i]; skd := sk -> 'duel';
        if skd ->> 'kind' = 'heal' then
          heal := round(mx[i] * (skd ->> 'heal')::numeric); hp[i] := least(mx[i], hp[i] + heal);
          lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'skill', 'w', side[i], 't', replace(replace(sk ->> 'line', '{me}', nm[i]), '{n}', heal::text)));
          continue;
        elsif skd is not null then
          if skd ->> 'kind' = 'focus' then focus[i] := (skd ->> 'n')::int; focus_mul[i] := (skd ->> 'mul')::numeric;
          elsif skd ->> 'kind' = 'crit' then is_crit := true; mul := coalesce((skd ->> 'mul')::numeric, 1);
          elsif skd ->> 'kind' = 'pierce' then mul := (skd ->> 'mul')::numeric; pierce := true;
          elsif skd ->> 'kind' = 'bind' then mul := (skd ->> 'mul')::numeric; stun[tgt] := 1;
          else mul := coalesce((skd ->> 'mul')::numeric, 1); end if;
          lg := lg || jsonb_build_array(jsonb_build_object('x', x, 'k', 'skill', 'w', side[i], 't', replace(replace(sk ->> 'line', '{me}', nm[i]), '{them}', nm[tgt])));
        end if;$x$);
    o := $a$mul := 1; is_crit := false;$a$;
    if position(o in d) = 0 then raise exception '1.1.0 world_tourney_duel mul 문구가 없습니다'; end if;
    d := replace(d, o, 'mul := 1; is_crit := false; pierce := false;');
    o := $a$(1 - case when job[i] = 'artificer' and mul = 1.7 then 0 else red[tgt] end / 100.0)$a$;
    if position(o in d) = 0 then raise exception '1.1.0 world_tourney_duel 관통 문구가 없습니다'; end if;
    d := replace(d, o, '(1 - case when pierce then 0 else red[tgt] end / 100.0)');
    o := $a$if focus[i] > 0 then dmg := dmg * 1.4; focus[i] := focus[i] - 1; end if;$a$;
    if position(o in d) = 0 then raise exception '1.1.0 world_tourney_duel 집중 문구가 없습니다'; end if;
    d := replace(d, o, 'if focus[i] > 0 then dmg := dmg * coalesce(focus_mul[i], 1.4); focus[i] := focus[i] - 1; end if;');
    o := $a$focus int[] := '{}';$a$;
    if position(o in d) = 0 then raise exception '1.1.0 world_tourney_duel 선언 문구가 없습니다'; end if;
    d := replace(d, o, $x$focus int[] := '{}'; focus_mul numeric[] := '{}'; sk jsonb; skd jsonb; pierce boolean := false;$x$);
    execute d;
  end if;
end $w$;

do $w$
declare d text; own text; r record;
begin
  for own in select distinct pg_get_userbyid(proowner) from pg_proc where proname in ('world_battle_action', 'world_pfight_act') loop
    execute format('grant execute on function public.world_job_skill_rules() to %I', own);
  end loop;
  d := replace(pg_get_functiondef('public.world_battle_action'::regproc), E'\r\n', E'\n');
  if position('world_job_skill_rules' in d) = 0 then
    for r in select * from (values
      ($a$skill_name := '퇴마진';$a$, $x$skill_name := public.world_job_skill_rules() -> 'exorcist' ->> 'name';$x$),
      ($a$skill_name := '급소 사격';$a$, $x$skill_name := public.world_job_skill_rules() -> 'scout' ->> 'name';$x$),
      ($a$skill_name := '봉인술';$a$, $x$skill_name := public.world_job_skill_rules() -> 'sealmaster' ->> 'name';$x$),
      ($a$skill_name := '파갑참';$a$, $x$skill_name := public.world_job_skill_rules() -> 'artificer' ->> 'name';$x$),
      ($a$jsonb_build_array('응급 처방: 체력 ' ||$a$, $x$jsonb_build_array((public.world_job_skill_rules() -> 'medic' ->> 'name') || ': 체력 ' ||$x$),
      ($a$jsonb_build_array('약점 간파: ' ||$a$, $x$jsonb_build_array((public.world_job_skill_rules() -> 'analyst' ->> 'name') || ': ' ||$x$),
      ($a$RAISE EXCEPTION '응급 처방은 한 전투에 한 번만 쓸 수 있습니다.';$a$, $x$RAISE EXCEPTION '%은(는) 한 전투에 한 번만 쓸 수 있습니다.', public.world_job_skill_rules() -> 'medic' ->> 'name';$x$)
    ) v(a, b) loop
      if (length(d) - length(replace(d, r.a, ''))) / length(r.a) <> 1 then raise exception '1.1.0 world_battle_action 기준 문구가 없습니다: %', r.a; end if;
      d := replace(d, r.a, r.b);
    end loop;
    execute d;
  end if;
  d := replace(pg_get_functiondef('public.world_pfight_act'::regproc), E'\r\n', E'\n');
  if position('world_job_skill_rules' in d) = 0 then
    if position($a$raise exception '응급 처방은 한 전투에 한 번만 쓸 수 있습니다.';$a$ in d) = 0 then raise exception '1.1.0 world_pfight_act 기준 문구가 없습니다'; end if;
    execute replace(d, $a$raise exception '응급 처방은 한 전투에 한 번만 쓸 수 있습니다.';$a$, $x$raise exception '%은(는) 한 전투에 한 번만 쓸 수 있습니다.', public.world_job_skill_rules() -> 'medic' ->> 'name';$x$);
  end if;
end $w$;

create or replace function public.world_expedition_xp_rules()
returns jsonb language sql immutable set search_path to '' as $f$
  select jsonb_build_object('searches', 30, 'fight', 0.42, 'near', 0.85,
    'time', jsonb_build_object('30', 0.5, '60', 1.0, '120', 1.15, '240', 1.4, '480', 2.0))
$f$;
revoke all on function public.world_expedition_xp_rules() from public, anon, authenticated;
grant execute on function public.world_expedition_xp_rules() to fn_owner_field, service_role;

create or replace function public.world_expedition_base_xp(p_level int, p_minutes int)
returns numeric language sql immutable set search_path to '' as $f$
  with r as (select public.world_expedition_xp_rules() j)
  select (j ->> 'searches')::numeric * (j ->> 'near')::numeric * (8 + (j ->> 'fight')::numeric * (18 + 3 * greatest(1, p_level)))
       * coalesce((j -> 'time' ->> p_minutes::text)::numeric,
                  case when p_minutes <= 60 then p_minutes / 60.0 else 1 + 1.0 * least(1, (p_minutes - 60) / 420.0) end)
    from r
$f$;
revoke all on function public.world_expedition_base_xp(int, int) from public, anon, authenticated;
grant execute on function public.world_expedition_base_xp(int, int) to fn_owner_field, service_role;

do $w$
declare d text; a text; own text;
begin
  select pg_get_userbyid(proowner) into own from pg_proc where oid = 'public.world_expedition_complete'::regproc;
  execute format('grant execute on function public.world_expedition_base_xp(int, int) to %I', own);
  execute format('grant execute on function public.world_expedition_xp_rules() to %I', own);
  d := replace(pg_get_functiondef('public.world_expedition_complete'::regproc), E'\r\n', E'\n');
  if position('world_expedition_base_xp' in d) = 0 then
    a := $a$(60 + coalesce(n.min_level, r.min_level, c.level) * 15) * power(e.minutes / 60.0, 0.8)$a$;
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.1.0 world_expedition_complete 기준 문구가 없습니다'; end if;
    execute replace(d, a, 'public.world_expedition_base_xp(coalesce(n.min_level, r.min_level, c.level), e.minutes)');
  end if;
end $w$;
