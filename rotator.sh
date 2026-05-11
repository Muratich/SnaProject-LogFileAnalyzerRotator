#!/bin/bash

# rotator.sh — Log Rotation Script
# Rotates log files that exceed a size threshold.
# After rotation, sends SIGUSR2 to a tracked application PID (if available).

# ── Configuration ────────────────────────────────────────────────────────────

LOG_DIR="./logs"
ARCHIVE_DIR="./logs/archive"
PID_FILE="./app.pid"

# Size threshold in bytes (default: 1 MB)
MAX_SIZE_BYTES=$((1 * 1024 * 1024))

# How many rotated archives to keep per log file
MAX_ARCHIVES=5

# ── Helpers ───────────────────────────────────────────────────────────────────

log_msg() {
  echo "[rotator] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

# Returns file size in bytes (cross-distro)
file_size() {
  stat -c%s "$1" 2>/dev/null || echo 0
}

# ── Setup ─────────────────────────────────────────────────────────────────────

mkdir -p "$ARCHIVE_DIR"

rotated_any=false

# ── Main rotation loop ────────────────────────────────────────────────────────

for log_file in "$LOG_DIR"/*.log; do
  # Skip if glob found nothing
  [[ -e "$log_file" ]] || continue

  size="$(file_size "$log_file")"

  if [[ "$size" -lt "$MAX_SIZE_BYTES" ]]; then
    log_msg "SKIP  $(basename "$log_file")  (${size} bytes, under threshold)"
    continue
  fi

  # Build archive name: <basename>-<timestamp>.log.gz
  base="$(basename "$log_file" .log)"
  timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"
  archive_name="${base}-${timestamp}.log.gz"
  archive_path="$ARCHIVE_DIR/$archive_name"

  log_msg "ROTATE $(basename "$log_file")  (${size} bytes → $archive_name)"

  # Compress into archive directory
  if gzip -c "$log_file" > "$archive_path"; then
    # Truncate the original log (keeps the file descriptor open for writers)
    truncate -s 0 "$log_file"
    log_msg "OK    created $archive_path"
    rotated_any=true
  else
    log_msg "ERROR gzip failed for $log_file — skipping"
    rm -f "$archive_path"   # remove partial archive
    continue
  fi

  # ── Prune old archives (keep only MAX_ARCHIVES most recent) ─────────────────
  mapfile -t old_archives < <(
    ls -1t "$ARCHIVE_DIR/${base}-"*.log.gz 2>/dev/null
  )

  if [[ ${#old_archives[@]} -gt $MAX_ARCHIVES ]]; then
    for old in "${old_archives[@]:$MAX_ARCHIVES}"; do
      log_msg "PRUNE $old"
      rm -f "$old"
    done
  fi
done

# ── Send SIGUSR2 to the application ──────────────────────────────────────────

if [[ "$rotated_any" == true ]]; then
  if [[ -f "$PID_FILE" ]]; then
    app_pid="$(cat "$PID_FILE")"

    if [[ -n "$app_pid" ]] && kill -0 "$app_pid" 2>/dev/null; then
      log_msg "SIGNAL sending SIGUSR2 to PID $app_pid"
      kill -SIGUSR2 "$app_pid"
    else
      log_msg "WARN  PID file exists but process $app_pid is not running — skipping signal"
    fi
  else
    log_msg "INFO  no app.pid found — SIGUSR2 not sent"
  fi
else
  log_msg "INFO  no files were rotated — SIGUSR2 not sent"
fi

log_msg "DONE"
