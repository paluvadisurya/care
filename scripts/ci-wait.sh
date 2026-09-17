#!/bin/bash
# Waits for the newest CI run on HEAD and prints each job's conclusion.
sha=$(git rev-parse HEAD)
for i in $(seq 1 60); do
  run=$(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/repos/paluvadisurya/care/actions/runs?head_sha=$sha&per_page=1" | python3 -c "import sys,json; r=json.load(sys.stdin).get('workflow_runs',[]); print(r[0]['id'] if r else '')")
  [ -n "$run" ] && break; sleep 10
done
[ -z "$run" ] && { echo "no run for $sha"; exit 1; }
while true; do
  js=$(curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/repos/paluvadisurya/care/actions/runs/$run/jobs")
  done_=$(python3 -c "import sys,json; j=json.load(sys.stdin)['jobs']; print('yes' if j and all(x['status']=='completed' for x in j) else 'no')" <<<"$js")
  [ "$done_" = "yes" ] && break; sleep 20
done
python3 -c "import sys,json; [print(x['name'],'->',x['conclusion'],'job',x['id']) for x in json.load(sys.stdin)['jobs']]" <<<"$js"
echo "run=$run"
