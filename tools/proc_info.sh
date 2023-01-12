#!/bin/bash

sqlplus -S -L / as sysdba << EOF
SELECT s.sid, s.serial#, s.username, s.machine, p.spid
FROM v\$process p, v\$session s
WHERE p.addr = s.paddr
AND spid = $1;
quit
EOF