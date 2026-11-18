create or replace function pg_temp.yh_hdr(p_note text, p_hdr text, p_new text) returns void language plpgsql as $f$
declare b text; k int;
begin
  select body into b from public.world_patch_notes where note_id = p_note;
  if b is null then raise exception '패치노트 % 없음', p_note; end if;
  k := (length(b) - length(replace(b, E'\n\n' || p_hdr || E'\n', ''))) / length(E'\n\n' || p_hdr || E'\n');
  if k = 0 and position(E'\n' || p_hdr || E'\n' in b) = 0 then return; end if;
  if k <> 1 then raise exception '패치노트 % 머리 % 가 % 곳', p_note, p_hdr, k; end if;
  update public.world_patch_notes set body = replace(b, E'\n\n' || p_hdr || E'\n', case when p_new = '' then E'\n' else E'\n\n' || p_new || E'\n' end) where note_id = p_note;
end $f$;

select pg_temp.yh_hdr('0-7.5.0', '## 7.6.3b', '');
select pg_temp.yh_hdr('0-7.5.0', '## 7.6.3c', '');
select pg_temp.yh_hdr('0-7.5.0', '## 7.6.3d', '');
select pg_temp.yh_hdr('0-7.7.0', h, '') from unnest(array['## 7.7.1b', '## 7.7.2b', '## 7.7.2c', '## 7.7.2d', '## 7.7.3b', '## 7.7.3c', '## 7.7.4b',
  '## 7.7.7b', '## 7.7.7c', '## 7.7.7d', '## 7.7.7e', '## 7.7.7f', '## 7.7.7g', '## 7.7.7h', '## 7.7.7i', '## 7.7.7j', '## 7.7.7k', '## 7.7.7l', '## 7.7.7o']) h;
select pg_temp.yh_hdr('0-7.7.0', '## 7.7.7m', '### 그 밖');
select pg_temp.yh_hdr('1.0.0', '## 1.0.1b · 기민 — 직업마다 주 능력치로', '### 기민 — 직업마다 주 능력치로');
select pg_temp.yh_hdr('1.0.0', '## 1.0.2b · 탐색·퀘스트 경험치', '### 탐색·퀘스트 경험치');
select pg_temp.yh_hdr('1.1.0', h, '') from unnest(array['## 1.1.0b', '## 1.1.0c', '## 1.1.0d', '## 1.1.0e']) h;
select pg_temp.yh_hdr('3.0.0', '## 3.0.0b', '');

do $d$ begin
  if exists (select 1 from public.world_patch_notes where body ~ '(?m)^#+ *[0-9]+\.[0-9]+\.[0-9]+[a-z]') then
    raise exception '글자 붙은 패치 번호 머리가 남음';
  end if;
end $d$;
