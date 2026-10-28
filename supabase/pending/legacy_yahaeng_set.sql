-- 대기 파일: 「야행(夜行)의 흔적」 레거시 세트 — 11월 초 서버 전체 롤백 때 돌린다(지금은 돌리지 않는다).
-- migrations 폴더 밖에 두어 실수로 돌지 않게 했다. 화면 그림(cosmetics.js fr_yahaeng·pt_yahaeng·sl_heun, chat.js 이름 색 1016, app.css t-legacy)은 미리 배포돼 있어도 아무도 갖지 않아 보이지 않는다.
--
-- 순서
--   ① 롤백 「직전」: 이 파일의 1단계만 돌려 지금 캐릭터가 있는 계정을 명단(world_legacy_marks)에 남긴다. 계정(owner_id)은 롤백해도 그대로다.
--   ② 롤백을 한다(캐릭터 정리 방식은 그때 정한다).
--   ③ 롤백 「직후」: 2단계를 돌린다. 세트(칭호 3·테두리·바탕 무늬·낙관·이름 색)를 만들고, 명단에 있는 계정이 새 캐릭터를 만들면 저절로 주며(트리거),
--      이미 캐릭터가 있는 명단 계정에는 바로 준다. 얻는 다른 길은 없다(칭호 rule null — 판정이 절대 주지 않음, 꾸미기 rule은 레거시 칭호를 가졌을 때).
--   SQL 편집기에 붙일 때는 다른 패치처럼 줄바꿈(CR) 정리 감싸기로 돌린다.
--
-- 세트(별도 능력치 효과 없음)
--   칭호(신품·분류 「레거시」, 가진 사람 말고는 칭호 목록에 안 보임 — 운영진 칭호와 같은 처리)
--     · 제일야(第一夜)의 증인 · 미완(未完)의 길을 연 자 · 꺼지지 않은 불씨
--   꾸미기(등급 「흔적」): 테두리 「야행(夜行)의 테」(그믐달에 든 등롱·별, 핏빛 겹테·금빛 문양) · 바탕 무늬 「흑야 운문(黑夜雲紋)」 · 낙관 「痕」
--   이름 색 「야행묵금」(1016, 금빛 이름 + 핏빛 마름모): 레거시 칭호가 하나라도 있으면

-- ── 1단계(롤백 직전) ─────────────────────────────
create table if not exists public.world_legacy_marks (
  owner_id uuid primary key,
  character_name text,
  level int,
  marked_at timestamptz not null default now()
);
alter table public.world_legacy_marks enable row level security;
revoke all on public.world_legacy_marks from anon, authenticated;
insert into public.world_legacy_marks(owner_id, character_name, level)
select c.owner_id, c.character_name, c.level from public.world_characters c
on conflict (owner_id) do nothing;

-- ── 2단계(롤백 직후) ─────────────────────────────
grant fn_owner_field to postgres with inherit true, set true;

insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
  ('legacy_first_night', '제일야(第一夜)의 증인', 'moon',
   '아직 지도가 다 그려지지 않았던 밤, 야행국의 첫 번째 시대를 끝까지 지켜본 자. 그 밤은 지워졌으나 증인은 지워지지 않는다.',
   '야행국의 첫 번째 시대를 함께한 이에게만 주어졌다', '{}'::jsonb, true, false, null, 901, '레거시', 5),
  ('legacy_unfinished_road', '미완(未完)의 길을 연 자', 'map',
   '길이 이름을 얻기도 전에 먼저 걸었다. 지금 이 세계의 모든 길은 그 발자국 위에 다시 놓였다.',
   '야행국의 첫 번째 시대를 함께한 이에게만 주어졌다', '{}'::jsonb, true, false, null, 902, '레거시', 5),
  ('legacy_ember', '꺼지지 않은 불씨', 'spark',
   '세계가 한 번 꺼졌다 다시 켜지던 밤에도 홀로 꺼지지 않고 남은 불씨. 다음 밤을 여는 것은 언제나 이런 불씨다.',
   '야행국의 첫 번째 시대를 함께한 이에게만 주어졌다', '{}'::jsonb, true, false, null, 903, '레거시', 5)
on conflict (title_key) do nothing;

-- 꾸미기 등급에 「흔적(legacy)」을 더한다(화면 이름: 설정 TIER legacy '흔적', 그림 cosmetics.js t-legacy)
alter table public.world_cosmetic_catalog drop constraint if exists world_cosmetic_catalog_tier_check;
alter table public.world_cosmetic_catalog add constraint world_cosmetic_catalog_tier_check check (tier = any (array['common', 'rare', 'legend', 'legacy']));

insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort) values
  ('fr_yahaeng', 'frame', 'legacy', '야행(夜行)의 테', '롤백 전, 야행국의 첫 번째 시대를 함께한 이의 증표 · 이제 얻을 수 없다', '레거시', '{"title": "legacy_first_night"}'::jsonb, false, true, 901),
  ('pt_yahaeng', 'pattern', 'legacy', '흑야 운문(黑夜雲紋)', '롤백 전, 야행국의 첫 번째 시대를 함께한 이의 증표 · 이제 얻을 수 없다', '레거시', '{"title": "legacy_first_night"}'::jsonb, false, true, 902),
  ('sl_heun', 'seal', 'legacy', '낙관 「痕」', '롤백 전, 야행국의 첫 번째 시대를 함께한 이의 증표 · 이제 얻을 수 없다', '레거시', '{"title": "legacy_first_night"}'::jsonb, false, true, 903)
on conflict (cosmetic_key) do nothing;

-- 레거시 칭호는 운영진 칭호처럼 가진 사람만 칭호 목록에서 본다(얻을 길이 없는 칸이 다른 이의 목록·진행률을 막지 않게)
do $$ declare d text := pg_get_functiondef('public.world_title_snapshot()'::regprocedure);
  a text := $a$(tc.category is distinct from '운영' or ct.owner_id is not null)$a$;
  b text := $a$(coalesce(tc.category, '') not in ('운영', '레거시') or ct.owner_id is not null)$a$;
begin
  if position($a$'레거시'$a$ in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '칭호 목록 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;

-- 이름 색 1016 「야행묵금」: 레거시 칭호가 하나라도 있으면
do $$ declare d text := pg_get_functiondef('public.world_name_styles()'::regprocedure);
  a text := $a$(1013, 'cat', '교류', 2), (1014, 'cat', '이동', 4), (1015, 'cat', '성장', 4))$a$;
  b text := $a$(1013, 'cat', '교류', 2), (1014, 'cat', '이동', 4), (1015, 'cat', '성장', 4), (1016, 'cat', '레거시', 1))$a$;
begin
  if position('1016' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '이름 색 고칠 자리'; end if;
  execute replace(d, a, b);
end $$;

-- 세트 주기: 명단에 있는 계정에만, 한 번만(이미 가졌으면 건너뜀)
create or replace function public.world_legacy_grant(p_owner uuid)
returns boolean language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  if not exists (select 1 from public.world_legacy_marks where owner_id = p_owner) then return false; end if;
  if not exists (select 1 from public.world_characters where owner_id = p_owner) then return false; end if;
  if exists (select 1 from public.world_character_titles where owner_id = p_owner and title_key = 'legacy_first_night') then return false; end if;
  insert into public.world_character_titles(owner_id, title_key, earned_at)
  select p_owner, k, now() from unnest(array['legacy_first_night', 'legacy_unfinished_road', 'legacy_ember']) k
  on conflict do nothing;
  insert into public.world_character_cosmetics(owner_id, cosmetic_key, unlocked_at)
  select p_owner, k, now() from unnest(array['fr_yahaeng', 'pt_yahaeng', 'sl_heun']) k
  on conflict do nothing;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_owner, 'reward', '야행(夜行)의 흔적',
    '혼돈의 시절, 야행국이 미완이던 그때 이 세계를 함께 걸어 주셔서 고맙습니다. 첫 번째 시대를 함께한 이에게만 주어지는 「야행(夜行)의 흔적」 세트를 드립니다. '
    || '칭호 「제일야(第一夜)의 증인」·「미완(未完)의 길을 연 자」·「꺼지지 않은 불씨」, 테두리 「야행(夜行)의 테」, 바탕 무늬 「흑야 운문」, 낙관 「痕」, 이름 색 「야행묵금」. '
    || '칭호 화면과 게임 설정 › 꾸미기에서 쓸 수 있습니다(능력치 효과는 없습니다).',
    jsonb_build_object('legacy', true));
  return true;
end $$;
revoke all on function public.world_legacy_grant(uuid) from public, anon, authenticated;

-- 명단 계정이 롤백 뒤 새 캐릭터를 만들면 저절로
create or replace function public.trg_world_legacy_on_create()
returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
begin
  perform public.world_legacy_grant(new.owner_id);
  return new;
end $$;
revoke all on function public.trg_world_legacy_on_create() from public, anon, authenticated;
drop trigger if exists trg_world_legacy_on_create on public.world_characters;
create trigger trg_world_legacy_on_create after insert on public.world_characters
  for each row execute function public.trg_world_legacy_on_create();

-- 이미 캐릭터가 있는 명단 계정에는 바로
select count(*) filter (where public.world_legacy_grant(m.owner_id)) as granted_now from public.world_legacy_marks m;

grant fn_owner_field to postgres with inherit false, set false;
