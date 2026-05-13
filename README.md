# Log File Analyzer and Rotator

## Quick start
```bash
bash install.sh
crontab -l
```

The installer will:

- make scripts executable
- create required directories
- generate a sample log file
- register the hourly cron job

`crontab -l` is used to verify that the cron entry was installed correctly.

---

## Log Analyzer (`analyzer.sh`)

### Overview

`analyzer.sh` is a Bash-based log analysis tool that processes system logs and generates summarized reports.  
It is designed to work with common Linux log files such as:

- `/var/log/syslog`
- `/var/log/auth.log`

The script scans log entries using keyword-based classification and groups them into three categories:

- **ERROR** – critical failures, denied actions, crashes, authentication failures
- **WARNING** – suspicious or potentially problematic events
- **INFO** – normal system activity and all remaining logs

### Features

- Parses multiple system log files
- Uses regex/keyword matching for classification
- Generates timestamped summary reports
- Stores reports in `./summary/`
- Automatically tracks total log statistics:
  - ERROR count
  - WARNING count
  - INFO count
  - TOTAL lines processed
- Compares with previous report (if available) and shows trend changes
- Triggers `rotator.sh` after analysis (if present)

### Output

Reports are stored in the `./summary` folder, which is created by `analyzer.sh` if it does not already exist.

### Analyzer launch

Make the script executable:
```bash
chmod +x analyzer.sh
```

Execute script manually:
```bash
./analyzer.sh
```

The script is primarily intended to be run automatically by cron, but it can also be executed manually for testing.

---

## Summary (`summary/summary-<timestamp>.txt`)

### Overview

Each run of `analyzer.sh` creates a timestamped summary report in `./summary/`.  
The report is more than a simple snapshot: it includes basic analytics that make hourly reports easier to read and compare.

### Summary contents

A generated summary includes:

- **Processed files**
  - shows which log files were readable and analyzed
  - shows which files were skipped because they were not readable

- **Overall statistics**
  - TOTAL lines processed
  - ERROR count
  - WARNING count
  - INFO count

- **Top 5 error messages**
  - shows the most common error messages found in the analyzed logs
  - helps identify repeated failures instead of only counting them

- **Most active log file**
  - shows which analyzed log file contained the most lines
  - helps identify where most activity happened

- **Error rate**
  - shows the percentage of ERROR lines relative to all processed lines
  - gives a quick health signal for the current snapshot

- **Tendency**
  - compares the current report with the previous summary file, if one exists
  - shows the difference in ERROR / WARNING / INFO counts from the previous run
  - helps track whether the system is getting better or worse over time

### Example summary sections

```text
Summary:
TOTAL: 4125
ERROR:   491
WARNING: 237
INFO:    3397

Top 5 error messages:
 - 124x authentication failure
 - 87x connection refused
 - 53x disk full

Most active log file:
 - /var/log/syslog (3120 lines)

Error rate: 11.90%

Tendency:
ERROR_TENDENCY:   +12
WARNING_TENDENCY: -5
INFO_TENDENCY:    -30
```

---

## Log Rotator (`rotator.sh`)

### Overview

`rotator.sh` handles log rotation for custom application log files stored in `./logs/`.  
It is called automatically by `analyzer.sh` at the end of each analysis run.

> **Why not rotate system logs?**  
> System logs (`/var/log/syslog`, `/var/log/auth.log`) are already managed by `logrotate` on Linux.  
> Rotating them a second time would interfere with that system daemon and could corrupt log files.  
> Instead, this script rotates application-specific logs in `./logs/` — a safe, self-contained directory.

### How rotation works

1. Each `.log` file in `./logs/` is checked against a configurable size threshold (default: **1 MB**).
2. Files **under** the threshold are skipped with a log message.
3. Files **at or over** the threshold are:
   - Compressed with `gzip` into `./logs/archive/<name>-<timestamp>.log.gz`
   - Truncated in-place (so open file descriptors from running applications are preserved)
4. Old archives are pruned: only the **5 most recent** archives per log file are kept.
5. After any rotation occurs, **SIGUSR2** is sent to the application (see below).

### SIGUSR2 — application reload signal

After rotating at least one log file, `rotator.sh` reads `./app.pid` and sends `SIGUSR2` to that process.  
This is the standard Unix pattern for telling a running application to close and reopen its log file handles.

To enable this:
1. Write your application's PID to `./app.pid` on startup:
   ```bash
   echo $$ > ./app.pid
   ```
2. In your application, install a `SIGUSR2` handler that reopens the log file descriptor.

Example signal handler (Bash):
```bash
reopen_log() {
  exec >> ./logs/app.log 2>&1
  echo "$(date '+%b %d %H:%M:%S') $(hostname) myapp[$$]: INFO Log file reopened after rotation"
}
trap reopen_log SIGUSR2
```

