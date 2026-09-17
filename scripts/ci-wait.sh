#!/bin/bash
# Waits for the newest CI run on this branch and prints the pure-modules job result and any compiler errors.
sha=$(git rev-parse HEAD)
for i in $(seq 1 60); do
  run=$(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/repos/paluvadisurya/care/actions/runs?head_sha=$sha&per_page=1" | python3 -c "import sys,json; r=json.load(sys.stdin).get('workflow_runs',[]); print(r[0]['id'] if r else '')")
  [ -n "$run" ] && break; sleep 10
done
[ -z "$run" ] && { echo "no run for $sha"; exit 1; }
while true; do
  js=$(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/repos/paluvadisurya/care/actions/runs/$run/jobs")
  st=$(python3 -c "import sys,json; j=[x for x in json.load(sys.stdin)['jobs'] if x['name'].startswith('Pure')]; print(j[0]['status']+' '+str(j[0]['conclusion'])+' '+str(j[0]['id']) if j else 'none')" <<<"$js")
  set -- $st; [ "$1" = "completed" ] && break; sleep 20
done
echo "run=$run job=$3 conclusion=$2"
curl -sSL -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/repos/paluvadisurya/care/actions/jobs/$3/logs" | grep -E "error:|warning: (var|variable|immutable|unused|never)|Test Suite|Test Case.*(passed|failed)|✘|✔|Executed|error generated|Compiling|Build complete" | sed -E 's/^[0-9T:.\-]+Z //' | sort -u | grep -v "^\[" | head -120
