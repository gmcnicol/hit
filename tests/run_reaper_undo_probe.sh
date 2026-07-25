#!/bin/zsh
set -eu

reaper=/Applications/REAPER.app/Contents/MacOS/REAPER
probe=$PWD/tests/reaper_undo_probe.lua
output=/tmp/hit-reaper-undo-probe.txt
project=/tmp/hit-reaper-undo-probe.rpp
run_id=$$

run_phase() {
  local mode=$1
  local marker=$2
  shift 2

  HIT_UNDO_PROBE_MODE=$mode HIT_UNDO_PROBE_RUN_ID=$run_id \
    "$reaper" -newinst -nosplash "$@" "$probe" >/tmp/hit-reaper-$mode.log 2>&1 &
  local pid=$!

  for attempt in {1..40}; do
    grep -q "^$marker	$run_id$" "$output" 2>/dev/null && break
    sleep 0.25
  done

  if ps -p "$pid" -o command= | grep -q "$reaper"; then
    kill "$pid"
  fi
  wait "$pid" 2>/dev/null || true
  grep -q "^$marker	$run_id$" "$output"
}

run_phase write saved -new
run_phase reload reloaded "$project"
cat "$output"
