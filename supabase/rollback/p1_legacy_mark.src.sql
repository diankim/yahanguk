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
-- 「정청의 흔적」(정청 기록고, 다시 연 뒤 깨진 장부 조각으로 보임): 지우기 전에 첫째 밤의 모습을 함께 찍어 둔다
alter table public.world_legacy_marks add column if not exists job_key text, add column if not exists major_faction_id text,
  add column if not exists location text, add column if not exists chapters int, add column if not exists title_name text,
  add column if not exists last_seen timestamptz;
insert into public.world_legacy_marks(owner_id, character_name, level, job_key, major_faction_id, location, chapters, title_name, last_seen)
select c.owner_id, c.character_name, c.level, c.job_key, c.major_faction_id, c.location,
       (select count(*)::int from public.world_quest_progress q where q.owner_id = c.owner_id and q.quest_id like 'mq\_%' and q.done_at is not null),
       (select t.title_name from public.world_character_titles ct join public.world_title_catalog t using (title_key)
         where ct.owner_id = c.owner_id and ct.is_equipped order by t.grade desc, ct.earned_at limit 1),
       c.updated_at
  from public.world_characters c
on conflict (owner_id) do update set character_name = excluded.character_name, level = excluded.level, job_key = excluded.job_key,
  major_faction_id = excluded.major_faction_id, location = excluded.location, chapters = excluded.chapters,
  title_name = excluded.title_name, last_seen = excluded.last_seen;

-- 기록고 읽기(로그인한 조사원 누구나): 계정 id는 내주지 않는다
create or replace function public.world_legacy_records()
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
begin
  if public.fn_owner_auth_uid() is null then raise exception '로그인이 필요합니다.'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'name', m.character_name, 'level', m.level, 'job', public.world_job_name(m.job_key),
      'faction', (select f.faction_name from public.world_major_factions f where f.faction_id = m.major_faction_id),
      'location', m.location, 'chapters', coalesce(m.chapters, 0), 'title', m.title_name,
      'mine', m.owner_id = public.fn_owner_auth_uid()) order by m.level desc nulls last, m.character_name)
    from public.world_legacy_marks m where m.character_name is not null and m.owner_id not in (select s.owner_id from public.world_staff s)), '[]'::jsonb);
end $$;
revoke all on function public.world_legacy_records() from public, anon;
grant execute on function public.world_legacy_records() to authenticated;

