
-- ─────────────────────────────────────────────────────────────
-- 7.2 ③ 기술 고유 효과를 원정에도: 이름 있는 기술(추가·택일·숙달·조합)이 원정 정산(world_expedition_settle)에 작은 보정과 일지 줄로 나온다
--   atk 원정 전투력 % · guard 받는 피해 −% · win 이길 확률 + · loot 채집량·전리품 % · find 발견 % · heal 회차마다 체력(반쯤) · ward 요기 침식 −%
--   합에 상한(전투력 25 · 피해 30 · 승률 0.08 · 채집 30 · 발견 35 · 회복 4 · 침식 35). 현장 토벌의 고유 효과(world_battle_action)는 그대로다.
-- ─────────────────────────────────────────────────────────────
create table if not exists public.world_exp_skill_def (
  skill_id text primary key, atk numeric not null default 0, guard numeric not null default 0, win numeric not null default 0,
  loot numeric not null default 0, find numeric not null default 0, heal int not null default 0, ward numeric not null default 0,
  kind text not null default 'fight', txt text not null
);
alter table public.world_exp_skill_def enable row level security;
revoke all on public.world_exp_skill_def from anon, authenticated;
grant select on public.world_exp_skill_def to fn_owner_field;
delete from public.world_exp_skill_def;
insert into public.world_exp_skill_def(skill_id, atk, guard, win, loot, find, heal, ward, kind, txt) values
 ('melee_x13', 3, 0, 0, 0, 0, 0, 0, 'fight', '칼을 뽑는 순간 먼저 베어 들어갑니다.'),
 ('melee_c24a', 4, 0, 0, 0, 0, 0, 0, 'fight', '한 번에 힘을 모아 내리칩니다.'),
 ('melee_c30a', 4, 0, 0.01, 0, 0, 0, 0, 'fight', '흐르는 물처럼 칼끝을 이어 갑니다.'),
 ('melee_c43a', 6, 0, 0, 0, 0, 0, 0, 'fight', '하늘을 가르듯 크게 휘두릅니다.'),
 ('melee_m50', 8, 0, 0.02, 0, 0, 0, 0, 'fight', '칼과 몸이 하나가 되어 길을 엽니다.'),
 ('melee_c13b', 0, 3, 0, 0, 0, 0, 0, 'fight', '크게 호령해 요괴의 기세를 꺾습니다.'),
 ('melee_c24b', 0, 4, 0, 0, 0, 0, 0, 'fight', '요괴의 눈길을 제게로 끌어 버팁니다.'),
 ('melee_x30', 0, 5, 0, 0, 0, 0, 0, 'fight', '기운을 갑옷처럼 둘러 공격을 받아 냅니다.'),
 ('melee_c43b', 0, 6, 0.01, 0, 0, 0, 0, 'fight', '사자처럼 울부짖어 요괴를 물러서게 합니다.'),
 ('ranged_x13', 2, 0, 0, 0, 3, 0, 0, 'fight', '숨을 고르고 요괴의 움직임을 응시합니다.'),
 ('ranged_c24b', 3, 0, 0, 0, 0, 0, 0, 'fight', '시위를 빠르게 연달아 당깁니다.'),
 ('ranged_c24a', 4, 0, 0, 0, 0, 0, 0, 'fight', '먼 곳에서 급소를 겨눠 쏩니다.'),
 ('ranged_x30', 3, 0, 0.01, 0, 0, 0, 0, 'fight', '바람결을 읽고 화살을 띄웁니다.'),
 ('ranged_c43b', 5, 0, 0, 0, 0, 0, 0, 'fight', '화살을 고리처럼 이어 퍼붓습니다.'),
 ('ranged_c43a', 6, 0, 0, 0, 0, 0, 0, 'fight', '단단한 껍질째 꿰뚫어 버립니다.'),
 ('ranged_m50', 8, 0, 0.02, 0, 0, 0, 0, 'fight', '하늘 활처럼 시위가 울립니다.'),
 ('sealing_c13a', 3, 0, 0, 0, 0, 0, 0, 'fight', '부적을 사슬처럼 이어 붙입니다.'),
 ('sealing_c24a', 4, 0, 0, 0, 0, 0, 0, 'fight', '부적이 요괴 앞에서 터집니다.'),
 ('sealing_c30a', 4, 0, 0, 0, 0, 0, 0, 'fight', '술식을 고리로 엮어 몰아칩니다.'),
 ('sealing_c43a', 6, 0, 0, 0, 0, 0, 0, 'fight', '하늘의 우레를 부적에 실어 내립니다.'),
 ('sealing_x13', 0, 0, 0, 0, 0, 0, 5, 'camp', '미리 접어 둔 부적으로 잠자리를 지킵니다.'),
 ('sealing_c24b', 0, 4, 0, 0, 0, 0, 0, 'fight', '몸을 감싸는 부적을 붙입니다.'),
 ('sealing_x30', 0, 0, 0, 0, 0, 0, 6, 'camp', '술식을 겹으로 둘러 요기를 막습니다.'),
 ('sealing_c43b', 0, 3, 0, 0, 0, 0, 8, 'camp', '맑은 결계를 쳐 쉬어 갑니다.'),
 ('sealing_m50', 6, 0, 0, 0, 0, 0, 6, 'fight', '태을의 진을 펼쳐 요괴를 묶습니다.'),
 ('analysis_x13', 0, 0, 0.01, 0, 0, 0, 0, 'fight', '요괴의 버릇을 눈여겨봅니다.'),
 ('analysis_c24b', 0, 0, 0.015, 0, 0, 0, 0, 'fight', '싸움의 흐름을 읽고 한발 앞섭니다.'),
 ('analysis_c24a', 4, 0, 0, 0, 0, 0, 0, 'fight', '드러난 급소를 놓치지 않습니다.'),
 ('analysis_x30', 0, 0, 0.01, 2, 0, 0, 0, 'fight', '지난 싸움에서 적어 둔 약점을 떠올립니다.'),
 ('analysis_c43b', 0, 0, 0.02, 0, 0, 0, 0, 'fight', '싸움터 전체를 한눈에 셈합니다.'),
 ('analysis_c43a', 6, 0, 0, 0, 0, 0, 0, 'fight', '반드시 쓰러뜨릴 한 수를 계산해 둡니다.'),
 ('analysis_m50', 0, 0, 0.03, 0, 0, 0, 0, 'fight', '모든 움직임이 보입니다.'),
 ('guarding_x13', 0, 3, 0, 0, 0, 0, 0, 'fight', '덤벼드는 공격을 흘려 넘깁니다.'),
 ('guarding_c24a', 0, 5, 0, 0, 0, 0, 0, 'fight', '쇠벽처럼 버티고 섭니다.'),
 ('guarding_c24b', 0, 3, 0.01, 0, 0, 0, 0, 'fight', '막아 낸 틈으로 맞받아칩니다.'),
 ('guarding_x30', 0, 4, 0, 0, 0, 0, 0, 'fight', '발을 땅에 박고 움직이지 않습니다.'),
 ('guarding_c43b', 3, 4, 0, 0, 0, 0, 0, 'fight', '받은 힘을 되돌려 흘려보냅니다.'),
 ('guarding_c43a', 0, 7, 0, 0, 0, 0, 0, 'fight', '금강처럼 부서지지 않습니다.'),
 ('guarding_m50', 0, 9, 0, 0, 0, 0, 0, 'fight', '만 길 성벽처럼 앞을 막아섭니다.'),
 ('first_aid_x13', 0, 0, 0, 0, 0, 1, 0, 'camp', '다친 곳을 단단히 묶어 피를 멎게 합니다.'),
 ('first_aid_c24a', 0, 0, 0, 0, 0, 1, 0, 'camp', '쉬는 틈에 붕대를 새로 감습니다.'),
 ('first_aid_c24b', 0, 0, 0, 0, 0, 1, 3, 'camp', '숨을 고르며 마음을 가라앉힙니다.'),
 ('first_aid_x30', 0, 0, 0, 0, 0, 1, 0, 'camp', '침을 놓아 지친 몸을 풉니다.'),
 ('first_aid_c43a', 0, 0, 0, 0, 0, 2, 0, 'camp', '쓰러질 듯한 몸을 되살려 냅니다.'),
 ('first_aid_c43b', 0, 0, 0, 0, 0, 0, 4, 'camp', '스며든 독기를 풀어냅니다.'),
 ('first_aid_m50', 0, 3, 0, 0, 0, 2, 0, 'camp', '죽을 고비에서도 다시 일어섭니다.'),
 ('tracking_x13', 0, 0, 0, 0, 5, 0, 0, 'find', '흙에 남은 자국을 살펴 길을 고릅니다.'),
 ('tracking_c24b', 0, 0, 0, 0, 6, 0, 0, 'find', '남들이 모르는 샛길로 들어섭니다.'),
 ('tracking_c24a', 0, 0, 0, 0, 6, 0, 0, 'find', '흔적을 끝까지 따라갑니다.'),
 ('tracking_x30', 0, 2, 0, 0, 3, 0, 0, 'find', '기척을 숨기고 조용히 지나갑니다.'),
 ('tracking_c43b', 0, 0, 0, 0, 8, 0, 0, 'find', '바람처럼 가볍게 숲을 누빕니다.'),
 ('tracking_c43a', 0, 0, 0, 2, 8, 0, 0, 'find', '작은 단서에서 숨은 곳을 짚어 냅니다.'),
 ('tracking_m50', 0, 0, 0, 0, 12, 0, 0, 'find', '만 리 밖의 흔적까지 읽어 냅니다.'),
 ('foraging_x13', 0, 0, 0, 3, 0, 0, 0, 'gather', '눈썰미로 쓸 만한 것을 먼저 찾습니다.'),
 ('foraging_c24b', 0, 0, 0, 3, 0, 0, 0, 'gather', '좋은 것만 골라 담습니다.'),
 ('foraging_c24a', 0, 0, 0, 4, 0, 0, 0, 'gather', '둘레를 넓게 훑어 거둡니다.'),
 ('foraging_x30', 0, 0, 0, 2, 3, 0, 0, 'gather', '지난번 거둔 길목을 기억해 냅니다.'),
 ('foraging_c43a', 0, 0, 0, 6, 0, 0, 0, 'gather', '한 아름 가득 거둡니다.'),
 ('foraging_c43b', 0, 0, 0, 4, 0, 0, 0, 'gather', '흙 속에 묻힌 귀한 것을 알아봅니다.'),
 ('foraging_m50', 0, 0, 0, 8, 0, 0, 0, 'gather', '산과 내가 아낌없이 내어 줍니다.'),
 ('herbalism_x13', 0, 0, 0, 2, 0, 0, 0, 'gather', '잎맥을 살펴 약초를 가립니다.'),
 ('herbalism_c24a', 0, 0, 0, 4, 0, 0, 0, 'gather', '뿌리째 깊이 캐냅니다.'),
 ('herbalism_c24b', 0, 0, 0, 2, 0, 1, 0, 'gather', '캔 약초를 상하지 않게 갈무리합니다.'),
 ('herbalism_x30', 0, 0, 0, 3, 0, 0, 0, 'gather', '약초꾼만 아는 길로 들어섭니다.'),
 ('herbalism_c43b', 0, 0, 0, 3, 0, 0, 0, 'gather', '영험한 풀을 한눈에 알아봅니다.'),
 ('herbalism_c43a', 0, 0, 0, 6, 0, 0, 0, 'gather', '약초 군락을 찾아냅니다.'),
 ('herbalism_m50', 0, 0, 0, 7, 0, 1, 0, 'gather', '손이 닿는 풀마다 약이 됩니다.'),
 ('mining_x13', 0, 0, 0, 2, 0, 0, 0, 'gather', '광맥의 결을 읽습니다.'),
 ('mining_c24a', 0, 0, 0, 4, 0, 0, 0, 'gather', '힘껏 곡괭이를 내리칩니다.'),
 ('mining_c24b', 0, 0, 0, 3, 0, 0, 0, 'gather', '쓸 만한 돌만 골라냅니다.'),
 ('mining_x30', 0, 1, 0, 3, 0, 0, 0, 'gather', '갱도의 숨소리를 느낍니다.'),
 ('mining_c43b', 0, 0, 0, 3, 0, 0, 0, 'gather', '돌 속의 빛을 알아봅니다.'),
 ('mining_c43a', 0, 0, 0, 6, 0, 0, 0, 'gather', '노다지를 캐냅니다.'),
 ('mining_m50', 0, 0, 0, 7, 0, 0, 0, 'gather', '땅의 맥이 길을 내어 줍니다.'),
 ('spirit_gathering_x13', 0, 0, 0, 2, 0, 0, 0, 'gather', '흐르는 영기를 감지합니다.'),
 ('spirit_gathering_c24a', 0, 0, 0, 4, 0, 0, 0, 'gather', '영기를 빨아들여 거둡니다.'),
 ('spirit_gathering_c24b', 0, 0, 0, 2, 0, 0, 4, 'gather', '요기를 걸러 맑게 거둡니다.'),
 ('spirit_gathering_x30', 0, 0, 0, 3, 0, 0, 0, 'gather', '영맥의 결을 고릅니다.'),
 ('spirit_gathering_c43b', 0, 0, 0, 0, 0, 0, 6, 'camp', '맑은 마음으로 요기를 흘려보냅니다.'),
 ('spirit_gathering_c43a', 0, 0, 0, 5, 0, 0, 0, 'gather', '영기가 넘치도록 거둡니다.'),
 ('spirit_gathering_m50', 0, 0, 0, 6, 0, 0, 3, 'gather', '천지의 영기가 손끝에 모입니다.'),
 ('alchemy_c24a', 0, 0, 0, 0, 0, 1, 0, 'camp', '챙겨 온 약을 진하게 달여 마십니다.'),
 ('alchemy_c43b', 0, 0, 0, 0, 0, 1, 0, 'camp', '영약을 지어 기운을 북돋웁니다.'),
 ('alchemy_m50', 0, 0, 0, 0, 0, 2, 0, 'camp', '아홉 번 달인 금단으로 몸을 다스립니다.'),
 ('smithing_c24b', 0, 2, 0, 0, 0, 0, 0, 'camp', '쉬는 틈에 장비를 손봅니다.'),
 ('smithing_c43b', 0, 3, 0, 0, 0, 0, 0, 'fight', '단련한 몸으로 공격을 받아 냅니다.'),
 ('smithing_m50', 3, 2, 0, 0, 0, 0, 0, 'fight', '명장의 손길이 닿은 장비가 빛납니다.'),
 ('wardcraft_c24b', 0, 0, 0, 0, 0, 0, 4, 'camp', '잠자리에 결계를 두릅니다.'),
 ('wardcraft_x30', 0, 0, 0, 0, 0, 0, 4, 'camp', '결계를 한 겹 더 칩니다.'),
 ('wardcraft_c43b', 0, 3, 0, 0, 0, 0, 3, 'camp', '몸을 지키는 결계를 새깁니다.'),
 ('wardcraft_m50', 0, 0, 0, 0, 0, 0, 6, 'camp', '모든 술법이 하나로 모여 요기를 밀어냅니다.'),
 ('combo_sealing_wardcraft', 2, 0, 0, 0, 0, 0, 5, 'fight', '봉인을 두 겹으로 겹쳐 요괴를 누릅니다.'),
 ('combo_foraging_alchemy', 0, 0, 0, 2, 0, 1, 0, 'camp', '거둔 풀로 그 자리에서 약을 짓습니다.'),
 ('combo_first_aid_herbalism', 0, 0, 0, 0, 0, 2, 0, 'camp', '들판에 약방을 차려 상처를 돌봅니다.'),
 ('combo_guarding_mining', 0, 5, 0, 0, 0, 0, 0, 'fight', '바위처럼 단단히 버팁니다.'),
 ('combo_analysis_spirit_gathering', 0, 0, 0, 3, 3, 0, 0, 'find', '영맥의 흐름을 읽어 숨은 곳을 찾습니다.'),
 ('combo_melee_smithing', 4, 0, 0, 0, 0, 0, 0, 'fight', '손수 벼린 칼로 베어 들어갑니다.'),
 ('combo_ranged_tracking', 3, 0, 0, 0, 4, 0, 0, 'fight', '사냥꾼의 눈으로 먼저 겨눕니다.');

