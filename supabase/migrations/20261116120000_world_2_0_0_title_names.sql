update public.world_title_catalog set title_name = '단숨의 승부' where title_key = 'spar_ko10' and title_name = '일격필살';
update public.world_title_catalog set title_name = '지는 법을 아는 자' where title_key = 'spar_lose30' and title_name = '칠전팔기';

do $$ begin
  if exists (select 1 from public.world_title_catalog group by title_name having count(*) > 1) then
    raise exception '칭호 이름이 겹칩니다';
  end if;
end $$;

update public.world_patch_notes set body = body || $N$

### 칭호
- 이름이 다른 칭호와 겹치던 비무 칭호의 이름을 바꿨습니다. 「일격필살」(비무에서 쓰러뜨려 10번 이기기)은 「단숨의 승부」가 됩니다. 숨김 비무 칭호 하나도 같은 까닭으로 이름이 바뀝니다. 이미 얻은 칭호는 그대로 남고 이름만 바뀝니다.
$N$ where note_id = '2.0.0';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261116120000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
