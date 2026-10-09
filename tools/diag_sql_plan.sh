#!/bin/bash
# Execution plan by sql_id: from cursor cache (all children), or from AWR if cursor is gone
# Usage: diag_sql_plan.sh <sql_id>

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

if [ "$#" -eq 0 ]; then
  echo "Error: SQL_ID is not defined."
  exit 1
fi
if ! [[ "$1" =~ ^[0-9a-z]{13}$ ]]; then
  echo "Error: SQL_ID must be 13 chars [0-9a-z]."
  exit 1
fi

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 300
SET PAGESIZE 0
SET FEEDBACK OFF
SET TRIMSPOOL ON

SELECT 'Source: ' || CASE WHEN COUNT(*) > 0 THEN 'cursor cache (v\$sql)' ELSE 'AWR (dba_hist_sql_plan)' END
FROM   v\$sql WHERE sql_id = '$1';

SELECT plan_table_output
FROM   TABLE(DBMS_XPLAN.DISPLAY_CURSOR('$1', NULL, 'TYPICAL'))
WHERE  EXISTS (SELECT 1 FROM v\$sql WHERE sql_id = '$1');

SELECT plan_table_output
FROM   TABLE(DBMS_XPLAN.DISPLAY_AWR('$1', NULL, NULL, 'TYPICAL'))
WHERE  NOT EXISTS (SELECT 1 FROM v\$sql WHERE sql_id = '$1');

EXIT
EOF