If `app.pid` is absent or the process is not running, the signal is silently skipped.

### Configuration

Edit the variables at the top of `rotator.sh`:

| Variable         | Default          | Description                                 |
|------------------|------------------|---------------------------------------------|
| `LOG_DIR`        | `./logs`         | Directory containing log files to rotate    |
| `ARCHIVE_DIR`    | `./logs/archive` | Where compressed archives are stored        |
| `PID_FILE`       | `./app.pid`      | File containing the application's PID       |
| `MAX_SIZE_BYTES` | `1048576` (1 MB) | File size that triggers rotation            |
| `MAX_ARCHIVES`   | `5`              | Number of archives to keep per log file     |

### Output example

```text
[rotator] 2026-05-10 22:50:19 ROTATE app.log  (1073666 bytes → app-2026-05-10_22-50-19.log.gz)
[rotator] 2026-05-10 22:50:19 OK    created ./logs/archive/app-2026-05-10_22-50-19.log.gz
[rotator] 2026-05-10 22:50:19 SIGNAL sending SIGUSR2 to PID 4821
[rotator] 2026-05-10 22:50:19 DONE
```

---

## Sample Log Generator (`generate_sample_log.sh`)

### Overview

Generates a realistic syslog-style log file at `./logs/app.log` for testing rotation.  
The file is intentionally sized above the 1 MB rotation threshold by default.

### Usage

```bash
bash generate_sample_log.sh          # generates ~1 MB (15 000 lines)
bash generate_sample_log.sh 5000     # fewer lines (may not trigger rotation)
bash generate_sample_log.sh 20000    # more lines (larger file)
```

### Log format

Entries follow the standard syslog format:

```text
May 10 14:27:50 server01 myapp[9649]: ERROR connection refused to 10.0.0.74:5432
May 10 14:03:03 server01 nginx[7893]: INFO Started worker thread #89
May 10 20:19:32 server01 myapp[5999]: WARNING High memory usage detected: 83%
```

The mix of severities is weighted to match realistic traffic: ~70% INFO, ~20% WARNING, ~10% ERROR.

---

## Cron Automation (`install.sh`)

### Overview

`install.sh` is a one-time setup script that:

1. Verifies `analyzer.sh` and `rotator.sh` are present
2. Makes all scripts executable
3. Creates the required directory structure (`logs/`, `logs/archive/`, `summary/`)
4. Generates a sample log file (via `generate_sample_log.sh`)
5. Registers a **cron job** that runs `analyzer.sh` every hour

### Usage

```bash
bash install.sh
```

### Cron job

The installed cron entry looks like:

```text
0 * * * * /path/to/project/analyzer.sh >> /path/to/project/logs/cron.log 2>&1
```

- Runs at minute 0 of every hour (hourly)
- Output and errors are appended to `logs/cron.log`
- `analyzer.sh` then calls `rotator.sh` automatically at the end of each run

Verify the job is registered:

```bash
crontab -l
```

Remove the job if needed:

```bash
crontab -e   # then delete the line manually
```

---

## Project File Structure

```text
project/
├── analyzer.sh               # Log parser — classifies and counts log entries
├── rotator.sh                # Log rotator — compresses and prunes old logs
├── install.sh                # One-time setup and cron registration
├── generate_sample_log.sh    # Generates a test log file for rotation demo
├── app.pid                   # (runtime) PID of the monitored application
├── logs/
│   ├── app.log               # Active application log (rotated when > 1 MB)
│   ├── cron.log              # Cron execution output
│   └── archive/
│       └── app-<timestamp>.log.gz   # Compressed rotation archives
└── summary/
    └── summary-<timestamp>.txt      # Analysis reports from analyzer.sh
```

---

## Full Workflow

```text
[cron: every hour]
       │
       ▼
 analyzer.sh
  • reads /var/log/syslog, /var/log/auth.log
  • classifies each line (ERROR / WARNING / INFO)
  • writes summary-<timestamp>.txt to ./summary/
  • compares with previous summary (trend diff)
  • adds top error messages, most active file, and error rate
       │
       ▼
 rotator.sh
  • checks ./logs/*.log file sizes
  • rotates files ≥ 1 MB → ./logs/archive/
  • prunes archives beyond the last 5
  • sends SIGUSR2 to app.pid (if present)
```

### Notes

- `analyzer.sh` creates a timestamped snapshot report on each run.
- `crontab` provides the hourly execution, which makes the reports periodic.
- `rotator.sh` only manages custom application logs in `./logs/`.

---

## Short Developer Notes

- `analyzer.sh` is focused on analysis and reporting.
- `rotator.sh` is focused on safe rotation of application logs.
- `install.sh` prepares the project and installs the cron job.
- `generate_sample_log.sh` creates test data for rotation demonstrations.