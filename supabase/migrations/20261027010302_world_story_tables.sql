-- 주 이야기: 장·단서·가설. 진행도는 기존 world_case_progress(case_id = 장 id)에 쌓는다.
CREATE TABLE IF NOT EXISTS public.world_story_chapters (
  chapter_id text PRIMARY KEY, seq integer NOT NULL UNIQUE, title text NOT NULL, summary text NOT NULL,
  intro text NOT NULL, outro text NOT NULL, min_level integer NOT NULL DEFAULT 1, rewards jsonb NOT NULL DEFAULT '{}'::jsonb);
CREATE TABLE IF NOT EXISTS public.world_story_clues (
  clue_id text PRIMARY KEY, chapter_id text NOT NULL REFERENCES public.world_story_chapters(chapter_id),
  name text NOT NULL, tag text NOT NULL, region_id text NOT NULL REFERENCES public.world_map_regions(region_id),
  description text NOT NULL, sort integer NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS public.world_story_combos (
  combo_id text PRIMARY KEY, chapter_id text NOT NULL REFERENCES public.world_story_chapters(chapter_id),
  name text NOT NULL, needs text[] NOT NULL, description text NOT NULL, conclusion text NOT NULL, sort integer NOT NULL DEFAULT 0);
ALTER TABLE public.world_story_chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_story_clues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.world_story_combos ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.world_story_chapters, public.world_story_clues, public.world_story_combos TO fn_owner_field;

