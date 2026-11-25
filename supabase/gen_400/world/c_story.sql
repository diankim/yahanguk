do $$
declare x record; d text; n int;
begin
  for x in select * from (values
      ('public.world_quest_board()'::regprocedure, $a$x.quest_id ~ '^(gq|mkq|mdq)_[0-9]+$'$a$, $b$x.quest_id ~ '^(gq|mkq|mdq|hwq)_[0-9]+$'$b$, 1),
      ('public.world_quest_board()'::regprocedure, $a$a.quest_id ~ '^(gq|mkq|mdq)_[0-9]+$'$a$, $b$a.quest_id ~ '^(gq|mkq|mdq|hwq)_[0-9]+$'$b$, 1)
  ) v(f, o, nw, want) loop
    d := pg_get_functiondef(x.f);
    n := (length(d) - length(replace(d, x.o, ''))) / length(x.o);
    if n <> x.want then raise exception '% 조각 % 개 (기대 %)', x.f, n, x.want; end if;
    execute replace(d, x.o, x.nw);
  end loop;
end $$;
