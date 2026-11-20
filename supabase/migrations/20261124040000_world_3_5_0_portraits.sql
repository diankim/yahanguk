create or replace function pg_temp.pj_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int; want int; old text;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    old := p_pairs[2 * i - 1]; want := 1;
    if old like '%#%' and old ~ '^#[0-9]+#' then want := substring(old from '^#([0-9]+)#')::int; old := regexp_replace(old, '^#[0-9]+#', ''); end if;
    n := (length(d) - length(replace(d, old, ''))) / length(old);
    if n <> want then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳, 바란 것 %)', p_name, i, n, want; end if;
    d := replace(d, old, p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function pg_temp.pj_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;

create or replace function pg_temp.pj_own(p_fn text, p_role text) returns void language plpgsql as $f$
declare g boolean := not has_schema_privilege(p_role, 'public', 'CREATE');
begin
  if g then execute format('grant create on schema public to %I', p_role); end if;
  execute format('alter function %s owner to %I', p_fn, p_role);
  if g then execute format('revoke create on schema public from %I', p_role); end if;
end $f$;

create or replace function pg_temp.yh_pj_setjson(p_fn regprocedure, p_j jsonb) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); body text := (select prosrc from pg_proc where oid = p_fn);
begin
  if position(body in src) = 0 then raise exception 'yh_pj_setjson %: 본문을 못 찾음', p_fn; end if;
  execute replace(src, body, ' select ' || quote_literal(p_j::text) || '::jsonb ');
end $f$;



insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, equipment_traits) values
('hf_portrait_hanseol', '초상 · 감찰관 한설', 'furniture', 4, '별채 가구 · 초상. 감찰관 한설의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_hanseol", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "hanseol"}'::jsonb),
('hf_portrait_mogaram', '초상 · 기록관 모가람', 'furniture', 4, '별채 가구 · 초상. 기록관 모가람의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_mogaram", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "mogaram"}'::jsonb),
('hf_portrait_yeonseohui', '초상 · 서기관 연서희', 'furniture', 4, '별채 가구 · 초상. 서기관 연서희의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_yeonseohui", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "yeonseohui"}'::jsonb),
('hf_portrait_nodeul', '초상 · 뱃사공 노들 영감', 'furniture', 4, '별채 가구 · 초상. 뱃사공 노들 영감의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_nodeul", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "nodeul"}'::jsonb),
('hf_portrait_danbi', '초상 · 주홍 무녀 단비', 'furniture', 4, '별채 가구 · 초상. 주홍 무녀 단비의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_danbi", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "danbi"}'::jsonb),
('hf_portrait_yeounbi', '초상 · 호송대장 여운비', 'furniture', 4, '별채 가구 · 초상. 호송대장 여운비의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_yeounbi", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "yeounbi"}'::jsonb),
('hf_portrait_sawol', '초상 · 무녀 사월', 'furniture', 4, '별채 가구 · 초상. 무녀 사월의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_sawol", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "sawol"}'::jsonb),
('hf_portrait_seokjinak', '초상 · 맹주 석진악', 'furniture', 4, '별채 가구 · 초상. 맹주 석진악의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_seokjinak", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "seokjinak"}'::jsonb),
('hf_portrait_baekmu', '초상 · 말뚝지기 백무', 'furniture', 4, '별채 가구 · 초상. 말뚝지기 백무의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_baekmu", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "baekmu"}'::jsonb),
('hf_portrait_wolhwa', '초상 · 교주 월화', 'furniture', 4, '별채 가구 · 초상. 교주 월화의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_wolhwa", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "wolhwa"}'::jsonb),
('hf_portrait_jinsorang', '초상 · 도방 진소랑', 'furniture', 4, '별채 가구 · 초상. 도방 진소랑의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_jinsorang", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "jinsorang"}'::jsonb),
('hf_portrait_gaon', '초상 · 늙은 거북 가온', 'furniture', 4, '별채 가구 · 초상. 늙은 거북 가온의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_gaon", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "gaon"}'::jsonb),
('hf_portrait_jangmuhyeon', '초상 · 노장 장무현', 'furniture', 4, '별채 가구 · 초상. 노장 장무현의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_jangmuhyeon", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "jangmuhyeon"}'::jsonb),
('hf_portrait_galmae', '초상 · 정찰대장 갈매', 'furniture', 4, '별채 가구 · 초상. 정찰대장 갈매의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_galmae", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "galmae"}'::jsonb),
('hf_portrait_dohwa', '초상 · 등대지기 도화', 'furniture', 4, '별채 가구 · 초상. 등대지기 도화의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_dohwa", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "dohwa"}'::jsonb),
('hf_portrait_baekunseo', '초상 · 도제조 백운서', 'furniture', 4, '별채 가구 · 초상. 도제조 백운서의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_baekunseo", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "baekunseo"}'::jsonb),
('hf_portrait_yundohan', '초상 · 출납관 윤도한', 'furniture', 4, '별채 가구 · 초상. 출납관 윤도한의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_yundohan", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "yundohan"}'::jsonb),
('hf_portrait_hahujeong', '초상 · 태사령 하후정', 'furniture', 4, '별채 가구 · 초상. 태사령 하후정의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_hahujeong", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "hahujeong"}'::jsonb),
('hf_portrait_guseul', '초상 · 장부지기 구슬', 'furniture', 4, '별채 가구 · 초상. 장부지기 구슬의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_guseul", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "guseul"}'::jsonb),
('hf_portrait_samagyeom', '초상 · 대호법 사마겸', 'furniture', 4, '별채 가구 · 초상. 대호법 사마겸의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_samagyeom", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "samagyeom"}'::jsonb),
('hf_portrait_maehyang', '초상 · 장부 행수 매향', 'furniture', 4, '별채 가구 · 초상. 장부 행수 매향의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_maehyang", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "maehyang"}'::jsonb),
('hf_portrait_cheongpa', '초상 · 잠수꾼 청파', 'furniture', 4, '별채 가구 · 초상. 잠수꾼 청파의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_cheongpa", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "cheongpa"}'::jsonb),
('hf_portrait_seoiyeon', '초상 · 수석 관측관 서이연', 'furniture', 4, '별채 가구 · 초상. 수석 관측관 서이연의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_seoiyeon", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "seoiyeon"}'::jsonb),
('hf_portrait_seoharam', '초상 · 관측관 서하람', 'furniture', 4, '별채 가구 · 초상. 관측관 서하람의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_seoharam", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "seoharam"}'::jsonb),
('hf_portrait_mumyeong', '초상 · 회주 무명', 'furniture', 4, '별채 가구 · 초상. 회주 무명의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_mumyeong", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "mumyeong"}'::jsonb),
('hf_portrait_soi', '초상 · 무녀 소이', 'furniture', 4, '별채 가구 · 초상. 무녀 소이의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_soi", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "soi"}'::jsonb),
('hf_portrait_kangducheol', '초상 · 교관 강두철', 'furniture', 4, '별채 가구 · 초상. 교관 강두철의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_kangducheol", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "kangducheol"}'::jsonb),
('hf_portrait_munsu', '초상 · 서리 문수', 'furniture', 4, '별채 가구 · 초상. 서리 문수의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_munsu", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "munsu"}'::jsonb),
('hf_portrait_munseojin', '초상 · 기밀 사관 문서진', 'furniture', 4, '별채 가구 · 초상. 기밀 사관 문서진의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_munseojin", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "munseojin"}'::jsonb),
('hf_portrait_yeoul', '초상 · 길잡이 여울', 'furniture', 4, '별채 가구 · 초상. 길잡이 여울의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_yeoul", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "yeoul"}'::jsonb),
('hf_portrait_mukho', '초상 · 촌장 묵호', 'furniture', 4, '별채 가구 · 초상. 촌장 묵호의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_mukho", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "mukho"}'::jsonb),
('hf_portrait_dani', '초상 · 단이', 'furniture', 4, '별채 가구 · 초상. 단이의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_dani", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "dani"}'::jsonb),
('hf_portrait_hisu', '초상 · 서리 희수', 'furniture', 4, '별채 가구 · 초상. 서리 희수의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_hisu", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "hisu"}'::jsonb),
('hf_portrait_daon', '초상 · 다온', 'furniture', 4, '별채 가구 · 초상. 다온의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_daon", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "daon"}'::jsonb),
('hf_portrait_wolha', '초상 · 이름 거둠꾼 월하', 'furniture', 4, '별채 가구 · 초상. 이름 거둠꾼 월하의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_wolha", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "wolha"}'::jsonb),
('hf_portrait_seoyul', '초상 · 서율', 'furniture', 4, '별채 가구 · 초상. 서율의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_seoyul", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "seoyul"}'::jsonb),
('hf_portrait_seoha', '초상 · 서하', 'furniture', 4, '별채 가구 · 초상. 서하의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_seoha", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "seoha"}'::jsonb),
('hf_portrait_hyegak', '초상 · 수좌 혜각', 'furniture', 4, '별채 가구 · 초상. 수좌 혜각의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_hyegak", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "hyegak"}'::jsonb),
('hf_portrait_yeoseotjjae', '초상 · 채무 추적자 여섯째', 'furniture', 4, '별채 가구 · 초상. 채무 추적자 여섯째의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_yeoseotjjae", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "yeoseotjjae"}'::jsonb),
('hf_portrait_gwakduchil', '초상 · 곽두칠', 'furniture', 4, '별채 가구 · 초상. 곽두칠의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_gwakduchil", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "gwakduchil"}'::jsonb),
('hf_portrait_gyeonghyeon', '초상 · 정리관 경현', 'furniture', 4, '별채 가구 · 초상. 정리관 경현의 초상. 별채 벽에 거는 초상 액자. 누르면 큰 그림을 볼 수 있습니다. 초상 화첩에서 꺼낸 것이라 버려도 화첩에서 다시 꺼낼 수 있습니다.', false, false, 0, 1, '{"hk": "portrait_gyeonghyeon", "kind": "wall", "wall": "deco", "ww": 1.75, "wh": 38, "cat": "초상", "grade": 4, "portrait": "gyeonghyeon"}'::jsonb)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  stackable = excluded.stackable, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size, equipment_traits = excluded.equipment_traits;

