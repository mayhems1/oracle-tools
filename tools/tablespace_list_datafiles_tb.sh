#!/bin/bash
# Datafiles of one tablespace
# Usage: tablespace_list_datafiles_tb.sh <TABLESPACE>

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

if [ "$#" -eq 0 ]; then
  echo "Error: Tablespace name is not defined."
  exit 1
fi
TB=$(echo "$1" | tr '[:lower:]' '[:upper:]')
if ! [[ "$TB" =~ ^[A-Z0-9_\$#]+$ ]]; then
  echo "Error: invalid tablespace name: $1"
  exit 1
fi

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 200
COLUMN file_name FORMAT A70

SELECT file_id,
       file_name,
       ROUND(bytes/1024/1024/1024) AS size_gb,
       ROUND(maxbytes/1024/1024/1024) AS max_size_gb,
       autoextensible,
       increment_by,
       status
FROM   dba_data_files
WHERE  tablespace_name = '$TB'
ORDER BY file_id;

EXIT
EOF
