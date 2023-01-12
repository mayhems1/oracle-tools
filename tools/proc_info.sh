#!/bin/bash

sqlplus -S -L / as sysdba << EOF
SELECT s.sid, s.serial#, s.username, s.machine, p.spid
FROM v\$process p, v\$session s
WHERE p.addr = s.paddr
AND spid = $1;
quit
EOF

#sqlplus -s "/ as sysdba" <<EOF
# sqlplus -s "/ as sysdba" @/home/oracle/tools/sql/proc_info.sql $1
#start proc_info.sql &1
#exit;
#EOF


# SELECT s.sid, s.serial#, s.username, s.machine, p.spid
# FROM v$process p, v$session s
# WHERE p.addr = s.paddr
# AND spid = &1;
# quit