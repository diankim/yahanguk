insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, minimum_level, rarity, acquisition_difficulty, drop_rate_modifier,
  equipment_traits, tradeable, reference_price, stack_size)
values ('hf_lantern_hanger', '등불 걸개', 'furniture', 3,
  '별채 가구 · 조명. 항구 물가에서 남의 등불을 여러 번 건져 올린 이가 받는 걸개입니다. 건진 등불을 줄줄이 걸어 두면 이름 모를 글들이 밤새 은은하게 흔들립니다. 별채에 놓으면 가방에서 빠지고, 거두면 곳간으로 돌아갑니다.',
  false, '{}'::jsonb, 1, 'rare', 3, 1,
  '{"hk": "lantern_hanger", "w": 1, "d": 1, "top": 0, "kind": "floor", "cat": "조명", "grade": 3}'::jsonb, false, 600, 1)
on conflict (item_id) do update set item_name = excluded.item_name, category = excluded.category, tier = excluded.tier, description = excluded.description,
  equipment_traits = excluded.equipment_traits, tradeable = excluded.tradeable, reference_price = excluded.reference_price, stack_size = excluded.stack_size;

insert into public.world_furniture_sources(source, item_id, chance)
select 'lantern', public.world_lantern_rules() -> 'hanger' ->> 'item', 1
where not exists (select 1 from public.world_furniture_sources where source = 'lantern');

insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade)
select t ->> 'key', t ->> 'name', 'flame', t ->> 'desc', t ->> 'cond', '{}'::jsonb, true, (t ->> 'hidden')::boolean,
  jsonb_build_object('lantern', t ->> 'by', 'n', (t ->> 'n')::int), 3500 + o::int, '등불 편지', (t ->> 'grade')::int
from jsonb_array_elements(public.world_lantern_rules() -> 'titles') with ordinality z(t, o)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text,
  hidden = excluded.hidden, rule = excluded.rule, sort = excluded.sort, category = excluded.category, grade = excluded.grade;
