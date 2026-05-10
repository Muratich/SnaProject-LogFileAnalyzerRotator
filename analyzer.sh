#!/bin/bash

LOG_FILES=(
  "/var/log/syslog"
  "/var/log/auth.log"
)

SUMMARY_DIR="./summary"
TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"
REPORT_FILE="$SUMMARY_DIR/summary-$TIMESTAMP.txt"
ROTATOR_SCRIPT="./rotator.sh"

ERROR_WORDS=(
  "error" "critical" "panic" "fail" "failed" "failure" "fatal"
  "denied" "rejected" "invalid" "unauthorized" "forbidden"
  "timeout" "timed out" "refused" "unreachable" "unavailable"
  "crash" "crashed" "segfault" "killed" "terminated"
  "cannot" "unable" "permission denied"
  "authentication failure" "connection refused" "connection reset"
  "no such file" "not found" "disk full" "out of memory"
)

WARNING_WORDS=(
  "warning" "warn" "deprecated" "retry" "retries" "slow"
  "delayed" "suspicious" "unexpected" "rate limit" "throttled"
  "overload" "high usage" "high memory" "low disk" "low memory"
  "partial" "unstable" "temporary" "fallback" "expired"
  "mismatch" "skipped" "ignored" "notice" "alert"
  "attempt" "multiple"
)

contains_word() {
  local line="$1"
  shift

  local word
  for word in "$@"; do
    if [[ "$line" == *"$word"* ]]; then
      return 0
    fi
  done

  return 1
}

classify_line() {
  local line="${1,,}"

  if contains_word "$line" "${ERROR_WORDS[@]}"; then
    echo "ERROR"
  elif contains_word "$line" "${WARNING_WORDS[@]}"; then
    echo "WARNING"
  else
    echo "INFO"
  fi
}

analyze_file() {
  local file="$1"

  local error_count=0
  local warning_count=0
  local info_count=0
  local total_count=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    ((total_count++))

    case "$(classify_line "$line")" in
      ERROR)   ((error_count++)) ;;
      WARNING) ((warning_count++)) ;;
      INFO)    ((info_count++)) ;;
    esac
  done < "$file"

  printf "%s;%s;%s;%s\n" \
    "$error_count" \
    "$warning_count" \
    "$info_count" \
    "$total_count"
}

get_previous_summary() {
  local reports=()
  local file

  for file in "$SUMMARY_DIR"/summary-*.txt; do
    [[ -e "$file" ]] || continue
    [[ "$file" == "$REPORT_FILE" ]] && continue
    reports+=("$file")
  done

  if [[ ${#reports[@]} -eq 0 ]]; then
    echo ""
    return
  fi

  printf '%s\n' "${reports[@]}" | sort | tail -n 1
}

extract_metric() {
  local metric="$1"
  local file="$2"

  grep -E "^${metric}:" "$file" | tail -n 1 | awk '{print $2}'
}

mkdir -p "$SUMMARY_DIR"

{
  echo "Analysis result:"
  echo "Time: $TIMESTAMP"
  echo
  echo "Processed files:"
} > "$REPORT_FILE"

overall_error=0
overall_warning=0
overall_info=0
overall_total=0

for log_file in "${LOG_FILES[@]}"; do
  if [[ ! -r "$log_file" ]]; then
    echo " - NOT READABLE: $log_file" >> "$REPORT_FILE"
    continue
  fi

  echo " - OK: $log_file" >> "$REPORT_FILE"

  IFS=';' read -r error_count warning_count info_count total_count < <(analyze_file "$log_file")

  overall_error=$((overall_error + error_count))
  overall_warning=$((overall_warning + warning_count))
  overall_info=$((overall_info + info_count))
  overall_total=$((overall_total + total_count))
done

{
  echo
  echo "Summary:"
  echo "TOTAL: $overall_total"
  echo "ERROR:   $overall_error"
  echo "WARNING: $overall_warning"
  echo "INFO:    $overall_info"
} >> "$REPORT_FILE"

previous_summary="$(get_previous_summary)"

if [[ -n "$previous_summary" ]]; then
  prev_error="$(extract_metric "ERROR" "$previous_summary")"
  prev_warning="$(extract_metric "WARNING" "$previous_summary")"
  prev_info="$(extract_metric "INFO" "$previous_summary")"

  prev_error="${prev_error:-0}"
  prev_warning="${prev_warning:-0}"
  prev_info="${prev_info:-0}"

  diff_error=$((overall_error - prev_error))
  diff_warning=$((overall_warning - prev_warning))
  diff_info=$((overall_info - prev_info))

  {
    echo
    echo "Comparison with previous summary:"
    echo "ERROR:   $(printf '%+d' "$diff_error")"
    echo "WARNING: $(printf '%+d' "$diff_warning")"
    echo "INFO:    $(printf '%+d' "$diff_info")"
    echo "Previous summary: $previous_summary"
  } >> "$REPORT_FILE"
fi

if [[ -f "$ROTATOR_SCRIPT" ]]; then
  bash "$ROTATOR_SCRIPT"
else
  echo "rotator.sh not found"
fi