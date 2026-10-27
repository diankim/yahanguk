-- 프로필 꾸미기 2: 장착·해제 함수와 캐릭터 정리 시 함께 지워지는 외래 키.
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 안전하다.

/* ── 장착·해제 ───────────────────────────────────────── */
create or replace function public.world_cosmetic_equip(p_kind text, p_key text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_kind is null or p_kind not in ('frame', 'pattern', 'seal') then raise exception '꾸미기 종류가 올바르지 않습니다.'; end if;
  perform 1 from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if p_key is null or p_key = '' then
    update public.world_characters set profile = coalesce(profile, '{}'::jsonb) - p_kind, updated_at = now() where owner_id = uid;
    return jsonb_build_object('ok', true, 'content', '꾸미기를 내렸습니다.');
  end if;
  select cc.cosmetic_name into nm from public.world_character_cosmetics o join public.world_cosmetic_catalog cc using (cosmetic_key)
   where o.owner_id = uid and o.cosmetic_key = p_key and cc.kind = p_kind and cc.active;
  if nm is null then raise exception '얻은 꾸미기만 고를 수 있습니다.'; end if;
  update public.world_characters set profile = coalesce(profile, '{}'::jsonb) || jsonb_build_object(p_kind, p_key), updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'content', '「' || nm || '」을 달았습니다.');
end $$;

alter function public.world_cosmetic_equip(text, text) owner to fn_owner_field;
revoke all on function public.world_cosmetic_equip(text, text) from public, anon, authenticated;
grant execute on function public.world_cosmetic_equip(text, text) to authenticated;

-- 캐릭터를 정리하면 꾸미기 소유 기록도 함께 지운다
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'world_character_cosmetics_owner_fk') then
    alter table public.world_character_cosmetics add constraint world_character_cosmetics_owner_fk
      foreign key (owner_id) references public.world_characters(owner_id) on delete cascade;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'world_character_cosmetics_key_fk') then
    alter table public.world_character_cosmetics add constraint world_character_cosmetics_key_fk
      foreign key (cosmetic_key) references public.world_cosmetic_catalog(cosmetic_key) on delete cascade;
  end if;
end $$;

select 'ok' as result,
  exists (select 1 from pg_proc where proname = 'world_cosmetic_equip') as equip,
  (select count(*) from pg_constraint where conname like 'world_character_cosmetics_%_fk') as foreign_keys;
