#!/bin/bash
# Top sessions from ASH: how long each session was active in the period, user, machine, main SQL
# Usage: diag_ash_top_sessions.sh [hours] [top=20]

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

# Period: no argument = today since 00:00, otherwise last N hours (e.g. 2, 0.5, 24)
HOURS=${1:-}
if [ -z "$HOURS" ]; then
  FROM="TRUNC(SYSDATE)"
  echo "Period: today since 00:00"
elif [[ "$HOURS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  FROM="SYSDATE - $HOURS/24"
  echo "Period: last $HOURS hour(s)"
else
  echo "Error: hours must be a number, e.g. 2 or 0.5"
  exit 1
fi

TOP=${2:-20}
if ! [[ "$TOP" =~ ^[0-9]+$ ]]; then
  echo "Error: top must be integer."
  exit 1
fi

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 400
SET PAGESIZE 1000
SET FEEDBACK OFF

COLUMN username FORMAT A20
COLUMN machine FORMAT A30
COLUMN program FORMAT A30
COLUMN active_min FORMAT 999999.9
COLUMN cpu_pct FORMAT 999.9
COLUMN first_seen FORMAT A11
COLUMN last_seen FORMAT A11
COLUMN now_status FORMAT A10

WITH ash AS (
  SELECT sample_time, session_id, session_serial#, user_id, sql_id, sql_plan_hash_value,
         session_state, event, wait_class, module, program, machine,
         blocking_session, blocking_session_serial#, 1 AS w
  FROM   v\$active_session_history
  WHERE  sample_time >= $FROM
  UNION ALL
  SELECT sample_time, session_id, session_serial#, user_id, sql_id, sql_plan_hash_value,
         session_state, event, wait_class, module, program, machine,
         blocking_session, blocking_session_serial#, 10 AS w
  FROM   dba_hist_active_sess_history
  WHERE  sample_time >= $FROM
  AND    sample_time < (SELECT NVL(MIN(sample_time), SYSTIMESTAMP) FROM v\$active_session_history)
  AND    dbid = (SELECT dbid FROM v\$database)
)
SELECT * FROM (
  SELECT a.session_id AS sid,
         a.session_serial# AS serial#,
         NVL(u.username,'(oracle)') AS username,
         STATS_MODE(a.machine) AS machine,
         STATS_MODE(SUBSTR(CASE WHEN a.program LIKE 'oracle@%' THEN 'oracle ' || REGEXP_SUBSTR(a.program,'\([^)]+\)') ELSE a.program END,1,30)) AS program,
         ROUND(SUM(a.w)/60,1) AS active_min,
         ROUND(100*SUM(DECODE(a.session_state,'ON CPU',a.w,0))/SUM(a.w),1) AS cpu_pct,
         STATS_MODE(a.sql_id) AS top_sql_id,
         TO_CHAR(MIN(a.sample_time),'DD.MM HH24:MI') AS first_seen,
         TO_CHAR(MAX(a.sample_time),'DD.MM HH24:MI') AS last_seen,
         NVL((SELECT s.status FROM v\$session s
              WHERE s.sid = a.session_id AND s.serial# = a.session_serial#),'GONE') AS now_status
  FROM   ash a,
         dba_users u
  WHERE  u.user_id (+) = a.user_id
  GROUP BY a.session_id, a.session_serial#, NVL(u.username,'(oracle)')
  ORDER BY SUM(a.w) DESC
) WHERE ROWNUM <= $TOP;

EXIT
EOF
