#!/bin/bash
# Sessions active longer than N minutes (default 5) + long operations progress
# Usage: diag_now_long_running.sh [minutes]

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

MIN=${1:-5}
if ! [[ "$MIN" =~ ^[0-9]+$ ]]; then
  echo "Error: minutes must be integer."
  exit 1
fi

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 400
SET PAGESIZE 1000
SET FEEDBACK ON

COLUMN username FORMAT A18
COLUMN machine FORMAT A25
COLUMN program FORMAT A25
COLUMN event FORMAT A30
COLUMN active_min FORMAT 99999.9
COLUMN sql_text FORMAT A100
COLUMN opname FORMAT A30
COLUMN target FORMAT A40
COLUMN pct FORMAT 999.9

PROMPT === SESSIONS ACTIVE > $MIN MIN
SELECT s.sid,
       s.serial#,
       s.username,
       s.machine,
       SUBSTR(s.program,1,25) AS program,
       ROUND(s.last_call_et/60,1) AS active_min,
       s.sql_id,
       DECODE(s.state,'WAITING',s.event,'ON CPU') AS event,
       s.blocking_session AS blocker,
       (SELECT SUBSTR(REPLACE(q.sql_text,CHR(10),' '),1,100)
        FROM v\$sql q WHERE q.sql_id = s.sql_id AND ROWNUM = 1) AS sql_text
FROM   v\$session s
WHERE  s.type = 'USER'
AND    s.status = 'ACTIVE'
AND    s.last_call_et >= $MIN * 60
ORDER BY s.last_call_et DESC;

PROMPT
PROMPT === LONG OPERATIONS IN PROGRESS (v\$session_longops)
SELECT sid,
       serial#,
       opname,
       target,
       ROUND(sofar/NULLIF(totalwork,0)*100,1) AS pct,
       elapsed_seconds AS ela_s,
       time_remaining AS left_s,
       sql_id
FROM   v\$session_longops
WHERE  sofar <> totalwork
AND    time_remaining > 0
ORDER BY elapsed_seconds DESC;

EXIT
EOF
