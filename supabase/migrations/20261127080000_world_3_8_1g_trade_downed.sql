create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

select pg_temp.yh_fix('world_trade_direct_offer(uuid,jsonb,bigint,jsonb,bigint)', array[
$q$  if coalesce(a.is_dead, false) or a.downed_at is not null or a.health <= 0 then raise exception '현재 상태에서는 거래할 수 없습니다.'; end if;$q$,
$q$  if coalesce(a.is_dead, false) or a.downed_at is not null or a.health <= 0 then raise exception '현재 상태에서는 거래할 수 없습니다.'; end if;
  if b.downed_at is not null or b.health <= 0 then raise exception '상대가 쓰러져 있어 거래를 제안할 수 없습니다.'; end if;$q$]);

select pg_temp.yh_fix('world_trade_direct_respond(uuid,boolean)', array[
$q$  if b.downed_at is not null or b.health <= 0 then raise exception '현재 상태에서는 거래할 수 없습니다.'; end if;$q$,
$q$  if b.downed_at is not null or b.health <= 0 then raise exception '현재 상태에서는 거래할 수 없습니다.'; end if;
  if coalesce(a.is_dead, false) or a.downed_at is not null or a.health <= 0 then raise exception '제안한 조사원이 쓰러져 있어 거래할 수 없습니다.'; end if;$q$]);

update public.world_patch_notes set body = body || E'\n- [거래] 쓰러진 조사원에게는 직접 거래를 제안할 수 없고, 제안한 사람이 그 뒤 쓰러지면 수락해도 거래가 되지 않습니다.'
where note_id = '3.8.0' and position('쓰러진 조사원에게는 직접 거래를' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127080000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
