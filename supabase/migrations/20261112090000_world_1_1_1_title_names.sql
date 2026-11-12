update public.world_title_catalog set title_name = '단숨의 승부' where title_key = 'spar_ko10' and title_name = '일격필살';
update public.world_title_catalog set title_name = '지는 법을 아는 자' where title_key = 'spar_lose30' and title_name = '칠전팔기';

do $$ begin
  if exists (select 1 from public.world_title_catalog group by title_name having count(*) > 1) then
    raise exception '칭호 이름이 겹칩니다';
  end if;
end $$;

update public.world_patch_notes set body = body || E'\n- 비무 칭호 「일격필살」(비무에서 쓰러뜨려 10번 이기기)이 다른 칭호와 이름이 같아 「단숨의 승부」로 바꿨습니다. 숨김 비무 칭호 하나도 같은 까닭으로 이름이 바뀝니다. 이미 얻은 칭호는 그대로이고 이름만 바뀝니다.\n- 휴대폰에서 귓속말처럼 입력칸이 있는 창에 글을 쓸 때 키패드가 올라오면 창 위쪽이 잘리던 것을 고쳤습니다. 이제 창이 키패드 위 보이는 높이에 맞춰집니다.'
where note_id = '1.1.0' and position('단숨의 승부' in body) = 0;

update public.world_app_meta set value = '20261112090000' where key = 'db_version';
