-- 7.7.0 — 제보 69·71·72·73 (2026-11-01), 패치노트는 따로 한 줄(사용자 요청)
-- ① 요화가 다음 단계로 넘어가지 않고 사라지던 것(제보 72, 연주): 요화 줄의 만료 시각이 지나면 pg_cron yh-yohwa(5분)가 단계를 올리는데,
--    그 사이 상태판 읽기(world_hud_snapshot, 1분)·상태 걸기(world_field_status)가 만료된 상태를 모두 지우면서 요화 줄까지 지웠다.
--    world_status_snapshot·world_apply_activity_status처럼 'yohwa'는 빼고 지운다. (지금까지 2단계·3단계로 넘어간 기록(world_yohwa_log stage3)이 하나도 없던 까닭.)
-- ② 부적 정화가 우수 정화 부적을 받지 않던 것(제보 73): world_survival_action 'cleanse'가 보통 정화 부적만 세었다.
--    보통을 먼저 쓰고 없으면 우수품(침식 −21·정신 +7, 보통 ×1.15 올림)을 쓴다.
lock table public.world_characters in access exclusive mode;

do $p$
declare r record; d text; own text; inh boolean; n int;
begin
  for r in select * from (values
      ('public.world_hud_snapshot()'::regprocedure,
       $a$DELETE FROM public.world_character_statuses WHERE owner_id = uid AND expires_at <= now();$a$,
       $b$DELETE FROM public.world_character_statuses WHERE owner_id = uid AND expires_at <= now() AND status_key <> 'yohwa'; -- 요화는 yh-yohwa가 단계를 올린다(7.7.0)$b$,
       $m$expires_at <= now() AND status_key <> 'yohwa'$m$),
      ('public.world_field_status(uuid,text,text)'::regprocedure,
       $a$DELETE FROM public.world_character_statuses WHERE owner_id = p_owner AND expires_at <= now();$a$,
       $b$DELETE FROM public.world_character_statuses WHERE owner_id = p_owner AND expires_at <= now() AND status_key <> 'yohwa';$b$,
       $m$expires_at <= now() AND status_key <> 'yohwa'$m$),
      ('public.world_survival_action(text)'::regprocedure,
       $a$er int; cl int := 0;$a$,
       $b$er int; cl int := 0; wm int := 6;$b$, 'wm int := 6;'),
      ('public.world_survival_action(text)'::regprocedure,
       $a$if coalesce((inv->>'ward_talisman')::integer,0)<1 then raise exception '정화 부적이 없습니다. 안전지대 상점에서 사거나 만들 수 있습니다.'; end if;$a$,
       $b$if coalesce((inv->>'ward_talisman')::integer,0)+coalesce((inv->>'ward_talisman_hq')::integer,0)<1 then raise exception '정화 부적이 없습니다. 안전지대 상점에서 사거나 만들 수 있습니다.'; end if;$b$,
       $m$+coalesce((inv->>'ward_talisman_hq')::integer,0)<1$m$),
      ('public.world_survival_action(text)'::regprocedure,
       $a$inv:=case when (inv->>'ward_talisman')::integer<=1 then inv-'ward_talisman' else jsonb_set(inv,'{ward_talisman}',to_jsonb((inv->>'ward_talisman')::integer-1)) end;
   er:=greatest(0,c.erosion-18);$a$,
       $b$if coalesce((inv->>'ward_talisman')::integer,0)>=1 then
     inv:=case when (inv->>'ward_talisman')::integer<=1 then inv-'ward_talisman' else jsonb_set(inv,'{ward_talisman}',to_jsonb((inv->>'ward_talisman')::integer-1)) end;
     er:=greatest(0,c.erosion-18);
   else
     -- 우수 정화 부적(7.7.0, 제보 73): 보통이 없을 때 쓰고 침식 -21·정신 +7
     inv:=case when (inv->>'ward_talisman_hq')::integer<=1 then inv-'ward_talisman_hq' else jsonb_set(inv,'{ward_talisman_hq}',to_jsonb((inv->>'ward_talisman_hq')::integer-1)) end;
     er:=greatest(0,c.erosion-21); wm:=7;
   end if;$b$, $m$inv-'ward_talisman_hq'$m$),
      ('public.world_survival_action(text)'::regprocedure,
       $a$mental=least(100,mental+6),updated_at=now() where owner_id=uid returning * into c;
   result_text:='정화 부적을 태워 정화 의식을 마쳤다. 침식 -18, 정신 안정도 +6.'$a$,
       $b$mental=least(100,mental+wm),updated_at=now() where owner_id=uid returning * into c;
   result_text:='정화 부적을 태워 정화 의식을 마쳤다. 침식 -'||case when wm=7 then 21 else 18 end||', 정신 안정도 +'||wm||'.'$b$,
       $m$mental=least(100,mental+wm)$m$)
    ) x(fn, a, b, mark)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.mark in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception '7.7.0 anchor in % (% of 1): %', r.fn, n, left(r.a, 60); end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
    if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
  end loop;
