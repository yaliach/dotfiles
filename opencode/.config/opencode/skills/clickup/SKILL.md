---
name: clickup
description: >
  Create and list ClickUp tasks through the ClickUp REST API v2. Use whenever the user asks to
  create, open, or add a ClickUp task, ticket, or to-do, or to list tasks, show what is open, or
  check the status of tasks. Contains the list IDs, what belongs in each list, and the repository
  mapped to each list, so the right list is chosen without asking.
---

This skill creates and lists tasks in the user's ClickUp workspace with `curl`. Follow it exactly.

## Authentication

- The personal API token is read from the `CLICKUP_API_TOKEN` environment variable.
- Send it as the raw `Authorization` header value: `Authorization: $CLICKUP_API_TOKEN`.
  Do NOT prefix it with `Bearer`; personal tokens (`pk_...`) are sent as-is.
- Never print, echo, log, or commit the token. To check that it is set, use
  `[ -n "$CLICKUP_API_TOKEN" ] && echo set || echo missing`.
- If it is missing, stop and tell the user to export `CLICKUP_API_TOKEN` (generated in ClickUp under
  Settings > Apps). Do not ask the user to paste the token into the chat.

## Lists

Pick the list whose description best matches the request. The list ID goes in the URL path.

| List Name                 | List ID        | Use for                                                                                                         | Repository                                              |
|---------------------------|----------------|-----------------------------------------------------------------------------------------------------------------|---------------------------------------------------------|
| Automations (n8n)         | `901215539970` | Webhook-based automation triggers, mostly from incoming alerts. E.g. an automation for DLP alerts via Harmony Mail. | N/A                                                     |
| Jobs (n8n)                | `901219055313` | Scheduled, recurring n8n workflows. E.g. a scheduled alert-reminder or enrichment workflow.                     | N/A                                                     |
| Operations (n8n)          | `901219055325` | Automations a human triggers manually. E.g. a workflow to isolate a machine or a file.                          | N/A                                                     |
| AWS Infra                 | `901218925411` | AWS resources managed with Terraform and Kubernetes manifests (FluxCD). E.g. an SQS queue for Telegram messages. | `infra`                                                 |
| Office Infra              | `901219055376` | Office and on-prem infrastructure: network, servers, site-to-site VPN.                                          | N/A                                                     |
| WE Cloud Infra            | `901219055379` | Infrastructure hosted on WE Cloud.                                                                              | N/A                                                     |
| SaaS Infra                | `901219055422` | Configuring external SaaS services. E.g. configure a new OAuth app in Okta.                                     | N/A                                                     |
| Client Portal Application | `901210652918` | Features, fixes and refactors in the customer-facing portal. E.g. add a new dashboard widget.                   | `client-portal-app`                                     |
| Fusion Application        | `901210652945` | Features, fixes and refactors in the Fusion platform. E.g. refactor the Telegram lib to send to SQS.            | `fusion-app`                                            |
| Services                  | `901210652946` | Standalone backend services, collectors and consumers. E.g. a consumer for Telegram messages from the SQS queue. | `fusion-services`, `client-portal-services`, `qradar-archive` |

### Choosing the list

- Match on the request's subject, not on keywords alone. "Create an SQS queue" is AWS Infra;
  "create a consumer that reads from the SQS queue" is Services; "change the Telegram lib to
  use SQS" is Fusion Application.
- A request that spans several lists (e.g. new queue plus a new consumer) becomes one task per
  list, not one combined task. Tell the user the proposed split and get a yes before creating.
- If two lists fit equally well, or none fit, ask the user which one. Do not guess.
- n8n lists differ by trigger: incoming alert/webhook = Automations, schedule = Jobs, human clicks
  to run = Operations.

### Repository

- If the list's repository is not `N/A`, put it in the task description on its own first line:
  `Repository: <name>`.
- The Services list maps to three repositories. Choose one from the request (e.g. a QRadar archive
  task is `qradar-archive`). If it is not clear which one, ask.
- If the repository is `N/A`, leave the line out.

### Statuses

All 10 lists use the same statuses, in this order: `backlog`, `to do`, `in progress`, `stuck`,
`in qa`, `complete`. Use these exact lowercase names for the `status` field and for status filters.
`complete` is the closed status. If a request fails with a status error, re-check the list with
`GET https://api.clickup.com/api/v2/list/{list_id}` (the `statuses` array), because statuses can be
changed in ClickUp.

### Tags

