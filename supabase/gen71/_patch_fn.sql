-- ─────────────────────────────────────────────────────────────
-- A. 만렙 40 · 쌓아 둘 능력치 포인트 117 · 기술 30단계부터 가파르게 · 깊이별 레벨 되살림
-- ─────────────────────────────────────────────────────────────

-- 함수 본문 고치기 도우미: 고칠 자리(old)가 정확히 n번 있어야 바꾼다. 이미 바뀌어 있으면 건너뛴다.
create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute replace(d, p_old, p_new);
end $$;