end $p$;

-- 연주(제보 72): 잃은 요화를 3단계 8시간으로 다시 건다(사용자 결정 2026-11-01). 지금 걸린 1단계(넘친 침식) 줄은 대신한다.
do $y$
declare u uuid := '9153e90f-1b41-40ac-969e-efc34373db82';
begin
  delete from public.world_character_statuses where owner_id = u and status_key in ('yohwa', 'yohwa_frenzy');
  insert into public.world_character_statuses(owner_id, status_key, stacks, potency, source_activity, expires_at, metadata)
    values (u, 'yohwa', 3, 3, 'erosion', now() + interval '8 hours', jsonb_build_object('stage', 3, 'started_at', now(), 'from', 'gm_restore'));
  insert into public.world_notifications(user_id, kind, title, content, payload)
    values (u, 'yohwa', '요화: 3단계 반요', '제보 72로 사라졌던 요화를 운영진이 다시 걸었습니다. 반쯤 요괴가 된 상태로, 8시간 안에 귀령초를 쓰지 않으면 요괴화를 거쳐 쓰러집니다.', jsonb_build_object('stage', 3));
  perform public.world_yohwa_mark(u, 'stage3');
end $y$;

insert into public.world_patch_notes(note_id, title, body) values ('7.7.0', '7.7.0 · 요화 단계 진행 바로잡기 · 우수품 정화', $N$
## 7.7.0
- 요화가 3일·2일이 지나도 다음 단계로 넘어가지 않고 조용히 사라지던 것을 고쳤습니다(제보 72). 단계가 바뀌는 시각과 서버의 5분 판정 사이에 상태판 읽기가 만료된 상태를 치우면서 요화 줄까지 지우고 있었습니다. 이제 요화는 정해진 때에 2단계·3단계로 넘어가고, 3단계가 끝나면 한 시간 요괴화 뒤에 쓰러집니다.
- 캐릭터 › 상태의 「부적 정화」가 우수 정화 부적을 받지 않던 것을 고쳤습니다(제보 73). 보통 정화 부적을 먼저 쓰고, 없으면 우수품을 쓰며 그때는 침식 −21·정신 +7입니다.
- 물품 정보 창의 「가진 수량」에 짝이 되는 우수품(또는 보통)의 수를 함께 적고, 「이 물품이 들어가는 제작법」의 재료 수는 둘을 합쳐 셉니다(제보 69).
- PC 상태판 탐색력 아래 「n분 뒤 +1」이 깜빡이며 칸 높이가 흔들리던 것을 고쳤습니다(제보 71). 봉연 토벌처럼 상태판을 매초 다시 그리는 동안 글이 한 번씩 비었습니다.
$N$) on conflict (note_id) do nothing;

update public.world_app_meta set value = '20261104200400' where key = 'db_version';
