#!/bin/bash
# RMAN: crosscheck backups and delete EXPIRED records

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

rman target / << EOF
run
{
CROSSCHECK BACKUP;
DELETE NOPROMPT EXPIRED BACKUP;
}
EXIT
EOF
