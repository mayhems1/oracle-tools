#!/bin/bash

if [ "$#" -eq 0 ]; then
  echo "Error: Session SID is not defined."
  exit 1
fi

sqlplus -S -L / as sysdba << EOF
SELECT s.sid, s.serial#, s.username, s.machine, p.spid
FROM v\$process p, v\$session s
WHERE p.addr = s.paddr
AND sid = $1;
quit
EOF
