do $w$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_notify_downed()'::regprocedure), E'\r\n', E'\n');
  if position('''rescued''' in d) > 0 then return; end if;
  a := $a$'. 구조하러 가지 않아도 됩니다.');$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.4h world_notify_downed 기준 문구가 없습니다'; end if;
  execute replace(d, a, a || $b$
  if coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''), new.owner_id::text) <> new.owner_id::text then
   insert into public.world_notifications(user_id,kind,title,content,payload) values(new.owner_id,'rescued','다시 일어났습니다',
     coalesce((select character_name||' 조사원이' from public.world_characters where owner_id::text = current_setting('request.jwt.claim.sub', true)), '누군가')||' 일으켜 주었습니다. 체력 '||new.health||'(으)로 돌아왔습니다.',jsonb_build_object('health',new.health,'location',new.location));
  end if;$b$);
end $w$;

update public.world_app_meta set value = '20261106000000' where key = 'db_version';
