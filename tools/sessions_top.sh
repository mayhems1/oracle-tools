#!/bin/bash
# Top sessions by statistic: READS (logical reads), EXECS (executions), CPU (seconds)
# Values are cumulative since session logon (v$sesstat), not current load.
# For "who loads the DB now" use: diag_ash_top_sessions.sh 0.25
# Usage: sessions_top.sh [READS|EXECS|CPU] [top=20]

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

STAT=$(echo "${1:-CPU}" | tr '[:lower:]' '[:upper:]')
case "$STAT" in
  READS) NAME='session logical reads'; DIV=1 ;;
  EXECS) NAME='execute count'; DIV=1 ;;
  CPU)   NAME='CPU used by this session'; DIV=100 ;;
  *) echo "Error: statistic must be READS, EXECS or CPU."; exit 1 ;;
esac
TOP=${2:-20}
if ! [[ "$TOP" =~ ^[0-9]+$ ]]; then
  echo "Error: top must be integer."
  exit 1
fi

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 500
SET PAGESIZE 1000
SET VERIFY OFF

COLUMN username FORMAT A15
COLUMN machine FORMAT A25
COLUMN logon_time FORMAT A20

SELECT * FROM (
  SELECT NVL(a.username, '(oracle)') AS username,
         a.osuser,
         a.sid,
         a.serial#,
         ROUND(c.value/$DIV) AS $STAT,
         a.lockwait,
         a.status,
         a.module,
         a.machine,
         a.program,
         TO_CHAR(a.logon_Time,'DD-MON-YYYY HH24:MI:SS') AS logon_time
  FROM   v\$session a,
         v\$sesstat c,
         v\$statname d
  WHERE  a.sid        = c.sid
  AND    c.statistic# = d.statistic#
  AND    d.name       = '$NAME'
  ORDER BY c.value DESC
) WHERE ROWNUM <= $TOP;

EXIT
EOF
