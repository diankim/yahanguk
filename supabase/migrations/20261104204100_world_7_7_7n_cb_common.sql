-- 7.7.7n — 파티 전투 공용 함수 ②(사용자 요청 2026-11-01): 회복품 효과 표·공격 피해 굴림·늘려 준 몫 나누기·협동 기술 기운 걸기·표적 고르기를 한 곳에.
-- 봉연·결전(world_raid_action)·귀허(world_gw_resolve)·파티 토벌(world_pfight_round)·원정 합동 전투(world_exp_fight_story)·물품(world_use_item·world_party_use_item)·원정 보급(world_expedition_settle)이 함께 쓴다.
-- 바뀌는 규칙: 귀허 보호막이 덮어쓰기 → 더하기(봉연과 같게), 귀허 급소 키 critnext → crit_next(둘 다 읽음). 나머지 수치는 그대로.
create or replace function public.world_item_fx(p_base text)
returns jsonb language plpgsql immutable set search_path to 'pg_catalog', 'public' as $f$
-- 물품을 썼을 때의 회복·치료·기운(우수품·직업·상태 보정 전 기본값). world_use_item·world_party_use_item·귀허 정산·원정 정산이 함께 쓴다(7.7.7n).
declare v_base text := p_base; hp int := 0; mn int := 0; er int := 0; stam int := 0; spg int := 0; cures text[] := '{}'; buffs text[] := '{}';
begin
  CASE v_base
    WHEN 'tonic' THEN hp := 35; cures := ARRAY['shaken'];
    WHEN 'herbal_extract' THEN hp := 22; cures := ARRAY['bleeding', 'burned', 'sprain'];
    WHEN 'herb' THEN hp := 12; cures := ARRAY['poisoned', 'stomach_upset'];
    WHEN 'medicine_base' THEN mn := 12; cures := ARRAY['fatigue', 'cold', 'exhausted', 'overtrained'];
    WHEN 'ward_talisman' THEN mn := 8; er := 12; cures := ARRAY['erosion_whisper', 'shaken', 'poisoned'];
    WHEN 'travel_ration' THEN stam := 2;
    WHEN 'spirit_tea' THEN spg := 10;
    WHEN 'clear_spirit_pill' THEN spg := 20;
    WHEN 'spirit_qi_pill' THEN spg := 35;
    WHEN 'moonlight_essence' THEN spg := 55; cures := ARRAY['shaken'];
    WHEN 'heavenly_dew' THEN spg := 80; cures := ARRAY['shaken', 'erosion_whisper'];
    WHEN 'rejuv_pill' THEN hp := 60; cures := ARRAY['bleeding', 'burned', 'sprain', 'poisoned'];
    WHEN 'grand_pill' THEN hp := 100; mn := 20; cures := ARRAY['shaken', 'exhausted'];
    WHEN 'purify_water' THEN mn := 5; er := 20; cures := ARRAY['erosion_whisper'];
    WHEN 'calm_brew' THEN mn := 30; cures := ARRAY['shaken', 'fatigue'];
    WHEN 'herb_fish_steam' THEN hp := 40; cures := ARRAY['poisoned']; buffs := ARRAY['vigor'];
    WHEN 'spirit_gukbap' THEN hp := 30; mn := 15; spg := 15; stam := 3; buffs := ARRAY['warm_belly'];
    WHEN 'grilled_fish' THEN hp := 25; buffs := ARRAY['well_fed'];
    WHEN 'spicy_stew' THEN hp := 30; mn := 10; cures := ARRAY['cold']; buffs := ARRAY['warm_belly'];
    WHEN 'fish_porridge' THEN mn := 15; stam := 4; cures := ARRAY['fatigue'];
    WHEN 'eel_tonic' THEN hp := 45; cures := ARRAY['exhausted']; buffs := ARRAY['vigor'];
    WHEN 'carp_broth' THEN hp := 60; mn := 20; buffs := ARRAY['well_fed', 'warm_belly'];
    WHEN 'bream_sashimi' THEN hp := 40; mn := 10; buffs := ARRAY['sea_luck', 'vigor'];
    WHEN 'sweetfish_grill' THEN hp := 30; mn := 5; buffs := ARRAY['well_fed'];
    WHEN 'catfish_braise' THEN hp := 45; cures := ARRAY['poisoned']; buffs := ARRAY['warm_belly'];
    WHEN 'snakehead_broth' THEN hp := 35; mn := 15; cures := ARRAY['exhausted', 'fatigue']; buffs := ARRAY['vigor'];
    WHEN 'goby_soup' THEN mn := 25; er := 8; cures := ARRAY['shaken'];
    WHEN 'hairtail_braise' THEN hp := 50; mn := 10; buffs := ARRAY['well_fed'];
    WHEN 'dried_croaker' THEN hp := 15; stam := 3; buffs := ARRAY['well_fed'];
    WHEN 'croaker_soup' THEN hp := 60; mn := 15; buffs := ARRAY['warm_belly', 'vigor'];
    WHEN 'char_grill' THEN hp := 40; mn := 10; cures := ARRAY['cold']; buffs := ARRAY['well_fed'];
    WHEN 'salmon_grill' THEN hp := 40; mn := 10; spg := 10; buffs := ARRAY['well_fed'];
    WHEN 'trout_sashimi' THEN hp := 25; mn := 10; buffs := ARRAY['vigor'];
    WHEN 'mirror_soup' THEN mn := 35; spg := 30; er := 10; buffs := ARRAY['warm_belly'];
    WHEN 'hagfish_grill' THEN hp := 55; mn := 10; buffs := ARRAY['vigor'];
    WHEN 'ray_steam' THEN hp := 70; mn := 30; er := 15; buffs := ARRAY['warm_belly', 'vigor'];
    WHEN 'koi_broth' THEN hp := 100; mn := 40; spg := 40; buffs := ARRAY['vigor', 'sea_luck', 'warm_belly'];
    WHEN 'dragon_feast' THEN hp := 100; mn := 50; spg := 50; er := 25; buffs := ARRAY['vigor', 'sea_luck', 'warm_belly', 'well_fed'];
    WHEN 'wraith_soul_pill' THEN mn := 40; er := 15; cures := ARRAY['shaken', 'erosion_whisper'];
    WHEN 'fish_oil_lamp' THEN buffs := ARRAY['lamp_glow'];
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         WHEN 'guide_lantern' THEN stam := 10;
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             WHEN 'exp_elixir_iron' THEN buffs := ARRAY['st_iron_wall'];
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 WHEN 'exp_elixir_tiger' THEN buffs := ARRAY['st_tiger_might'];
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     WHEN 'exp_elixir_clear' THEN buffs := ARRAY['st_clear_mind']; WHEN 'wedding_rice_cake' THEN hp := 20; mn := 15; WHEN 'herb_rice' THEN hp := 20; buffs := ARRAY['well_fed']; WHEN 'moss_porridge' THEN hp := 35; mn := 10; buffs := ARRAY['warm_belly']; WHEN 'bark_stew' THEN hp := 50; mn := 10; buffs := ARRAY['vigor'];
    WHEN 'rockfish_stew' THEN hp := 45; mn := 10; cures := ARRAY['cold']; buffs := ARRAY['warm_belly'];
    WHEN 'flounder_sashimi' THEN hp := 35; mn := 15; buffs := ARRAY['vigor'];
    WHEN 'mackerel_grill' THEN hp := 45; spg := 15; buffs := ARRAY['well_fed'];
    WHEN 'cod_soup' THEN hp := 60; mn := 15; cures := ARRAY['cold']; buffs := ARRAY['warm_belly', 'vigor'];
    WHEN 'skate_ferment' THEN mn := 30; er := 10; cures := ARRAY['shaken']; buffs := ARRAY['vigor'];
    WHEN 'yellowtail_sashimi' THEN hp := 50; mn := 15; buffs := ARRAY['sea_luck', 'vigor'];
    WHEN 'grouper_steam' THEN hp := 80; mn := 30; er := 10; buffs := ARRAY['warm_belly', 'vigor'];
    WHEN 'marlin_grill' THEN hp := 80; mn := 30; spg := 40; buffs := ARRAY['sea_luck', 'vigor'];
    WHEN 'haeryong_feast' THEN hp := 100; mn := 50; spg := 50; er := 20; buffs := ARRAY['vigor', 'sea_luck', 'warm_belly', 'well_fed']; WHEN 'banyo_salve' THEN hp := 70; mn := 15; cures := ARRAY['bleeding', 'burned', 'poisoned']; WHEN 'oblivion_incense' THEN mn := 20; er := 30; cures := ARRAY['erosion_whisper', 'shaken'];
    ELSE NULL;
  END CASE;
  return jsonb_build_object('hp', hp, 'mn', mn, 'sp', spg, 'er', er, 'stam', stam, 'cures', to_jsonb(cures), 'buffs', to_jsonb(buffs));