create or replace function public.world_exp_skill_fx(p_uid uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  with f as (select d.*, sk.skill_name from unnest(public.world_skill_procs(p_uid)) p(id)
               join public.world_exp_skill_def d on d.skill_id = p.id join public.world_skill_catalog sk on sk.skill_id = p.id)
  select jsonb_build_object('atk', least(25, coalesce(sum(atk), 0)), 'guard', least(30, coalesce(sum(guard), 0)), 'win', least(0.08, coalesce(sum(win), 0)),
    'loot', least(30, coalesce(sum(loot), 0)), 'find', least(35, coalesce(sum(find), 0)), 'heal', least(4, coalesce(sum(heal), 0)), 'ward', least(35, coalesce(sum(ward), 0)),
    'fight', coalesce(jsonb_agg(jsonb_build_object('n', skill_name, 't', txt)) filter (where kind = 'fight'), '[]'::jsonb),
    'gather', coalesce(jsonb_agg(jsonb_build_object('n', skill_name, 't', txt)) filter (where kind = 'gather'), '[]'::jsonb),
    'find_l', coalesce(jsonb_agg(jsonb_build_object('n', skill_name, 't', txt)) filter (where kind = 'find'), '[]'::jsonb),
    'camp', coalesce(jsonb_agg(jsonb_build_object('n', skill_name, 't', txt)) filter (where kind = 'camp'), '[]'::jsonb))
  from f
$$;
alter function public.world_exp_skill_fx(uuid) owner to fn_owner_field;
do $$ begin set role fn_owner_field; revoke all on function public.world_exp_skill_fx(uuid) from public, anon, authenticated; reset role; end $$;
grant execute on function public.world_exp_skill_fx(uuid) to fn_owner_field;

-- 원정 정산에 잇는다
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)', 'ammo_used int := 0; cfx jsonb; cl jsonb;', 'ammo_used int := 0; cfx jsonb; cl jsonb; skf jsonb; skl jsonb;');
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)', ' brank := coalesce((c.skill_progress -> ''guarding'' ->> ''rank'')::int, 0);',
  ' brank := coalesce((c.skill_progress -> ''guarding'' ->> ''rank'')::int, 0);
  skf := public.world_exp_skill_fx(e.owner_id); power := power * (1 + coalesce((skf ->> ''atk'')::float8, 0) / 100.0);');
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)', '  heal_at := case e.stance when ''cautious'' then 60',
  '  disc_mul := disc_mul * (1 + coalesce((skf ->> ''find'')::float8, 0) / 100.0); loot_mul := loot_mul * (1 + coalesce((skf ->> ''loot'')::float8, 0) / 100.0);
  heal_at := case e.stance when ''cautious'' then 60');
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)', 'if c.job_key = ''scout'' and roll < p_fight and random() < 0.3 then',
  'if coalesce((skf ->> ''heal'')::int, 0) > 0 and hp > 0 and hp < 100 and random() < 0.5 then
      hp := least(100, hp + (skf ->> ''heal'')::int);
      if random() < 0.15 and jsonb_array_length(coalesce(skf -> ''camp'', ''[]''::jsonb)) > 0 then
        skl := (skf -> ''camp'') -> floor(random() * jsonb_array_length(skf -> ''camp''))::int;
        seq := seq + 1; jr := jr || jsonb_build_object(''at'', base_t + make_interval(secs => seq * 2), ''kind'', ''skill'', ''who'', me, ''owner'', e.owner_id, ''text'', ''['' || (skl ->> ''n'') || ''] '' || (skl ->> ''t''));
      end if;
    end if;
    if c.job_key = ''scout'' and roll < p_fight and random() < 0.3 then');
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)', '        win_p := greatest(0.08, least(0.95, win_p));',
  '        win_p := win_p + coalesce((skf ->> ''win'')::float8, 0);
        if jsonb_array_length(coalesce(skf -> ''fight'', ''[]''::jsonb)) > 0 and random() < 0.3 then
          skl := (skf -> ''fight'') -> floor(random() * jsonb_array_length(skf -> ''fight''))::int;
          seq := seq + 1; jr := jr || jsonb_build_object(''at'', base_t + make_interval(secs => seq * 2), ''kind'', ''skill'', ''who'', me, ''owner'', e.owner_id, ''text'', ''['' || (skl ->> ''n'') || ''] '' || (skl ->> ''t''));
        end if;
        win_p := greatest(0.08, least(0.95, win_p));');
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)', '* greatest(0.3, 1 + g_inc / 100.0) * (1 + 0.45 * nal));',
  '* greatest(0.3, 1 + g_inc / 100.0) * (1 + 0.45 * nal) * (1 - coalesce((skf ->> ''guard'')::float8, 0) / 100.0));');
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)', 'k := round(k * greatest(0, 1 + g_er / 100.0))::int;',
  'k := round(k * greatest(0, 1 + g_er / 100.0) * (1 - coalesce((skf ->> ''ward'')::float8, 0) / 100.0))::int;');
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)', 'gathers := gathers + 1; xp := xp + 4; gxp := gxp + 8; loot := public.world_inv_add(loot, item, qty);',
  'gathers := gathers + 1; xp := xp + 4; gxp := gxp + 8; loot := public.world_inv_add(loot, item, qty);
          if random() < 0.2 and jsonb_array_length(coalesce(skf -> ''gather'', ''[]''::jsonb)) > 0 then
            skl := (skf -> ''gather'') -> floor(random() * jsonb_array_length(skf -> ''gather''))::int;
            seq := seq + 1; jr := jr || jsonb_build_object(''at'', base_t + make_interval(secs => seq * 2), ''kind'', ''skill'', ''who'', me, ''owner'', e.owner_id, ''text'', ''['' || (skl ->> ''n'') || ''] '' || (skl ->> ''t''));
          end if;');
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)', 'finds := finds + 1; xp := xp + 6; ixp := ixp + 10;',
  'finds := finds + 1; xp := xp + 6; ixp := ixp + 10;
      if random() < 0.25 and jsonb_array_length(coalesce(skf -> ''find_l'', ''[]''::jsonb)) > 0 then
        skl := (skf -> ''find_l'') -> floor(random() * jsonb_array_length(skf -> ''find_l''))::int;
        seq := seq + 1; jr := jr || jsonb_build_object(''at'', base_t + make_interval(secs => seq * 2), ''kind'', ''skill'', ''who'', me, ''owner'', e.owner_id, ''text'', ''['' || (skl ->> ''n'') || ''] '' || (skl ->> ''t''));
      end if;');
