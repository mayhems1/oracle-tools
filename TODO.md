# TODO

Review of the original scripts in `tools/` (2026-10-07). Order of work: 1 → 2 → then decide next.

## 1. Bugs (confirmed on a test 11.2 database)

- [x] `sessions_by_machine.sh` — `v$session` without `\` → bash expands `$session` → `FROM v` → ORA-04044. Script does not work.
- [x] `sessions_top.sh` — `&1` is sqlplus substitution, not bash: argument is ignored, sqlplus prints `Enter value for 1:` and always falls to CPU. Use `$1`, validate READS|EXECS|CPU.
- [x] `sessions_top.sh`, `sessions_top_cpu*.sh` — `v$sesstat` is cumulative since logon: old INACTIVE sessions on top (e.g. a monitoring session logged in days ago), no ACTIVE filter / no limit, `sessions_top_cpu.sh` has no ORDER BY, `NAME like '%...%'` instead of `=`. For "who loads now" use ASH (`diag_ash_top_sessions.sh 0.25`).
- [x] All scripts — exit code is always 0 on ORA- error, no `WHENEVER SQLERROR EXIT`. `jobs_to_disable.sh` prints "Job disabled" even on error.
- [x] `tablespace_check.sh` — `/* + RULE */` with space is a comment, not a hint (RULE is obsolete anyway); `% Used` ignores autoextend `MAXBYTES`. Use `dba_tablespace_usage_metrics`.

## 2. Unify template

- [x] `sqlplus -S -L / as sysdba` everywhere (`jobs_*` use `-s` without `-L` → hangs on password prompt if login fails).
- [x] Load Oracle env when not set (non-login `ssh host 'script'` → empty `ORACLE_SID`).
- [x] Validate arguments (SID / SPID numeric, names by regex); `p.spid = '$1'` (VARCHAR2).
- [x] Newline after final `EOF` (8 files), consistent `EXIT` at the end, drop useless `SET PAGESIZE 14` at the end.

## 3. Improvements (later)

- [ ] `jobs_*`: LINESIZE / COLUMN, add OWNER, LAST_START_DATE, NEXT_RUN_DATE, FAILURE_COUNT; merge list/enabled/disabled into one script with argument; `DISABLE` needs `OWNER.JOB_NAME`.
- [ ] Date format `DD.MM.YYYY` instead of `DD-MON-YYYY` (NLS dependent).
- [ ] `sessions_sql_text_by_sid.sh`: `v$sqltext` splits text by 64 chars, empty for INACTIVE → use `v$sql.sql_fulltext` by `sql_id`, fallback `prev_sql_id`.
- [ ] `sessions_active.sh`: add `sql_id`, `event`, `blocking_session`, exclude background; or keep only `diag_now_active.sh`.
- [ ] `sessions_top_cpu.sh` / `sessions_top_cpu2.sh` — near duplicates, merge.
- [ ] `check_fra.sh`: add `SPACE_RECLAIMABLE`, %, breakdown by file type (`v$recovery_area_usage`).
- [ ] `check_status_lag_replication.sh`: hardcoded 2 RAC threads / DEST_ID 1,2, UNION of copies, gap value not printed → `v$archive_dest_status` (primary), `v$dataguard_stats` / `v$managed_standby` (standby).
- [ ] `rman_crosscheck_*.sh`: log to file, check exit code.

## 4. New scripts

Incidents ("slow" / "hangs"):

- [ ] `sessions_kill_cmd.sh <sid|username>` — only PRINTS `ALTER SYSTEM KILL SESSION ...` and `kill -9 spid`, does not execute.
- [ ] `temp_usage_by_session.sh`, `undo_usage_by_session.sh` — who uses TEMP / UNDO.
- [ ] `alert_log_errors.sh [hours]` — ORA- errors from alert log (`v$diag_alert_ext` / adrci).
- [ ] `redo_switches_hourly.sh` — log switches per hour (DML peaks, small redo logs).

Health checks:

- [ ] `backup_last.sh` — last RMAN backups, status, duration (`v$rman_backup_job_details`).
- [ ] `stats_stale.sh [owner]` — stale stats + last dictionary / fixed objects stats gathering.
- [ ] `objects_invalid.sh`
- [ ] `users_expiring.sh` — locked users, expiring passwords.
- [ ] `db_size.sh`, `segments_top.sh [N]`

Repo:

- [ ] `_common.sh` (env, WHENEVER, SET, validation) — trade-off: scripts no longer fully standalone.
- [ ] Run `shellcheck` on all scripts.
- [ ] README: list of all scripts, not only `diag_*`.

## Done

- [x] `diag_*` scripts for first-look performance diagnostics (2026-10-07).
