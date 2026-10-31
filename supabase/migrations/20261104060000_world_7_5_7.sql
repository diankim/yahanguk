-- 7.5.7 — 직접 거래 막힘 고침(제보 62) + 화면 묶음의 패치노트(7.5.0 본문 맨 아래에 덧붙임)
-- 제보 62(강산하): 직접 거래는 안전지대 밖에서도 되는데(5.0.0), 성사 기록(trade_id·gil)이 거래소 막기에 걸려
-- 「거래소는 안전지대에서만 이용할 수 있습니다」로 튕기던 것. 거래소 막기에서 직접 거래 기록(trade_id)을 뺀다.
do $p$
declare d text; a text; n int; own text; inh boolean;
begin
  d := replace(pg_get_functiondef('public.world_guard_action_context()'::regprocedure), E'\r\n', E'\n');
  a := $o$IF k = 'trade' AND (p ? 'unit_price' OR p ? 'gil') AND (r.region_id IS NULL OR NOT r.is_safe_zone) THEN$o$;
  if position('NOT (p ? ''trade_id'')' in d) > 0 then return; end if; -- 이미 고쳤으면 건너뜀
  n := (length(d) - length(replace(d, a, ''))) / length(a);
  if n <> 1 then raise exception '7.5.7 guard anchor %', n; end if;
  select p.proowner::regrole::text into own from pg_proc p where p.oid = 'public.world_guard_action_context()'::regprocedure;
  select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
  if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
  execute replace(d, a, $n$IF k = 'trade' AND (p ? 'unit_price' OR (p ? 'gil' AND NOT (p ? 'trade_id'))) AND (r.region_id IS NULL OR NOT r.is_safe_zone) THEN$n$);
  if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
end $p$;

update public.world_patch_notes set body = body || $N$

## 7.5.7
- 안전지대(반요촌 빼고)에 있을 때 가방의 물품 정보 창에서 바로 **창고에 넣기**를 할 수 있습니다. 수량을 정하거나 「최대」로 한꺼번에 맡깁니다(강산하 님 제보). 장착 중인 마지막 하나는 남깁니다.
- PC 왼쪽 상태판(소지금 아래)에 **퀵슬롯** 8칸을 작게 두었습니다. 누르면 바로 씁니다. 칸은 캐릭터 › 상태의 퀵슬롯과 같고 「바꾸기」로 고칩니다(강산하 님 제보). 휴대폰은 위쪽 상태 띠를 펼치면 보입니다.
- 안전지대 밖에서 같은 곳에 있는 조사원과 **직접 거래**를 할 때, 받아들이는 순간 「거래소는 안전지대에서만 이용할 수 있습니다」로 막히던 것을 고쳤습니다. 도움말대로 직접 거래는 어디서나 됩니다(강산하 님 제보). 거래소(등록·구매)는 그대로 안전지대에서만.
- 휴대폰에서 채팅·귓속말을 보낸 뒤 키패드가 내려가던 것을 고쳤습니다. 보내기 단추를 눌러도 입력칸이 그대로 열려 있어 이어서 쓸 수 있습니다.
- 휴대폰에서 채팅 입력칸을 누르면 키패드가 올라오며 마지막 말이 가려지던 것을 고쳤습니다. 키패드가 다 올라온 뒤에도 맨 아래 말이 보입니다.
- 창고에 맡기거나 꺼낸 뒤, 상점·거래소·대장간에서 사고판 뒤 창이 맨 위로 올라가던 것을 고쳤습니다. 보던 자리 그대로 남아 이어서 할 수 있습니다.
$N$
 where note_id = '7.5.0' and position('## 7.5.7' in body) = 0;

update public.world_app_meta set value = '20261104060000' where key = 'db_version';
