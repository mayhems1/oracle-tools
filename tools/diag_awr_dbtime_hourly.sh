#!/bin/bash
# DB time / DB CPU per AWR snapshot (hourly) for the last N days (default 1). Shows when load started vs normal.
# Usage: diag_awr_dbtime_hourly.sh [days]

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

DAYS=${1:-1}
if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
  echo "Error: days must be integer."
  exit 1
fi
echo "CPU cores: $(nproc). AAS = DB time / interval; AAS close to or above cores = CPU saturation."

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 300
SET PAGESIZE 1000
SET FEEDBACK OFF

COLUMN snap_end FORMAT A14
COLUMN dbtime_min FORMAT 999999.9
COLUMN dbcpu_min FORMAT 999999.9
COLUMN aas FORMAT 9999.9

SELECT snap_id,
       TO_CHAR(end_time,'DD.MM HH24:MI') AS snap_end,
       ROUND(dbtime/60,1) AS dbtime_min,
       ROUND(dbcpu/60,1) AS dbcpu_min,
       ROUND(dbtime/NULLIF(interval_s,0),1) AS aas
FROM (
  SELECT s.snap_id,
         s.end_interval_time AS end_time,
         (CAST(s.end_interval_time AS DATE) - CAST(s.begin_interval_time AS DATE))*86400 AS interval_s,
         CASE WHEN s.startup_time = LAG(s.startup_time) OVER (ORDER BY s.snap_id)
              THEN (t.value - LAG(t.value) OVER (ORDER BY s.snap_id))/1e6 END AS dbtime,
         CASE WHEN s.startup_time = LAG(s.startup_time) OVER (ORDER BY s.snap_id)
              THEN (c.value - LAG(c.value) OVER (ORDER BY s.snap_id))/1e6 END AS dbcpu
  FROM   dba_hist_snapshot s,
         dba_hist_sys_time_model t,
         dba_hist_sys_time_model c
  WHERE  t.snap_id = s.snap_id AND t.dbid = s.dbid AND t.instance_number = s.instance_number
  AND    c.snap_id = s.snap_id AND c.dbid = s.dbid AND c.instance_number = s.instance_number
  AND    t.stat_name = 'DB time'
  AND    c.stat_name = 'DB CPU'
  AND    s.dbid = (SELECT dbid FROM v\$database)
  AND    s.instance_number = (SELECT instance_number FROM v\$instance)
  AND    s.end_interval_time > TRUNC(SYSDATE) - $DAYS
)
ORDER BY snap_id;

EXIT
EOF
