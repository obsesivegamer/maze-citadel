#!/usr/bin/env bash
# Renderer experiment matrix, per docs/perf.md: benches every configuration in
# a file on the wave-24 battle (and optionally the idle board), R times, with
# an unchanged control run after every N configurations and a rest between
# runs so the fanless Air doesn't heat up. Odd repeats run the list forwards,
# even ones backwards. A crashed or hung run is recorded and the matrix moves on.
#
# Usage: ALLOW_WINDOW=1 tools/perf_matrix.sh [options] <configs.txt>
#   --preset=balanced          quality preset every run starts from
#   --scenes=battle            battle, idle, or battle,idle
#   --repeats=3                runs per configuration
#   --control-every=4          a control run after every N configurations
#   --rest=60                  seconds between runs (0 with --headless)
#   --seconds=20               measured seconds per run, after a 4 s warm-up
#   --timeout=0                kill a run after this many seconds (0: seconds + 150)
#   --only=a,b                 just these configurations (plus the control)
#   --captures=a,b|all         afterwards, battle PNGs per config and the control
#   --capture-views=full,portal
#   --out=DIR                  default docs/perf/matrix-<MMDD-HHMM>
#   --dry-run                  print the runs and the estimated time; run nothing
#   --headless                 plumbing test without a window; numbers are meaningless
# Config lines are `name | engine args | game args` (tools/perf_matrix.py has
# the details; tools/perf_configs/renderer.txt is an example). Engine args go
# before `--`; `+section/key=value` tokens become a temporary override.cfg for
# that run, which is always removed afterwards.
# Output: runs/<seq>-<name>-<scene>.json and .log, runs.tsv, summary.md.
set -euo pipefail

preset=balanced scenes=battle repeats=3 every=4 rest="" secs=20 timeout=0
only="" captures="" views=full,portal out="" dry=0 headless=0 configs=""
for arg in "$@"; do
  case "$arg" in
    --preset=*) preset="${arg#*=}" ;;
    --scenes=*) scenes="${arg#*=}" ;;
    --repeats=*) repeats="${arg#*=}" ;;
    --control-every=*) every="${arg#*=}" ;;
    --rest=*) rest="${arg#*=}" ;;
    --seconds=*) secs="${arg#*=}" ;;
    --timeout=*) timeout="${arg#*=}" ;;
    --only=*) only="${arg#*=}" ;;
    --captures=*) captures="${arg#*=}" ;;
    --capture-views=*) views="${arg#*=}" ;;
    --out=*) out="${arg#*=}" ;;
    --dry-run) dry=1 ;;
    --headless) headless=1 ;;
    -h | --help) sed -n '2,26p' "$0"; exit 0 ;;
    -*) echo "perf_matrix: unknown option $arg" >&2; exit 2 ;;
    *) configs="$arg" ;;
  esac
done
[[ -n "$configs" ]] || { echo "usage: tools/perf_matrix.sh [options] <configs.txt> (--help)" >&2; exit 2; }
[[ -f "$configs" ]] || { echo "perf_matrix: no such file: $configs" >&2; exit 2; }
if [[ -z "$rest" ]]; then
  rest=60
  if (( headless )); then rest=0; fi
fi
for n in "$repeats" "$every" "$rest" "$secs" "$timeout"; do
  [[ "$n" =~ ^[0-9]+$ ]] || { echo "perf_matrix: numbers must be whole: $n" >&2; exit 2; }
done
if (( ! dry && ! headless )) && [[ "${ALLOW_WINDOW:-}" != 1 ]]; then
  # Opens game windows that take focus. Jeremy uses this Mac, so only run
  # inside an agreed screen-time slot.
  echo "refusing: opens windows; set ALLOW_WINDOW=1 in a screen slot (or --dry-run / --headless)" >&2
  exit 2
