#!/bin/bash
# Prints compiler errors from a CI job via the GitHub API (log download goes through the proxy-blocked host, so use the jobs API summary when needed).
job=$1
curl -sSL -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/repos/paluvadisurya/care/actions/jobs/$job/logs" 2>/dev/null | grep -E "error:" | sed -E 's/^[0-9T:.\-]+Z //' | sort -u
