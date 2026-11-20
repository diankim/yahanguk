create or replace function pg_temp.rf(p_fn regprocedure, p_pairs text[]) returns void language plpgsql as $g$
declare src text := pg_get_functiondef(p_fn); i int; n int;
begin
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(src) - length(replace(src, p_pairs[2 * i - 1], ''))) / greatest(length(p_pairs[2 * i - 1]), 1);
    if n <> 1 then raise exception '% 조각 %: % 번 나옴', p_fn, i, n; end if;
    src := replace(src, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute src;
end $g$;

alter table public.world_drawings add column if not exists pal text check (pal is null or pal ~ '^([0-9a-f]{6}){16,32}$');
alter table public.world_drawings drop constraint if exists world_drawings_px_check;
alter table public.world_drawings add constraint world_drawings_px_check check (px ~ '^[0-9a-v.]+$');

select pg_temp.rf('public.world_drawing_json(public.world_drawings, uuid)'::regprocedure, array[
$o$'px', d.px, $o$, $n$'px', d.px, 'pal', d.pal, $n$]);
select pg_temp.rf('public.world_drawing_brief(bigint)'::regprocedure, array[
$o$'px', d.px, $o$, $n$'px', d.px, 'pal', d.pal, $n$]);
select pg_temp.rf('public.world_drawing_give(bigint, uuid)'::regprocedure, array[
$o$title, size, px, giver_id, gift_from)$o$, $n$title, size, px, pal, giver_id, gift_from)$n$,
$o$d.title, d.size, d.px, uid, nm)$o$, $n$d.title, d.size, d.px, d.pal, uid, nm)$n$]);

do $d$
declare src text := pg_get_functiondef('public.world_drawing_save(bigint, text, text, text)'::regprocedure); i int; pairs text[] := array[
$o$world_drawing_save(p_id bigint, p_size text, p_title text, p_px text)$o$,
$n$world_drawing_save(p_id bigint, p_size text, p_title text, p_px text, p_pal text DEFAULT NULL::text)$n$,
$o$  t := btrim(regexp_replace($o$,
$n$  if p_pal is not null and p_pal !~ '^([0-9a-f]{6}){16,32}$' then raise exception '그림 색이 올바르지 않습니다.'; end if;
  if (select max(strpos('0123456789abcdefghijklmnopqrstuv', ch)) from regexp_split_to_table(p_px, '') ch where ch <> '.') > coalesce(char_length(p_pal) / 6, 16) then
    raise exception '그림에 없는 색 칸이 쓰였습니다.'; end if;
  t := btrim(regexp_replace($n$,
$o$title, size, px) values (uid, uid, nm, t, p_size, p_px)$o$,
$n$title, size, px, pal) values (uid, uid, nm, t, p_size, p_px, p_pal)$n$,
$o$p_px !~ '^[0-9a-f.]+$' then$o$,
$n$p_px !~ '^[0-9a-v.]+$' then$n$,
$o$if p_px !~ '[0-9a-f]' then$o$,
$n$if p_px !~ '[0-9a-v]' then$n$,
$o$set px = p_px, title = t,$o$,
$n$set px = p_px, pal = p_pal, title = t,$n$];
begin
  for i in 1 .. array_length(pairs, 1) / 2 loop
    if (length(src) - length(replace(src, pairs[2 * i - 1], ''))) / length(pairs[2 * i - 1]) <> 1 then raise exception 'world_drawing_save 조각 %', i; end if;
    src := replace(src, pairs[2 * i - 1], pairs[2 * i]);
  end loop;
  drop function public.world_drawing_save(bigint, text, text, text);
  execute src;
end $d$;
alter function public.world_drawing_save(bigint, text, text, text, text) owner to fn_owner_field;
revoke all on function public.world_drawing_save(bigint, text, text, text, text) from public, anon;
grant execute on function public.world_drawing_save(bigint, text, text, text, text) to authenticated, service_role;

select pg_temp.rf('public.world_meisho_soil(text)'::regprocedure, array[
$o$  g := public.world_meisho_grade(m.min_level);$o$,
$n$  if not coalesce((public.world_meisho_when(m.meisho_id) ->> 'open')::boolean, false) then
    raise exception '%은(는) 지금 닫혀 있습니다. 흙은 명소가 열려 있는 동안에만 살필 수 있습니다.', m.meisho_name using hint = 'mz_closed'; end if;
  g := public.world_meisho_grade(m.min_level);$n$]);

select pg_temp.rf('public.world_bijang_rules()'::regprocedure, array[
$o$"open": {"cap": 60, "pct": 30, "gear": "mz_soil_pct"}$o$, $n$"open": {"cap": 70, "pct": 40, "gear": "mz_soil_pct"}$n$]);

update public.world_patch_notes set body = rtrim(body, E'\n') || E'\n- 명소의 「흙 살피기」는 이제 명소가 열려 있는 동안에만 할 수 있습니다(명소마다 하루 한 번은 그대로).\n- 비장도를 펼쳤을 때 비장고가 열릴 확률을 30%에서 40%로 올렸습니다. 명장 장비로 올릴 수 있는 상한도 60%에서 70%로 올렸습니다.\n- 그림첩 그림판에서 색 칸마다 원하는 색을 직접 고를 수 있습니다. 처음엔 열여섯 칸이고 「색 더하기」로 서른두 칸까지 늘릴 수 있습니다. 그림마다 고른 색이 따로 남고, 이미 그린 그림은 원래 색 그대로입니다.\n'
 where note_id = '3.5.0' and position('흙 살피기」는 이제' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261124060000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