end $f$;
revoke all on function public.world_item_fx(text) from public, anon, authenticated;
grant execute on function public.world_item_fx(text) to fn_owner_field;

-- 표적 고르기 공용: 무게 = 이목^1.3(이목 5 아래는 5로). order by world_cb_pick_key(이목) limit 1 이 무게에 비례한 뽑기.
create or replace function public.world_cb_aggro(p_pres numeric)
returns numeric language sql immutable as $f$ select power(greatest(5, coalesce(p_pres, 30)), 1.3) $f$;
create or replace function public.world_cb_pick_key(p_pres numeric)
returns float8 language sql volatile as $f$ select -ln(greatest(random(), 1e-9)) / power(greatest(5, coalesce(p_pres, 30)), 1.3)::float8 $f$;

-- 협동 기술의 「한 사람에게 거는 기운」 공용: 효과 종류 → 참가자 fx에 덧붙일 조각(없으면 null)
create or replace function public.world_cb_buff(p_type text, p_eff jsonb, p_by uuid)
returns jsonb language sql immutable as $f$
  select case p_type
    when 'ward' then jsonb_build_object('ward', jsonb_build_object('pct', p_eff -> 'pct', 'n', p_eff -> 'n', 'by', p_by))
    when 'ward_all' then jsonb_build_object('ward', jsonb_build_object('pct', p_eff -> 'pct', 'n', p_eff -> 'n', 'by', p_by))
    when 'might' then jsonb_build_object('might', jsonb_build_object('pct', p_eff -> 'pct', 'n', p_eff -> 'n', 'by', p_by))
    when 'might_all' then jsonb_build_object('might', jsonb_build_object('pct', p_eff -> 'pct', 'n', p_eff -> 'n', 'by', p_by))
    when 'rally' then jsonb_build_object('might', jsonb_build_object('pct', p_eff -> 'pct', 'n', coalesce(p_eff -> 'n', '1'::jsonb), 'by', p_by))
    when 'resonance' then jsonb_build_object('might', jsonb_build_object('pct', p_eff -> 'pct', 'n', p_eff -> 'n', 'by', p_by), 'ward', jsonb_build_object('pct', p_eff -> 'pct', 'n', p_eff -> 'n', 'by', p_by))
    when 'crit_all' then jsonb_build_object('crit', jsonb_build_object('pct', p_eff -> 'pct', 'n', p_eff -> 'n', 'by', p_by))
    when 'evade' then jsonb_build_object('evade', jsonb_build_object('pct', p_eff -> 'pct', 'n', p_eff -> 'n', 'by', p_by))
    when 'gward' then jsonb_build_object('gward', jsonb_build_object('pct', coalesce(p_eff -> 'pct', '50'::jsonb), 'by', p_by))
    when 'crit_next' then jsonb_build_object('crit_next', p_by)
    when 'taunt' then jsonb_build_object('taunt', jsonb_build_object('pres', p_eff -> 'pres', 'pct', p_eff -> 'pct', 'n', p_eff -> 'n'))
  end
