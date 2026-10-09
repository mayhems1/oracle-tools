#!/bin/bash
# Load timeline from ASH: avg active sessions (AAS) per bucket split by CPU / IO / locks etc. Compare AAS with CPU cores.
# Usage: diag_ash_load_timeline.sh [hours] [bucket_minutes=10]

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

BUCKET=${2:-10}
if ! [[ "$BUCKET" =~ ^[0-9]+$ ]] || [ "$BUCKET" -eq 0 ]; then
  echo "Error: bucket minutes must be integer > 0."
  exit 1
fi
echo "Bucket: $BUCKET min, CPU cores: $(nproc)"

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 300
SET PAGESIZE 1000
SET FEEDBACK OFF

COLUMN bucket FORMAT A11

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
SELECT TO_CHAR(TRUNC(CAST(sample_time AS DATE),'HH24')
               + FLOOR(TO_NUMBER(TO_CHAR(sample_time,'MI'))/$BUCKET)*$BUCKET/1440,'DD.MM HH24:MI') AS bucket,
       ROUND(SUM(w)/($BUCKET*60),1) AS aas,
       ROUND(SUM(DECODE(session_state,'ON CPU',w,0))/($BUCKET*60),1) AS cpu,
       ROUND(SUM(DECODE(wait_class,'User I/O',w,0))/($BUCKET*60),1) AS user_io,
       ROUND(SUM(DECODE(wait_class,'System I/O',w,0))/($BUCKET*60),1) AS sys_io,
       ROUND(SUM(DECODE(wait_class,'Application',w,0))/($BUCKET*60),1) AS app_lock,
       ROUND(SUM(DECODE(wait_class,'Concurrency',w,0))/($BUCKET*60),1) AS concur,
       ROUND(SUM(DECODE(wait_class,'Commit',w,0))/($BUCKET*60),1) AS commit_,
       ROUND(SUM(CASE WHEN session_state='WAITING' AND wait_class NOT IN ('User I/O','System I/O','Application','Concurrency','Commit') THEN w ELSE 0 END)/($BUCKET*60),1) AS other,
       COUNT(DISTINCT session_id||','||session_serial#) AS sessions
FROM   ash
GROUP BY TO_CHAR(TRUNC(CAST(sample_time AS DATE),'HH24')
               + FLOOR(TO_NUMBER(TO_CHAR(sample_time,'MI'))/$BUCKET)*$BUCKET/1440,'DD.MM HH24:MI')
ORDER BY 1;

EXIT
EOF