create or replace function public.world_portrait_rules() returns jsonb language sql immutable set search_path = pg_catalog, public as $f$ select '{"item": "hf_portrait_", "cast": [{"k": "hanseol", "q": "mq_red_seal"}, {"k": "mogaram", "q": "mq_red_seal"}, {"k": "yeonseohui", "q": "mq_red_seal"}, {"k": "nodeul", "q": "mq_drowned_ledger"}, {"k": "danbi", "q": "mq_red_moon_oath"}, {"k": "yeounbi", "q": "mq_red_moon_oath"}, {"k": "sawol", "q": "mq_red_moon_oath"}, {"k": "seokjinak", "q": "mq_frost_seal"}, {"k": "baekmu", "q": "mq_frost_seal"}, {"k": "wolhwa", "q": "mq_eclipse_gate"}, {"k": "jinsorang", "q": "mq_sunken_lantern"}, {"k": "gaon", "q": "mq_sunken_lantern"}, {"k": "jangmuhyeon", "q": "mq_ash_sea"}, {"k": "galmae", "q": "mq_ash_sea"}, {"k": "dohwa", "q": "mq_ash_sea"}, {"k": "baekunseo", "q": "mq_lamp_shadow"}, {"k": "yundohan", "q": "mq_nine_gates"}, {"k": "hahujeong", "q": "mq_nine_gates"}, {"k": "guseul", "q": "mq_nameless_bell"}, {"k": "samagyeom", "q": "mq_eclipse_gate"}, {"k": "maehyang", "q": "mdq_4"}, {"k": "cheongpa", "q": "mdq_4"}, {"k": "seoiyeon", "q": "mq_nine_gates"}, {"k": "seoharam", "q": "mdq_4"}, {"k": "mumyeong", "q": "mq_frost_seal"}, {"k": "soi", "q": "mq_frost_seal"}, {"k": "kangducheol", "q": "mq_red_seal"}, {"k": "munsu", "q": "mdq_1"}, {"k": "munseojin", "q": "mq_nine_gates"}, {"k": "yeoul", "q": "gq_1"}, {"k": "mukho", "q": "gq_1"}, {"k": "dani", "q": "gq_1"}, {"k": "hisu", "q": "mkq_1"}, {"k": "daon", "q": "mkq_1"}, {"k": "wolha", "q": "mkq_1"}, {"k": "seoyul", "q": "mkq_5"}, {"k": "seoha", "q": "mkq_5"}, {"k": "hyegak", "q": "mdq_7"}, {"k": "yeoseotjjae", "q": "mdq_8"}, {"k": "gwakduchil", "q": "mdq_15"}, {"k": "gyeonghyeon", "q": "mdq_17"}]}'::jsonb $f$;


create or replace function public.world_portrait_have(p_uid uuid, p_item text) returns int
language plpgsql stable security definer set search_path = pg_catalog, public as $f$
declare hm uuid := public.world_housing_home(p_uid); n int := 0;
begin
  n := n + coalesce((select (c.inventory ->> p_item)::int from public.world_characters c where c.owner_id = p_uid), 0);
  n := n + coalesce((select (s.items ->> p_item)::int from public.world_storage s where s.owner_id = p_uid), 0);
  n := n + coalesce((select (s.items ->> p_item)::int from public.world_housing_store s where s.owner_id = hm), 0);
  n := n + coalesce((select (public.world_housing_counts_all(h.items, h.wall, h.paper, h.ground, h.rooms) ->> p_item)::int from public.world_housing h where h.owner_id = hm), 0);
  return n;
end $f$;

