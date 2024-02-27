#!/bin/bash

sqlplus -S -L / as sysdba << EOF
SET PAGESIZE 60
SET LINESIZE 300

COLUMN username FORMAT A30
COLUMN sid FORMAT 999,999,999
COLUMN serial# FORMAT 999,999,999
COLUMN "cpu usage (seconds)"  FORMAT 999,999,999.0000

select
   ss.username,
   se.SID,
   VALUE/100 cpu_usage_seconds
from
   v\$session ss,
   v\$sesstat se,
   v\$statname sn
where
   se.STATISTIC# = sn.STATISTIC#
and
   NAME like '%CPU used by this session%'
and
   se.SID = ss.SID
and
   ss.status='ACTIVE'
and
   ss.username is not null
order by VALUE desc;
EOF