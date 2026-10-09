# oracle-tools

Oracle some useful scripts for daily works

## Add to user Path e.g. oracle user

```bash
# Oracle tools
export PATH="$PATH:$HOME/oracle-tools/tools"
```

## Diagnostics: diag_* (read-only)

Small scripts for first-look performance diagnostics ("DB is slow"). Only SELECT on `v$` / `dba_` / ASH / AWR, no changes in DB.
ASH / AWR scripts need Diagnostic Pack (`control_management_pack_access` = `DIAGNOSTIC` or `DIAGNOSTIC+TUNING`).

`[hours]` for `diag_ash_*`: no argument = today since 00:00, or last N hours (`2`, `0.5`, `24`).
In-memory ASH is used first, older part of the period is taken from AWR ASH (`dba_hist_active_sess_history`, 10s samples).

### Quick start

```bash
diag_quick.sh            # now + last 1 hour
diag_quick.sh 3 --log    # now + last 3 hours, save to $DIAG_LOG_DIR (default ~/diag-logs)
```

### Right now

| Script | What |
| --- | --- |
| `diag_now_overview.sh` | host load / CPU / RAM, sessions by status, current wait events, load last 15 min |
| `diag_now_active.sh` | active sessions: user, machine, program, minutes active, sql_id, event, blocker, SQL text |
| `diag_now_long_running.sh [min=5]` | sessions active longer than N minutes + `v$session_longops` progress |
| `diag_now_blocking.sh` | blocking tree and objects waited on |
| `diag_now_open_tx.sh` | open transactions: how long open, undo used (INACTIVE + open tx = forgotten commit) |

### For a period (ASH / AWR)

| Script | What |
| --- | --- |
| `diag_ash_load_timeline.sh [hours] [bucket_min=10]` | load (AAS) per bucket split by CPU / IO / locks; compare AAS with CPU cores |
| `diag_ash_top_sql.sh [hours] [top=15]` | top SQL by DB time, % of load, CPU %, sessions, user, module |
| `diag_ash_top_users.sh [hours] [top=20]` | who loads the DB: user / machine / program, top sql_id |
| `diag_ash_top_sessions.sh [hours] [top=20]` | top sessions: minutes active in period, main SQL, current status |
| `diag_ash_top_events.sh [hours]` | top wait events |
| `diag_ash_blocking.sh [hours]` | blocking history: blocker user / machine, waited time, waiters |
| `diag_awr_dbtime_hourly.sh [days=1]` | DB time / DB CPU / AAS per AWR snapshot, to compare with normal load |

### Drill down

| Script | What |
| --- | --- |
| `diag_sql_info.sh <sql_id> [days=7]` | full SQL text, cursor stats per execution, AWR history by day / plan |
| `diag_sql_plan.sh <sql_id>` | execution plan from cursor cache, or from AWR if cursor is gone |
| `diag_table_indexes.sh <OWNER> <TABLE>` | table / column stats, indexes, columns without index, FK without index |

### Typical flow

```bash
diag_quick.sh 2                                  # what is loading and since when
diag_ash_top_sql.sh 2                            # -> sql_id
diag_sql_info.sh <sql_id>                        # per-exec time / gets, did it change by day / plan
diag_sql_plan.sh <sql_id>                        # FULL scan?
diag_table_indexes.sh <OWNER> <TABLE>            # is there an index on the filtered column
```

## Sources

- [Oracle-Base DBA Scripts](https://oracle-base.com/dba/scripts)
