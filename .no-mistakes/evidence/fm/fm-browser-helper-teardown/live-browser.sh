#!/bin/bash
set -eu
ROOT=$PWD
LAB=$ROOT/.gate-browser-lab
unset NO_MISTAKES_GATE FM_ROOT_OVERRIDE FM_STATE_OVERRIDE FM_DATA_OVERRIDE FM_CONFIG_OVERRIDE FM_PROJECTS_OVERRIDE FM_GATE_REFUSE_BYPASS FM_PROC_ROOT_OVERRIDE
bin/fm-lab-home.sh create "$LAB"
export FM_HOME=$LAB HOME=$LAB
export CHROME_DEVTOOLS_AXI_SESSION=fm-lab-cleanup
unset FM_BROWSER_HELPER_STATE_OVERRIDE
SOCKDIR=$(bin/fm-lab-home.sh tmux-dir "$LAB")
export TMUX_TMPDIR=$SOCKDIR
cleanup() {
  cd "$ROOT"
  chrome-devtools-axi stop || true
  CHROME_DEVTOOLS_AXI_SESSION=fm-lab-other chrome-devtools-axi stop || true
  if [ -n "${BYSTANDER:-}" ]; then kill "$BYSTANDER" 2>/dev/null || true; fi
  TMUX_TMPDIR="$SOCKDIR" tmux -L fm-lab kill-server || true
  bin/fm-lab-home.sh teardown "$LAB" || true
  rm -rf "$LAB"
}
trap cleanup EXIT
mkdir -p "$LAB/task" "$LAB/other"
printf 'uncommitted work\n' > "$LAB/task/preserved.txt"
tmux -L fm-lab -f /dev/null new-session -d -s fm-lab -n fm-browser -c "$LAB/task" /bin/zsh -f
export TMUX="$SOCKDIR/tmux-$(id -u)/fm-lab,0,0"
cat > "$LAB/state/browser.meta" <<EOF
window=fm-lab:fm-browser
endpoint_task_id=browser
worktree=$LAB/task
project=$LAB/task
harness=claude
kind=secondmate
mode=no-mistakes
EOF
cd "$LAB/task"
chrome-devtools-axi start
chrome-devtools-axi pages || true
cd "$LAB/other"
OLDPWD="$LAB/other" CHROME_DEVTOOLS_AXI_SESSION=fm-lab-other chrome-devtools-axi start
OTHER=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["pid"])' "$LAB/.chrome-devtools-axi/sessions/fm-lab-other/bridge.pid")
cd "$ROOT"
PID=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["pid"])' "$LAB/.chrome-devtools-axi/sessions/fm-lab-cleanup/bridge.pid")
ps -p "$PID" -o pid=,ppid=,command=
. bin/fm-task-process-lib.sh
printf 'real bridge PWD: '; task_process_env_field "$PID" PWD
printf '\n'
ID=browser TASK_PROCESS_SCOPE=browser
task_owned_pids "$LAB/task"
OWNED=$TASK_PIDS
printf 'Owned process identities before exit:\n'
for p in $OWNED; do ps -p "$p" -o pid=,ppid=,comm=; done
bin/fm-control.sh browser exit
kill -0 "$PID"
echo 'SECOND MATE: real bridge survives exit as required'
sed -i '' 's/kind=secondmate/kind=ship/' "$LAB/state/browser.meta"
cp "$LAB/state/browser.meta" "$LAB/meta-before"
(cd "$LAB/task" && exec /bin/sleep 300) &
BYSTANDER=$!
bin/fm-control.sh browser exit
for p in $OWNED; do
  if kill -0 "$p" 2>/dev/null; then echo "FAIL: owned process survives: $p"; exit 1; fi
done
kill -0 "$BYSTANDER"
kill -0 "$OTHER"
echo "OWNERSHIP: unrelated real bridge $OTHER survives"
kill "$BYSTANDER"
BYSTANDER=
cmp "$LAB/meta-before" "$LAB/state/browser.meta"
test "$(cat "$LAB/task/preserved.txt")" = 'uncommitted work'
echo 'SHIP: real bridge and all observed descendants stopped; work, metadata, and unrelated sleeper preserved'
bin/fm-control.sh browser exit
echo 'REPEAT: exit remains successful'
sed -i '' 's/kind=ship/kind=scout/' "$LAB/state/browser.meta"
cd "$LAB/task"
chrome-devtools-axi start
SCOUT_PID=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["pid"])' "$LAB/.chrome-devtools-axi/sessions/fm-lab-cleanup/bridge.pid")
cd "$ROOT"
bin/fm-control.sh browser exit
if kill -0 "$SCOUT_PID" 2>/dev/null; then echo 'FAIL: scout bridge survived'; exit 1; fi
kill -0 "$OTHER"
echo 'SCOUT: owned real bridge stopped; unrelated real bridge survives'
