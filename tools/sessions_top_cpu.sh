#!/bin/bash
# CPU used by ACTIVE user sessions (seconds, cumulative since logon)
# For "who loads the DB now" use: diag_ash_top_sessions.sh 0.25

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET PAGESIZE 60
SET LINESIZE 300

COLUMN username FORMAT A30
COLUMN sid FORMAT 999,999,999
COLUMN serial# FORMAT 999,999,999
COLUMN "cpu usage (seconds)" FORMAT 999,999,999.0000
COLUMN cpu_usage_seconds FORMAT 999,999,999.0000

SELECT
   s.username,
   t.sid,
   s.serial#,
   t.value/100 AS "cpu usage (seconds)"
FROM
   v\$session s,
   v\$sesstat t,
   v\$statname n
WHERE
   t.statistic# = n.statistic#
AND
   n.name = 'CPU used by this session'
AND
   t.sid = s.sid
AND
   s.status = 'ACTIVE'
AND
   s.username IS NOT NULL
ORDER BY t.value DESC;

EXIT
EOF
