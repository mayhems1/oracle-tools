#!/bin/bash

if [ "$#" -eq 0 ]; then
  echo "Error: Session SID is not defined."
  exit 1
fi

sqlplus -S -L / as sysdba << EOF
SET LINESIZE 500 PAGESIZE 1000 VERIFY OFF

COLUMN username FORMAT A30
COLUMN osuser FORMAT A20
COLUMN spid FORMAT A10
COLUMN service_name FORMAT A15
COLUMN module FORMAT A45
COLUMN machine FORMAT A30
COLUMN logon_time FORMAT A20

SELECT NVL(s.username, '(oracle)') AS username,
       s.osuser,
       s.sid,
       s.serial#,
       p.spid,
       s.lockwait,
       s.status,
       s.service_name,
       s.machine,
       s.program,
       TO_CHAR(s.logon_Time,'DD-MON-YYYY HH24:MI:SS') AS logon_time,
       s.last_call_et AS last_call_et_secs,
       s.module,
       s.action,
       s.client_info,
       s.client_identifier
FROM   v\$session s,
       v\$process p
WHERE  s.paddr = p.addr
AND    s.sid = $1
ORDER BY s.username, s.osuser;

SET PAGESIZE 14
quit
EOF
