do $m$
declare
  d text := pg_get_functiondef('public.world_design_clean(text,text,text,text,text,text)'::regprocedure);
  o text := $o$    if p_slot = 'hair' and exists (select 1 from generate_series(0, (m ->> 'bh')::int - 1) j, generate_series(0, (m ->> 'bw')::int - 1) i
        where substr(px, ((m ->> 'by')::int + j) * (m ->> 'w')::int + (m ->> 'bx')::int + i + 1, 1) <> '.') then
      raise exception '눈·입 자리는 칠할 수 없습니다.'; end if;
$o$;
begin
  if position(o in d) > 0 then execute replace(d, o, '');
  elsif position('눈·입 자리는 칠할' in d) > 0 then raise exception 'world_design_clean: 눈·입 칸 검사 조각을 찾지 못함';
  end if;
end $m$;

do $m$
declare
  fn regprocedure := 'public.world_avatar_parts()'::regprocedure;
  j jsonb := public.world_avatar_parts();
  src text := pg_get_functiondef(fn);
  body text := (select prosrc from pg_proc where oid = fn);
begin
  j := jsonb_set(j, '{free,hair}', (select jsonb_agg(distinct v order by v) from jsonb_array_elements_text((j -> 'free' -> 'hair')
    || '["drape","slick","sweep","bowl","leaf","pipi","bob","flip","curlybob","braid","tucked","lowtwin","ponytail","halfbang"]'::jsonb) v));
  if position(body in src) = 0 then raise exception 'world_avatar_parts: 본문을 못 찾음'; end if;
  execute replace(src, body, ' select ' || quote_literal(j::text) || '::jsonb ');
end $m$;

update public.world_patch_notes set body = body || $N$

## 3.6.1 · 내 모습
- 기본 눈 열 가지의 자리를 조금 옮겼습니다. 한 줄 아래로 내리고 두 눈 사이를 한 칸씩 좁혔으며, 입도 한 줄 내려왔습니다. 눈·입을 직접 그린 도안은 그대로입니다.
- 기본 머리의 앞머리를 눈이 내려간 만큼 한 줄 내렸습니다.
- 기본 머리 열네 가지를 더했습니다: 흘러내린 앞머리·넘긴 올림 머리·옆으로 쓸린 짧은 머리·바가지 머리·반반 잎 머리·짧은 삐삐 머리·시스루 단발·바깥 뻗침 중단발·곱슬 단발·한 갈래 땋은 머리·귀 뒤로 넘긴 긴 머리·낮게 묶은 양갈래·뒤로 묶은 꽁지머리·앞머리 반묶음 긴 머리.
- 머리 그리기에서 눈·입 자리까지 칠할 수 있습니다. 앞머리를 눈썹이나 콧등까지 내려 그릴 수 있고, 칠한 칸은 눈·입 위로 그려집니다. 기본 머리를 밑그림으로 시작하면 그 머리의 앞머리도 함께 따라옵니다.
$N$
 where note_id = '3.5.0' and position('## 3.6.1' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261124180000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
