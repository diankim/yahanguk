lock table public.world_gear_enhance, public.world_shop_stock, public.world_patch_notes in share row exclusive mode;

do $$
declare s boolean := not pg_has_role(current_user, 'fn_owner_18453', 'SET');
begin
  if s then execute 'grant fn_owner_18453 to ' || quote_ident(current_user) || ' with set true'; end if;
  execute 'set role fn_owner_18453';
  execute 'grant execute on function public.world_equip_item(text) to fn_owner_field';
  execute 'reset role';
  if s then execute 'grant fn_owner_18453 to ' || quote_ident(current_user) || ' with set false'; end if;
end $$;

with last as (
  select distinct on (actor_id, payload ->> 'item') actor_id owner_id, payload ->> 'item' item,
         case when (payload ->> 'ok')::boolean then (payload ->> 'to')::int else (payload ->> 'from')::int end lv
    from public.world_events where event_type = 'enhance' order by actor_id, payload ->> 'item', created_at desc),
sw as (select n.user_id owner_id, n.payload ->> 'from' f, n.payload ->> 'to' t from public.world_notifications n
        where n.kind = 'guide' and n.payload ->> 'tip' = 'weapon_swap')
insert into public.world_gear_enhance(owner_id, item_id, level, updated_at)
select sw.owner_id, sw.t, last.lv, now() from sw join last on last.owner_id = sw.owner_id and last.item = sw.f
 where last.lv > 0
on conflict do nothing;

insert into public.world_gear_enhance(owner_id, item_id, level, updated_at)
select c.owner_id, 'w_ranged6_heavy_hq', 10, now() from public.world_characters c
 where c.character_name = 'GM' and exists (select 1 from public.world_staff s where s.owner_id = c.owner_id)
on conflict do nothing;

insert into public.world_shop_stock(shop_id, item_id, stock, unit_price, refreshed_at)
select st.shop_id, 'reset_identity', 99, 100, max(st.refreshed_at)
  from public.world_shop_stock st
 where exists (select 1 from public.world_shop_catalog k where k.shop_id = st.shop_id and k.item_id = 'reset_identity')
   and st.refreshed_at >= public.world_shop_slot()
   and not exists (select 1 from public.world_shop_stock x where x.shop_id = st.shop_id and x.item_id = 'reset_identity' and x.refreshed_at >= public.world_shop_slot())
 group by st.shop_id;

update public.world_patch_notes set body = left(body, position('## 3.4.0' in body) - 1) || $pn$## 3.4.0
### 새 직업 셋
- 혈기사: 도끼·대검을 드는 방패입니다(이목 +70). 근접 공격마다 준 피해의 일부를 체력으로 되찾고(피흡), 「피 갑주」로 제 체력을 깎아 세 턴 동안 보호막을 두르며 그 차례에 베어 듭니다.
- 여명 창객: 언월도·장창을 드는 근접 공격수입니다. 연달아 공격할수록 「창끝 기세」가 겹으로 쌓여 세지고(다섯 겹까지), 방어·버티기·물품·이동을 하면 끊깁니다. 합동 토벌·귀허류 같은 우두머리 싸움에서는 수법을 받아 내느라 방어해도 쌓인 기세의 절반이 남습니다. 현장 토벌에서는 첫 공격에 선제로 한 번 더 찌르고, 「관통 찌르기」는 요괴 방어의 절반을 꿰뚫습니다.
- 진법가: 산가지·나경을 드는 치유사입니다. 다친 뒤 고치는 의무관과 달리 보호막과 피해 감소로 맞기 전에 지킵니다. 「산가지 진」은 산가지를 날리며 세 턴 동안 받는 피해를 줄입니다. 합동 토벌·귀허류에서 진법가가 보호막·결계로 막아 준 피해는 기여도 「버팀」에서 2.5배로 셉니다.
- 세 직업 모두 기술 계열(혈투·창술·진법), 협동 기술 넷, 원정 기술, 비무회 기술이 있습니다.
- 직업 퀘스트가 세 편씩 생겼습니다(혈기사 남명회 땅 · 진법가 흑련회 땅 · 여명 창객 수향연맹 땅).
- 잘 듣는 요괴 갈래: 혈기사 거괴·갑각 · 여명 창객 비금·천상 · 진법가 금주·수귀.
- 기본 옷도 직업마다 한 벌씩 생겼고, 옷 꾸러미에서도 나옵니다.