create or replace function public.world_portrait_book()
returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $f$
declare uid uuid := public.fn_owner_auth_uid(); done text[]; pre text := public.world_portrait_rules() ->> 'item';
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  done := public.world_quest_done_ids(uid);
  return jsonb_build_object(
    'house', exists (select 1 from public.world_housing h where h.owner_id = public.world_housing_home(uid)),
    'list', coalesce((select jsonb_agg(jsonb_build_object('k', c.value ->> 'k', 'quest', q.title, 'lv', q.min_level,
        'story', case when q.kind = 'main' then '홍인사 ' || (select count(*) from public.world_quests m where m.kind = 'main' and m.quest_id like 'mq\_%' and m.min_level <= q.min_level) || '장'
          when q.cat like '외전·%' then case split_part(q.cat, '·', 2) when '귀허도' then '요인록' else split_part(q.cat, '·', 2) end || ' ' || substring(q.quest_id from '_(\d+)$') || '장'
          else q.cat end,
        'open', (c.value ->> 'q') = any(done),
        'have', (c.value ->> 'q') = any(done) and public.world_portrait_have(uid, pre || (c.value ->> 'k')) > 0) order by c.ord)
      from jsonb_array_elements(public.world_portrait_rules() -> 'cast') with ordinality c(value, ord)
      left join public.world_quests q on q.quest_id = c.value ->> 'q'), '[]'::jsonb));
end $f$;

create or replace function public.world_portrait_take(p_key text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $f$
declare uid uuid := public.fn_owner_auth_uid(); r jsonb; it text; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  select c into r from jsonb_array_elements(public.world_portrait_rules() -> 'cast') c where c ->> 'k' = p_key;
  if r is null then raise exception '없는 초상입니다.'; end if;
  perform 1 from public.world_characters where owner_id = uid for update;
  if not exists (select 1 from public.world_housing h where h.owner_id = public.world_housing_home(uid)) then
    raise exception '별채가 있어야 초상 액자를 꺼낼 수 있습니다.' using hint = 'no_house';
  end if;
  if not ((r ->> 'q') = any(public.world_quest_done_ids(uid))) then
    raise exception '아직 화첩에 열리지 않은 초상입니다.' using hint = 'locked';
  end if;
  it := (public.world_portrait_rules() ->> 'item') || p_key;
  select item_name into nm from public.world_item_catalog where item_id = it;
  if public.world_portrait_have(uid, it) > 0 then
    raise exception '%', public.world_josa(nm, '은', '는') || ' 이미 가방·창고·별채 어딘가에 있습니다.' using hint = 'have';
  end if;
  perform public.world_housing_grant(uid, it, 1, '초상 화첩', true);
  return jsonb_build_object('item', it, 'name', nm);
end $f$;

do $g$
declare f text;
begin
  perform pg_temp.pj_share('public.world_portrait_rules()');
  foreach f in array array['world_portrait_have(uuid, text)', 'world_portrait_book()', 'world_portrait_take(text)'] loop
    perform pg_temp.pj_share('public.' || f);
    perform pg_temp.pj_own('public.' || f, 'fn_owner_field');
  end loop;
end $g$;
grant execute on function public.world_portrait_book() to authenticated;
grant execute on function public.world_portrait_take(text) to authenticated;
grant execute on function public.world_portrait_rules() to anon, authenticated;


insert into public.world_patch_notes(note_id, title, body) values ('3.5.0', '3.5.0 · 초상 화첩', $N$이야기에서 만난 인물들의 초상을 모아 별채 벽에 걸 수 있습니다.

## 초상 화첩
### 화첩
- 홍인사·요인록·묵적록·명등기에서 만난 인물 마흔한 명의 초상을 모으는 「초상 화첩」이 생겼습니다.
- 그 인물이 처음 크게 나오는 본편 장을 마치면 화첩에 열립니다. 아직 열리지 않은 칸에는 어느 장을 마치면 되는지 적혀 있습니다.
- 열린 인물을 누르면 큰 초상과 인물 소개가 액자에 담겨 뜹니다.
- 화첩은 별채 머리의 「초상 화첩」에서 엽니다. 별채가 없어도 화첩은 볼 수 있습니다.

### 초상 액자
- 열린 인물 창에서 「꺼내기」를 누르면 그 인물의 초상 액자가 별채 곳간에 들어옵니다. 별채 「꾸미기」에서 벽에 걸고, 걸린 액자를 누르면 큰 초상을 봅니다.
- 같은 인물 액자는 하나만 가질 수 있습니다. 버리거나 잃어도 화첩에서 다시 꺼낼 수 있습니다.
- 액자는 거래하거나 상점에 팔 수 없습니다.
- 초상 그림은 생성형 AI로 만든 이미지입니다.

## 고친 것
- 캐릭터 › 기술에서 3.4.0부터 분석·막기·응급 처치·채굴·낚시와 제작 계열 대부분이 「다른 직업 기술」처럼 흐리게 보이고, 24·43단계 택일 기술을 고르는 단추와 빨간 점이 나오지 않던 것을 고쳤습니다. 이제 이 계열들도 단계 칸을 눌러 택일 기술을 고를 수 있습니다.
$N$)
on conflict (note_id) do update set title = excluded.title, body = excluded.body;


insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261124040000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
