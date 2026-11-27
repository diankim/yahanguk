#!/bin/bash
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
export PGHOST=${PGHOST:-/var/lib/postgresql/yhrep/sock} PGPORT=${PGPORT:-5433} PGUSER=${PGUSER:-postgres}
BASE=${YH_SIM_BASE:-yh_sim40}
OUT=${YH_SIM_OUT:-$HERE/out}
STAGE=${1:-}
PAR=${2:-4}
if [ -z "$STAGE" ]; then
  echo "usage: run_all.sh <check|hard|ug|raid|all> [parallel]"; exit 1
fi
mkdir -p "$OUT"
Q="$OUT/queue.$STAGE"; R="$OUT/$STAGE.jsonl"; : > "$Q"

T4A="{bloodknight,spearman,medic,scout}"; T4B="{artificer,analyst,formation,exorcist}"; T4H="{bloodknight,medic,formation,spearman}"
T3="{artificer,medic,analyst}"; T2A="{bloodknight,spearman}"; T2B="{medic,sealmaster}"; T2C="{scout,exorcist}"; T2H="{formation,analyst}"
R8="'artificer','bloodknight','medic','formation','exorcist','scout','analyst','spearman'"
R13="$R8,'sealmaster','tamer','medic','artificer','spearman'"
R20="$R13,'bloodknight','exorcist','analyst','formation','scout','medic','tamer'"

gw() { echo "gw|$1|$2|$3|$4|$5|$6" >> "$Q"; }
raid() { echo "raid|$1|$2|$3|$4|$5|$6" >> "$Q"; }

if [ "$STAGE" = check ]; then
  for b in dohaesu ttangul; do
    gw $b "$T4A" perfect hard 0.11 '{}'; gw $b "$T2A" perfect hard 0.12 '{}'; gw $b "$T2C" perfect hard 0.13 '{"hold": "hold"}'
    gw $b "$T4A" ignore hard 0.14 '{}'
  done
  for b in gwiheo mukjeok gapgwi dohaesu; do
    gw $b "$T4A" perfect ultimate 0.11 '{"start": 24, "start2": 24}'; gw $b "$T2B" perfect ultimate 0.12 '{"start": 24, "start2": 24}'
    gw $b "$T4A" ignore ultimate 0.13 '{"start": 24, "start2": 24}'
  done
  for b in neol shadow; do
    raid $b "$R8" best 0.31 240 100; raid $b "$R8" best 0.32 240 60; raid $b "$R8" best 0.33 240 30
    raid $b "$R8" half 0.34 240 30; raid $b "$R8" none 0.35 240 30
  done
fi
if [ "$STAGE" = hard ] || [ "$STAGE" = all ]; then
  for b in dohaesu ttangul; do
    for s in 0.11 0.12 0.13 0.14 0.15 0.16; do gw $b "$T4A" perfect hard $s '{}'; gw $b "$T4B" perfect hard $s '{}'; done
    for s in 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.30; do
      gw $b "$T2A" perfect hard $s '{}'; gw $b "$T2B" perfect hard $s '{"hold": "rush"}'
      gw $b "$T2C" perfect hard $s '{"hold": "hold"}'; gw $b "$T2C" perfect hard $s '{"hold": "rush"}'
    done
    for s in 0.41 0.42 0.43; do gw $b "$T4A" ignore hard $s '{}'; done
    for s in 0.51 0.52 0.53; do gw $b "$T4A" perfect hard $s '{"tier": 8, "enh": 5}'; done
  done
fi
if [ "$STAGE" = ug ] || [ "$STAGE" = all ]; then
  for b in gwiheo mukjeok gapgwi dohaesu; do
    for s in 0.11 0.12 0.13; do
      gw $b "$T4A" perfect ultimate $s '{}'; gw $b "$T4H" perfect ultimate $s '{}'
      gw $b "$T3" perfect ultimate $s '{}'; gw $b "$T2A" perfect ultimate $s '{}'; gw $b "$T2H" perfect ultimate $s '{}'
    done
    for s in 0.21 0.22; do gw $b "$T4A" ignore ultimate $s '{}'; gw $b "$T4A" real ultimate $s '{}'; done
    for s in 0.31 0.32 0.33; do gw $b "$T4A" perfect ultimate $s '{"tier": 8, "enh": 5}'; done
  done
fi
if [ "$STAGE" = raid ] || [ "$STAGE" = all ]; then
  for b in neol shadow; do
    for s in 0.31 0.32 0.33 0.34 0.35; do raid $b "$R13" best $s 3600 100; raid $b "$R13" half $s 3600 100; done
    for s in 0.36 0.37 0.38; do raid $b "$R13" none $s 3600 100; done
    for s in 0.41 0.42 0.43; do raid $b "$R8" best $s 3600 100; raid $b "$R20" best $s 3600 100; done
    for s in 0.51 0.52; do raid $b "$R13" best+late $s 3600 100; done
  done
fi

N=$(wc -l < "$Q"); echo "$STAGE: $N runs, $PAR workers -> $R"
for i in $(seq 1 "$PAR"); do
  W=yh_simrun_$i
  psql -d postgres -Atqc "select 1 from pg_database where datname = '$W'" | grep -q 1 || createdb -T "$BASE" "$W"
done

worker() {
  local W=$1
  while true; do
    local line
    line=$(flock "$Q.lock" bash -c "head -1 '$Q'; sed -i 1d '$Q'")
    [ -z "$line" ] && break
    IFS='|' read -r kind a1 a2 a3 a4 a5 a6 <<< "$line"
    if [ "$kind" = gw ]; then
      local o
      o=$(psql -d "$W" -Atq -v ON_ERROR_STOP=1 2>&1 <<SQL
\i $HERE/gw_sim.sql
call pg_temp.yh_gw_play('$a1', '$a2', '$a3', '$a4', $a5, '$a6', null);
SQL
)
      o2=$(echo "$o" | grep '^{' | tail -1)
      if [ -n "$o2" ]; then echo "$o2" >> "$R"; else python3 -c 'import json,sys; print(json.dumps({"err": sys.argv[1], "msg": sys.argv[2][-300:]}, ensure_ascii=False))' "$line" "$o" >> "$R"; fi
    else
      local late=""; local pol=$a3
      if [[ "$pol" == *+late ]]; then pol=${pol%+late}; late="select set_config('yh.sim_late', '5:300', true);"; fi
      psql -d "$W" -Atq -c "begin; $late select public.yh_sim_fight('$a1', array[$a2], '$pol', $a4, $a5, null, '2026-12-01 13:00+09', $a6);
        select jsonb_build_object('kind', 'raid', 'boss', boss, 'n', n, 'pol', '$a3', 'seed', seed, 'won', won, 'secs', secs, 'hp_pct', hp_left, 'falls', falls, 'info', info)
          from yh_sim_runs order by id desc limit 1; rollback;" 2>&1 | grep '"kind": "raid"' | tail -1 >> "$R"
    fi
  done
}
for i in $(seq 1 "$PAR"); do worker yh_simrun_$i & done
wait
python3 "$HERE/sim_report.py" "$R"
