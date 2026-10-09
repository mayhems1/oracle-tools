#!/bin/bash
# Table stats, column stats and indexes: helps to find missing index for a filtered column
# Usage: diag_table_indexes.sh <OWNER> <TABLE>

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

if [ "$#" -lt 2 ]; then
  echo "Error: OWNER and TABLE are not defined. Usage: $(basename "$0") <OWNER> <TABLE>"
  exit 1
fi
OWNER=$(echo "$1" | tr '[:lower:]' '[:upper:]')
TABLE=$(echo "$2" | tr '[:lower:]' '[:upper:]')
if ! [[ "$OWNER" =~ ^[A-Z0-9_\$#]+$ && "$TABLE" =~ ^[A-Z0-9_\$#]+$ ]]; then
  echo "Error: invalid OWNER or TABLE name."
  exit 1
fi

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 300
SET PAGESIZE 1000
SET FEEDBACK OFF

COLUMN index_name FORMAT A30
COLUMN column_name FORMAT A30
COLUMN columns FORMAT A60
COLUMN data_type FORMAT A15
COLUMN last_analyzed FORMAT A16
COLUMN size_mb FORMAT 9999999.9

PROMPT === TABLE
SELECT t.num_rows,
       t.blocks,
       ROUND((SELECT SUM(bytes) FROM dba_segments
              WHERE owner = t.owner AND segment_name = t.table_name)/1024/1024,1) AS size_mb,
       t.partitioned,
       TO_CHAR(t.last_analyzed,'DD.MM.YYYY HH24:MI') AS last_analyzed,
       s.stale_stats
FROM   dba_tables t,
       dba_tab_statistics s
WHERE  t.owner = '$OWNER' AND t.table_name = '$TABLE'
AND    s.owner (+) = t.owner AND s.table_name (+) = t.table_name AND s.object_type (+) = 'TABLE';

PROMPT
PROMPT === INDEXES
SELECT i.index_name,
       i.uniqueness,
       i.status,
       (SELECT LISTAGG(c.column_name, ', ') WITHIN GROUP (ORDER BY c.column_position)
        FROM dba_ind_columns c
        WHERE c.index_owner = i.owner AND c.index_name = i.index_name) AS columns,
       i.blevel,
       i.distinct_keys,
       i.clustering_factor,
       TO_CHAR(i.last_analyzed,'DD.MM.YYYY HH24:MI') AS last_analyzed
FROM   dba_indexes i
WHERE  i.table_owner = '$OWNER' AND i.table_name = '$TABLE'
ORDER BY i.index_name;

PROMPT
PROMPT === COLUMNS (indexed = leading column of some index)
SELECT c.column_name,
       c.data_type,
       c.num_distinct,
       c.num_nulls,
       c.histogram,
       CASE WHEN EXISTS (SELECT 1 FROM dba_ind_columns ic
                         WHERE ic.table_owner = c.owner AND ic.table_name = c.table_name
                         AND ic.column_name = c.column_name AND ic.column_position = 1)
            THEN 'YES' ELSE '-' END AS indexed
FROM   dba_tab_columns c
WHERE  c.owner = '$OWNER' AND c.table_name = '$TABLE'
ORDER BY c.column_id;

PROMPT
PROMPT === FOREIGN KEYS WITHOUT INDEX (cause locks on parent DML)
SELECT c.constraint_name,
       LISTAGG(cc.column_name, ', ') WITHIN GROUP (ORDER BY cc.position) AS columns
FROM   dba_constraints c,
       dba_cons_columns cc
WHERE  c.owner = '$OWNER' AND c.table_name = '$TABLE' AND c.constraint_type = 'R'
AND    cc.owner = c.owner AND cc.constraint_name = c.constraint_name
AND    NOT EXISTS (SELECT 1 FROM dba_ind_columns ic
                   WHERE ic.table_owner = c.owner AND ic.table_name = c.table_name
                   AND ic.column_name = cc.column_name AND ic.column_position = cc.position)
GROUP BY c.constraint_name;

EXIT
EOF
