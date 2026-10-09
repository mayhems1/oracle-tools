#!/bin/bash
# Blocking history from ASH: blockers, wait event, waited time, number of waiters, blocker user/machine
# Usage: diag_ash_blocking.sh [hours]

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
SET LINESIZE 400
SET PAGESIZE 1000
SET FEEDBACK ON

COLUMN event FORMAT A35
COLUMN blocker_user FORMAT A20
COLUMN blocker_machine FORMAT A30
COLUMN waited_min FORMAT 999999.9
COLUMN first_seen FORMAT A11
COLUMN last_seen FORMAT A11

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
, blk AS (
  SELECT blocking_session, blocking_session_serial#, event,
         SUM(w) AS waited_s,
         COUNT(DISTINCT session_id||','||session_serial#) AS waiters,
         MIN(sample_time) AS f, MAX(sample_time) AS l
  FROM   ash
  WHERE  blocking_session IS NOT NULL
  GROUP BY blocking_session, blocking_session_serial#, event
)
SELECT * FROM (
  SELECT b.blocking_session AS blocker_sid,
         b.blocking_session_serial# AS blocker_serial,
         (SELECT STATS_MODE(u.username) FROM ash x, dba_users u
          WHERE x.session_id = b.blocking_session AND x.session_serial# = b.blocking_session_serial#
          AND u.user_id = x.user_id) AS blocker_user,
         (SELECT STATS_MODE(x.machine) FROM ash x
          WHERE x.session_id = b.blocking_session AND x.session_serial# = b.blocking_session_serial#) AS blocker_machine,
         b.event,
         ROUND(b.waited_s/60,1) AS waited_min,
         b.waiters,
         TO_CHAR(b.f,'DD.MM HH24:MI') AS first_seen,
         TO_CHAR(b.l,'DD.MM HH24:MI') AS last_seen
  FROM   blk b
  ORDER BY b.waited_s DESC
) WHERE ROWNUM <= 20;

EXIT
EOF
