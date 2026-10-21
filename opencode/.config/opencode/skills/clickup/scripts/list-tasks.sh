#!/usr/bin/env bash
# List ClickUp tasks as a markdown table per list. Read-only.
#
# Usage: list-tasks.sh [-l <list name or part of it>] [-c] [-s <status>]...
#   -l  only lists whose name contains this text (case-insensitive). Default: all lists.
#   -c  include closed tasks (excluded by default).
#   -s  filter by status name; repeat for several (e.g. -s "to do" -s "in progress").
#
# Requires: curl, jq, and CLICKUP_API_TOKEN in the environment. The token is never printed.

set -uo pipefail

# Keep in sync with the Lists table in SKILL.md.
LISTS=(
  "Automations (n8n)|901215539970"
  "Jobs (n8n)|901219055313"
  "Operations (n8n)|901219055325"
  "AWS Infra|901218925411"
  "Office Infra|901219055376"
  "WE Cloud Infra|901219055379"
  "SaaS Infra|901219055422"
  "Client Portal Application|901210652918"
  "Fusion Application|901210652945"
  "Services|901210652946"
)

filter=""
closed=false
statuses=()

while getopts "l:cs:" opt; do
  case "$opt" in
    l) filter="$OPTARG" ;;
    c) closed=true ;;
    s) statuses+=("$OPTARG") ;;
    *) echo "Usage: $0 [-l list] [-c] [-s status]..." >&2; exit 2 ;;
  esac
done

if [ -z "${CLICKUP_API_TOKEN:-}" ]; then
  echo "CLICKUP_API_TOKEN is not set. Export it and try again." >&2
  exit 1
fi

shopt -s nocasematch
matched=0
total=0
declare -A status_count=()
failed=0

for entry in "${LISTS[@]}"; do
  name=${entry%%|*}
  id=${entry##*|}
  if [ -n "$filter" ] && [[ "$name" != *"$filter"* ]]; then
    continue
  fi
  matched=$((matched + 1))

  args=(--data-urlencode "order_by=updated" --data-urlencode "reverse=true")
  [ "$closed" = true ] && args+=(--data-urlencode "include_closed=true")
  for s in "${statuses[@]+"${statuses[@]}"}"; do
    args+=(--data-urlencode "statuses[]=$s")
  done

  page=0
  all='[]'
  ok=true
  while :; do
    out=$(curl -sS -G "https://api.clickup.com/api/v2/list/${id}/task" \
      -H "Authorization: ${CLICKUP_API_TOKEN}" \
      --data-urlencode "page=${page}" "${args[@]}" -w '\n%{http_code}') || { ok=false; code="curl-error"; break; }
    code=${out##*$'\n'}
    body=${out%$'\n'*}
    if [ "$code" != "200" ]; then
      ok=false
      break
    fi
    all=$(jq -c --argjson a "$all" '$a + .tasks' <<<"$body")
    [ "$(jq -r '.last_page' <<<"$body")" = "true" ] && break
    page=$((page + 1))
  done

  echo "## ${name}"
  if [ "$ok" != true ]; then
    echo "Failed: HTTP ${code} $(jq -r '.err // empty' <<<"${body:-}" 2>/dev/null)"
    echo
    failed=$((failed + 1))
    continue
  fi

  count=$(jq 'length' <<<"$all")
  if [ "$count" -eq 0 ]; then
    echo "No tasks."
    echo
    continue
  fi

  echo "| ID | Status | Priority | Assignee | Tags | Name |"
  echo "|----|--------|----------|----------|------|------|"
  jq -r '.[] | [
      "[" + .id + "](" + .url + ")",
      .status.status,
      (.priority.priority // "-"),
      ([.assignees[].username | gsub("^\\s+|\\s+$"; "")] | join(", ") | if . == "" then "-" else . end),
      ([.tags[].name] | join(", ") | if . == "" then "-" else . end),
      (.name | gsub("\\|"; "/"))
    ] | "| " + join(" | ") + " |"' <<<"$all"
  echo

  total=$((total + count))
  while IFS= read -r s; do
    status_count["$s"]=$(( ${status_count["$s"]:-0} + 1 ))
  done < <(jq -r '.[].status.status' <<<"$all")
done

if [ "$matched" -eq 0 ]; then
  echo "No list matches \"${filter}\"." >&2
  exit 1
fi

summary=""
for s in "${!status_count[@]}"; do
  summary+="${status_count[$s]} ${s}, "
done
echo "Total: ${total}${summary:+ (${summary%, })}"
[ "$closed" = false ] && echo "Closed tasks excluded (use -c to include)."
[ "$failed" -gt 0 ] && exit 1
exit 0
