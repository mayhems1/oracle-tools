#!/bin/bash
# Tablespaces usage incl. TEMP / UNDO. % Used is calculated from max size (autoextend MAXBYTES included).
# Size (MB) = currently allocated files size, Max (MB) = size the tablespace can grow to.

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 200
SET PAGESIZE 1000

COLUMN "Tablespace" FORMAT A30
COLUMN "Type" FORMAT A10

SELECT m.tablespace_name "Tablespace",
       t.contents "Type",
       ROUND(f.bytes / 1024 / 1024) "Size (MB)",
       ROUND(m.tablespace_size * t.block_size / 1024 / 1024) "Max (MB)",
       ROUND(m.used_space * t.block_size / 1024 / 1024) "Used (MB)",
       ROUND((m.tablespace_size - m.used_space) * t.block_size / 1024 / 1024) "Free (MB)",
       ROUND(100 - m.used_percent, 1) "% Free",
       ROUND(m.used_percent, 1) "% Used"
FROM   dba_tablespace_usage_metrics m,
       dba_tablespaces t,
       (SELECT tablespace_name, SUM(bytes) bytes FROM dba_data_files GROUP BY tablespace_name
        UNION ALL
        SELECT tablespace_name, SUM(bytes) bytes FROM dba_temp_files GROUP BY tablespace_name) f
WHERE  t.tablespace_name = m.tablespace_name
AND    f.tablespace_name (+) = m.tablespace_name
ORDER BY m.used_percent DESC;

EXIT
EOF
