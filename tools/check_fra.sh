#!/bin/bash

sqlplus -S -L / as sysdba << EOF
select ROUND((SPACE_USED)/1024/1024/1024) "Used GB", ROUND((SPACE_LIMIT)/1024/1024/1024) "Limit GB", ROUND(((SPACE_LIMIT)-(SPACE_USED))/1024/1024/1024) "Free GB" from v\$recovery_File_Dest;
quit
EOF