fi
configs="$(cd "$(dirname "$configs")" && pwd)/$(basename "$configs")"
case "$out" in
  "" | /*) ;;
  *) out="$PWD/$out" ;;
esac
cd "$(dirname "$0")/.."
[[ -n "$out" ]] || out="$PWD/docs/perf/matrix-$(date +%m%d-%H%M)"
GODOT="${GODOT:-godot}"
PY=(python3 tools/perf_matrix.py)
MARKER="perf_matrix.sh: temporary"
battle=(--autoplay --warp-wave=24 --warp-into=18)
window=(-m -t)
if (( headless )); then window=(--headless); fi
limit=$timeout
(( limit > 0 )) || limit=$(( secs + 150 ))

plan=$("${PY[@]}" plan "$configs" --repeats="$repeats" --control-every="$every" \
  --scenes="$scenes" --only="$only")
nruns=$(grep -c . <<< "$plan")
names=$(cut -d $'\x1f' -f 3 <<< "$plan" | awk '!seen[$0]++')
capture_list=""
if [[ "$captures" == all ]]; then
  capture_list="$names"
elif [[ -n "$captures" ]]; then
  capture_list=$(printf 'control\n%s\n' "${captures//,/$'\n'}" | awk 'NF && !seen[$0]++')
fi
for name in $capture_list; do
  grep -qxF "$name" <<< "$names" || {
    echo "perf_matrix: --captures name not in this matrix: $name" >&2
    exit 2
  }
done
ncaps=$(grep -c . <<< "$capture_list" || true)
if (( headless )); then ncaps=0; fi
nbattle=$(cut -d $'\x1f' -f 5 <<< "$plan" | grep -cx battle || true)
minutes=$("${PY[@]}" estimate "$nbattle" $(( nruns - nbattle )) "$secs" "$rest" "$ncaps")

# Startup-only project settings go in override.cfg next to project.godot.
# Never clobber one that isn't ours; one of ours is left over from a killed run.
child=""
clear_override() {
  if [[ -f override.cfg ]] && grep -qF "$MARKER" override.cfg; then rm -f override.cfg; fi
}
write_override() { # space-separated +section/key=value tokens
  local tokens=()
  read -r -a tokens <<< "$1"
  "${PY[@]}" override-cfg ${tokens[@]+"${tokens[@]}"} > override.cfg
}
cleanup() {
  if [[ -n "$child" ]]; then kill "$child" 2>/dev/null || true; fi
  clear_override
}
if (( ! dry )); then
  if [[ -f override.cfg ]] && ! grep -qF "$MARKER" override.cfg; then
    echo "refusing: override.cfg exists and wasn't written by perf_matrix.sh" >&2
    exit 2
  fi
  clear_override
  trap cleanup EXIT
  trap 'exit 130' INT TERM
fi

# The bench command for one run, one argument per line.
bench_cmd() { # json engine scene game
  local eng=() usr=() sc=()
  if [[ -n "$2" ]]; then read -r -a eng <<< "$2"; fi
  if [[ -n "$4" ]]; then read -r -a usr <<< "$4"; fi
  if [[ "$3" == battle ]]; then sc=("${battle[@]}"); fi
  printf '%s\n' "$GODOT" ${eng[@]+"${eng[@]}"} --path . "${window[@]}" --disable-vsync -- \
    --bench="$secs" --bench-out="$1" --quality="$preset" ${sc[@]+"${sc[@]}"} \
    ${usr[@]+"${usr[@]}"}
}

# Battle PNGs of one configuration via tools/capture.sh (printed on dry runs).
capture() { # name
  local line engine overrides game usr=()
  line=$(awk -F $'\x1f' -v n="$1" '$3 == n { print; exit }' <<< "$plan")
  IFS=$'\x1f' read -r _ _ _ _ _ _ engine overrides game <<< "$line"
  if [[ -n "$game" ]]; then read -r -a usr <<< "$game"; fi
  if (( dry )); then
    echo "capture $1:${overrides:+ override.cfg $overrides;} GODOT_ARGS=\"$engine\"" \
      "tools/capture.sh $out/captures/$1 $views $preset ${battle[*]} $game"
    return 0
  fi
  if [[ -n "$overrides" ]]; then write_override "$overrides"; fi
  GODOT_ARGS="$engine" tools/capture.sh "$out/captures/$1" "$views" "$preset" \
    "${battle[@]}" ${usr[@]+"${usr[@]}"} < /dev/null || echo "capture failed: $1"
  clear_override
}

echo "perf matrix: $nruns runs ($scenes, $repeats repeats, control every $every," \
  "${secs}s + ${rest}s rest), est. $minutes min -> $out"

if (( dry )); then
  while IFS=$'\x1f' read -r seq tag name role scene rep engine overrides game <&3; do
    echo "[$seq/$nruns] $tag ($role, repeat $rep)"
    if [[ -n "$overrides" ]]; then
      "${PY[@]}" override-cfg $overrides | sed 's/^/    override.cfg: /'
    fi
    echo "    $(bench_cmd "$out/runs/$tag.json" "$engine" "$scene" "$game" | tr '\n' ' ')"
  done 3<<< "$plan"
  for name in $capture_list; do capture "$name"; done
  exit 0
fi

mkdir -p "$out/runs"
cp "$configs" "$out/configs.txt"
printf 'preset=%s scenes=%s repeats=%s control_every=%s seconds=%s rest=%s headless=%s started=%s\n' \
  "$preset" "$scenes" "$repeats" "$every" "$secs" "$rest" "$headless" "$(date +%FT%T)" \
  > "$out/params.txt"
printf 'seq\ttag\tname\trole\tscene\trepeat\tstatus\texit\tjson\tlog\tstarted\tended\tengine\toverrides\tgame\n' \
  > "$out/runs.tsv"

while IFS=$'\x1f' read -r seq tag name role scene rep engine overrides game <&3; do
  json="runs/$tag.json"
  log="runs/$tag.log"
  if [[ -n "$overrides" ]]; then write_override "$overrides"; fi
  cmd=()
  while IFS= read -r a; do cmd+=("$a"); done < <(bench_cmd "$out/$json" "$engine" "$scene" "$game")
  started=$(date +%FT%T)
  "${cmd[@]}" < /dev/null > "$out/$log" 2>&1 &
  child=$!
  status=ok
  waited=0
  while kill -0 "$child" 2>/dev/null; do
    if (( waited >= limit )); then
      status=timeout
      kill "$child" 2>/dev/null || true
      sleep 3
      kill -9 "$child" 2>/dev/null || true
      break
    fi
    sleep 1
    waited=$(( waited + 1 ))
  done
  if wait "$child" 2>/dev/null; then rc=0; else rc=$?; fi
  child=""
  clear_override
  # A crash on quit after the report was written still counts; the exit code
  # stays in runs.tsv.
  if [[ "$status" == ok && ! -s "$out/$json" ]]; then
    status=no-json
    if (( rc != 0 )); then status=crashed; fi
  fi
  if [[ "$status" != ok ]]; then
    printf '{"crashed": true, "status": "%s", "exit_code": %d, "label": "%s"}\n' \
      "$status" "$rc" "$tag" > "$out/$json"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$seq" "$tag" "$name" \
    "$role" "$scene" "$rep" "$status" "$rc" "$json" "$log" "$started" "$(date +%FT%T)" \
    "$engine" "$overrides" "$game" >> "$out/runs.tsv"
  echo "[$seq/$nruns] $("${PY[@]}" brief "$out/$json" "$tag")"
  if (( seq < nruns && rest > 0 )); then sleep "$rest"; fi
done 3<<< "$plan"

if [[ -n "$capture_list" ]] && (( headless )); then
  echo "captures skipped: they need a window"
elif [[ -n "$capture_list" ]]; then
  mkdir -p "$out/captures"
  for name in $capture_list; do capture "$name"; done
fi

"${PY[@]}" summarise "$out"
echo "perf matrix done: $out/summary.md"
