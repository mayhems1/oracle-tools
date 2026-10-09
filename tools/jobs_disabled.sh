#!/bin/bash
# Scheduler jobs: disabled

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SELECT JOB_NAME, STATE, JOB_CREATOR FROM DBA_SCHEDULER_JOBS WHERE STATE = 'DISABLED' ORDER BY JOB_NAME;
EXIT
EOF
