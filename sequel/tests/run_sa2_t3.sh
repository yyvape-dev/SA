#!/usr/bin/env bash
set -euo pipefail
project_dir=$(cd "$(dirname "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-godot}
T3_LOG_DIR=${T3_LOG_DIR:-/tmp/sa2-t3-logs}
mkdir -p "$T3_LOG_DIR"
run_case() {
  local label=$1 script=$2 fps=$3
  shift 3
  timeout 100s "$GODOT_BIN" --headless --path "$project_dir" --fixed-fps "$fps" --script "res://tests/$script" "$@" > "$T3_LOG_DIR/$label.log" 2>&1
  python3 - "$T3_LOG_DIR/$label.log" <<'PY'
import sys,pathlib
s=pathlib.Path(sys.argv[1]).read_text()
if not ('PASS' in s or 'SAVED' in s) or any(x in s for x in ['SCRIPT ERROR','ERROR:','FAIL','leaked']):
 print(s);raise SystemExit(1)
print(pathlib.Path(sys.argv[1]).stem+': PASS')
PY
}
run_case t1 sa2_t1_flow_test.gd 60
run_case t15 sa2_t1_5_dialogue_test.gd 60
run_case t2-guard sa2_t2_lily_manual_test.gd 60
run_case t25-recovery sa2_t2_5_recovery_test.gd 60
for fps in 30 600; do run_case "asset-$fps" sa2_t2_asset_wait_test.gd "$fps"; done
run_case t25-input sa2_t2_5_input_test.gd 60
run_case t25-complete-resume sa2_t2_5_input_test.gd 60 -- --resume
for stage in pause-instance resume-instance pause-result resume-result; do run_case "t25-$stage" sa2_t2_5_input_test.gd 60 -- "--$stage"; done
for name in contract state boundaries playable review save_fault legacy_street input; do run_case "t3-$name" "sa2_t3_${name}_test.gd" 60; done
for stage in resume-win loss restart-save restart-resume; do run_case "t3-$stage" sa2_t3_input_test.gd 60 -- "--$stage"; done
