select 'top_time' what, regexp_replace(left(query, 60), '\s+', ' ', 'g') q, calls, round(mean_exec_time::numeric, 1) mean_ms, round((total_exec_time / sum(total_exec_time) over () * 100)::numeric, 1) pct, round(wal_bytes / 1048576.0, 1) wal_mb
from pg_stat_statements where query ~* 'world_' order by total_exec_time desc limit 25;

select 'top_wal' what, regexp_replace(left(query, 60), '\s+', ' ', 'g') q, calls, round(wal_bytes / 1048576.0, 1) wal_mb, round((wal_bytes / greatest(calls, 1))::numeric) wal_per_call
from pg_stat_statements order by wal_bytes desc limit 15;

select 'since' what, stats_reset from pg_stat_statements_info;

select 'tables' what, relname, n_tup_ins, n_tup_upd, n_tup_hot_upd, round(100.0 * n_tup_hot_upd / greatest(n_tup_upd, 1), 1) hot_pct, n_dead_tup
from pg_stat_user_tables where schemaname = 'public' order by n_tup_ins + n_tup_upd desc limit 15;

select 'unused_idx' what, s.relname, s.indexrelname, s.idx_scan, pg_size_pretty(pg_relation_size(s.indexrelid)) sz
from pg_stat_user_indexes s join pg_index i on i.indexrelid = s.indexrelid
where s.schemaname = 'public' and not i.indisunique and (s.idx_scan = 0 or pg_relation_size(s.indexrelid) > 1048576)
order by pg_relation_size(s.indexrelid) desc limit 30;
