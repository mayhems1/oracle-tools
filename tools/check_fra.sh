#!/bin/bash
# Fast Recovery Area: used / limit / free (GB)

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
select ROUND((SPACE_USED)/1024/1024/1024) "Used GB", ROUND((SPACE_LIMIT)/1024/1024/1024) "Limit GB", ROUND(((SPACE_LIMIT)-(SPACE_USED))/1024/1024/1024) "Free GB" from v\$recovery_File_Dest;
EXIT
EOF
