# Log file Analyzer and Rotator

## Log Analyzer (analyzer.sh)

### Overview

analyzer.sh is a Bash-based log analysis tool that processes system logs and generates summarized reports.  
It is designed to work with common Linux log files such as:

- /var/log/syslog
- /var/log/auth.log

The script scans log entries using keyword-based classification and groups them into three categories:

- ERROR – critical failures, denied actions, crashes, authentication failures
- WARNING – suspicious or potentially problematic events
- INFO – normal system activity and all remaining logs

### Features

- Parses multiple system log files
- Uses regex/keyword matching for classification
- Generates timestamped summary reports
- Stores reports in ./summary/
- Automatically tracks total log statistics:
  - ERROR count
  - WARNING count
  - INFO count
  - TOTAL lines processed
- Compares with previous report (if available) and shows trend changes
- Triggers rotator.sh after analysis (if present)

### Output

Reports are stored in ./summary folder, which creates with analyzer.sh.

### Analyzer launch

Make the script executable:
```bash
chmod +x analyzer.sh
```

Execute script manually:
```bash
./analyzer.sh
```

But cron should execute it automatically, so it's not recomended to launch analyzer.sh manually.