$f$;

-- 공격 피해 굴림 공용: 기세(might)·사슬(bound)·약점 드러내기(expose)·약점(crit)·급소(crit_next — 옛 귀허 critnext도 읽음)를 쓰고 닳게 한다.
-- 돌려줌: d(무기 소모·혼자 보정 등 엔진 몫 전), crit, fx, bfx, src(늘려 준 사람 — world_cb_boost_credits에 넘김)
create or replace function public.world_cb_attack(p_stats jsonb, p_fx jsonb, p_bfx jsonb, p_lo numeric, p_span numeric)
returns jsonb language plpgsql volatile set search_path to 'pg_catalog', 'public' as $f$
declare f jsonb := coalesce(p_fx, '{}'); b jsonb := coalesce(p_bfx, '{}'); mul numeric := 1; cr boolean; n int; src jsonb;
  base_crit numeric := coalesce((p_stats ->> 'crit')::numeric, 5); cn text := coalesce(f ->> 'crit_next', f ->> 'critnext');
begin
  src := jsonb_build_object(
    'mb', case when coalesce((f -> 'might' ->> 'n')::int, 0) > 0 then f -> 'might' ->> 'by' end, 'mp', coalesce((f -> 'might' ->> 'pct')::numeric, 0),
    'eb', case when coalesce((b -> 'expose' ->> 'n')::int, 0) > 0 then b -> 'expose' ->> 'by' end, 'ep', coalesce((b -> 'expose' ->> 'pct')::numeric, 0),
    'cb', case when coalesce((f -> 'crit' ->> 'n')::int, 0) > 0 then f -> 'crit' ->> 'by' end, 'cp', coalesce((f -> 'crit' ->> 'pct')::numeric, 0), 'cn', cn);
  n := coalesce((f -> 'might' ->> 'n')::int, 0);
  if n > 0 then mul := mul * (1 + (f -> 'might' ->> 'pct')::numeric / 100.0); f := case when n > 1 then jsonb_set(f, '{might,n}', to_jsonb(n - 1)) else f - 'might' end; end if;
  if f ? 'bound' then mul := mul * 0.5; f := f - 'bound'; end if;
  n := coalesce((b -> 'expose' ->> 'n')::int, 0);
  if n > 0 then mul := mul * (1 + (b -> 'expose' ->> 'pct')::numeric / 100.0); b := case when n > 1 then jsonb_set(b, '{expose,n}', to_jsonb(n - 1)) else b - 'expose' end; end if;
  cr := cn is not null;
  f := f - 'crit_next' - 'critnext';
  n := coalesce((f -> 'crit' ->> 'n')::int, 0);
  if not cr then cr := random() * 100 < base_crit + case when n > 0 then (f -> 'crit' ->> 'pct')::numeric else 0 end; end if;
  if n > 0 then f := case when n > 1 then jsonb_set(f, '{crit,n}', to_jsonb(n - 1)) else f - 'crit' end; end if;
  if cr then mul := mul * 1.5; end if;
  return jsonb_build_object('d', coalesce((p_stats ->> 'attack')::numeric, 50) * (p_lo + random() * p_span) * mul, 'crit', cr, 'fx', f, 'bfx', b, 'src', src);
