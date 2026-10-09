#!/bin/bash
# Open transactions: how long open, undo used, session status (idle-in-transaction = INACTIVE)

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 400
SET PAGESIZE 1000
SET FEEDBACK ON

COLUMN username FORMAT A18
COLUMN machine FORMAT A25
COLUMN program FORMAT A25
COLUMN tx_start FORMAT A17
COLUMN tx_open_min FORMAT 999999.9

SELECT s.sid,
       s.serial#,
       s.username,
       s.machine,
       SUBSTR(s.program,1,25) AS program,
       s.status,
       TO_CHAR(t.start_date,'DD.MM.YYYY HH24:MI') AS tx_start,
       ROUND((SYSDATE - t.start_date)*1440,1) AS tx_open_min,
       ROUND(s.last_call_et/60,1) AS last_call_min,
       t.used_ublk AS undo_blocks,
       t.used_urec AS undo_records,
       s.sql_id,
       s.prev_sql_id
FROM   v\$transaction t,
       v\$session s
WHERE  s.saddr = t.ses_addr
ORDER BY t.start_date;

EXIT
EOF
