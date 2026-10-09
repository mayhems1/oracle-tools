#!/bin/bash
# Disable scheduler job
# Usage: jobs_to_disable.sh <[OWNER.]JOB_NAME>

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

if [ "$#" -eq 0 ]; then
  echo "Error: Job scheduler name is not defined."
  exit 1
fi
if ! [[ "$1" =~ ^[A-Za-z0-9_\$#]+([.][A-Za-z0-9_\$#]+)?$ ]]; then
  echo "Error: invalid job name: $1"
  exit 1
fi

sqlplus -S -L / as sysdba << EOF || { echo "Error: job is not disabled: $1"; exit 1; }
WHENEVER SQLERROR EXIT FAILURE
exec DBMS_SCHEDULER.DISABLE('$1');
EXIT
EOF

echo "Job disabled: $1"