Tags are meaningful in these lists. They usually say which tool or client a task is for, for
example `cortex`, `microsoft-sentinel`, `crowdstrike-falcon`, `qradar`. Tasks with the same name but
different tags are different tasks, not duplicates (e.g. "Create whatever operations the api allow
using alert data" exists once per tool).

To see the tags currently in use, run the listing script and read the Tags column.

## Creating a task

Endpoint: `POST https://api.clickup.com/api/v2/list/{list_id}/task`

Build the JSON body with `jq -n` so quotes, newlines, and special characters in the user's text
are escaped correctly. Never assemble JSON by string concatenation.

```bash
LIST_ID=901218925411

jq -n \
  --arg name "Create SQS queue for Telegram messages" \
  --arg desc "Repository: infra

Provision an SQS queue (Terraform) and the matching FluxCD manifests for Telegram messages." \
  '{name: $name, markdown_content: $desc}' \
| curl -sS -X POST "https://api.clickup.com/api/v2/list/${LIST_ID}/task" \
    -H "Authorization: ${CLICKUP_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data @- \
    -w '\n%{http_code}\n'
```

Then parse the response. The last line is the HTTP status code; the rest is the JSON body.
Report the task `name`, the list name, and `url` (e.g. `https://app.clickup.com/t/9hx`) to the user.

### Before creating: check for duplicates

Run `scripts/list-tasks.sh -l "<list name>"` first (add `-c` to include closed tasks). A task is a
duplicate only if both its **name and its tags** match an existing task. If one matches, show it to
the user and ask whether to create anyway. A same-name task with different tags is not a duplicate;
create it without a warning.

### Tags when creating

- Use the tags the user gave. Match their spelling to existing tags from the listing
  (e.g. `microsoft-sentinel`, not `Microsoft Sentinel`).
- If the request is for a specific tool or client (a SIEM, EDR, or customer) and the user gave no
  tag, ask which tag to use. Do not guess and do not create it untagged without saying so.
- If the request has no tool or client, create it without tags.

### Body fields

Only `name` is required. Set the others only when the user gave the information; never invent them.

| Field              | Type            | Notes                                                                                  |
|--------------------|-----------------|----------------------------------------------------------------------------------------|
| `name`             | string          | Required. Short, specific, starts with a verb (e.g. "Add dashboard widget for ...").   |
| `markdown_content` | string          | Description in Markdown. Preferred over `description`; wins if both are sent.         |
| `description`      | string          | Plain text description. Use only if Markdown is not wanted.                            |
| `priority`         | integer or null | `1` urgent, `2` high, `3` normal, `4` low. Omit unless the user states a priority.    |
| `assignees`        | integer[]       | ClickUp user IDs (numbers, not names or emails). Omit unless known.                   |
| `tags`             | string[]        | Tag names, lowercase as used in the lists. See "Tags" and "Tags when creating".        |
| `status`           | string          | One of the statuses listed under "Statuses". Omit to use the list's default.          |
| `parent`           | string          | An existing task ID in the same list, to create a subtask.                            |

Optional fields that are **omitted by default**. Send them only when the user explicitly asks for
them in that request. Never infer, default, or suggest values for them:

| Field           | Type    | Notes                                                                                   |
|-----------------|---------|-----------------------------------------------------------------------------------------|
| `start_date`    | integer | Unix time in **milliseconds**.                                                          |
| `due_date`      | integer | Unix time in **milliseconds**. Add `"due_date_time": true` only if a time of day is given. |
| `time_estimate` | integer | Milliseconds.                                                                           |

Convert dates with `date -d '2026-11-05 17:00' +%s%3N` (milliseconds).

## Writing the task

- **Name:** one line, imperative, under about 80 characters. No trailing period.
- **Description:** short Markdown. Say what needs to be done and why, plus acceptance points if the
  user gave them. Keep the user's wording and details; do not pad it with invented requirements.
- Start the description with the `Repository:` line when the list has one (see above).
- Do not put secrets, tokens, or credentials in a task.

## Listing tasks and status

Use this when the user asks what tasks exist, what is open, or what the status of a task is.
It is read-only.

Use the script `scripts/list-tasks.sh` (in this skill's directory). It queries the lists, follows
pagination, and prints one markdown table per list with ID (linked), status, priority, assignee,
tags, and name, followed by a total and a count per status.

```bash
S=~/.config/opencode/skills/clickup/scripts/list-tasks.sh

$S                              # all lists, open tasks
$S -l "operations"              # one list (case-insensitive part of the name)
$S -l "automations" -s "in progress"   # filter by status; repeat -s for several
$S -c                           # include closed (complete) tasks
```

- A named list or a clear subject ("infra tasks", "what's open in Services"): use `-l` with the list
  name.
- "All tasks" or no list given: run it with no `-l`.
- Closed tasks are excluded unless the user asks for done/closed/all tasks (`-c`).
- Show the script's output as is. It already trims names, handles empty lists, and prints the totals.
- If the script exits non-zero, report which list failed and the HTTP code it printed.
- A single task by ID ("status of 9hx"): `GET https://api.clickup.com/api/v2/task/{task_id}` with
  `curl`; this is not covered by the script.

If the script is not available, query `GET https://api.clickup.com/api/v2/list/{list_id}/task`
directly with `curl -G` and `--data-urlencode`, following the parameters and pagination below.

### Query parameters (direct API use)

| Parameter                         | Notes                                                                                     |
|-----------------------------------|-------------------------------------------------------------------------------------------|
| `page`                            | Starts at `0`. Each page holds up to 100 tasks.                                           |
| `include_closed=true`             | Closed tasks are **excluded by default**. Add this only when the user asks for done/closed tasks or "all" tasks. |
| `statuses[]=<name>`               | Filter by status. Repeat for several, e.g. `statuses[]=to do&statuses[]=in progress`. Use `--data-urlencode` for the spaces. |
| `subtasks=true`                   | Include subtasks. Off by default.                                                         |
| `order_by`                        | `id`, `created`, `updated`, or `due_date`. Default is `created`.                          |
| `reverse=true`                    | Reverse the order (newest first for `created`/`updated`).                                 |
| `assignees[]=<user_id>`           | Filter by assignee user ID. Only when the user gave one.                                  |
| `tags[]=<name>`                   | Filter by tag. Only when the user asked.                                                  |

### Pagination

The response has `tasks` and a boolean `last_page`. If `last_page` is `false`, request the next
`page` (1, 2, ...) until it is `true`. Do not stop after the first page unless the user asked for a
limited number of tasks.

### What to show

If you query the API directly instead of using the script, show the same table per list,
newest-updated first:

| ID | Status | Priority | Assignee | Tags | Name |
|----|--------|----------|----------|------|------|

- **Status** is `task.status.status`, exactly as ClickUp returns it.
- **Priority** is `task.priority.priority`, or `-` when `null`.
- **Assignee** is the `task.assignees[].username` values, trimmed (ClickUp can return trailing
  spaces), or `-` when empty.
- **Tags** is `task.tags[].name`, or `-` when empty. Always show tags: tasks with the same name can
  differ only by tag.
- Make the ID a link to the task `url`.
- Do not show `start_date`, `due_date`, or `time_estimate` unless the user asked for them. If they
  did, they come back as millisecond strings; convert with `date -d @$((ms/1000))`.
- End with a total and a count per status. Say when closed tasks were excluded.
- For a single task, also show its description, creator, and any parent or subtasks.
- If a list has no tasks, say so in one line. Do not print an empty table.

## Errors

| Status | Meaning                                  | Action                                                                  |
|--------|------------------------------------------|-------------------------------------------------------------------------|
| `200`  | Success                                  | Create: report the `url`. List: show the table.                         |
| `400`  | Invalid body (bad status, bad field)     | Read `err` in the response, fix the field, retry once.                  |
| `401`  | Missing or invalid token                 | Tell the user to check `CLICKUP_API_TOKEN`. Do not retry.               |
| `403`  | Token has no access to the list          | Tell the user. Do not retry.                                            |
| `404`  | List ID not found                        | Re-check the ID against the table above.                                |
| `429`  | Rate limited (100 requests/min)          | Wait about 60 seconds, then retry once.                                 |
| `5xx`  | ClickUp server error                     | Retry once after a few seconds, then report the failure.                |

Do not retry a create request that may have succeeded without first checking, because a retry
creates a duplicate task. If the response was lost (timeout, no output), list the tasks to see
whether it was created before creating it again. Listing is read-only and safe to retry.

## Rules

- Allowed actions: create tasks and list/read tasks. Do not update, delete, close, move, or comment
  on existing tasks unless asked.
- Never create more tasks than the user asked for; confirm the split first when one request maps to
  several lists.
- After creating, report the task URL(s) and the list each went to.
- Never send `start_date`, `due_date`, or `time_estimate` unless the user asked for them.
- Before creating, check for a duplicate (same name and same tags) with the listing script.
- Never treat same-named tasks with different tags as duplicates.
- Ask for the tag when the request is for a specific tool or client and no tag was given.
- If the user's request is vague (no clear subject), ask one short question instead of creating a
  placeholder task.
