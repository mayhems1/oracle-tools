#!/bin/bash
# Current SQL text of session by SID
# Usage: sessions_sql_text_by_sid.sh <SID>

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

if [ "$#" -eq 0 ]; then
  echo "Error: Session SID is not defined."
  exit 1
fi
if ! [[ "$1" =~ ^[0-9]+$ ]]; then
  echo "Error: Session SID must be a number."
  exit 1
fi

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 500
SET PAGESIZE 1000
SET VERIFY OFF

SELECT a.sql_text
FROM   v\$sqltext a,
       v\$session b
WHERE  a.address = b.sql_address
AND    a.hash_value = b.sql_hash_value
AND    b.sid = $1
ORDER BY a.piece;

EXIT
EOF
