lock table public.world_characters in access exclusive mode;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

select pg_temp.yh_fix('world_quest_task_count', array[
$q$else coalesce((e.payload ->> 'caught')::boolean, false)$q$,
$q$else coalesce((e.payload ->> 'caught')::boolean, false)
               and (not p_task ? 'f' or e.payload ->> 'fish' in (select jsonb_array_elements_text(p_task -> 'f')))$q$]);

select pg_temp.yh_fix('world_quest_task_label', array[
$q$'') || '물고기 낚아 올리기'$q$,
$q$'') || coalesce((select string_agg(f.fish_name, '·') from public.world_fish_species f where f.fish_id in (select jsonb_array_elements_text(p_task -> 'f'))) || ' 낚기', '물고기 낚아 올리기')$q$]);

create or replace function public.world_quest_title_trg()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare t record;
begin
  if new.done_at is null or (tg_op = 'UPDATE' and old.done_at is not null) then return new; end if;
  for t in select c.title_key, c.title_name from public.world_quest_steps s join public.world_title_catalog c on c.title_key = s.reward ->> 'title'
            where s.quest_id = new.quest_id and s.reward ? 'title' and c.active loop
    insert into public.world_character_titles(owner_id, title_key) values (new.owner_id, t.title_key) on conflict do nothing;
    if found then
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (new.owner_id, 'title', '칭호를 얻었습니다', '「' || t.title_name || '」 · 캐릭터 › 칭호에서 장착할 수 있습니다.', jsonb_build_object('title_key', t.title_key));
    end if;
  end loop;
  return new;
end $function$;
revoke all on function public.world_quest_title_trg() from public, anon, authenticated;
drop trigger if exists trg_world_quest_title on public.world_quest_progress;
create trigger trg_world_quest_title after insert or update of done_at on public.world_quest_progress for each row execute function public.world_quest_title_trg();
