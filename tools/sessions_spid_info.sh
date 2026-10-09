#!/bin/bash
# Session short info by SPID
# Usage: sessions_spid_info.sh <SPID>

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

if [ "$#" -eq 0 ]; then
  echo "Error: Session SPID is not defined."
  exit 1
fi
if ! [[ "$1" =~ ^[0-9]+$ ]]; then
  echo "Error: Session SPID must be a number."
  exit 1
fi

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SELECT s.sid, s.serial#, s.username, s.machine, p.spid
FROM v\$process p, v\$session s
WHERE p.addr = s.paddr
AND p.spid = '$1';
EXIT
EOF