end $f$;

-- 늘려 준 몫을 건 사람에게(때린 사람 몫에서 뺀다): [[사람, 몫, 'boost'], …, [때린 사람, 남은 몫, 'dmg']]
create or replace function public.world_cb_boost_credits(p_d numeric, p_crit boolean, p_src jsonb, p_self uuid, p_critbase numeric)
returns jsonb language plpgsql immutable set search_path to 'pg_catalog', 'public' as $f$
declare c numeric := coalesce(p_d, 0); ex numeric; out jsonb := '[]'; s jsonb := coalesce(p_src, '{}');
  mb text := s ->> 'mb'; mp numeric := coalesce((s ->> 'mp')::numeric, 0); eb text := s ->> 'eb'; ep numeric := coalesce((s ->> 'ep')::numeric, 0);
  cb text := s ->> 'cb'; cp numeric := coalesce((s ->> 'cp')::numeric, 0); cn text := s ->> 'cn';
begin
  if c <= 0 then return out; end if;
  if mb is not null and mb <> p_self::text and mp > 0 then ex := p_d - p_d / (1 + mp / 100.0); out := out || jsonb_build_array(jsonb_build_array(mb, ex, 'boost')); c := c - ex; end if;
  if eb is not null and eb <> p_self::text and ep > 0 then ex := p_d - p_d / (1 + ep / 100.0); out := out || jsonb_build_array(jsonb_build_array(eb, ex, 'boost')); c := c - ex; end if;
  if p_crit and cn is not null and cn not in ('1', 'true', p_self::text) then ex := p_d - p_d / 1.5; out := out || jsonb_build_array(jsonb_build_array(cn, ex, 'boost')); c := c - ex;
  elsif p_crit and cb is not null and cb <> p_self::text and cp > 0 then
    ex := (p_d - p_d / 1.5) * cp / greatest(1, coalesce(p_critbase, 5) + cp); out := out || jsonb_build_array(jsonb_build_array(cb, ex, 'boost')); c := c - ex; end if;
  return out || jsonb_build_array(jsonb_build_array(p_self::text, greatest(0, c), 'dmg'));
end $f$;
do $g$ declare f text; begin
  foreach f in array array['world_cb_aggro(numeric)', 'world_cb_pick_key(numeric)', 'world_cb_buff(text,jsonb,uuid)', 'world_cb_attack(jsonb,jsonb,jsonb,numeric,numeric)', 'world_cb_boost_credits(numeric,boolean,jsonb,uuid,numeric)'] loop
    execute format('revoke all on function public.%s from public, anon, authenticated', f);
    execute format('grant execute on function public.%s to fn_owner_field', f);
  end loop; end $g$;

create or replace function pg_temp.yh_sub(d text, o text, n text, tag text) returns text language plpgsql as $f$
begin
  if (length(d) - length(replace(d, o, ''))) / greatest(1, length(o)) <> 1 then raise exception '7.7.7n anchor %', tag; end if;
  return replace(d, o, n);
end $f$;
-- a부터 b까지(둘 다 포함, 한 번씩만 나와야 함)를 n으로
create or replace function pg_temp.yh_span(d text, a text, b text, n text, tag text) returns text language plpgsql as $f$
declare i int; j int;
begin
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '7.7.7n span start %', tag; end if;
  i := strpos(d, a); j := strpos(substr(d, i), b);
  if j = 0 then raise exception '7.7.7n span end %', tag; end if;
  return substr(d, 1, i - 1) || n || substr(d, i + j - 1 + length(b));