### 무기 갈래
- 무기를 직업마다 두 갈래로 나눴습니다. 같은 단계 무기는 위력이 같고, 갈래마다 보조 수치(묵직·예리·소리 없음)만 다릅니다. 직업별 갈래는 도움말 › 직업에 있습니다.
- 이미 낀 무기가 새 직업 갈래에 맞지 않으면 같은 단계의 내 직업 무기로 바꿔 끼워 드렸습니다(우수품은 우수품으로, 강화·내구도도 옮김). 바뀐 조사원에게는 알림이 갑니다. 가방·창고에 있는 맞지 않는 무기는 그대로 남고, 분해·판매할 수 있습니다.
- 갈래에 맞게 기존 무기 이름이 여럿 바뀌었습니다(예: 무쇠 철퇴 → 무쇠 도끼, 월철 환도 → 월철 등패와 환도). 바뀐 이름은 물품 정보에서 볼 수 있습니다.
- 새 갈래를 채우는 무기 65자루와 그 제작법이 생겼습니다(1~8단계).
- 떨어지는 무기는 내 직업 갈래가 더 잘 나옵니다.
- 쇠뇌·취관은 화살 대신 「편전」을 씁니다. 가지고 있던 쇠뇌살은 편전으로 바뀌었습니다. 활이 쇠뇌·취관으로 바뀐 무기를 끼고 있던 조사원은 가진 화살 가운데 100개까지를 편전으로 바꿔 드렸습니다.

### 이목 상한
- 이목에 직업마다 상한을 두었습니다(호위 무사·혈기사 300 · 봉인술사 220 · 그 밖의 직업 160). 방패가 아닌 직업이 무거운 장비를 둘러 방패보다 요괴 눈에 더 띄던 것을 막습니다.
- 방패 둘이 함께 가면 이목이 같을 때 요괴가 둘을 반반으로 칩니다. 한 사람이 받아 내게 하려면 다른 쪽 이목을 낮추세요(도움말 › 장비 칸과 이목).

### 장비 세트
- 가방 › 장비에서 지금 낀 장비를 세트로 저장해 두었다가 한 번에 바꿔 낍니다.
- 처음 네 칸이고, 어느 직업이든 전투 기술 계열 하나가 15단계에 닿을 때마다 한 칸씩 늘어 열 칸까지입니다(직업을 바꿔도 줄지 않습니다).

### 직업 바꾸기
- 「환골탈태 서첩」을 모든 안전지대 상점에서 늘 팝니다(값은 레벨에 따라 다름).
- 이제 서첩은 직업만 바꾸고 소속은 그대로 둡니다. 레벨로 받은 능력치는 새 직업의 주 능력치에 맞게 저절로 놓이고, 쓴 뒤 한 시간은 다시 쓸 수 없습니다(남은 시간은 가방의 서첩 단추에 보입니다).
- 새 직업 무기가 하나도 없으면 시작 무기 하나를 받습니다. 주 능력치가 상한에 닿아 남는 점수는 직접 나눕니다.
- 직업을 바꿔도 계열마다 쌓은 기술 단계는 그대로 남고, 새 직업의 계열은 따로 키웁니다. 캐릭터 › 기술의 「다른 직업 기술」을 펼치면 다른 직업 계열의 단계와 기술을 볼 수 있습니다.
- 「세심단」(능력치만 다시 나누기)은 대세력 비고 2등급에서 공훈으로 삽니다.

### 자율 활동
- 「자율 수련」은 직업 계열·막기·응급 처치·분석 가운데, 「장비 정비」는 제작 분야 여덟 가운데 올릴 기술을 고를 수 있습니다. 오르는 양은 그대로입니다.

### 고친 것
- 무기를 바꿔 끼워 드릴 때 강화 단계가 0으로 돌아가던 것을 고치고, 바꿔 끼운 무기에 원래 강화 단계를 되돌려 드렸습니다.
- 장비 세트의 「끼기」를 눌러도 장비가 바뀌지 않던 것을 고쳤습니다.
- 상점에 환골탈태 서첩이 다음 물품 교체 때까지 보이지 않던 것을 고쳤습니다.
- 가방 › 장비의 「장비 세트」 칸을 접었다 펼 수 있습니다.
$pn$
 where note_id = '3.0.0' and position('## 3.4.0' in body) > 0;

update public.world_patch_notes
   set title = '[공지] 새 직업 셋과 무기 갈래 · 연담·명등기·묵적록·조련사·명소·비장고',
       body = replace(replace(body, '## 3.3.0 · 연담', $pn$## 3.4.0 · 세 직업
· **새 직업 셋** — 피를 마시며 버티는 방패 **혈기사**, 연달아 칠수록 세지는 창 공격수 **여명 창객**, 맞기 전에 지키는 치유사 **진법가**가 생겼습니다. 직업마다 퀘스트 세 편과 기본 옷이 있습니다.
· **무기 갈래** — 무기를 직업마다 두 갈래로 나눴습니다. 맞지 않는 무기를 끼고 있던 조사원은 같은 단계의 직업 무기로 바꿔 끼워 드렸습니다(강화 단계 그대로).
· **직업 바꾸기** — 환골탈태 서첩을 모든 안전지대 상점에서 팝니다. 직업만 바뀌고, 쌓은 기술 단계는 그대로 남습니다.
· **장비 세트**와 자율 활동의 올릴 기술 고르기도 들어왔습니다.

$pn$ || '## 3.3.0 · 연담'),
                      '**3.0.0**(3.1·3.2·3.3 포함)', '**3.0.0**(3.1~3.4 포함)')
 where note_id = '0.0.0' and position('## 3.4.0' in body) = 0;

update public.world_app_meta set value = '20261123010000' where key = 'db_version';
