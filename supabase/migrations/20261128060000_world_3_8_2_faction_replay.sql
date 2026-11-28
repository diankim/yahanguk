create or replace function public.world_faction_scene_view(p_kind text, p_step integer) returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $f$
declare uid uuid := public.fn_owner_auth_uid(); fid text; p public.world_faction_progress%rowtype; s public.world_faction_scenes%rowtype; spk text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select major_faction_id into fid from public.world_characters where owner_id = uid;
  if fid is null then raise exception '대세력에 들어야 합니다.'; end if;
  select * into p from public.world_faction_progress where owner_id = uid and faction_id = fid;
  if not found or p_kind is null or p_step is null
     or not ((p_kind = 'join' and p_step between 1 and coalesce(p.join_step, 0))
          or (p_kind = 'rank' and p_step between 2 and coalesce(p.rank, 1))) then
    raise exception '아직 마치지 않은 장면은 다시 볼 수 없습니다.';
  end if;
  select * into s from public.world_faction_scenes where faction_id = fid and kind = p_kind and step = p_step;
  if not found then raise exception '장면을 찾을 수 없습니다.'; end if;
  select array_agg(distinct x ->> 's') into spk from jsonb_array_elements(s.lines) x where x ->> 's' is not null;
  return jsonb_build_object('title', s.title, 'kind', s.kind, 'step', s.step, 'lines', s.lines, 'again', '지난 장면을 다시 보았습니다.',
    'cast', (select coalesce(jsonb_object_agg(z.npc_key, jsonb_build_object('name', z.npc_name, 'bio', z.bio)), '{}'::jsonb) from public.world_faction_npcs z where z.npc_key = any (spk)));
end $f$;
revoke all on function public.world_faction_scene_view(text, integer) from public, anon;
grant execute on function public.world_faction_scene_view(text, integer) to authenticated;

update public.world_patch_notes set body = body || E'\n\n## 3.8.2\n- [세력] 캐릭터 › 세력 › 「등급」 창에서 이미 마친 가입 퀘스트·등급 퀘스트 장면을 「지난 장면 다시 보기」로 다시 볼 수 있습니다.\n- [칭호] 칭호 카드 폭이 좁을 때 칭호 이름이 한 글자씩 세로로 늘어지던 것을 고쳤습니다.'
where note_id = '3.8.0' and position('## 3.8.2' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261128060000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
