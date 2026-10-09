#!/bin/bash
# Top wait events from ASH (ON CPU included)
# Usage: diag_ash_top_events.sh [hours]

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

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 300
SET PAGESIZE 1000
SET FEEDBACK OFF

COLUMN event FORMAT A45
COLUMN wait_class FORMAT A15
COLUMN db_min FORMAT 999999.9
COLUMN pct FORMAT 999.9

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
  SELECT DECODE(session_state,'ON CPU','ON CPU',event) AS event,
         DECODE(session_state,'ON CPU','CPU',wait_class) AS wait_class,
         ROUND(SUM(w)/60,1) AS db_min,
         ROUND(100*RATIO_TO_REPORT(SUM(w)) OVER (),1) AS pct,
         COUNT(DISTINCT session_id||','||session_serial#) AS sessions
  FROM   ash
  GROUP BY DECODE(session_state,'ON CPU','ON CPU',event), DECODE(session_state,'ON CPU','CPU',wait_class)
  ORDER BY SUM(w) DESC
) WHERE ROWNUM <= 20;

EXIT
EOF
