#!/bin/bash
# Top SQL by DB time from ASH: % of load, CPU share, users, modules, number of sessions
# Usage: diag_ash_top_sql.sh [hours] [top=15]

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

TOP=${2:-15}
if ! [[ "$TOP" =~ ^[0-9]+$ ]]; then
  echo "Error: top must be integer."
  exit 1
fi

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 400
SET PAGESIZE 1000
SET FEEDBACK OFF

COLUMN username FORMAT A18
COLUMN module FORMAT A30
COLUMN db_min FORMAT 999999.9
COLUMN pct FORMAT 999.9
COLUMN cpu_pct FORMAT 999.9
COLUMN sql_text FORMAT A70

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
  SELECT a.sql_id,
         a.sql_plan_hash_value AS plan_hash,
         ROUND(SUM(a.w)/60,1) AS db_min,
         ROUND(100*RATIO_TO_REPORT(SUM(a.w)) OVER (),1) AS pct,
         ROUND(100*SUM(DECODE(a.session_state,'ON CPU',a.w,0))/SUM(a.w),1) AS cpu_pct,
         COUNT(DISTINCT a.session_id||','||a.session_serial#) AS sessions,
         COUNT(DISTINCT a.user_id) AS users,
         STATS_MODE(u.username) AS username,
         STATS_MODE(SUBSTR(a.module,1,30)) AS module,
         NVL((SELECT SUBSTR(REPLACE(q.sql_text,CHR(10),' '),1,70)
              FROM v\$sql q WHERE q.sql_id = a.sql_id AND ROWNUM = 1),
             (SELECT REPLACE(DBMS_LOB.SUBSTR(h.sql_text,70,1),CHR(10),' ')
              FROM dba_hist_sqltext h WHERE h.sql_id = a.sql_id AND ROWNUM = 1)) AS sql_text
  FROM   ash a,
         dba_users u
  WHERE  u.user_id (+) = a.user_id
  GROUP BY a.sql_id, a.sql_plan_hash_value
  ORDER BY SUM(a.w) DESC
) WHERE ROWNUM <= $TOP;

EXIT
EOF
