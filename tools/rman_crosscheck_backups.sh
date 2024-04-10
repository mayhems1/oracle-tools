#!/bin/bash

rman target / <<EOF
run
{
CROSSCHECK BACKUP;
DELETE NOPROMPT EXPIRED BACKUP;
}
exit;
EOF
