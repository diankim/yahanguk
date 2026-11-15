create or replace function pg_temp.yh_fix2(p_fn regprocedure, p_old text, p_new text) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); n int;
begin
  n := (length(src) - length(replace(src, p_old, ''))) / greatest(length(p_old), 1);
  if n <> 1 then raise exception 'yh_fix2 %: 조각이 % 번 있음', p_fn, n; end if;
  execute replace(src, p_old, p_new);
end $f$;

create or replace function pg_temp.yh_setjson(p_fn regprocedure, p_j jsonb) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); body text := (select prosrc from pg_proc where oid = p_fn);
begin
  if position(body in src) = 0 then raise exception 'yh_setjson %: 본문을 못 찾음', p_fn; end if;
  execute replace(src, body, ' select ' || quote_literal(p_j::text) || '::jsonb ');
end $f$;

select pg_temp.yh_setjson('public.world_avatar_parts()'::regprocedure, '@PARTS@'::jsonb);

select pg_temp.yh_setjson('public.world_outfit_rules()'::regprocedure, public.world_outfit_rules() || jsonb_build_object(
  'pool', (public.world_outfit_rules() -> 'pool') || '["of_top_hoodie", "of_bottom_jeans"]'::jsonb,
  'titles', '{"raid_win1": "top:shadowrobe", "mk_kill1": "bottom:inkpleat", "gw_kill1": "acc:gat", "river_angler": "top:fisher", "deep_walker": "bottom:haengjeon", "gather_100": "acc:paeraengi", "codex_50": "acc:horns", "wed_vow": "acc:jokduri", "tn_top4": "acc:shades", "ch5_done": "top:doroni", "ct_cooking_15": "top:apron", "hs_furn30": "bottom:flowerskirt", "ch1_done": "acc:flowercrown", "pet_5": "acc:catears", "spar_win1": "acc:ribbon"}'::jsonb,
  'feast', '{"n": 5, "look": "top:saekdong"}'::jsonb,
  'src', '{
    "top:guard": "호위 무사 기본 옷 · 옷 꾸러미", "top:scout": "월궁 사수 기본 옷 · 옷 꾸러미", "top:exorcist": "퇴마관 기본 옷 · 옷 꾸러미", "top:medic": "의무관 기본 옷 · 옷 꾸러미",
    "top:seal": "봉인술사 기본 옷 · 옷 꾸러미", "top:shadow": "암영 검객 기본 옷 · 옷 꾸러미", "top:tamer": "조련사 기본 옷 · 옷 꾸러미",
    "bottom:guard": "호위 무사 기본 옷 · 옷 꾸러미", "bottom:scout": "월궁 사수 기본 옷 · 옷 꾸러미", "bottom:exorcist": "퇴마관 기본 옷 · 옷 꾸러미", "bottom:medic": "의무관 기본 옷 · 옷 꾸러미",
    "bottom:seal": "봉인술사 기본 옷 · 옷 꾸러미", "bottom:shadow": "암영 검객 기본 옷 · 옷 꾸러미", "bottom:tamer": "조련사 기본 옷 · 옷 꾸러미",
    "top:jeogori": "직조 제작 · 옷 꾸러미", "top:vest": "상점(백등 야시장·구름나루·잔불촌) · 옷 꾸러미", "top:magoja": "직조 제작 · 옷 꾸러미", "top:jeoksam": "상점(구름나루·철벽 고찰·잔불촌) · 옷 꾸러미",
    "top:dallyeong": "정통파 세력 비고", "top:furvest": "북령맹 세력 비고", "top:saekdong": "세력 행사에 다섯 번 함께하기", "top:shadowrobe": "봉연의 그림자를 처음 걷어 내기(칭호 「그림자를 걷은 자」)",
    "top:fisher": "칭호 「강태공」", "top:galot": "상점(잔불촌)", "top:silkcheollik": "비장고 마지막 방(귀한·봉인된 비장도)", "top:hoodie": "옷 꾸러미", "top:knitvest": "상점(백등 야시장)",
    "bottom:chima": "직조 제작 · 옷 꾸러미", "bottom:redmoon": "적월교 세력 비고", "bottom:emberwrap": "남명회 세력 비고", "bottom:inkpleat": "먹그림자 깊은 명부 처치(칭호 「먹그림자를 보낸 이」)",
    "bottom:haengjeon": "칭호 「심처 답파」", "bottom:jjokchima": "직조 제작", "bottom:leatherboots": "가죽 공예 제작", "bottom:okchima": "상점(구름나루)", "bottom:jeans": "옷 꾸러미", "bottom:jogger": "직조 제작",
    "acc:flowerpin": "보조 퀘스트 「객사 별채」", "acc:glasses": "법구 공예 제작 · 옷 꾸러미", "acc:earring": "법구 공예 제작 · 옷 꾸러미", "acc:scarf": "상점(백등 야시장·철벽 고찰) · 옷 꾸러미", "acc:norigae": "직조 제작 · 옷 꾸러미",
    "acc:mk_hairpin": "묵적록 연작 「희수」 마지막 편", "acc:mk_nameplate": "묵적록 연작 「다온」 마지막 편", "acc:mk_lotus": "묵적록 연작 「월하」 마지막 편", "acc:foxmask": "비무회 우승",
    "acc:gat": "귀허의 주인 처치(칭호 「귀허를 닫은 자」)", "acc:jokduri": "혼례 올리기(칭호 「백년가약」)", "acc:lotushood": "흑련회 세력 비고", "acc:satgat": "수향연맹 세력 비고", "acc:starpin": "천명원 세력 비고",
    "acc:paeraengi": "칭호 「부지런한 손」", "acc:horns": "칭호 「백귀 사냥꾼」", "acc:nambawi": "상점(철벽 고찰)", "acc:cap": "선배와 새내기 · 챙김 쓰기", "acc:headphone": "법구 공예 제작", "acc:shades": "비무회 4강(칭호 「사강의 이름」)",
    "top:doroni": "주 이야기 5장 마치기(칭호 「이름 없는 종지기」)", "top:durumagi": "상점(본부 정청·본부 객사)", "top:apron": "칭호 「간 보는 손」(요리 15단계)", "bottom:shorts": "상점(십삼문 암시장)", "bottom:flowerskirt": "칭호 「가구 수집가」(별채 가구 30)",
    "acc:flowercrown": "주 이야기 1장 마치기(칭호 「붉은 인장 해결자」)", "acc:catears": "칭호 「동무 다섯」(꼬마 동무 다섯)", "acc:ribbon": "비무 첫 승리(칭호 「첫 승리의 맛」)"
  }'::jsonb));

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, equipment_traits) values
('of_top_dallyeong', '청사 단령', 'outfit', 3, '정청 관리의 둥근 깃 관복입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, false, 100, 1, '{"look": "top:dallyeong"}'::jsonb),
('of_top_furvest', '설원 털배자', 'outfit', 3, '북령의 눈바람을 막는 털 덧옷입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, false, 100, 1, '{"look": "top:furvest"}'::jsonb),
('of_bottom_redmoon', '붉은 달 치마바지', 'outfit', 3, '적월교 제례 때 입는 통 넓은 바지입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, false, 100, 1, '{"look": "bottom:redmoon"}'::jsonb),
('of_bottom_emberwrap', '잔불 각반 바지', 'outfit', 3, '남명회 봉화꾼이 정강이에 감는 불빛 각반입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, false, 100, 1, '{"look": "bottom:emberwrap"}'::jsonb),
('of_acc_lotushood', '흑련 두건', 'outfit', 3, '흑련회 장부지기가 쓰는 검은 두건입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, false, 100, 1, '{"look": "acc:lotushood"}'::jsonb),
('of_acc_satgat', '삿갓', 'outfit', 3, '수향연맹 뱃사람이 비를 가리는 삿갓입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, false, 100, 1, '{"look": "acc:satgat"}'::jsonb),
('of_acc_starpin', '별빛 떨잠', 'outfit', 3, '천명원 관측관이 별자리를 따라 꽂는 떨잠입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, false, 100, 1, '{"look": "acc:starpin"}'::jsonb),
('of_top_galot', '갈옷 적삼', 'outfit', 2, '감물을 들여 볕에 말린 적삼입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 350, 1, '{"look": "top:galot"}'::jsonb),
('of_bottom_okchima', '옥색 치마', 'outfit', 2, '물빛을 닮은 옥색 치마입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 380, 1, '{"look": "bottom:okchima"}'::jsonb),
('of_acc_nambawi', '남바위', 'outfit', 2, '귀까지 덮는 털 두른 겨울 쓰개입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 420, 1, '{"look": "acc:nambawi"}'::jsonb),
('of_top_knitvest', '털실 조끼', 'outfit', 2, '털실로 마름모를 떠 넣은 조끼입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 400, 1, '{"look": "top:knitvest"}'::jsonb),
('of_bottom_jjokchima', '쪽빛 홑치마', 'outfit', 2, '쪽물을 들인 가벼운 홑치마입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 460, 1, '{"look": "bottom:jjokchima"}'::jsonb),
('of_bottom_leatherboots', '가죽 장화 바지', 'outfit', 2, '무릎까지 오는 가죽 장화를 받쳐 입는 바지입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 300, 1, '{"look": "bottom:leatherboots"}'::jsonb),
('of_bottom_jogger', '줄무늬 운동 바지', 'outfit', 2, '옆선에 흰 줄을 넣은 편한 바지입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 390, 1, '{"look": "bottom:jogger"}'::jsonb),
('of_acc_headphone', '소리 귀덮개', 'outfit', 2, '영유리 울림판을 귀에 대는 법구입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 340, 1, '{"look": "acc:headphone"}'::jsonb),
('of_top_silkcheollik', '비단 철릭', 'outfit', 4, '붉은 비단에 금띠를 두른 무관의 철릭입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 1200, 1, '{"look": "top:silkcheollik"}'::jsonb),
('of_top_hoodie', '쓰개 달린 겉옷', 'outfit', 2, '머리에 쓰는 쓰개가 등에 달린 겉옷입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 400, 1, '{"look": "top:hoodie"}'::jsonb),
('of_bottom_jeans', '청바지와 운동화', 'outfit', 2, '푸른 물을 들인 질긴 바지와 흰 신입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 400, 1, '{"look": "bottom:jeans"}'::jsonb),
('of_top_durumagi', '흰 두루마기', 'outfit', 2, '옷고름을 길게 맨 흰 겉옷입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 380, 1, '{"look": "top:durumagi"}'::jsonb),
('of_bottom_shorts', '무릎 반바지', 'outfit', 2, '무릎 위까지 오는 짧은 바지와 흰 신입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 300, 1, '{"look": "bottom:shorts"}'::jsonb),
('of_acc_cap', '챙 모자', 'outfit', 3, '앞에 챙을 단 둥근 모자입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, false, 100, 1, '{"look": "acc:cap"}'::jsonb)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = 1, equipment_traits = excluded.equipment_traits;

insert into public.world_faction_vault(faction_id, item_id, rank_need, price, sort, kind) values
('night_office', 'of_top_dallyeong', 3, 200, 906, 'item'),
('north_league', 'of_top_furvest', 3, 200, 906, 'item'),
('red_moon_cult', 'of_bottom_redmoon', 3, 200, 906, 'item'),
('southern_remnant', 'of_bottom_emberwrap', 3, 200, 906, 'item'),
('black_lotus', 'of_acc_lotushood', 3, 200, 906, 'item'),
('river_alliance', 'of_acc_satgat', 3, 200, 906, 'item'),
('mandate_court', 'of_acc_starpin', 3, 200, 906, 'item')
on conflict do nothing;

insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max) values
('south_market', 'of_top_galot', 350, 0, 5), ('river_market', 'of_bottom_okchima', 380, 0, 5),
('north_market', 'of_acc_nambawi', 420, 0, 5), ('capital_market', 'of_top_knitvest', 400, 0, 5),
('night_office_store', 'of_top_durumagi', 380, 0, 5), ('underworld_market', 'of_bottom_shorts', 300, 0, 5)
on conflict do nothing;

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, description, minimum_level, recipe_difficulty, craft_field) values
('r_of_jjokchima', '쪽빛 홑치마 짓기', 'of_bottom_jjokchima', 1, '{"silk": 3, "cloud_cotton": 1, "spirit_thread": 1}', '영사에 쪽물을 들여 홑치마를 짓습니다.', 15, 2, 'weaving'),
('r_of_leatherboots', '가죽 장화 바지 짓기', 'of_bottom_leatherboots', 1, '{"beast_hide": 3, "resin": 1, "lacquer": 1}', '요수 가죽을 옻칠해 장화를 짓고 바지를 받쳐 입습니다.', 12, 2, 'leatherwork'),
('r_of_jogger', '줄무늬 운동 바지 짓기', 'of_bottom_jogger', 1, '{"cloud_cotton": 3, "spirit_thread": 1}', '운면을 두껍게 짜 옆선에 흰 줄을 넣습니다.', 20, 2, 'weaving'),
('r_of_headphone', '소리 귀덮개 깎기', 'of_acc_headphone', 1, '{"ore": 2, "spirit_glass": 1, "beast_hide": 1}', '영유리 울림판을 깎아 가죽 귀덮개에 끼웁니다.', 20, 2, 'artifice')
on conflict (recipe_id) do update set ingredients = excluded.ingredients, minimum_level = excluded.minimum_level, output_item = excluded.output_item, craft_field = excluded.craft_field;

select pg_temp.yh_setjson('public.world_bijang_rules()'::regprocedure, jsonb_set(jsonb_set(public.world_bijang_rules(),
  '{final,tiers,2}', (public.world_bijang_rules() -> 'final' -> 'tiers' -> '2') || '[{"id": "of_top_silkcheollik", "w": 2, "n": 1}]'::jsonb),
  '{final,tiers,3}', (public.world_bijang_rules() -> 'final' -> 'tiers' -> '3') || '[{"id": "of_top_silkcheollik", "w": 2, "n": 1}]'::jsonb));

select pg_temp.yh_setjson('public.world_mentor_rules()'::regprocedure, jsonb_set(public.world_mentor_rules(), '{shop}',
  (public.world_mentor_rules() -> 'shop') || '[{"key": "of_acc_cap", "kind": "item", "name": "챙 모자", "desc": "내 모습 장신구", "price": 50}]'::jsonb));

create or replace function public.world_outfit_give(p_uid uuid, p_look text, p_why text)
 returns boolean language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare nm text := public.world_avatar_parts() -> 'outfits' -> p_look ->> 'name';
begin
  if p_uid is null or nm is null then return false; end if;
  insert into public.world_wardrobe(owner_id, look_key) values (p_uid, p_look) on conflict do nothing;
  if not found then return false; end if;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_uid, 'outfit_got', '새 옷: ' || nm, p_why || ' 「' || nm || '」을(를) 옷장에 넣었습니다. 「내 모습」에서 골라 입을 수 있습니다.', jsonb_build_object('look', p_look));
  return true;
end $function$;
revoke all on function public.world_outfit_give(uuid, text, text) from public, anon, authenticated;

create or replace function public.world_outfit_title_trg()
 returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare lk text := public.world_outfit_rules() -> 'titles' ->> new.title_key;
begin
  if lk is not null then
    perform public.world_outfit_give(new.owner_id, lk, '칭호 「' || coalesce((select title_name from public.world_title_catalog where title_key = new.title_key), new.title_key) || '」을(를) 얻은 기념으로');
  end if;
  return null;
end $function$;
revoke all on function public.world_outfit_title_trg() from public, anon, authenticated;
drop trigger if exists trg_world_outfit_title on public.world_character_titles;
create trigger trg_world_outfit_title after insert on public.world_character_titles for each row execute function public.world_outfit_title_trg();

grant execute on function public.world_outfit_give(uuid, text, text) to fn_owner_field;
select pg_temp.yh_fix2('public.world_feast_tick()'::regprocedure,
$o$        n := n + 1;
      end loop;$o$,
$n$        n := n + 1;
        if (select count(*) from public.world_feast_members y where y.owner_id = m.owner_id) >= (public.world_outfit_rules() -> 'feast' ->> 'n')::int then
          perform public.world_outfit_give(m.owner_id, public.world_outfit_rules() -> 'feast' ->> 'look', '세력 행사에 ' || (public.world_outfit_rules() -> 'feast' ->> 'n') || '번 함께한 기념으로');
        end if;
      end loop;$n$);

select pg_temp.yh_fix2('public.world_notify_group(text)'::regprocedure,
$o$when p_kind in ('reward', 'skill_rerank') then 'reward'$o$, $n$when p_kind in ('reward', 'skill_rerank', 'outfit_got') then 'reward'$n$);

insert into public.world_wardrobe(owner_id, look_key)
select t.owner_id, r.value from public.world_character_titles t
  join jsonb_each_text(public.world_outfit_rules() -> 'titles') r on r.key = t.title_key
  join public.world_characters c on c.owner_id = t.owner_id
on conflict do nothing;
insert into public.world_wardrobe(owner_id, look_key)
select y.owner_id, public.world_outfit_rules() -> 'feast' ->> 'look' from public.world_feast_members y
  join public.world_characters c on c.owner_id = y.owner_id
 group by y.owner_id having count(*) >= (public.world_outfit_rules() -> 'feast' ->> 'n')::int
on conflict do nothing;

update public.world_patch_notes set body = body || '

## 2.4.0
- 「내 모습」 옷이 서른일곱 벌 늘었습니다(윗옷 12·아랫옷 11·장신구 14). 갓·두건·족두리·삿갓 같은 머리쓰개는 장신구 칸에 씁니다.
- 옷마다 얻는 곳이 다릅니다: 세력 비고(세력마다 하나), 세력 행사에 다섯 번 함께하기, 봉연의 그림자·귀허의 주인·먹그림자, 비장고 마지막 방, 상점(본부 정청·백등 야시장·구름나루·철벽 고찰·잔불촌·십삼문 암시장), 직조·가죽 공예·법구 공예 제작, 옷 꾸러미, 선배와 새내기 챙김, 주 이야기 1·5장, 그리고 요리·채집·낚시·탐사·도감·별채·동무·비무 같은 활동 칭호와 혼례. 세력 비고 옷은 세력마다 하나라 한 사람에게는 한 벌이고, 나머지는 누구나 얻을 수 있습니다.
- 칭호로 얻는 옷은 칭호를 얻는 순간 옷장에 바로 들어갑니다. 이미 그 칭호를 가진 조사원은 옷장에 넣어 두었습니다.
- 「내 모습」에서 아직 없는 옷을 누르면 어디서 얻는지 보입니다.
' where note_id = '2.3.0' and body not like '%## 2.4.0%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118180000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
