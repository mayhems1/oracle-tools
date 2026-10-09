#!/bin/bash
# Active user sessions right now: who, from where, how long active, what is waiting, blocker

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 400
SET PAGESIZE 1000
SET FEEDBACK ON

COLUMN username FORMAT A18
COLUMN osuser FORMAT A15
COLUMN machine FORMAT A25
COLUMN program FORMAT A25
COLUMN module FORMAT A25
COLUMN event FORMAT A30
COLUMN active_min FORMAT 99999.9
COLUMN sql_text FORMAT A60

SELECT s.sid,
       s.serial#,
       p.spid,
       s.username,
       s.osuser,
       s.machine,
       SUBSTR(s.program,1,25) AS program,
       SUBSTR(s.module,1,25) AS module,
       ROUND(s.last_call_et/60,1) AS active_min,
       s.sql_id,
       DECODE(s.state,'WAITING',s.event,'ON CPU') AS event,
       s.seconds_in_wait AS wait_s,
       s.blocking_session AS blocker,
       (SELECT SUBSTR(REPLACE(q.sql_text,CHR(10),' '),1,60)
        FROM v\$sql q WHERE q.sql_id = s.sql_id AND ROWNUM = 1) AS sql_text
FROM   v\$session s,
       v\$process p
WHERE  s.paddr = p.addr
AND    s.type = 'USER'
AND    s.status = 'ACTIVE'
AND    s.sid <> SYS_CONTEXT('USERENV','SID')
ORDER BY s.last_call_et DESC;

EXIT
EOF
