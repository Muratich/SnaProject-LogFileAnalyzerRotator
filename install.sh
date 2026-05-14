#!/bin/bash

# install.sh — Project setup and cron job installer
# Run once from the project root to make scripts executable
# and register the hourly analysis cron job.

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Project directory: $PROJECT_DIR"

# Check required scripts exist

for script in analyzer.sh rotator.sh; do
  if [[ ! -f "$PROJECT_DIR/$script" ]]; then
    echo "ERROR: $script not found in $PROJECT_DIR"
    exit 1
  fi
done

# Make scripts executable

chmod +x "$PROJECT_DIR/analyzer.sh"
chmod +x "$PROJECT_DIR/rotator.sh"
echo "Permissions set on analyzer.sh and rotator.sh"

# Create required directories

mkdir -p "$PROJECT_DIR/logs/archive"
mkdir -p "$PROJECT_DIR/summary"
echo "Directories created: logs/, logs/archive/, summary/"

# Generate a sample log

SAMPLE_LOG="$PROJECT_DIR/logs/app.log"
if [[ ! -f "$SAMPLE_LOG" ]]; then
  echo "Generating sample log file at $SAMPLE_LOG …"
  bash "$PROJECT_DIR/generate_sample_log.sh" 2>/dev/null \
    || echo "(generate_sample_log.sh not found — skipping)"
fi

# Register cron job (runs analyzer.sh every hour)

CRON_ENTRY="0 * * * * $PROJECT_DIR/analyzer.sh >> $PROJECT_DIR/logs/cron.log 2>&1"

# Add only if not already present

if crontab -l 2>/dev/null | grep -qF "$PROJECT_DIR/analyzer.sh"; then
  echo "Cron job already registered — skipping"
else
  (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
  echo "Cron job installed: runs every hour"
fi

echo
echo "Installation complete."
echo
echo "Quick-start commands:"
echo "  ./analyzer.sh          — run analysis now"
echo "  ./rotator.sh           — run rotation now"
echo "  crontab -l             — verify cron entry"
echo "  cat summary/<latest>   — view the latest report"
