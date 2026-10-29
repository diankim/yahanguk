-- 6.1.3 의견 모으기: 처음 보낸 제보·건의·소감에 한 번 보상(노정 건량 2·청심환 2), 분류 「소감」 추가, 옛 private 스키마 정리.
-- 보상은 계정마다 한 번(world_report_rewards). 이미 제보한 조사원에게도 첫 제보 기준으로 한 번 준다(운영진 제외).
-- 가방에 들어가는 만큼 가방에, 남는 것은 개인 창고에 넣는다(창고는 넘쳐도 물품이 남고 맡기기만 막힌다).
lock table public.world_characters in access exclusive mode;

-- 옛 방 기반 시절 함수·스키마(쓰는 표·정책·함수 없음). cascade 없이 지워 무언가 기대면 실패한다.
drop function if exists private.is_room_member(uuid, uuid);
drop schema if exists private;

create table if not exists public.world_report_rewards (
  owner_id uuid primary key references public.world_characters(owner_id) on delete cascade,
  report_id bigint,
  retro boolean not null default false,
  granted_at timestamptz not null default now()
);
alter table public.world_report_rewards enable row level security;
revoke all on public.world_report_rewards from public, anon, authenticated;
grant select, insert on public.world_report_rewards to fn_owner_field;

-- 보상 지급(화면에서 직접 부르지 않음). 이미 받았거나 캐릭터가 없으면 null
create or replace function public.world_report_reward_give(p_uid uuid, p_report bigint, p_retro boolean)
returns text language plpgsql security definer set search_path = pg_catalog, public as $f$
declare inv jsonb; k text; q int; put int; lim int; spill jsonb := '{}'::jsonb; msg text;
  items jsonb := '{"travel_ration": 2, "tonic": 2}'::jsonb;
begin
  if p_uid is null or exists (select 1 from public.world_staff where owner_id = p_uid) then return null; end if;
  select coalesce(inventory, '{}'::jsonb) into inv from public.world_characters where owner_id = p_uid for update;
  if not found then return null; end if;
  insert into public.world_report_rewards(owner_id, report_id, retro) values (p_uid, p_report, p_retro) on conflict do nothing;
  if not found then return null; end if;
  lim := public.world_bag_limit(p_uid);
  for k, q in select key, value::int from jsonb_each_text(items) loop
    put := least(q, greatest(0, public.world_bag_room(inv, k, lim)));
    if put > 0 then inv := public.world_inv_add(inv, k, put); end if;
    if q > put then spill := spill || jsonb_build_object(k, q - put); end if;
  end loop;
  update public.world_characters set inventory = inv, updated_at = now() where owner_id = p_uid;
  if spill <> '{}'::jsonb then
    insert into public.world_storage(owner_id, items) values (p_uid, spill)
    on conflict (owner_id) do update set items = (select coalesce(jsonb_object_agg(x.key, x.v), '{}'::jsonb) from (
        select key, sum(value::int) v from (select * from jsonb_each_text(public.world_storage.items) union all select * from jsonb_each_text(excluded.items)) u group by key) x),
      updated_at = now();
  end if;
  msg := '첫 의견을 보내 주셔서 고맙습니다. 노정 건량 2개·청심환 2개를 드렸습니다' || case when spill <> '{}'::jsonb then '(가방에 자리가 모자란 몫은 개인 창고에 넣었습니다).' else '.' end;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_uid, 'reward', '첫 의견 보상', msg, jsonb_build_object('report_id', p_report, 'items', items, 'storage', spill));
  return msg;
end $f$;
alter function public.world_report_reward_give(uuid, bigint, boolean) owner to fn_owner_field;
do $$ begin
  if not pg_has_role('postgres', 'fn_owner_field', 'usage') then grant fn_owner_field to postgres with inherit true, set true; end if;
end $$;
set role fn_owner_field;
revoke all on function public.world_report_reward_give(uuid, bigint, boolean) from public, anon, authenticated;
reset role;

-- 분류 「소감」(review)
alter table public.world_bug_reports drop constraint world_bug_reports_category_check;
alter table public.world_bug_reports add constraint world_bug_reports_category_check check (category = any (array['bug', 'screen', 'balance', 'idea', 'review', 'other']));

-- 보내기: 소감 분류 받기 + 첫 의견 보상
do $$ declare d text; a text; n int;
begin
  d := pg_get_functiondef('public.world_bug_report_submit(text,text,text,jsonb)'::regprocedure);
  if position('world_report_reward_give' in d) = 0 then
    a := E'not in (''bug'', ''screen'', ''balance'', ''idea'', ''other'')';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 제보 분류(%)', n; end if;
    d := replace(d, a, E'not in (''bug'', ''screen'', ''balance'', ''idea'', ''review'', ''other'')');
    a := E'  return jsonb_build_object(''ok'', true, ''report_id'', rid, ''content'', ''제보를 보냈습니다. 운영진이 확인하면 알림으로 답을 드립니다.'');';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 제보 결과(%)', n; end if;
    d := replace(d, a, E'  nm := public.world_report_reward_give(uid, rid, false);\n'
      || E'  return jsonb_build_object(''ok'', true, ''report_id'', rid, ''reward'', nm is not null, ''content'', ''보내 주셔서 고맙습니다. 운영진이 확인하면 알림으로 답을 드립니다.'' || coalesce('' '' || nm, ''''));');
    execute d;
  end if;
  -- 목록: 첫 의견 보상을 받았는지(화면 안내용)
  d := pg_get_functiondef('public.world_bug_report_list(text)'::regprocedure);
  if position('reward_done' in d) = 0 then
    a := E'select jsonb_build_object(''is_gm'', (select is_gm from gm),';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 제보 목록(%)', n; end if;
    execute replace(d, a, a || E' ''reward_done'', exists (select 1 from public.world_report_rewards w, me where w.owner_id = me.uid),');
  end if;
end $$;

-- 이미 제보한 조사원: 첫 제보 기준으로 한 번
select public.world_report_reward_give(r.owner_id, min(r.report_id), true) from public.world_bug_reports r group by r.owner_id;

update public.world_patch_notes set body = body || E'\n### 6.1.3\n- **첫 의견 보상**: 버그 제보·건의·소감을 처음 보내면 한 번 **노정 건량 2개·청심환 2개**를 드립니다(가방이 가득하면 개인 창고로). 이미 제보해 주신 분께도 드렸습니다.\n- **소감도 받습니다**: 제보 창에 「소감」 분류를 더했습니다. 오류가 아니어도 게임을 하며 느낀 점·좋았던 점·아쉬운 점을 편하게 보내 주세요. 도움말·설정 페이지의 「제보·소감」 단추로 엽니다.\n'
 where note_id = '6.1.0' and position('### 6.1.3' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261031020000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
