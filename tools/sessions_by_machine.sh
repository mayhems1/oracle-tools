#!/bin/bash
# Sessions count by machine: active / inactive / killed

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 200
SET PAGESIZE 1000
COLUMN machine FORMAT A64

SELECT machine,
       NVL(active_count, 0) AS active,
       NVL(inactive_count, 0) AS inactive,
       NVL(killed_count, 0) AS killed
FROM   (SELECT machine, status, count(*) AS quantity
        FROM   v\$session
        GROUP BY machine, status)
PIVOT  (SUM(quantity) AS count FOR (status) IN ('ACTIVE' AS active, 'INACTIVE' AS inactive, 'KILLED' AS killed))
ORDER BY machine;

EXIT
EOF
