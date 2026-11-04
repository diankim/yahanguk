create or replace function public.world_expedition_duo_lines(p_a uuid, p_b uuid) returns jsonb
language plpgsql stable set search_path = '' as $f$
declare ea public.world_expeditions%rowtype; eb public.world_expeditions%rowtype; na text; nb text; x text; y text; ox uuid;
  total int; done int; i int; h bigint; lines jsonb := '[]'::jsonb; k text;
  pool text[] := array['%a이(가) %b에게 물주머니를 건넵니다.', '%a이(가) 앞서 걷고 %b이(가) 뒤를 살핍니다.', '%a이(가) %b의 짐끈을 고쳐 매 줍니다.',
    '%a이(가) 수상한 기척을 손짓으로 %b에게 알립니다.', '%b이(가) 찾은 흔적을 %a이(가) 지도에 옮겨 적습니다.', '%a이(가) 발을 헛디딘 %b을(를) 붙잡아 줍니다.',
    '%a과(와) %b이(가) 바위 그늘에서 잠깐 숨을 고릅니다.', '%a이(가) 마른 육포를 반으로 갈라 %b에게 나눠 줍니다.'];
begin
  select * into ea from public.world_expeditions where expedition_id = p_a;
  select * into eb from public.world_expeditions where expedition_id = p_b;
  if ea.expedition_id is null or eb.expedition_id is null then return lines; end if;
  select character_name into na from public.world_characters where owner_id = ea.owner_id;
  select character_name into nb from public.world_characters where owner_id = eb.owner_id;
  k := least(p_a::text, p_b::text) || greatest(p_a::text, p_b::text);
  total := case ea.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end;
  done := greatest(0, least(total, floor(total * extract(epoch from least(now(), ea.ends_at) - ea.started_at) / extract(epoch from ea.ends_at - ea.started_at))::int));
  if ea.state ->> 'ended' in ('downed', 'exhausted') then done := least(done, ea.settled_rounds); end if;
  if eb.state ->> 'ended' in ('downed', 'exhausted') then done := least(done, eb.settled_rounds); end if;
  for i in 1..done loop
    h := abs(hashtext(k || '~duo~' || i)::bigint);
    if h % 3 <> 0 then continue; end if;
    if (h / 3) % 2 = 0 then x := na; y := nb; ox := ea.owner_id; else x := nb; y := na; ox := eb.owner_id; end if;
    lines := lines || jsonb_build_object('at', ea.started_at + (ea.ends_at - ea.started_at) * (i - 0.5) / total, 'kind', 'walk', 'who', x, 'owner', ox,
      'text', replace(replace(pool[1 + (h / 6) % cardinality(pool)], '%a', x), '%b', y));
  end loop;
  return lines;
end $f$;
revoke all on function public.world_expedition_duo_lines(uuid, uuid) from public, anon, authenticated;
grant execute on function public.world_expedition_duo_lines(uuid, uuid) to fn_owner_field;

do $w$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_expedition_progress()'::regprocedure), E'\r\n', E'\n');
  a := $a$if x.together then lines := lines || public.world_expedition_walk_lines(x.expedition_id); end if;$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.3c world_expedition_progress 기준 문구가 없습니다'; end if;
  execute replace(d, a, $x$if x.together then lines := lines || public.world_expedition_walk_lines(x.expedition_id) || public.world_expedition_duo_lines(e.expedition_id, x.expedition_id); end if;$x$);
end $w$;
