#!/bin/bash
set -u
root=$PWD
scratch=$root/.test-bash32-live
mkdir -p "$scratch/restricted"
ln -sf /usr/bin/perl "$scratch/restricted/perl"
/bin/bash --version | head -1
printf '\nBase regression under PATH without sh:\n'
/bin/bash -uc '. "$1"; PATH="$2"; fm_exec_timed 5 1 /bin/echo command-ran' _ "$scratch/base-timeout.sh" "$scratch/restricted"
rc=$?
echo "base exit=$rc"
[ "$rc" -ne 0 ] || exit 1
printf '\nFixed product under PATH without sh:\n'
/bin/bash -uc '. "$1"; PATH="$2"; fm_exec_timed 5 1 /bin/sh -c "echo command-ran; echo stderr-preserved >&2; exit 7"' _ "$root/bin/fm-timeout-lib.sh" "$scratch/restricted"
rc=$?
echo "fixed exit=$rc"
[ "$rc" -eq 7 ] || exit 1
printf '\nReal backlog command through dispatch timeout interface:\n'
export TASKS_AXI_FILE="$scratch/backlog.md" TASKS_AXI_BACKEND=markdown
 tasks-axi add bash32-proof 'Disposable Bash 3.2 dispatch transition proof' --kind ship --json || exit 1
/bin/bash -uc '. "$1/bin/fm-backlog-transition-lib.sh"; FM_TASKS_AXI_TIMEOUT=10; fm_tasks_axi start bash32-proof --json' _ "$root" || exit 1
tasks-axi show bash32-proof || exit 1
