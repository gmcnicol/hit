#!/bin/zsh
set -eu

reaper=/Applications/REAPER.app/Contents/MacOS/REAPER
probe=$PWD/tests/reaper_idea_probe.lua
output=/tmp/hit-reaper-idea-probe.txt
expected=/tmp/hit-reaper-idea-probe.expected
project=/tmp/hit-reaper-idea-probe.rpp
audio=/System/Library/Sounds/Glass.aiff
run_id=$$

test -x "$reaper"
test -f "$probe"
test -f "$audio"

run_phase() {
  local mode=$1
  local marker=$2
  shift 2
  local log=/tmp/hit-reaper-idea-$mode.log

  HIT_IDEA_PROBE_MODE=$mode HIT_IDEA_PROBE_RUN_ID=$run_id \
    "$reaper" -newinst -nosplash "$@" "$probe" >"$log" 2>&1 &
  local pid=$!

  for attempt in {1..40}; do
    grep -q "^$marker	$run_id$" "$output" 2>/dev/null && break
    sleep 0.25
  done

  if ps -p "$pid" -o command= | grep -q "$reaper"; then
    kill "$pid"
  fi
  wait "$pid" 2>/dev/null || true
  if ! grep -q "^$marker	$run_id$" "$output" 2>/dev/null; then
    test ! -f "$output" || cat "$output" >&2
    cat "$log" >&2
    return 1
  fi
}

run_phase write saved -new
run_phase reload reloaded "$project"
cat "$output"
