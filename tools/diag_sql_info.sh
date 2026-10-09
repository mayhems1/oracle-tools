#!/bin/bash
# SQL details by sql_id: full text, cursor stats (per execution), AWR history by plan
# Usage: diag_sql_info.sh <sql_id> [days=7]

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

if [ "$#" -eq 0 ]; then
  echo "Error: SQL_ID is not defined."
  exit 1
fi
if ! [[ "$1" =~ ^[0-9a-z]{13}$ ]]; then
  echo "Error: SQL_ID must be 13 chars [0-9a-z]."
  exit 1
fi
DAYS=${2:-7}
if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
  echo "Error: days must be integer."
  exit 1
fi

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 400
SET PAGESIZE 1000
SET FEEDBACK OFF
SET LONG 100000
SET LONGCHUNKSIZE 100000

COLUMN sql_text FORMAT A200 WORD_WRAPPED
COLUMN schema FORMAT A20
COLUMN module FORMAT A30
COLUMN first_load FORMAT A19
COLUMN last_active FORMAT A14
COLUMN snap_day FORMAT A8

PROMPT === SQL TEXT
SELECT sql_text FROM (
  SELECT sql_fulltext AS sql_text FROM v\$sql WHERE sql_id = '$1' AND ROWNUM = 1
  UNION ALL
  SELECT sql_text FROM dba_hist_sqltext
  WHERE  sql_id = '$1' AND NOT EXISTS (SELECT 1 FROM v\$sql WHERE sql_id = '$1')
);

PROMPT
PROMPT === CURSOR STATS (v\$sql, since cursor load)
SELECT child_number AS ch,
       plan_hash_value AS plan_hash,
       parsing_schema_name AS schema,
       SUBSTR(module,1,30) AS module,
       executions AS execs,
       ROUND(elapsed_time/1e6) AS ela_s,
       ROUND(cpu_time/1e6) AS cpu_s,
       ROUND(elapsed_time/NULLIF(executions,0)/1e6,3) AS ela_per_exec_s,
       ROUND(buffer_gets/NULLIF(executions,0)) AS gets_per_exec,
       ROUND(disk_reads/NULLIF(executions,0)) AS reads_per_exec,
       ROUND(rows_processed/NULLIF(executions,0)) AS rows_per_exec,
       users_executing AS running,
       first_load_time AS first_load,
       TO_CHAR(last_active_time,'DD.MM HH24:MI') AS last_active
FROM   v\$sql
WHERE  sql_id = '$1'
ORDER BY child_number;

PROMPT
PROMPT === AWR HISTORY BY DAY / PLAN (last $DAYS days)
SELECT TO_CHAR(TRUNC(s.end_interval_time),'DD.MM') AS snap_day,
       q.plan_hash_value AS plan_hash,
       SUM(q.executions_delta) AS execs,
       ROUND(SUM(q.elapsed_time_delta)/1e6) AS ela_s,
       ROUND(SUM(q.cpu_time_delta)/1e6) AS cpu_s,
       ROUND(SUM(q.elapsed_time_delta)/NULLIF(SUM(q.executions_delta),0)/1e6,3) AS ela_per_exec_s,
       ROUND(SUM(q.buffer_gets_delta)/NULLIF(SUM(q.executions_delta),0)) AS gets_per_exec,
       ROUND(SUM(q.disk_reads_delta)/NULLIF(SUM(q.executions_delta),0)) AS reads_per_exec
FROM   dba_hist_sqlstat q,
       dba_hist_snapshot s
WHERE  s.snap_id = q.snap_id AND s.dbid = q.dbid AND s.instance_number = q.instance_number
AND    q.sql_id = '$1'
AND    s.end_interval_time > TRUNC(SYSDATE) - $DAYS
GROUP BY TRUNC(s.end_interval_time), q.plan_hash_value
ORDER BY TRUNC(s.end_interval_time), q.plan_hash_value;

EXIT
EOF
