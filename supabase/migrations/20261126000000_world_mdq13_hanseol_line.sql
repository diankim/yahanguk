do $m$
declare v jsonb; full_t text := '여섯 판관 가운데 아무도 오지 않았다. 한 분만 문간에 와서 그러시더라. 「감찰관, 내 어머니 이름은 그분이 올해 빼 주셨네. 나는 그 회의에 못 앉네.」';
begin
  select lines into v from public.world_quest_steps where quest_id = 'mdq_13' and step = 6 for update;
  if v -> 15 ->> 't' is distinct from '여섯 판관 가운데 아무도 오지 않았다. 한 분만'
     or v -> 16 ->> 't' is distinct from '여섯 판관 가운데 아무도 오지 않았다. 한 분만' then
    raise exception 'mdq_13 여섯째 장면 모양이 예상과 다릅니다';
  end if;
  v := jsonb_set(v, '{15,t}', to_jsonb(full_t));
  v := jsonb_set(v, '{16,t}', to_jsonb(full_t));
  update public.world_quest_steps set lines = v where quest_id = 'mdq_13' and step = 6;
end $m$;

update public.world_patch_notes set body = body || E'\n- 명등기 13장 「한설의 술」에서 판관 회의 이야기를 하던 한설의 대사가 중간에 끊기던 것을 고쳤습니다.'
 where note_id = '3.7.0' and body not like '%판관 회의 이야기를 하던 한설%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126000000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
