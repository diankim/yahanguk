do $$
declare r record;
begin
  for r in select * from (values
    ('3.8.0', '- [대사] 명등기 13장·16장에서 경현이 쌀 두 섬 이야기를 같은 말로 되풀이하던 대사를 다듬었습니다.', '- [대사] 명등기 일부 장면의 대사를 다듬었습니다.'),
    ('3.7.0', '- 명등기 13장 「한설의 술」에서 판관 회의 이야기를 하던 한설의 대사가 중간에 끊기던 것을 고쳤습니다.', '- 명등기 일부 장면에서 대사가 중간에 끊기던 것을 고쳤습니다.'),
    ('3.5.0', '- 명등기 12장 「잘못 읽은 별」의 기록판 장면 대사를 다듬었습니다.', '- 명등기 일부 장면의 대사를 다듬었습니다.')) v(id, o, n) loop
    if (select count(*) from public.world_patch_notes where note_id = r.id and position(r.o in body) > 0) <> 1 then raise exception '없음 %', r.id; end if;
    update public.world_patch_notes set body = replace(body, r.o, r.n) where note_id = r.id;
  end loop;
end $$;
