#!/bin/bash

if [ "$#" -eq 0 ]; then
  echo "Error: Job scheduler name is not defined."
  exit 1
fi

sqlplus -s "/ as sysdba" <<EOF
exec DBMS_SCHEDULER.DISABLE('$1');
exit;
EOF

echo Job disabled: $1
