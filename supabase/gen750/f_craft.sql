-- ── 제작(7.5.0): 계열마다 기술·품질, 우수품, 품질은 개수를 바꾸지 않음 ─────────
create or replace function public.world_craft_item(p_recipe_id text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_crafting_recipes%rowtype; inv jsonb; tool_tier int := 0;
  k text; need int; have int; out_qty int; quality int; result_text text; loc_bonus int := 0; st jsonb; take int; from_st jsonb := '{}'::jsonb; room int;
  sk text[]; line text; lname text; ln_rank int; lb numeric; rq int; free_mat boolean := false; notes text[] := '{}'; rf text;
  ocat text; is_furn boolean; hq_ok boolean; is_hq boolean := false; hq_th int := 85; out_item text; left_n int; part text; saved boolean;
  cs_pct numeric; cx_pct numeric;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 생성하세요.'; end if;
  if c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태입니다. 다른 조사원의 구조를 받아야 행동할 수 있습니다.'; end if;
  select * into r from public.world_crafting_recipes where recipe_id = p_recipe_id;
  if not found then raise exception '존재하지 않는 제작법입니다.'; end if;
  if c.level < r.minimum_level then raise exception '이 제작법은 레벨 %부터 해금됩니다.', r.minimum_level; end if;
  if r.required_skill is not null and coalesce((c.skill_progress -> r.required_skill ->> 'rank')::int, 1) < r.required_skill_rank then
    raise exception '% 기술 %단계가 필요합니다(지금 %단계). 캐릭터 › 기술에서 확인하세요.', public.world_line_name(r.required_skill), r.required_skill_rank, coalesce((c.skill_progress -> r.required_skill ->> 'rank')::int, 1);
  end if;
  if r.required_job is not null and c.job_key <> r.required_job and c.job_key <> 'analyst' then
    raise exception '필요 직업: %', case r.required_job when 'exorcist' then '퇴마관' when 'scout' then '현장 조사원' when 'medic' then '의무관' when 'sealmaster' then '봉인술사' when 'analyst' then '백공 기술관' when 'artificer' then '호위 무사' else r.required_job end;
  end if;
  if r.required_location is not null and (coalesce(c.location, '') = r.required_location or (r.required_location = '야행국 본부 정청' and c.location in ('본부 로비', '야행국 본부 · 정청'))
     or (r.required_location = '연무장·팔괘진' and c.location in ('훈련실', '야행국 본부 · 연무장')) or (r.required_location = '장서각 지하서고' and c.location in ('기록 보관실', '야행국 본부 · 장서각'))) then loc_bonus := 12; end if;
  sk := public.world_skill_procs(uid);
  line := public.world_craft_line_of(r.craft_field); lname := public.world_line_name(line);
  ln_rank := coalesce((c.skill_progress -> line ->> 'rank')::int, 1);
  select i.category into ocat from public.world_item_catalog i where i.item_id = r.output_item;
  is_furn := ocat = 'furniture';
  hq_ok := exists (select 1 from public.world_item_catalog h where h.item_id = r.output_item || '_hq' and h.base_item_id = r.output_item);
  inv := coalesce(c.inventory, '{}'::jsonb);
  if exists (select 1 from public.world_current_shop(uid)) and not public.world_banyo_here(uid) then select items into st from public.world_storage where owner_id = uid for update; end if;
  st := coalesce(st, '{}'::jsonb);
  if r.required_tool is not null then
    select max(coalesce(i.tier, 0)) into tool_tier from public.world_item_catalog i where public.world_tool_covers(i.item_id, r.required_tool)
      and (coalesce((c.inventory ->> i.item_id)::numeric, 0) > 0 or exists (select 1 from public.world_character_equipment e where e.owner_id = uid and e.item_id = i.item_id));
    if tool_tier is null then raise exception '필요 도구가 가방에 있어야 합니다: %', coalesce((select ic.item_name from public.world_item_catalog ic where ic.item_id = r.required_tool), r.required_tool); end if;
    if coalesce(tool_tier, 0) < r.required_tool_tier then raise exception '도구 단계가 부족합니다. 필요 단계: %', r.required_tool_tier; end if;
  end if;
  -- 재료: 기본 물품 + 우수품(가방·창고)을 함께 센다
  for k, need in select key, value::text::int from jsonb_each(r.ingredients) loop
    have := coalesce((inv ->> k)::int, 0) + coalesce((st ->> k)::int, 0) + coalesce((inv ->> (k || '_hq'))::int, 0) + coalesce((st ->> (k || '_hq'))::int, 0);
    if have < need then raise exception '재료 부족: % (필요 %, 보유 %)', coalesce((select ic.item_name from public.world_item_catalog ic where ic.item_id = k), k), need, have; end if;
  end loop;
  -- 숙달(50단계): 10%는 재료를 하나도 쓰지 않는다
  free_mat := (line || '_m50') = any (sk) and random() < 0.10;
  if free_mat then notes := notes || ('「' || public.world_skill_name(line || '_m50') || '」 재료를 하나도 쓰지 않았다');
  else
    for k, need in select key, value::text::int from jsonb_each(r.ingredients) loop
      -- 약재 바탕 아끼기(연금 24b): 약제 바탕·농축 약초액은 30% 쓰지 않는다
      if line = 'alchemy' and 'alchemy_c24b' = any (sk) and k in ('medicine_base', 'herbal_extract') and random() < 0.30 then
        notes := notes || ('「약재 바탕 아끼기」 ' || coalesce((select item_name from public.world_item_catalog where item_id = k), '재료') || '을(를) 아꼈다'); continue;
      end if;
      left_n := need;
      -- 기본 먼저(가방 → 창고), 모자라면 우수품(가방 → 창고)
      foreach part in array array[k, k || '_hq'] loop
        exit when left_n <= 0;
        take := least(left_n, greatest(0, coalesce((inv ->> part)::int, 0)));
        if take > 0 then inv := jsonb_set(inv, array[part], to_jsonb(coalesce((inv ->> part)::int, 0) - take), true); left_n := left_n - take; end if;
        take := least(left_n, greatest(0, coalesce((st ->> part)::int, 0)));
        if take > 0 then st := jsonb_set(st, array[part], to_jsonb(coalesce((st ->> part)::int, 0) - take)); from_st := from_st || jsonb_build_object(part, coalesce((from_st ->> part)::int, 0) + take); left_n := left_n - take; end if;
      end loop;
    end loop;
    inv := (select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from jsonb_each(inv) where not (jsonb_typeof(value) = 'number' and value::text::numeric <= 0));
  end if;
  if from_st <> '{}'::jsonb then
    update public.world_storage set items = (select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from jsonb_each(st) where jsonb_typeof(value) = 'number' and value::text::int > 0), updated_at = now() where owner_id = uid;
  end if;
  -- 품질 = 10 + 계열 단계 + 계열 기본 기술(≤40) + 분야 일치 12 + 백공 15 + 장비·칭호·음식·상태 + 제작 공구 + 장소 12 − 8×난이도 + 0~19
  rq := floor(random() * 20)::int;
  if (line || '_c24a') = any (sk) then rq := greatest(rq, floor(random() * 20)::int); end if;
  lb := least(40, public.world_line_base(c.skill_progress, line, 'craft_quality'));
  quality := least(100, greatest(0, 10 + ln_rank + lb::int
    + case when c.crafting_profession = r.craft_field then 12 else 0 end
    + case when c.job_key = 'analyst' then 15 else 0 end
    + case when r.required_skill is not null and exists (select 1 from public.world_character_equipment e join public.world_item_catalog i on i.item_id = e.item_id where e.owner_id = uid and i.crafting_specialization = r.required_skill) then 10 else 0 end
    + public.world_craft_tool_bonus(uid, r.craft_field)
    + (public.world_status_effect_total('craft_quality') + public.world_title_bonus('craft_quality') + public.world_title_bonus('cq_' || line))::int
    + public.world_status_effect_total('action_quality_pct')::int
    + loc_bonus - r.recipe_difficulty * 8 + rq));
  -- 우수품: 품질 85(30단계 추가 기술이 있으면 80) 이상
  if (line || '_x30') = any (sk) then hq_th := 80; end if;
  is_hq := hq_ok and quality >= hq_th;
  out_item := case when is_hq then r.output_item || '_hq' else r.output_item end;
  room := public.world_bag_room(inv, out_item, public.world_bag_limit(uid));
  if room < r.output_qty then raise exception '가방에 완성품을 넣을 자리가 없습니다. 가방을 한 칸 비운 뒤 다시 제작하세요.'; end if;
  out_qty := r.output_qty;
  -- 개수 덤(가구는 언제나 하나)
  if not is_furn then
    if line = 'carpentry' and 'carpentry_c24b' = any (sk) and r.output_item in ('ammo_arrow', 'ammo_bolt', 'ammo_dart') then
      out_qty := ceil(out_qty * 1.25)::int; notes := notes || '「살대 다듬기」 25% 더 만들었다'::text; end if;
    if line = 'wardcraft' and 'wardcraft_c24b' = any (sk) and ocat = 'consumable' then
      out_qty := ceil(out_qty * 1.25)::int; notes := notes || '「부적 묶음」 25% 더 만들었다'::text; end if;
    if line = 'cooking' and 'cooking_c24b' = any (sk) and r.output_item = 'fish_fillet' and random() < 0.30 then
      out_qty := out_qty + 1; notes := notes || '「생선 손질 솜씨」 하나 더'::text; end if;
    if line in ('weaving', 'leatherwork', 'wardcraft', 'alchemy') and (line || '_c43a') = any (sk) and random() < 0.15 then
      out_qty := out_qty + 1; notes := notes || ('「' || public.world_skill_name(line || '_c43a') || '」 하나 더'); end if;
    if line = 'cooking' and 'cooking_c43a' = any (sk) and ocat = 'consumable' and random() < 0.15 then
      out_qty := out_qty + 1; notes := notes || '「넉넉한 솥」 한 그릇 더'::text; end if;
    cx_pct := public.world_title_bonus('cx_' || line) + public.world_title_bonus('cx_all');
    if cx_pct > 0 and random() * 100 < cx_pct then out_qty := out_qty + 1; notes := notes || '칭호 덕에 하나 더'::text; end if;
  end if;
  out_qty := greatest(r.output_qty, least(room, out_qty));
  inv := jsonb_set(inv, array[out_item], to_jsonb(coalesce((inv ->> out_item)::int, 0) + out_qty), true);
  -- 재료 돌려받기(13단계 추가 기술 10% · 칭호 cs_), 금단(연금 43b 30%, 가장 비싼 재료), 살림 목수(목공 43b, 가구 25%)
  if not free_mat and r.ingredients <> '{}'::jsonb then
    saved := false;
    cs_pct := public.world_title_bonus('cs_' || line) + public.world_title_bonus('cs_all');
    if ((line || '_x13') = any (sk) and random() < 0.10) or (cs_pct > 0 and random() * 100 < cs_pct)
       or (is_furn and line = 'carpentry' and 'carpentry_c43b' = any (sk) and random() < 0.25) then
      select key into rf from jsonb_each(r.ingredients) order by random() limit 1;
      if rf is not null then inv := jsonb_set(inv, array[rf], to_jsonb(coalesce((inv ->> rf)::int, 0) + 1), true); saved := true;
        notes := notes || ('재료를 아껴 ' || coalesce((select item_name from public.world_item_catalog where item_id = rf), '재료') || ' 하나를 돌려받았다'); end if;
    end if;
    if line = 'alchemy' and 'alchemy_c43b' = any (sk) and random() < 0.30 then
      rf := null;
      select j.key into rf from jsonb_each(r.ingredients) j left join public.world_item_catalog ic on ic.item_id = j.key order by coalesce(ic.reference_price, 0) desc limit 1;
      if rf is not null then inv := jsonb_set(inv, array[rf], to_jsonb(coalesce((inv ->> rf)::int, 0) + 1), true);
        notes := notes || ('「금단」 ' || coalesce((select item_name from public.world_item_catalog where item_id = rf), '재료') || ' 하나를 돌려받았다'); end if;
    end if;
  end if;
  update public.world_characters set inventory = inv, crafting_successes = crafting_successes + 1, crafting_quality = crafting_quality + quality, updated_at = now() where owner_id = uid;
  result_text := '제작 성공: ' || r.recipe_name || ' → ' || coalesce((select ic.item_name from public.world_item_catalog ic where ic.item_id = out_item), out_item) || ' ×' || out_qty || ' · 품질 ' || quality
    || case when loc_bonus > 0 then ' · 제작 장소 가산 +' || loc_bonus else '' end || case when is_hq then ' · 우수품!' else '' end
    || case when from_st <> '{}'::jsonb then ' · 창고 재료 사용' else '' end
    || case when cardinality(notes) > 0 then ' · ' || array_to_string(notes, ' · ') else '' end;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'craft', result_text, jsonb_build_object('recipe', r.recipe_id, 'output', r.output_item, 'item', out_item, 'hq', is_hq, 'qty', out_qty,
    'quality', quality, 'difficulty', r.recipe_difficulty, 'line', line));
  return jsonb_build_object('content', result_text, 'inventory', inv, 'recipe', r.recipe_id, 'output', out_item, 'base', r.output_item, 'hq', is_hq, 'hq_at', case when hq_ok then hq_th end,
    'qty', out_qty, 'quality', quality, 'location_bonus', loc_bonus, 'from_storage', from_st, 'line', line, 'line_name', lname);
end $function$;