end $f$;

do $p$
declare d text; o text;
begin
  -- ① world_use_item: 물품 효과 표 → world_item_fx
  d := replace(pg_get_functiondef('public.world_use_item(text)'::regprocedure), E'\r\n', E'\n');
  if position('world_item_fx' in d) = 0 then
    d := pg_temp.yh_sub(d, E'bname text;\nBEGIN', E'bname text; cbfx jsonb;\nBEGIN', 'use_item decl');
    d := pg_temp.yh_span(d, E'  CASE v_base\n    WHEN ''tonic''', E'  END CASE;',
      E'  cbfx := public.world_item_fx(v_base);\n  hp := (cbfx ->> ''hp'')::int; mn := (cbfx ->> ''mn'')::int; spg := (cbfx ->> ''sp'')::int; er := (cbfx ->> ''er'')::int; stam := (cbfx ->> ''stam'')::int;\n  cures := array(select jsonb_array_elements_text(cbfx -> ''cures'')); buffs := array(select jsonb_array_elements_text(cbfx -> ''buffs''));', 'use_item case');
    execute d;
  end if;

  -- ② world_party_use_item: 같은 표(동료에게 쓰는 아홉 가지만)
  d := replace(pg_get_functiondef('public.world_party_use_item(uuid,text)'::regprocedure), E'\r\n', E'\n');
  if position('world_item_fx' in d) = 0 then
    d := pg_temp.yh_span(d, E'  case public.world_item_base(p_item_id)\n    when ''tonic''', E'  end case;',
      E'  if public.world_item_base(p_item_id) not in (''tonic'', ''herbal_extract'', ''herb'', ''medicine_base'', ''ward_talisman'', ''rejuv_pill'', ''grand_pill'', ''purify_water'', ''calm_brew'') then\n    raise exception ''동료에게 쓸 수 있는 것은 약과 부적입니다.''; end if;\n  hp := (public.world_item_fx(public.world_item_base(p_item_id)) ->> ''hp'')::int; mn := (public.world_item_fx(public.world_item_base(p_item_id)) ->> ''mn'')::int; er := (public.world_item_fx(public.world_item_base(p_item_id)) ->> ''er'')::int;\n  cures := array(select jsonb_array_elements_text(public.world_item_fx(public.world_item_base(p_item_id)) -> ''cures''));', 'party case');
    execute d;
  end if;

  -- ③ 원정 정산: 보급품 회복량
  d := replace(pg_get_functiondef('public.world_expedition_settle(uuid,integer)'::regprocedure), E'\r\n', E'\n');
  if position('world_item_fx' in d) = 0 then
    d := pg_temp.yh_sub(d, 'heal := case item when ''tonic'' then 35 when ''tonic_hq'' then 41 when ''herbal_extract'' then 22 when ''herbal_extract_hq'' then 26 else 12 end;',
      'heal := ceil(coalesce((public.world_item_fx(public.world_item_base(item)) ->> ''hp'')::numeric, 0) * case when item like ''%\_hq'' then 1.15 else 1 end)::int;', 'settle heal');
    execute d;
  end if;

  -- ④ 귀허 정산: 회복품·공격 굴림·기운 걸기·표적
  d := replace(pg_get_functiondef('public.world_gw_resolve(uuid)'::regprocedure), E'\r\n', E'\n');
  if position('world_cb_attack' in d) = 0 then
    d := pg_temp.yh_sub(d, 'd := case public.world_item_base(a ->> ''i'') when ''tonic'' then 35 when ''herbal_extract'' then 22 when ''rejuv_pill'' then 60 when ''grand_pill'' then 100 when ''banyo_salve'' then 70 else 0 end',
      'd := coalesce((public.world_item_fx(public.world_item_base(a ->> ''i'')) ->> ''hp'')::numeric, 0)', 'gw item');
    d := pg_temp.yh_span(d, E'      v_mb := case when coalesce((vfx -> ''might'' ->> ''n'')::int, 0) > 0', E'* (1 + coalesce((m.stats ->> ''solo_dmg'')::numeric, 0) / 100.0);',
      E'      cbr := public.world_cb_attack(m.stats, vfx, vbfx, 0.9, 0.2);\n      vfx := cbr -> ''fx''; vbfx := cbr -> ''bfx''; cr := (cbr ->> ''crit'')::boolean;\n      v_mb := cbr -> ''src'' ->> ''mb''; v_mp := (cbr -> ''src'' ->> ''mp'')::numeric; v_eb := cbr -> ''src'' ->> ''eb''; v_ep := (cbr -> ''src'' ->> ''ep'')::numeric;\n      v_cb := cbr -> ''src'' ->> ''cb''; v_cp := (cbr -> ''src'' ->> ''cp'')::numeric; v_cn := cbr -> ''src'' ->> ''cn'';\n      update public.world_gw_members set fx = vfx where fight_id = p_fight and owner_id = m.owner_id;\n      d := (cbr ->> ''d'')::numeric * (1 + coalesce((m.stats ->> ''solo_dmg'')::numeric, 0) / 100.0);', 'gw attack');
    -- 한 사람·모두에게 거는 기운
    d := pg_temp.yh_sub(d, 'when ''ward'' then update public.world_gw_members set fx = fx || jsonb_build_object(''ward'', jsonb_build_object(''n'', (e ->> ''n'')::int, ''pct'', (e ->> ''pct'')::int, ''by'', m.owner_id)) where',
      'when ''ward'' then update public.world_gw_members set fx = fx || public.world_cb_buff(''ward'', e, m.owner_id) where', 'gw ward');
    d := pg_temp.yh_sub(d, 'when ''ward_all'' then update public.world_gw_members set fx = fx || jsonb_build_object(''ward'', jsonb_build_object(''n'', (e ->> ''n'')::int, ''pct'', (e ->> ''pct'')::int, ''by'', m.owner_id)) where',
      'when ''ward_all'' then update public.world_gw_members set fx = fx || public.world_cb_buff(''ward_all'', e, m.owner_id) where', 'gw ward_all');
    d := pg_temp.yh_sub(d, 'when ''might'' then update public.world_gw_members set fx = fx || jsonb_build_object(''might'', jsonb_build_object(''n'', (e ->> ''n'')::int, ''pct'', (e ->> ''pct'')::int, ''by'', m.owner_id)) where',
      'when ''might'' then update public.world_gw_members set fx = fx || public.world_cb_buff(''might'', e, m.owner_id) where', 'gw might');
    d := pg_temp.yh_sub(d, 'when ''might_all'' then update public.world_gw_members set fx = fx || jsonb_build_object(''might'', jsonb_build_object(''n'', (e ->> ''n'')::int, ''pct'', (e ->> ''pct'')::int, ''by'', m.owner_id)) where',
      'when ''might_all'' then update public.world_gw_members set fx = fx || public.world_cb_buff(''might_all'', e, m.owner_id) where', 'gw might_all');
    d := pg_temp.yh_sub(d, 'when ''rally'' then update public.world_gw_members set fx = fx || jsonb_build_object(''might'', jsonb_build_object(''n'', 1, ''pct'', (e ->> ''pct'')::int, ''by'', m.owner_id)) where',
      'when ''rally'' then update public.world_gw_members set fx = fx || public.world_cb_buff(''rally'', e, m.owner_id) where', 'gw rally');
    d := pg_temp.yh_span(d, 'when ''resonance'' then update public.world_gw_members set fx = fx || jsonb_build_object(''might''', '''by'', m.owner_id)) where',
      'when ''resonance'' then update public.world_gw_members set fx = fx || public.world_cb_buff(''resonance'', e, m.owner_id) where', 'gw resonance');
    d := pg_temp.yh_sub(d, 'when ''crit_all'' then update public.world_gw_members set fx = fx || jsonb_build_object(''crit'', jsonb_build_object(''n'', (e ->> ''n'')::int, ''pct'', (e ->> ''pct'')::int, ''by'', m.owner_id)) where',
      'when ''crit_all'' then update public.world_gw_members set fx = fx || public.world_cb_buff(''crit_all'', e, m.owner_id) where', 'gw crit_all');
    d := pg_temp.yh_sub(d, 'when ''evade'' then update public.world_gw_members set fx = fx || jsonb_build_object(''evade'', jsonb_build_object(''n'', (e ->> ''n'')::int, ''pct'', (e ->> ''pct'')::int, ''by'', m.owner_id)) where',
      'when ''evade'' then update public.world_gw_members set fx = fx || public.world_cb_buff(''evade'', e, m.owner_id) where', 'gw evade');
    d := pg_temp.yh_sub(d, 'when ''crit_next'' then update public.world_gw_members set fx = fx || jsonb_build_object(''critnext'', m.owner_id) where',
      'when ''crit_next'' then update public.world_gw_members set fx = fx || public.world_cb_buff(''crit_next'', e, m.owner_id) where', 'gw crit_next');
    d := pg_temp.yh_sub(d, 'when ''gward'' then update public.world_gw_members set fx = fx || jsonb_build_object(''gward'', m.owner_id) where',
      'when ''gward'' then update public.world_gw_members set fx = fx || public.world_cb_buff(''gward'', e, m.owner_id) where', 'gw gward');
    d := pg_temp.yh_sub(d, 'when ''taunt'' then update public.world_gw_members set fx = fx || jsonb_build_object(''taunt'', jsonb_build_object(''n'', (e ->> ''n'')::int, ''pct'', (e ->> ''pct'')::int, ''pres'', (e ->> ''pres'')::int)) where',
      'when ''taunt'' then update public.world_gw_members set fx = fx || public.world_cb_buff(''taunt'', e, m.owner_id) where', 'gw taunt');
    -- 보호막은 봉연과 같게 더한다(전에는 새로 건 양으로 덮었다)
    d := pg_temp.yh_sub(d, 'when ''shield'' then update public.world_gw_members set fx = fx || jsonb_build_object(''shield'', (e ->> ''amt'')::int, ''shield_by'', m.owner_id) where',
      'when ''shield'' then update public.world_gw_members set fx = fx || jsonb_build_object(''shield'', coalesce((fx ->> ''shield'')::int, 0) + (e ->> ''amt'')::int, ''shield_by'', m.owner_id) where', 'gw shield');
    -- 표적
    d := pg_temp.yh_sub(d, 'order by -ln(greatest(random(), 1e-9)) / power(greatest(1, coalesce((x.stats ->> ''pres'')::numeric, 30) + coalesce((x.fx -> ''taunt'' ->> ''pres'')::numeric, 0)), 1.3) limit 1',
      'order by public.world_cb_pick_key(coalesce((x.stats ->> ''pres'')::numeric, 30) + coalesce((x.fx -> ''taunt'' ->> ''pres'')::numeric, 0)) limit 1', 'gw pick');
    -- 선언: cbr
    d := regexp_replace(d, E'\ndeclare ', E'\ndeclare cbr jsonb; ', 'i');
    execute d;
  end if;

  -- ⑤ 귀허 늘려 준 몫 → 공용 계산
  create or replace function public.world_gw_credit_hit(p_fight uuid, p_uid uuid, p_d numeric, p_cr boolean, p_mb text, p_mp numeric, p_eb text, p_ep numeric, p_cb text, p_cp numeric, p_cn text, p_crit numeric)
  returns void language plpgsql security definer set search_path to 'pg_catalog', 'public' as $fn$
  declare x jsonb;
  begin
    for x in select * from jsonb_array_elements(public.world_cb_boost_credits(p_d, p_cr, jsonb_build_object('mb', p_mb, 'mp', p_mp, 'eb', p_eb, 'ep', p_ep, 'cb', p_cb, 'cp', p_cp, 'cn', p_cn), p_uid, p_crit)) loop
      perform public.world_gw_credit(p_fight, (x ->> 0)::uuid, (x ->> 1)::numeric, x ->> 2);
    end loop;
  end $fn$;

  -- ⑥ 봉연·결전: 공격 굴림·기운 걸기·표적
  d := replace(pg_get_functiondef('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure), E'\r\n', E'\n');
  if position('world_cb_attack' in d) = 0 then
    d := pg_temp.yh_sub(d, 'bt int; tick boolean := true; bnow numeric;', 'bt int; tick boolean := true; bnow numeric; cbr jsonb; cbc jsonb;', 'raid decl');
    d := pg_temp.yh_span(d, E'    bm := f -> ''might'' ->> ''by'';', E'    credit := greatest(0, credit);',
      E'    cbr := public.world_cb_attack(st, f, rfx, 0.85, 0.3);\n    f := cbr -> ''fx''; rfx := cbr -> ''bfx''; crit := (cbr ->> ''crit'')::boolean;\n    if rd.kind = ''final'' and (select count(*) from public.world_raid_members where raid_id = p_raid) = 1 then\n      mul := mul * (1 + coalesce((public.world_solo_aid(c.job_key) ->> ''final_dmg'')::numeric, (public.world_solo_aid(c.job_key) ->> ''solo_dmg'')::numeric, 0) / 100.0);\n    elsif rd.kind = ''final'' then mul := mul * (1 + coalesce((public.world_solo_aid(c.job_key) ->> ''final_all'')::numeric, 0) / 100.0); end if;\n    dmg := greatest(1, round((cbr ->> ''d'')::numeric * mul))::int;\n    rd.hp := greatest(case when rd.fx ? ''last_night'' then ceil(rd.max_hp * 0.03)::int else 0 end, rd.hp - dmg); mb.dmg := mb.dmg + dmg; credit := 0;\n    -- 늘려 준 몫은 건 사람에게(공용 world_cb_boost_credits), 남은 몫이 내 기여\n    for cbc in select * from jsonb_array_elements(public.world_cb_boost_credits(dmg, crit, cbr -> ''src'', uid, (st ->> ''crit'')::numeric)) loop\n      if cbc ->> 2 = ''dmg'' then credit := (cbc ->> 1)::numeric; else perform public.world_raid_credit(p_raid, (cbc ->> 0)::uuid, (cbc ->> 1)::numeric, ''boost''); end if;\n    end loop;', 'raid attack');
    d := pg_temp.yh_span(d, E'      if k in (''ward'', ''might'', ''evade'') then f := f || jsonb_build_object(k,', E'      elsif k = ''crit_next'' then f := f || jsonb_build_object(''crit_next'', uid);',
      E'      if k in (''ward'', ''might'', ''evade'', ''gward'', ''crit_next'') then f := f || public.world_cb_buff(k, v, uid);', 'raid self buff');
    d := pg_temp.yh_span(d, E'          when k in (''ward'', ''might'', ''evade'') then fx || jsonb_build_object(k,', E'          when k = ''crit_next'' then fx || jsonb_build_object(''crit_next'', uid)',
      E'          when k in (''ward'', ''might'', ''evade'', ''gward'', ''crit_next'') then fx || public.world_cb_buff(k, v, uid)', 'raid ally buff');
    d := pg_temp.yh_span(d, E'      update public.world_raid_members x set fx = case k\n          when ''ward_all''', E'end\n       where x.raid_id = p_raid and x.owner_id <> uid',
      E'      update public.world_raid_members x set fx = x.fx || public.world_cb_buff(k, v, uid)\n       where x.raid_id = p_raid and x.owner_id <> uid', 'raid all buff');
    d := pg_temp.yh_span(d, E'      f := case k\n          when ''ward_all''', E'          else f || jsonb_build_object(''might'', jsonb_build_object(''pct'', v -> ''pct'', ''n'', v -> ''n'', ''by'', uid)) end;',
      E'      f := f || public.world_cb_buff(k, v, uid);', 'raid all self');
    d := pg_temp.yh_sub(d, E'      f := f || jsonb_build_object(''taunt'', jsonb_build_object(''pres'', v -> ''pres'', ''pct'', v -> ''pct'', ''n'', v -> ''n''));',
      E'      f := f || public.world_cb_buff(''taunt'', v, uid);', 'raid taunt');
    -- 표적: 무게 합 루프 → 공용 뽑기
    d := pg_temp.yh_span(d, E'    select coalesce(sum(power(greatest(5, (x.stats ->> ''pres'')::numeric', E'      exit when acc >= rnd;\n    end loop;',
      E'    select x.owner_id, x.level into pick, lv from public.world_raid_members x\n     where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval ''120 seconds''\n     order by public.world_cb_pick_key((x.stats ->> ''pres'')::numeric + coalesce((x.fx -> ''taunt'' ->> ''pres'')::numeric, 0)) limit 1;', 'raid pick');
    execute d;
  end if;

  -- ⑦ 파티 토벌·원정 합동 전투 표적
  d := replace(pg_get_functiondef('public.world_pfight_round(uuid,integer)'::regprocedure), E'\r\n', E'\n');
  if position('world_cb_pick_key' in d) = 0 then
    d := pg_temp.yh_sub(d, 'order by -ln(greatest(random(), 1e-9)) / power(greatest(1, coalesce((public.world_combat_stats(pm.owner_id) ->> ''presence'')::numeric, 30)), 1.3) limit 1',
      'order by public.world_cb_pick_key((public.world_combat_stats(pm.owner_id) ->> ''presence'')::numeric) limit 1', 'pfight pick');
    execute d;
  end if;
  d := replace(pg_get_functiondef('public.world_exp_fight_story(uuid,text,text,jsonb,integer,boolean,integer,integer,jsonb,double precision,double precision,timestamp with time zone,integer,text,text,integer,jsonb)'::regprocedure), E'\r\n', E'\n');
  if position('world_cb_aggro' in d) = 0 then
    o := d;
    d := replace(d, '(greatest(5, p_pres) ^ 1.3)', 'public.world_cb_aggro(p_pres)::float8');
    d := replace(d, '(greatest(5, (x ->> ''pres'')::float8) ^ 1.3)', 'public.world_cb_aggro((x ->> ''pres'')::numeric)::float8');
    d := replace(d, '(greatest(5, (al ->> ''pres'')::float8) ^ 1.3)', 'public.world_cb_aggro((al ->> ''pres'')::numeric)::float8');
    if d = o or position('^ 1.3' in d) > 0 then raise exception '7.7.7n anchor fight_story'; end if;
    execute d;
  end if;
end $p$;

update public.world_app_meta set value = '20261104204100' where key = 'db_version';
