#!/bin/bash
# Overview right now: host load, instance, sessions, current waits

# Load Oracle env for non-login shells (e.g. ssh host 'script')
[ -z "$ORACLE_SID" ] && [ -f "$HOME/.bash_profile" ] && . "$HOME/.bash_profile" > /dev/null 2>&1

echo "=== HOST: $(hostname)"
uptime
echo "CPU cores: $(nproc)"
free -g | head -2
echo

sqlplus -S -L / as sysdba << EOF
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 300
SET PAGESIZE 1000
SET FEEDBACK OFF

COLUMN instance_name FORMAT A12
COLUMN host_name FORMAT A30
COLUMN version FORMAT A12
COLUMN startup FORMAT A17
COLUMN event FORMAT A45
COLUMN wait_class FORMAT A15

PROMPT === INSTANCE
SELECT instance_name, host_name, version, status,
       TO_CHAR(startup_time,'DD.MM.YYYY HH24:MI') AS startup
FROM   v\$instance;

PROMPT
PROMPT === SESSIONS BY TYPE / STATUS
SELECT type, status, COUNT(*) AS cnt
FROM   v\$session
GROUP BY type, status
ORDER BY type, status;

PROMPT
PROMPT === ACTIVE USER SESSIONS BY WAIT CLASS (now)
SELECT DECODE(state,'WAITING',wait_class,'ON CPU') AS wait_class, COUNT(*) AS cnt
FROM   v\$session
WHERE  type = 'USER' AND status = 'ACTIVE'
AND    (state <> 'WAITING' OR wait_class <> 'Idle')
AND    sid <> SYS_CONTEXT('USERENV','SID')
GROUP BY DECODE(state,'WAITING',wait_class,'ON CPU')
ORDER BY 2 DESC;

PROMPT
PROMPT === CURRENT WAIT EVENTS (active user sessions)
SELECT DECODE(state,'WAITING',event,'ON CPU') AS event,
       DECODE(state,'WAITING',wait_class,'CPU') AS wait_class,
       COUNT(*) AS sessions,
       MAX(DECODE(state,'WAITING',seconds_in_wait)) AS max_wait_s
FROM   v\$session
WHERE  type = 'USER' AND status = 'ACTIVE'
AND    (state <> 'WAITING' OR wait_class <> 'Idle')
AND    sid <> SYS_CONTEXT('USERENV','SID')
GROUP BY DECODE(state,'WAITING',event,'ON CPU'), DECODE(state,'WAITING',wait_class,'CPU')
ORDER BY 3 DESC;

PROMPT
PROMPT === LOAD LAST 15 MIN (ASH, avg active sessions per minute)
SELECT TO_CHAR(TRUNC(sample_time,'MI'),'HH24:MI') AS minute,
       ROUND(COUNT(*)/60,1) AS aas,
       ROUND(SUM(DECODE(session_state,'ON CPU',1,0))/60,1) AS cpu,
       ROUND(SUM(DECODE(session_state,'WAITING',1,0))/60,1) AS wait
FROM   v\$active_session_history
WHERE  sample_time > SYSDATE - 15/1440
GROUP BY TRUNC(sample_time,'MI')
ORDER BY 1;

EXIT
EOF
