#!/bin/bash

# generate_sample_log.sh
# Generates a realistic syslog-style log file at ./logs/app.log.
# The file is intentionally large enough to trigger rotation (>1 MB by default).
# Usage: bash generate_sample_log.sh [line_count]
#        default line_count = 15000

OUTPUT_DIR="./logs"
OUTPUT_FILE="$OUTPUT_DIR/app.log"
LINE_COUNT="${1:-15000}"

mkdir -p "$OUTPUT_DIR"

# Hostname and app names to make entries look realistic
HOSTNAME="$(hostname -s 2>/dev/null || echo 'server01')"
APPS=("myapp" "myapp" "myapp" "nginx" "sshd" "cron" "kernel" "systemd")

# Weighted message pool: ~10% ERROR, ~20% WARNING, ~70% INFO
MESSAGES=(
  # INFO (repeated to weight)
  "INFO Started worker thread #%d"
  "INFO Started worker thread #%d"
  "INFO Started worker thread #%d"
  "INFO Connection accepted from 192.168.1.%d"
  "INFO Connection accepted from 192.168.1.%d"
  "INFO Connection accepted from 192.168.1.%d"
  "INFO Request processed successfully in %dms"
  "INFO Request processed successfully in %dms"
  "INFO Request processed successfully in %dms"
  "INFO User session started for user_%d"
  "INFO User session started for user_%d"
  "INFO Scheduled task completed"
  "INFO Scheduled task completed"
  "INFO Health check passed"
  "INFO Health check passed"
  "INFO Cache refreshed, %d entries loaded"
  "INFO Disk usage at %d%%"
  "INFO Memory usage at %d%%"
  "INFO Config reloaded with no changes"
  "INFO Graceful shutdown initiated"
  # WARNING
  "WARNING High memory usage detected: %d%%"
  "WARNING High memory usage detected: %d%%"
  "WARNING Retry attempt %d for upstream connection"
  "WARNING Retry attempt %d for upstream connection"
  "WARNING Slow query detected: %dms"
  "WARNING Rate limit approached for 10.0.0.%d"
  "WARNING Deprecated API endpoint called"
  "WARNING Low disk space: %d%% remaining"
  # ERROR
  "ERROR authentication failure for user_%d from 10.0.0.%d"
  "ERROR connection refused to 10.0.0.%d:5432"
  "ERROR disk full on /var/log — cannot write"
  "ERROR segfault at address 0x%x — process terminated"
  "ERROR failed to bind to port %d: address already in use"
)

echo "Generating $LINE_COUNT log lines → $OUTPUT_FILE"

{
  for ((i = 1; i <= LINE_COUNT; i++)); do
    # Timestamp: spread over last 24 hours
    seconds_ago=$(( RANDOM % 86400 ))
    ts="$(date -d "-${seconds_ago} seconds" '+%b %d %H:%M:%S' 2>/dev/null \
        || date -v-${seconds_ago}S '+%b %d %H:%M:%S' 2>/dev/null \
        || date '+%b %d %H:%M:%S')"

    app="${APPS[$((RANDOM % ${#APPS[@]}))]}"
    pid=$(( RANDOM % 9000 + 1000 ))
    msg_template="${MESSAGES[$((RANDOM % ${#MESSAGES[@]}))]}"

    # Fill in up to two %d / %x placeholders with random numbers
    # Count placeholders first to avoid printf repeating the format string
    placeholder_count="$(grep -o '%[dx]' <<< "$msg_template" | wc -l)"
    case "$placeholder_count" in
      0) msg="$msg_template" ;;
      1) msg="$(printf "$msg_template" $((RANDOM % 256)))" ;;
      *) msg="$(printf "$msg_template" $((RANDOM % 256)) $((RANDOM % 256)))" ;;
    esac

    echo "$ts $HOSTNAME $app[$pid]: $msg"
  done
} > "$OUTPUT_FILE"

SIZE="$(stat -c%s "$OUTPUT_FILE" 2>/dev/null || stat -f%z "$OUTPUT_FILE")"
echo "Done. File size: ${SIZE} bytes ($(( SIZE / 1024 )) KB)"
echo "Threshold for rotation: 1 MB (1048576 bytes)"
if [[ "$SIZE" -ge 1048576 ]]; then
  echo "→ This file WILL trigger rotation."
else
  echo "→ This file will NOT trigger rotation yet."
  echo "  Run with a larger count: bash generate_sample_log.sh 20000"
fi
