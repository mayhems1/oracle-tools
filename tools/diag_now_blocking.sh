#!/bin/bash
# Current blocking tree: who holds, who waits, how long, which object

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 400
SET PAGESIZE 1000
SET FEEDBACK ON

COLUMN tree FORMAT A20
COLUMN username FORMAT A18
COLUMN machine FORMAT A25
COLUMN program FORMAT A25
COLUMN event FORMAT A35
COLUMN locked_object FORMAT A45

PROMPT === BLOCKING TREE
SELECT LPAD(' ', 2*(LEVEL-1)) || s.sid AS tree,
       s.serial#,
       s.username,
       s.machine,
       SUBSTR(s.program,1,25) AS program,
       s.status,
       ROUND(s.last_call_et/60,1) AS last_call_min,
       s.sql_id,
       s.prev_sql_id,
       DECODE(s.state,'WAITING',s.event,'ON CPU') AS event,
       s.seconds_in_wait AS wait_s
FROM   v\$session s
WHERE  s.blocking_session IS NOT NULL
OR     s.sid IN (SELECT blocking_session FROM v\$session WHERE blocking_session IS NOT NULL)
START WITH s.blocking_session IS NULL
CONNECT BY PRIOR s.sid = s.blocking_session;

PROMPT
PROMPT === OBJECTS WAITED ON
SELECT s.sid,
       s.blocking_session AS blocker,
       o.owner || '.' || o.object_name AS locked_object,
       o.object_type,
       s.row_wait_obj#,
       s.row_wait_file#,
       s.row_wait_block#,
       s.row_wait_row#
FROM   v\$session s,
       dba_objects o
WHERE  s.blocking_session IS NOT NULL
AND    o.object_id (+) = s.row_wait_obj#;

EXIT
EOF
