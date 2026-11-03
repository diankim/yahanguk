do $w$
declare d text; a text; b text;
begin
  d := replace(pg_get_functiondef('public.world_faction_current(uuid,boolean)'::regprocedure), E'\r\n', E'\n');
  a := $a$      update public.world_faction_progress set open_step = k, step_started_at = now(), updated_at = now() where owner_id = p_uid and faction_id = p.faction_id;
      p.step_started_at := now();
$a$;
  b := $a$      update public.world_faction_progress set open_step = k, updated_at = now() where owner_id = p_uid and faction_id = p.faction_id;
$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.2b world_faction_current 기준 문구가 없습니다'; end if;
  execute replace(d, a, b);
end $w$;

update public.world_patch_notes set body = body || $pn$
- 세력 등급 퀘스트에서 할 일을 해 둔 뒤 캐릭터 › 세력 화면을 처음 열면 그때까지 한 횟수가 0으로 돌아가던 것을 고쳤습니다. 이제 퀘스트 칸과 세력 화면이 같은 때(앞 장면을 보고한 때)부터 셉니다.
$pn$
where note_id = '1.0.0' and position('세력 화면을 처음 열면' in body) = 0;

update public.world_app_meta set value = '20261105120000' where key = 'db_version';
